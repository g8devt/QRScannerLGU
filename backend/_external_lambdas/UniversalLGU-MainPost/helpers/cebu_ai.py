"""Cebu AI — Gemini-backed LGU services assistant for the Cebu branch.

Wraps Gemini's `generateContent` with:
  • A scoped system prompt (Cebu LGU app services + general Cebu civic info).
  • Cebuano/Bisaya-first responses with brief English where helpful.
  • Hard refusal for violent / illegal-act / harmful-creation requests.

Usage:
    reply = chat_cebu_ai(history)
    # history = [{"role": "user"|"model", "text": "..."}, ...]
"""
import json
import logging
import os
import urllib.request
import urllib.error

logger = logging.getLogger()

# Prefer a Cebu-dedicated key so this branch can use its own Gemini key
# without affecting the shared GEMINI_API_KEY used by ID-scan / Atty Tony /
# District 6. Falls back to the shared key when the dedicated one is unset.
GEMINI_API_KEY = os.getenv('CEBU_GEMINI_API_KEY') or os.getenv('GEMINI_API_KEY', '')
GEMINI_MODEL = os.getenv('CEBU_GEMINI_MODEL') or os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')
GEMINI_URL = (
    f'https://generativelanguage.googleapis.com/v1beta/models/'
    f'{GEMINI_MODEL}:generateContent'
)

# What the Cebu LGU app actually offers — the assistant should guide users to
# these real in-app flows instead of inventing services.
LGU_SERVICES = """
SERBISYO NGA MA-AVAIL SA APP SA LGU SA CEBU:

  • Social Services Assistance — medical, educational, burial, ug livelihood
    assistance. Kinahanglan og KYC verification (ID upload) una makaapply.
  • Job Application — listahan sa available nga trabaho sa Cebu ug online
    nga pag-apply.
  • Emergency Hotlines — Cebu CDRRMO, PNP, BFP, Red Cross, ug mga ospital.
  • Incident Report — pagreport sa mga insidente sa komunidad (police, fire,
    natural calamity, public safety).
  • Smart Card — pag-request og unified government ID card para mas paspas
    nga access sa tanang serbisyo. Kinahanglan og KYC verification.
  • News & Updates — mga balita ug anunsyo gikan sa LGU.
  • Support — tabang ug pakigsulti sa LGU support team.
  • Profile & Settings — pag-usab sa imong impormasyon ug app preferences.
""".strip()

# Language directive injected into the system prompt based on the request's
# `lang` field (mirrors the app's locale toggle). Defaults to Cebuano.
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
    'ceb': (
        "LANGUAGE: Default to conversational Cebuano/Bisaya. Use brief English "
        "ONLY for service names or technical terms. Address the user warmly as "
        '"bay," "dong," "day," or "kabayan" — friendly, never '
        "formal-corporate."
    ),
}
_DEFAULT_LANG = 'ceb'


def _resolve_lang(lang):
    """Map a request `lang` value to a supported directive key."""
    key = (lang or '').strip().lower()
    if key in ('en', 'eng', 'english'):
        return 'en'
    if key in ('tl', 'fil', 'tagalog', 'filipino'):
        return 'tl'
    if key in ('ceb', 'bis', 'cebuano', 'bisaya'):
        return 'ceb'
    return _DEFAULT_LANG


def _build_system_prompt(lang_key):
    return f"""You are "Cebu Assistant," a warm, helpful AI assistant for
residents of Cebu, Philippines, built into the Cebu LGU mobile app.

{_LANG_DIRECTIVES[lang_key]}

YOUR JOB — help residents with:
  1. Using this Cebu LGU app and its services (see the service list below):
     how to apply, what requirements are needed, where to find a feature,
     and what each service is for.
  2. General Cebu civic / public-service information (LGU offices, basic
     procedures, where to go for common government needs).

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
  • Drift far off-topic from Cebu LGU services or civic help (e.g. coding
    help, homework, general trivia, recipes, entertainment recommendations,
    political endorsements).

REFUSAL STYLE: When you must decline, do so politely IN THE LANGUAGE specified
above, briefly explain you can only help with Cebu LGU services and app usage,
and invite the user to ask about social services, jobs, emergency, etc.

RESPONSE FORMAT:
  • Keep answers SHORT — 3 to 6 sentences for most questions.
  • For step-by-step procedures, use a numbered list.
  • NEVER make up office names, requirements, fees, hotline numbers, or
    statute references — if you are unsure, say so and point the user to the
    in-app Support or the relevant LGU office.
  • You are an AI assistant, not a government officer — never promise
    approval of any application.
""".strip()


def chat_cebu_ai(history, lang=None):
    """Send a chat history to Gemini and return the assistant reply text.

    Args:
        history: list of {"role": "user"|"model", "text": str}.
                 Order is oldest → newest. Last entry must be from "user".
        lang: optional language hint ('en' | 'tl' | 'ceb'); controls the
              reply language. Defaults to Cebuano.

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
        logger.error(f"Cebu AI Gemini HTTP {e.code}: {err_body[:500]}")
        return _fallback_reply(lang_key)
    except urllib.error.URLError as e:
        logger.error(f"Cebu AI Gemini URL error: {e}")
        return _fallback_reply(lang_key)

    try:
        parsed = json.loads(body)
        text = parsed['candidates'][0]['content']['parts'][0]['text']
        text = (text or '').strip()
        return text or _fallback_reply()
    except (KeyError, IndexError, TypeError, json.JSONDecodeError):
        logger.error(f"Cebu AI Gemini unexpected response: {body[:500]}")
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
    'ceb': (
        "Pasayloa ko, bay — naay gamay nga problema ang sistema. "
        "Palihug sulayi pag-usab paglabay sa pipila ka segundo. "
        "Salamat sa imong pasensya. 😊"
    ),
}


def _fallback_reply(lang_key=_DEFAULT_LANG):
    return _FALLBACKS.get(lang_key, _FALLBACKS[_DEFAULT_LANG])
