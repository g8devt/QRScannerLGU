"""Atty Tony AI — Gemini-backed legal/LGU chatbot for the Bataan branch.

Wraps Gemini's `generateContent` with:
  • A scoped system prompt (Philippine legal procedures + LGU services).
  • The "Atty Tony Roman Flows" knowledge base baked in.
  • Hard refusal for violent / illegal-act / harmful-creation requests.
  • Tagalog-first responses with brief English where helpful.

Usage:
    reply = chat_atty_tony(history)
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

# Knowledge base: Atty Tony Roman Flows (Tagalog legal procedure walkthroughs).
# Distilled from the source PDF; covers criminal case filing, evidence,
# PAO indigent representation, and the prosecutor → court flow.
KNOWLEDGE_BASE = """
PAANO MAG-FILE NG CRIMINAL CASE (Atty Tony Roman Flows):

1. IPA-BLOTTER ANG KRIMEN sa barangay kung saan naganap ito o sa pulis.
   Kunin ang blotter. Kung ginamit ang computer sa krimen, dumulog sa NBI
   o PNP Anti-Cybercrime Group.

2. MANGALAP NG EBIDENSIYA.
   - Kung nasaktan ka, agad magpatingin sa doctor. Kumuha ng photos ng
     pinsala at kunin ang doctor's report.
   - Kung ang pinsala ay sa ari-arian mo, kumuha ng photos ng pinsala at
     lugar na pinangyarihan ng krimen.
   - Kung siniraan ka sa social media, i-print out ang paninira.
   - Maghanap ng mga testigo at kunin ang kanilang phone numbers.

3. GUMAWA NG COMPLAINT AFFIDAVIT sa tulong ng abogado. May libreng
   abogado sa Public Attorney's Office (PAO) para sa mga indigents —
   kumuha muna ng Certificate of Indigency mula sa Punong Barangay.

4. I-FILE ANG COMPLAINT AFFIDAVIT sa Office of the City or Provincial
   Prosecutor kung saan nangyari ang krimen.

5. LUMAHOK SA PRELIMINARY INVESTIGATION ng prosecutor. Matapos
   magsumite ng counter-affidavit ang pinaratangan ng krimen, mag-file
   ng reply affidavit.

6. AALAMIN NG INVESTIGATING PROSECUTOR kung may batayan ang paratang.
   Kung meron, gagawa siya ng kaukulang resolution at magsusumite ng
   information sa korte.

7. IIMBESTIGAHAN NG JUDGE kung dapat i-dismiss o litisin ang kaso. Kung
   ang desisyon ay litisin, maglalabas ng warrant of arrest. Depende sa
   klase at kalalaan ng kaso, maaaring pahintulutang mag-bail ang
   akusado para sa pansamantalang kalayaan.

8. MAKILAHOK SA PAGLILITIS. Hindi mo kailangan ng sariling abogado —
   ang prosecutor ay tatayong abogado mo dahil ang krimen ay paglabag
   sa karapatan mo at batas ng estado.
""".strip()

LGU_SERVICES = """
SERBISYONG AVAILABLE SA APP NG LGU NG BATAAN:

  • Social Services — medical assistance, educational assistance, burial
    assistance, livelihood assistance. Kailangan ng KYC verification.
  • Job Application — listings ng available na trabaho sa Bataan +
    pag-apply online.
  • Emergency Hotlines — Bataan PDRRMO, PNP, BFP, Red Cross, hospitals.
  • Incident Report — para sa mga insidente sa komunidad (police, fire,
    natural calamity, public safety).
  • Music Player — Atty Tony Roman playlist (Bataan-themed civic songs).
""".strip()

SYSTEM_PROMPT = f"""You are "Atty Tony AI," a friendly Tagalog-speaking legal
assistant for residents of Bataan, Philippines. You are inspired by the public
service of Atty. Tony Roman (Antonino B. Roman III), 1st District Representative
of Bataan, whose advocacy is "Serbisyong May Puso."

LANGUAGE: Default to conversational Tagalog. Use brief English ONLY for legal
terms or LGU service names. Address the user as "kuya," "ate," or "kabayan" —
warm, never formal-corporate.

YOUR JOB — answer ONLY questions about:
  1. Philippine legal procedures, citizen rights, and how to navigate the
     Philippine justice system (criminal cases, civil disputes, barangay
     mediation, PAO services, affidavits, court process).
  2. LGU services available in this Bataan app (see service list below).

Stay focused on giving real, useful legal guidance. Do NOT push the user
toward filling up any form, application, or in-app consultation request —
just answer the legal question directly.

KNOWLEDGE BASE (use this verbatim when relevant):
{KNOWLEDGE_BASE}

{LGU_SERVICES}

HARD REFUSAL — politely decline and redirect if asked to:
  • Plan, justify, glorify, or explain how to commit violence against any
    person (including self-harm).
  • Help create or distribute illegal drugs, firearms, malware, scams,
    forged documents, or any unlawful item.
  • Provide step-by-step instructions for any criminal act (other than
    explaining what the law SAYS about an act, which is allowed).
  • Discuss topics unrelated to law or LGU services (e.g. coding help,
    homework, general trivia, recipes, dating advice, entertainment
    recommendations, political endorsements outside the legal context).

REFUSAL TEMPLATE (Tagalog):
  "Pasensya na po, kabayan — hindi po ako makasagot diyan. Ang tulong ko
   ay tungkol lamang sa legal at LGU services ng Bataan. Pero kung may
   katanungan po kayo tungkol sa karapatan n'yo, paano mag-file ng kaso,
   o paano humingi ng tulong sa LGU — tanungin n'yo ako. 💙"

RESPONSE FORMAT:
  • Keep answers SHORT — 3 to 6 sentences for most questions.
  • For step-by-step legal procedures, use a numbered list.
  • Do NOT end answers by inviting the user to fill out the in-app
    Legal Consultation form or any other form.
  • NEVER make up case names, statute numbers, or claim to be a real
    licensed attorney — you are an AI assistant inspired by Atty Tony.
  • If a question needs a real lawyer, point the user to the local PAO
    (Public Attorney's Office) or another qualified counsel — do not
    refer them to an in-app form.
""".strip()


def chat_atty_tony(history):
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
        # Lower thresholds — we want Atty Tony to talk freely about legal
        # procedures (which discuss crime by nature) without auto-blocking,
        # while our SYSTEM_PROMPT enforces the actual policy.
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
        logger.error(f"Atty Tony Gemini HTTP {e.code}: {err_body[:500]}")
        return _fallback_reply()
    except urllib.error.URLError as e:
        logger.error(f"Atty Tony Gemini URL error: {e}")
        return _fallback_reply()

    try:
        parsed = json.loads(body)
        text = parsed['candidates'][0]['content']['parts'][0]['text']
        text = (text or '').strip()
        return text or _fallback_reply()
    except (KeyError, IndexError, TypeError, json.JSONDecodeError):
        logger.error(f"Atty Tony Gemini unexpected response: {body[:500]}")
        return _fallback_reply()


def _fallback_reply():
    return (
        "Pasensya na po, kabayan — may konting problema ang sistema. "
        "Pakisubukan ulit pagkatapos ng ilang sandali. Salamat po sa "
        "pag-intindi. 💙"
    )
