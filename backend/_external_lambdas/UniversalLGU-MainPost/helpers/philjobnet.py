"""
Lightweight scraper for the philjobnet.gov.ph public job-vacancies feed.
Parses the public HTML page (no auth, no API key) and returns a JSON-
friendly list of postings. The Flutter app calls a thin lambda endpoint
that wraps this helper.

We don't use any HTML library to keep the lambda lean — the page
structure is stable enough that targeted regex extraction over each
`<div class="jobcard">…</div>` block works reliably. Each posting has
a deterministic detail URL the app opens in the user's browser, so
even if a field is missing we don't break the list.

The plain `/job-vacancies/` front page only ever shows a handful of
nationally "featured" postings (same ~10 regardless of area), not
actual local listings — so filtering that page by location always
returns empty. PhilJobnet exposes a keyword-search route,
`/job-vacancies/0/<term>/0`, that returns real matching postings; we
scrape that instead, per requested area keyword.
"""

import logging
import re
import time
import urllib.parse
import urllib.request
import urllib.error

logger = logging.getLogger()

PHILJOBNET_BASE = 'https://philjobnet.gov.ph'
PHILJOBNET_SEARCH_URL = PHILJOBNET_BASE + '/job-vacancies/0/{term}/0'

# Module-level cache, keyed by search term, so consecutive lambda
# invocations within the same warm container reuse the scrape. 30-min
# TTL — postings change a few times a day, not minute-to-minute.
_CACHE = {}
_CACHE_TTL_SECONDS = 30 * 60

# Each posting on the page is rendered as:
#   <a href="/job-vacancies/job/<slug>-<id>" class="nolink">
#     <div class="jobcard"> … </div>
#   </a>
# We capture the href + the entire jobcard block together so the href
# can never get crossed with a different card's body.
_RE_CARD = re.compile(
    r'<a\s+href="(/job-vacancies/job/[^"]+)"\s+class="nolink"\s*>'
    r'\s*<div\s+class="jobcard">(.*?)</div>\s*</a>',
    re.DOTALL | re.IGNORECASE,
)
_RE_TITLE = re.compile(
    r'<h1\s+class="jobtitle">\s*(.*?)\s*</h1>', re.DOTALL | re.IGNORECASE,
)
_RE_COMPANY = re.compile(
    r'<span\s+class="companytitle">\s*(.*?)\s*</span>',
    re.DOTALL | re.IGNORECASE,
)
_RE_SALARY = re.compile(
    r'<h3\s+class="salary">\s*(.*?)\s*</h3>', re.DOTALL | re.IGNORECASE,
)
_RE_LOGO = re.compile(
    r'<img\s+src="([^"]+)"\s+class="img-thumbnail', re.IGNORECASE,
)
_RE_GEO = re.compile(
    r'bi-geo-alt[^>]*></i>\s*([^<\n]+)', re.IGNORECASE,
)
_RE_EDU = re.compile(
    r'bi-mortarboard[^>]*></i>\s*([^<\n]+)', re.IGNORECASE,
)
_RE_TYPE = re.compile(
    r'bi-file-text[^>]*></i>\s*([^<\n]+)', re.IGNORECASE,
)
_RE_TAG = re.compile(r'<[^>]+>')


def _clean(text):
    if not text:
        return ''
    # Strip tags, collapse whitespace, decode a few common entities.
    text = _RE_TAG.sub('', text)
    text = (text.replace('&amp;', '&').replace('&nbsp;', ' ')
                .replace('&#39;', "'").replace('&quot;', '"'))
    return ' '.join(text.split()).strip()


def _absolutize(path):
    if not path:
        return ''
    if path.startswith('http://') or path.startswith('https://'):
        return path
    if path.startswith('/'):
        return PHILJOBNET_BASE + path
    return f'{PHILJOBNET_BASE}/{path}'


_PLACEHOLDER_VALUES = {
    '₱0.00', '0.00', '₱0', '0',
    'salary not specified', 'educ level not specified',
}


def _normalize(value):
    """Return '' for the site's known placeholder strings."""
    if not value:
        return ''
    return '' if value.strip().lower() in _PLACEHOLDER_VALUES else value


