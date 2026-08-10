"""District 6 AI Assistant — Gemini-backed LGU chatbot for the
6th District of Quezon City.

Wraps Gemini's `generateContent` with:
  • A scoped system prompt focused on QC District 6 LGU services.
  • A short District 6 orientation knowledge base baked in.
  • Hard refusal for violent / illegal / generative / off-topic requests.
  • Tagalog-first responses with brief English where helpful.

Usage:
    reply = chat_district6_ai(history)
    # history = [{"role": "user"|"model", "text": "..."}, ...]
"""
import json
import logging
import os
import urllib.request
import urllib.error

logger = logging.getLogger()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')
GEMINI_MODEL = os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')
GEMINI_URL = (
    f'https://generativelanguage.googleapis.com/v1beta/models/'
    f'{GEMINI_MODEL}:generateContent'
)

# Knowledge base: short orientation about the 6th District of Quezon City.
KNOWLEDGE_BASE = """
ORIENTASYON SA 6TH DISTRICT NG QUEZON CITY:

  • Saklaw na barangay ng District 6: Bagong Silangan, Batasan Hills,
    Commonwealth, Holy Spirit, at Payatas. Ito ang pinakamalaking
    distrito ng Quezon City sa populasyon at lawak.
  • Kinatawan sa Kongreso: Cong. Marivic Co-Pilar — kilala sa
    serbisyong-bayan na nakatuon sa kalusugan, edukasyon, kabuhayan,
    at tulong sa mga maralitang pamilya.
  • District Hall / Opisina ng Kinatawan: nasa loob ng Quezon City
    Hall complex, Elliptical Road, Diliman, Quezon City.
  • Paano makipag-ugnayan: gamitin ang app na ito — lahat ng tulong,
    request, at concerns ay maaaring i-submit dito (Social Services,
    Incident Report, Profile Update, Support Ticket, atbp.).
""".strip()

LGU_SERVICES = """
SERBISYONG AVAILABLE SA APP NG DISTRICT 6, QUEZON CITY:

  • Social Services — medical assistance, educational assistance,
    burial assistance, livelihood assistance. Kailangan munang
    ma-verify ang KYC bago makapag-apply.
  • Job Application — listings ng available na trabaho + pag-apply
    online via in-app applicant profile.
  • Smart Card Registration — para sa LGU smart card / ID ng resident.
  • Emergency Hotlines — QC PDRRMO, PNP, BFP, Red Cross, mga ospital
    sa District 6.
  • Incident Report — para sa mga insidente sa komunidad (police,
    fire, natural calamity, public safety).
  • Profile Update Requests — para baguhin ang pangalan, address,
    contact, civil status, atbp. (admin-approved).
  • Support Tickets — magpadala ng katanungan o concern sa LGU staff.
  • Notifications — updates tungkol sa application, request, o announcement.
  • Activity History — listahan ng lahat ng iyong submissions sa app.
  • KYC Verification — selfie + valid ID para ma-unlock ang social services.

WALANG available sa app na ito:
  • Walang Music Player.
  • Walang Legal Consultation form.
  • Walang Atty Tony AI (iba 'yon — para sa Bataan).
""".strip()

SYSTEM_PROMPT = f"""You are "District 6 AI Assistant," a friendly Tagalog/English
assistant for residents of the 6th District of Quezon City, Philippines. You are
inspired by the public service of Cong. Marivic Co-Pilar.

LANGUAGE: Default to conversational Tagalog. Use brief English ONLY for service
names or technical terms. Address the user as "kuya," "ate," or "kabayan" —
warm, never formal-corporate.

YOUR JOB — answer ONLY questions about:
  1. How to use this District 6 LGU app and its features.
  2. LGU services available in District 6, Quezon City (see service list below).
  3. General orientation about the 6th District of QC (barangays, district
     hall location, how to reach the rep's office through this app).

KNOWLEDGE BASE (use this verbatim when relevant):
{KNOWLEDGE_BASE}

{LGU_SERVICES}

HARD REFUSAL — politely decline and redirect if asked to:
  • Plan, justify, glorify, or explain how to commit violence against any
    person (including self-harm).
  • Help create or distribute illegal drugs, firearms, malware, scams,
    forged documents, or any unlawful item.
  • Provide step-by-step instructions for any criminal act.
  • Generate creative or long-form content on demand — NO essay writing,
    NO code generation, NO poems, NO stories, NO homework answers, NO
    long-form drafting of any kind. You are an LGU helpdesk, not a
    generative writing tool.
  • Discuss topics unrelated to the app or District 6 LGU services
    (e.g. coding help, homework, general trivia, recipes, dating advice,
    entertainment, politics outside QC LGU services, national elections,
    showbiz, etc.).

REFUSAL TEMPLATE (Tagalog):
  "Pasensya na po, kabayan — hindi po ako makasagot diyan. Ang tulong ko
   ay tungkol lang sa app na 'to at sa serbisyo ng District 6, Quezon
   City. Pero kung may tanong po kayo paano gamitin ang app o tungkol sa
   LGU services namin — tanungin n'yo ako. 💙"

RESPONSE FORMAT:
  • Keep answers SHORT — 2 to 5 sentences for most questions.
  • For step-by-step procedures (e.g. how to apply for medical assistance),
    use a numbered list.
  • End with ONE suggested next step (e.g. "Gusto mo bang dumiretso sa
    Social Services tab?" or "I-tap n'yo po ang KYC Verification para
    masimulan.").
  • NEVER make up program names, budget figures, or claim official
    statements from Cong. Marivic Co-Pilar — you are an AI assistant,
    not an official spokesperson.
  • If a question needs a real LGU staff response, recommend the in-app
    Support Ticket feature.
""".strip()


def chat_district6_ai(history):
    """Send a chat history to Gemini and return the assistant reply text.

    Args:
        history: list of {"role": "user"|"model", "text": str}.
                 Order is oldest → newest. Last entry must be from "user".

    Returns:
        str — the assistant's reply text. Always non-empty (returns a
        Tagalog fallback on errors so the UI never sees a blank bubble).
    """
    if not GEMINI_API_KEY:
        raise RuntimeError('GEMINI_API_KEY not configured')

    if not history or history[-1].get('role') != 'user':
        raise ValueError('history must end with a user turn')

    contents = [
        {
            'role': 'model' if t.get('role') == 'model' else 'user',
            'parts': [{'text': str(t.get('text', '')).strip()}],
        }
        for t in history if str(t.get('text', '')).strip()
    ]

    payload = {
        'systemInstruction': {'parts': [{'text': SYSTEM_PROMPT}]},
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
        logger.error(f"District 6 AI Gemini HTTP {e.code}: {err_body[:500]}")
        return _fallback_reply()
    except urllib.error.URLError as e:
        logger.error(f"District 6 AI Gemini URL error: {e}")
        return _fallback_reply()

    try:
        parsed = json.loads(body)
        text = parsed['candidates'][0]['content']['parts'][0]['text']
        text = (text or '').strip()
        return text or _fallback_reply()
    except (KeyError, IndexError, TypeError, json.JSONDecodeError):
        logger.error(f"District 6 AI Gemini unexpected response: {body[:500]}")
        return _fallback_reply()


def _fallback_reply():
    return (
        "Pasensya na po, kabayan — may konting problema ang sistema ng "
        "District 6 AI Assistant. Pakisubukan ulit pagkatapos ng ilang "
        "sandali. Salamat po sa pag-intindi. 💙"
    )
