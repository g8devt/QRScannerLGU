"""CSJDM AI — Gemini-backed LGU services assistant for the San Jose Del Monte branch.

Wraps Gemini's `generateContent` with:
  • A scoped system prompt (CSJDM LGU app services + general SJDM civic info).
  • English/Tagalog responses (mirrors the app's locale toggle).
  • Hard refusal for violent / illegal-act / harmful-creation requests.

Usage:
    reply = chat_csjdm_ai(history)
    # history = [{"role": "user"|"model", "text": "..."}, ...]
"""
import json
import logging
import os
import urllib.request
import urllib.error

logger = logging.getLogger()

# Prefer a CSJDM-dedicated key so this branch can use its own Gemini key
# without affecting the shared GEMINI_API_KEY used by ID-scan / Atty Tony /
# District 6 / Cebu. Falls back to the shared key when the dedicated one is unset.
GEMINI_API_KEY = os.getenv('CSJDM_GEMINI_API_KEY') or os.getenv('GEMINI_API_KEY', '')
GEMINI_MODEL = os.getenv('CSJDM_GEMINI_MODEL') or os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')
GEMINI_URL = (
    f'https://generativelanguage.googleapis.com/v1beta/models/'
    f'{GEMINI_MODEL}:generateContent'
)

# What the CSJDM LGU app actually offers — the assistant should guide users to
# these real in-app flows instead of inventing services.
LGU_SERVICES = """
SERVICES AVAILABLE IN THE CSJDM LGU APP:

  • Social Services Assistance — medical, educational, burial, and livelihood
    assistance. Requires KYC verification (ID upload) before applying.
  • Job Application — listing of available jobs in San Jose Del Monte and
    online application.
  • Emergency Hotlines — CSJDM CDRRMO, PNP, BFP, Red Cross, and hospitals.
  • Incident Report — report community incidents (police, fire, natural
    calamity, public safety).
  • Smart Card — request a unified government ID card for faster access to
    all services. Requires KYC verification.
  • Tourism — information about local attractions and destinations.
  • News & Updates — announcements from the LGU.
  • Support — help and messaging with the LGU support team.
  • Profile & Settings — update personal information and app preferences.
""".strip()

# Language directive injected into the system prompt based on the request's
# `lang` field (mirrors the app's locale toggle, which only offers en/tl).
_LANG_DIRECTIVES = {
    'en': (
        "LANGUAGE: Respond in clear, friendly English. Keep it warm and "
        "conversational, never formal-corporate."
    ),
    'tl': (
        "LANGUAGE: Default to conversational Tagalog/Filipino. Use brief "
        "English ONLY for service names or technical terms. Address the user "
        'warmly as "kabayan" — friendly, never formal-corporate.'
    ),
}
_DEFAULT_LANG = 'en'


def _resolve_lang(lang):
    """Map a request `lang` value to a supported directive key."""
    key = (lang or '').strip().lower()
    if key in ('tl', 'fil', 'tagalog', 'filipino'):
        return 'tl'
    return _DEFAULT_LANG


def _build_system_prompt(lang_key):
    return f"""You are the "AI Assistant" for the City Government of San Jose
Del Monte, Bulacan, Philippines, built into the CSJDM LGU mobile app.

{_LANG_DIRECTIVES[lang_key]}

YOUR JOB — help residents with:
  1. Using this CSJDM LGU app and its services (see the service list below):
     how to apply, what requirements are needed, where to find a feature,
     and what each service is for.
  2. General San Jose Del Monte civic / public-service information (LGU
     offices, basic procedures, where to go for common government needs).

Be practical and specific. When a user wants something the app can do, tell
them exactly which in-app service to open and the steps to follow.

KNOWLEDGE BASE (use this when relevant):
{LGU_SERVICES}

HARD REFUSAL — politely decline and redirect if asked to:
  • Plan, justify, glorify, or explain how to commit violence against any
    person (including self-harm).
  • Help create or distribute illegal drugs, firearms, malware, scams,
    forged documents, or any unlawful item.
  • Provide step-by-step instructions for any criminal act.
  • Drift far off-topic from CSJDM LGU services or civic help (e.g. coding
    help, homework, general trivia, recipes, entertainment recommendations,
    political endorsements).

REFUSAL STYLE: When you must decline, do so politely IN THE LANGUAGE specified
above, briefly explain you can only help with CSJDM LGU services and app
usage, and invite the user to ask about social services, jobs, emergency, etc.

RESPONSE FORMAT:
  • Keep answers SHORT — 3 to 6 sentences for most questions.
  • For step-by-step procedures, use a numbered list.
  • NEVER make up office names, requirements, fees, hotline numbers, or
    statute references — if you are unsure, say so and point the user to the
    in-app Support or the relevant LGU office.
  • You are an AI assistant, not a government officer — never promise
    approval of any application.
""".strip()


def chat_csjdm_ai(history, lang=None):
    """Send a chat history to Gemini and return the assistant reply text.

    Args:
        history: list of {"role": "user"|"model", "text": str}.
                 Order is oldest → newest. Last entry must be from "user".
        lang: optional language hint ('en' | 'tl'); controls the reply
              language. Defaults to English.

    Returns:
        str — the assistant's reply text. Always non-empty (returns a
        localized fallback on errors so the UI never sees a blank bubble).
    """
    if not GEMINI_API_KEY:
        raise RuntimeError('GEMINI_API_KEY not configured')

    if not history or history[-1].get('role') != 'user':
        raise ValueError('history must end with a user turn')

    lang_key = _resolve_lang(lang)

    contents = [
        {
            'role': 'model' if t.get('role') == 'model' else 'user',
            'parts': [{'text': str(t.get('text', '')).strip()}],
        }
        for t in history if str(t.get('text', '')).strip()
    ]

    payload = {
        'systemInstruction': {'parts': [{'text': _build_system_prompt(lang_key)}]},
        'contents': contents,
        'generationConfig': {
            'temperature': 0.6,
            'maxOutputTokens': 1024,
            'topP': 0.95,
        },
        'safetySettings': [
            {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_ONLY_HIGH'},
            {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_ONLY_HIGH'},
            {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_LOW_AND_ABOVE'},
            {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_ONLY_HIGH'},
        ],
    }

    req = urllib.request.Request(
        f'{GEMINI_URL}?key={GEMINI_API_KEY}',
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            body = resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        err_body = e.read().decode('utf-8', errors='ignore')
        logger.error(f"CSJDM AI Gemini HTTP {e.code}: {err_body[:500]}")
        return _fallback_reply(lang_key)
    except urllib.error.URLError as e:
        logger.error(f"CSJDM AI Gemini URL error: {e}")
        return _fallback_reply(lang_key)

    try:
        parsed = json.loads(body)
        text = parsed['candidates'][0]['content']['parts'][0]['text']
        text = (text or '').strip()
        return text or _fallback_reply()
    except (KeyError, IndexError, TypeError, json.JSONDecodeError):
        logger.error(f"CSJDM AI Gemini unexpected response: {body[:500]}")
        return _fallback_reply(lang_key)


_FALLBACKS = {
    'en': (
        "Sorry — the system hit a small problem. Please try again in a few "
        "seconds. Thanks for your patience. 😊"
    ),
    'tl': (
        "Pasensya na — may maliit na problema ang sistema. Pakisubukan muli "
        "pagkalipas ng ilang segundo. Salamat sa iyong pasensya. 😊"
    ),
}


def _fallback_reply(lang_key=_DEFAULT_LANG):
    return _FALLBACKS.get(lang_key, _FALLBACKS[_DEFAULT_LANG])
