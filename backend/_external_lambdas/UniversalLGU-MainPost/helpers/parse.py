import json
import re
import base64
from io import BytesIO
from requests_toolbelt.multipart import decoder

def parse_event(event):
    body = event.get('body', '')
    headers = event.get('headers', {})
    ct = headers.get('Content-Type') or headers.get('content-type', '')
    raw = base64.b64decode(body) if event.get('isBase64Encoded') else body.encode('utf-8')

    # admin-web's mainPostClient sends plain JSON (Content-Type:
    # application/json) since it never uploads files -- the Flutter app
    # sends real multipart/form-data for endpoints that do (KYC selfies,
    # ID scans, etc.). Branch on mimetype rather than assuming multipart,
    # or every JSON request raises requests_toolbelt's
    # NonMultipartContentTypeException before routing even happens.
    mimetype = ct.split(';')[0].strip().lower()
    if mimetype == 'application/json':
        data = json.loads(raw.decode('utf-8')) if raw else {}
        return data, []

    parts = decoder.MultipartDecoder(raw, ct)
    data, files = {}, []
    for p in parts.parts:
        cd = p.headers.get(b'Content-Disposition', b'').decode()
        if 'filename' in cd:
            fn = cd.split('filename=')[1].strip('"')
            field = cd.split('name=')[1].split(';')[0].strip('"')
            files.append({'filename': fn, 'content': BytesIO(p.content), 'field_name': field})
        else:
            name = cd.split('name=')[1].strip('"')
            data[name] = p.content.decode('utf-8')
    return data, files

def parse_form_data(data):
    raw = data.get('form_data') or data.get('formData')
    parsed = {}
    if raw:
        if isinstance(raw, bytes):
            raw = raw.decode('utf-8')
        if isinstance(raw, str):
            corrected = re.sub(r"'", '"', raw)
            parsed = json.loads(corrected)
        elif isinstance(raw, dict):
            parsed = raw
    form = parsed.copy()
    for k, v in data.items():
        if k == 'form_data':
            continue
        if k not in form:
            form[k] = v
    return form
