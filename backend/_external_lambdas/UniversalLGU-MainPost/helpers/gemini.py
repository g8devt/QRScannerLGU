import base64
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

ID_SCAN_PROMPT = (
    "You are an OCR assistant for Philippine government-issued IDs. "
    "Extract the cardholder's printed name, date of birth, gender, address, "
    "and identify which type of ID it is. "
    "Return ONLY a single JSON object with these keys and no other text: "
    '{"id_type": string, "first_name": string, "middle_name": string, '
    '"last_name": string, "suffix": string, "birthdate": string, '
    '"gender": string, "address_line": string, "barangay": string, '
    '"municipality": string, "province": string, "region": string}. '
    "Rules: "
    "- id_type MUST be EXACTLY one of: 'PhilSys/National ID', 'UMID', "
    "  'SSS ID', 'GSIS ID', 'PRC ID', 'Driver\\'s License', 'Passport', "
    "  'Voter\\'s ID', 'Postal ID', 'PhilHealth ID', 'TIN ID', 'NBI Clearance'. "
    "  Use empty string if unsure. "
    "- birthdate MUST be formatted as YYYY-MM-DD. "
    "- gender MUST be exactly 'Male' or 'Female' or empty if unclear. "
    "- address_line is the street / house / lot / building portion only. "
    "- barangay, municipality, province, region each contain just that unit. "
    "  Leave empty if not separately printed on the ID. "
    "- If a field is not visible or unclear, use an empty string. "
    "- Do NOT include titles like MR./MS., just the name. "
    "- Preserve the exact spelling including Ñ and accents. "
    "- If the ID uses 'SURNAME, GIVEN NAME MIDDLE NAME' format, split correctly. "
    "- 'suffix' is Jr./Sr./II/III/IV, not a middle name."
)

def _detect_mime(image_bytes):
    """Detect mime type from magic bytes; fall back to image/jpeg."""
    if len(image_bytes) < 12:
        return 'image/jpeg'
    head = image_bytes[:12]
    if head[:3] == b'\xff\xd8\xff':
        return 'image/jpeg'
    if head[:8] == b'\x89PNG\r\n\x1a\n':
        return 'image/png'
    if head[:4] == b'RIFF' and head[8:12] == b'WEBP':
        return 'image/webp'
    if head[:2] == b'BM':
        return 'image/bmp'
    if head[4:8] == b'ftyp':
        # HEIC/HEIF container
        return 'image/heic'
    return 'image/jpeg'

def scan_id_image(image_bytes, mime_type='image/jpeg'):
    """
    Send an ID photo to Gemini 2.5 Flash and return parsed name/DOB.
    Returns dict with keys: first_name, middle_name, last_name, suffix,
    birthdate (YYYY-MM-DD), raw_text. All values are strings; missing
    fields are empty strings.
    """
    if not GEMINI_API_KEY:
        raise RuntimeError('GEMINI_API_KEY not configured')

    # Re-detect mime from magic bytes — the multipart parser doesn't pass
    # content_type through, and Gemini rejects requests where the declared
    # mime doesn't match the actual image bytes.
    detected = _detect_mime(image_bytes)
    if detected != mime_type:
        logger.info(f"Gemini: mime override {mime_type} -> {detected}")
        mime_type = detected

    logger.info(
        f"Gemini scan: bytes={len(image_bytes)} mime={mime_type} "
        f"head={image_bytes[:8].hex() if image_bytes else 'empty'}"
    )

    b64 = base64.b64encode(image_bytes).decode('ascii')

    payload = {
        'contents': [{
            'parts': [
                {'text': ID_SCAN_PROMPT},
                {'inline_data': {'mime_type': mime_type, 'data': b64}},
            ],
        }],
        'generationConfig': {
            'temperature': 0.0,
            'responseMimeType': 'application/json',
            'responseSchema': {
                'type': 'OBJECT',
                'properties': {
                    'id_type':      {'type': 'STRING'},
                    'first_name':   {'type': 'STRING'},
                    'middle_name':  {'type': 'STRING'},
                    'last_name':    {'type': 'STRING'},
                    'suffix':       {'type': 'STRING'},
                    'birthdate':    {'type': 'STRING'},
                    'gender':       {'type': 'STRING'},
                    'address_line': {'type': 'STRING'},
                    'barangay':     {'type': 'STRING'},
                    'municipality': {'type': 'STRING'},
                    'province':     {'type': 'STRING'},
                    'region':       {'type': 'STRING'},
                },
                'required': ['first_name', 'last_name', 'birthdate'],
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
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        err_body = e.read().decode('utf-8', errors='ignore')
        logger.error(f"Gemini HTTP {e.code}: {err_body}")
        raise RuntimeError(f'Gemini API error: {e.code}')
    except urllib.error.URLError as e:
        logger.error(f"Gemini URL error: {e}")
        raise RuntimeError('Gemini API unreachable')

    parsed = json.loads(body)
    try:
        text = parsed['candidates'][0]['content']['parts'][0]['text']
    except (KeyError, IndexError, TypeError):
        logger.error(f"Gemini unexpected response: {body[:500]}")
        return _empty_result()

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        logger.error(f"Gemini non-JSON text: {text[:500]}")
        return _empty_result()

    return {
        'id_type':      (data.get('id_type') or '').strip(),
        'first_name':   (data.get('first_name') or '').strip(),
        'middle_name':  (data.get('middle_name') or '').strip(),
        'last_name':    (data.get('last_name') or '').strip(),
        'suffix':       (data.get('suffix') or '').strip(),
        'birthdate':    (data.get('birthdate') or '').strip(),
        'gender':       (data.get('gender') or '').strip(),
        'address_line': (data.get('address_line') or '').strip(),
        'barangay':     (data.get('barangay') or '').strip(),
        'municipality': (data.get('municipality') or '').strip(),
        'province':     (data.get('province') or '').strip(),
        'region':       (data.get('region') or '').strip(),
    }

def _empty_result():
    return {
        'id_type': '', 'first_name': '', 'middle_name': '', 'last_name': '',
        'suffix': '', 'birthdate': '', 'gender': '',
        'address_line': '', 'barangay': '', 'municipality': '',
        'province': '', 'region': '',
    }
