"""Public Philippine job openings — scraped from philjobnet.gov.ph."""
import logging

from helpers.auth import ok, fail
from helpers.philjobnet import fetch_job_openings

logger = logging.getLogger()


# PhilJobnet location strings vary ("CITY OF BALANGA, BATAAN",
# "MARIVELES, BATAAN", "ANGELES CITY", "SUBIC, ZAMBALES", etc.) so for
# each supported area we keyword-match case-insensitively against the
# province plus its component cities/municipalities. The province name
# alone catches most postings (PhilJobnet usually appends it); the LGU
# names catch independent/highly-urbanized cities that omit the province.
LOCATION_FILTERS = {
    # Bataan province: 11 municipalities + 1 component city.
    'BATAAN': (
        'bataan',
        'abucay', 'bagac', 'balanga', 'dinalupihan', 'hermosa', 'limay',
        'mariveles', 'morong', 'orani', 'orion', 'pilar', 'samal',
    ),
    # Subic (town + Subic Bay Freeport Zone) in Zambales, plus the
    # adjacent Olongapo City that shares the SBFZ labor market.
    'SUBIC': (
        'subic', 'olongapo',
    ),
    # Pampanga province: capital + component cities + municipalities.
    'PAMPANGA': (
        'pampanga',
        'angeles', 'mabalacat', 'san fernando', 'apalit', 'arayat',
        'bacolor', 'candaba', 'floridablanca', 'guagua', 'lubao',
        'macabebe', 'magalang', 'masantol', 'mexico', 'minalin',
        'porac', 'san luis', 'san simon', 'santa ana', 'santa rita',
        'santo tomas', 'sasmuan',
    ),
}

# Default area when no (or an unrecognized) `location` is requested.
DEFAULT_LOCATION = 'BATAAN'


def _resolve_location(raw) -> str:
    """Normalize a requested `location` to a key in LOCATION_FILTERS.

    Falls back to DEFAULT_LOCATION (Bataan) for empty/unknown values so
    the screen always has a sensible default.
    """
    key = str(raw or '').strip().upper()
    return key if key in LOCATION_FILTERS else DEFAULT_LOCATION


def _matches_location(location: str, area_key: str) -> bool:
    if not location:
        return False
    loc = location.lower()
    return any(k in loc for k in LOCATION_FILTERS[area_key])


def list_job_openings(cur, data, files, ts):
    """
    Return the current public job openings from philjobnet.gov.ph,
    filtered to a requested area (Bataan by default).

    Pass `location=BATAAN|SUBIC|PAMPANGA` to choose the area; unknown or
    missing values fall back to Bataan.
    Pass `force_refresh=1` to bypass the in-process cache.
    Pass `all_locations=1` to disable the area filter (admin / debug).

    Response:
        { status: True, location: 'BATAAN', jobs: [
            { title, company, location, education,
              employment_type, salary, logo, url }, ...
          ] }
    """
    try:
        force = str(data.get('force_refresh') or '').lower() in (
            '1', 'true', 'yes',
        )
        all_locations = str(data.get('all_locations') or '').lower() in (
            '1', 'true', 'yes',
        )
        area = _resolve_location(data.get('location'))
        # Use the area's primary keyword (first entry in its filter
        # tuple) as the PhilJobnet search term, e.g. BATAAN -> 'bataan'.
        term = LOCATION_FILTERS[area][0]
        jobs = fetch_job_openings(term=term, force_refresh=force)
        total = len(jobs)
        # Log every location string so we can see whether PhilJobnet
        # is even returning any postings for this area right now.
        locations = [j.get('location', '') for j in jobs]
        logger.info(
            '[list_job_openings] fetched=%d area=%s all_locations=%s '
            'locations=%s', total, area, all_locations, locations,
        )
        if not all_locations:
            kept = [
                j for j in jobs
                if _matches_location(j.get('location', ''), area)
            ]
            logger.info(
                '[list_job_openings] area=%s filter kept=%d dropped=%d',
                area, len(kept), total - len(kept),
            )
            jobs = kept
        return ok({'status': True, 'location': area, 'jobs': jobs})
    except Exception as e:
        logger.error(f'list_job_openings error: {e}', exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
