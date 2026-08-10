"""
Emergency triage helper. Given a free-text description of an emergency
and the list of hotlines actually available for the user's region,
asks Gemini to:

  1. Categorize the situation (police / fire / medical / disaster /
     utility / general).
  2. Suggest 1-3 specific hotline LABELS from the supplied list (never
     invent phone numbers — the app picks the number from the label).
  3. Return brief first-aid / immediate-action steps in conversational
     Tagalog.

This keeps the AI useful for triage while making it impossible for it
to hallucinate a phone number — the numbers always come from the
curated hotlines.json asset.
"""

import json
import logging
import urllib.request
import urllib.error

from helpers.gemini import GEMINI_API_KEY, GEMINI_URL

logger = logging.getLogger()


_TRIAGE_INSTRUCTIONS = (
    "You are an emergency triage assistant for residents of the "
    "Philippines. The user will describe an emergency situation in "
    "Tagalog or English. You respond with three things: "
    "(1) `category` — ONE of: police, fire, medical, disaster, "
    "utility, general. "
    "(2) `recommended_labels` — an ordered list of 1 to 3 hotline "
    "LABELS chosen ONLY from the provided 'available_hotlines' list. "
    "You MUST NOT invent phone numbers, agency names, or labels that "
    "aren't in the list. If no item in the list fits, pick the most "
    "general one. "
    "(3) `steps` — 2 to 5 short, calm Tagalog steps the user should "
    "do immediately while calling. Do NOT include medical disclaimers "
    "or 'consult a doctor' filler. "
    "(4) `summary` — one short Tagalog sentence acknowledging the "
    "situation. "
    "Never include personal opinions. Never recommend self-help "
    "actions for life-threatening trauma beyond basic stabilization. "
    "If the situation is not actually an emergency (e.g. someone "
    "asking trivia), set category to 'general' and steps to a single "
    "polite redirect."
)


def triage_emergency(description: str, available_hotlines, region: str = ''):
    """
    Args:
      description: user's free-text description of the situation.
      available_hotlines: list of dicts shaped like the entries in
        hotlines.json (need at least 'label' and 'category' keys).
      region: optional region tag (e.g. 'BATAAN') for context.

    Returns dict: {summary, category, steps[], recommended_labels[]}
    """
    if not GEMINI_API_KEY:
        raise RuntimeError('GEMINI_API_KEY not configured')

    desc = (description or '').strip()
    if not desc:
        raise ValueError('Emergency description is required')
    if len(desc) > 1000:
        desc = desc[:1000]

    # Strip down to what the model needs (no numbers).
    labels = []
    for h in available_hotlines or []:
        if not isinstance(h, dict):
            continue
        label = (h.get('label') or '').strip()
        cat = (h.get('category') or '').strip()
        if label:
            labels.append({'label': label, 'category': cat})

    user_block = {
        'region': region or 'unknown',
        'situation': desc,
        'available_hotlines': labels,
    }

    payload = {
        'contents': [{
            'parts': [
                {'text': _TRIAGE_INSTRUCTIONS},
                {'text': 'Input:\n' + json.dumps(user_block,
                                                  ensure_ascii=False)},
            ],
        }],
        'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
            'responseSchema': {
                'type': 'OBJECT',
                'properties': {
                    'summary':             {'type': 'STRING'},
                    'category':            {'type': 'STRING'},
                    'steps':               {
                        'type': 'ARRAY',
                        'items': {'type': 'STRING'},
                    },
                    'recommended_labels':  {
                        'type': 'ARRAY',
                        'items': {'type': 'STRING'},
                    },
                },
                'required': ['summary', 'category', 'steps',
                             'recommended_labels'],
            },
        },
    }

    req = urllib.request.Request(
        f'{GEMINI_URL}?key={GEMINI_API_KEY}',
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            body = resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        err_body = e.read().decode('utf-8', errors='ignore')
        logger.error(f"Gemini triage HTTP {e.code}: {err_body[:500]}")
        raise RuntimeError(f'Triage API error: {e.code}')
    except urllib.error.URLError as e:
        logger.error(f"Gemini triage URL error: {e}")
        raise RuntimeError('Triage API unreachable')

    parsed = json.loads(body)
    try:
        text = parsed['candidates'][0]['content']['parts'][0]['text']
        data = json.loads(text)
    except (KeyError, IndexError, TypeError, json.JSONDecodeError):
        logger.error(f"Triage unexpected response: {body[:500]}")
        return {
            'summary': '',
            'category': 'general',
            'steps': [],
            'recommended_labels': [],
        }

    # Defensively clamp the labels to ones we actually advertised, so
    # the client never sees an invented hotline label.
    allowed_labels = {item['label'] for item in labels}
    rec = [
        (lbl or '').strip()
        for lbl in (data.get('recommended_labels') or [])
        if isinstance(lbl, str)
    ]
    rec = [lbl for lbl in rec if lbl in allowed_labels][:3]

    return {
        'summary': (data.get('summary') or '').strip(),
        'category': (data.get('category') or 'general').strip().lower(),
        'steps': [
            (s or '').strip()
            for s in (data.get('steps') or [])
            if isinstance(s, str) and s.strip()
        ][:5],
        'recommended_labels': rec,
    }