def _parse_listing(html):
    jobs = []
    seen_urls = set()
    cards = _RE_CARD.findall(html)
    logger.info(
        '[philjobnet] html_len=%d cards_matched=%d', len(html), len(cards),
    )
    skipped_no_title = 0
    for href, block in cards:
        url = _absolutize(href)
        # The site repeats the same posting in multiple sections
        # (featured + main list). De-dupe by detail URL.
        if not url or url in seen_urls:
            continue
        title_m = _RE_TITLE.search(block)
        if not title_m:
            skipped_no_title += 1
            continue
        seen_urls.add(url)

        logo_m = _RE_LOGO.search(block)
        geo_m = _RE_GEO.search(block)
        edu_m = _RE_EDU.search(block)
        type_m = _RE_TYPE.search(block)
        salary_m = _RE_SALARY.search(block)
        company_m = _RE_COMPANY.search(block)

        jobs.append({
            'title':       _clean(title_m.group(1)),
            'company':     _clean(company_m.group(1)) if company_m else '',
            'location':    _normalize(_clean(geo_m.group(1))) if geo_m else '',
            'education':   _normalize(_clean(edu_m.group(1))) if edu_m else '',
            'employment_type':
                _normalize(_clean(type_m.group(1))) if type_m else '',
            'salary':      _normalize(_clean(salary_m.group(1)))
                if salary_m else '',
            'logo':        logo_m.group(1) if logo_m else '',
            'url':         url,
        })
    logger.info(
        '[philjobnet] parsed=%d skipped_no_title=%d', len(jobs),
        skipped_no_title,
    )
    return jobs


def _fetch_html(term):
    url = PHILJOBNET_SEARCH_URL.format(term=urllib.parse.quote(term))
    req = urllib.request.Request(
        url,
        headers={
            # PhilJobnet returns a stripped page if the UA looks like
            # curl/python — use a normal browser UA so we get the full
            # job listings.
            'User-Agent': (
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                'AppleWebKit/605.1.15 (KHTML, like Gecko) '
                'Version/17.0 Safari/605.1.15'
            ),
            'Accept': 'text/html,application/xhtml+xml',
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.read().decode('utf-8', errors='replace')


def fetch_job_openings(term='bataan', force_refresh=False):
    """
    Returns a list of job dicts matching the given search term (e.g.
    'bataan', 'pampanga', 'subic'). Uses an in-process 30-minute cache
    per term to avoid hammering philjobnet.gov.ph on every cold/warm
    invocation.
    """
    term = (term or 'bataan').strip().lower()
    cached = _CACHE.get(term, {'fetched_at': 0, 'jobs': []})
    now = time.time()
    if (not force_refresh
            and cached['jobs']
            and (now - cached['fetched_at']) < _CACHE_TTL_SECONDS):
        logger.info(
            '[philjobnet] cache_hit term=%s cached_jobs=%d age_s=%d',
            term, len(cached['jobs']), int(now - cached['fetched_at']),
        )
        return cached['jobs']

    logger.info(
        '[philjobnet] fetching live html term=%s force_refresh=%s',
        term, force_refresh,
    )
    try:
        html = _fetch_html(term)
    except urllib.error.URLError as e:
        logger.error(f'philjobnet fetch failed: {e}')
        # Fall back to whatever we had cached (even if stale) so the
        # app screen isn't blank during a transient outage.
        logger.info(
            '[philjobnet] falling back to stale cache term=%s size=%d',
            term, len(cached['jobs']),
        )
        return cached['jobs']

    try:
        jobs = _parse_listing(html)
    except Exception as e:
        logger.error(f'philjobnet parse error: {e}', exc_info=True)
        logger.info(
            '[philjobnet] falling back to stale cache term=%s size=%d',
            term, len(cached['jobs']),
        )
        return cached['jobs']

    if jobs:
        _CACHE[term] = {'fetched_at': now, 'jobs': jobs}
    else:
        logger.info(
            '[philjobnet] live fetch returned 0 jobs term=%s, '
            'cache not updated', term,
        )
    return jobs
