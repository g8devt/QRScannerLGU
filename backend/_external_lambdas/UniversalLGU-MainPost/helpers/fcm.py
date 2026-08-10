"""Firebase Cloud Messaging (HTTP v1) sender.

Sends a push to a single device token using the modern HTTP v1 API, which
requires an OAuth2 access token minted from a Firebase service account.

Design notes
------------
- Self-contained: only stdlib (`urllib`, `json`, `base64`, `time`) plus
  `cryptography` for the RS256 JWT signature. The legacy `fcm/send` server-key
  API was shut down by Google in 2024, so HTTP v1 + OAuth is the only option.
- Best-effort: every public function returns `(ok, info)` and never raises, so
  the caller can persist the notification regardless of push delivery.
- The service account JSON is read from the `FCM_SERVICE_ACCOUNT_JSON` env var
  (set the whole JSON blob as the value). Returns a clear status when it is not
  configured so the save path still works in environments without push set up.
- Access tokens are cached in the warm Lambda container until ~1 min before
  expiry to avoid re-signing on every call.
"""

import os
import json
import time
import base64
import logging
import urllib.parse
import urllib.request
import urllib.error

logger = logging.getLogger()

OAUTH_TOKEN_URI = "https://oauth2.googleapis.com/token"
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

# Cached OAuth token for the life of the warm container.
_token_cache = {"access_token": None, "exp": 0}


def _b64url(raw: bytes) -> bytes:
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def _load_service_account():
    """Parse the service account JSON from env, or None when not configured."""
    raw = os.getenv("FCM_SERVICE_ACCOUNT_JSON")
    if not raw or not raw.strip():
        return None
    try:
        sa = json.loads(raw)
        if not sa.get("client_email") or not sa.get("private_key") \
                or not sa.get("project_id"):
            logger.error("FCM service account JSON missing required fields")
            return None
        return sa
    except Exception as e:
        logger.error(f"FCM_SERVICE_ACCOUNT_JSON parse error: {e}")
        return None


def _sign_rs256(message: bytes, private_key_pem: str) -> bytes:
    """RS256 (RSASSA-PKCS1-v1_5 + SHA-256) signature over `message`.

    Uses `cryptography`, which reads the PKCS#8 PEM that service accounts ship.
    Raises if the dependency is unavailable so the caller logs a clear reason.
    """
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    key = serialization.load_pem_private_key(
        private_key_pem.encode("utf-8"), password=None
    )
    return key.sign(message, padding.PKCS1v15(), hashes.SHA256())


def _get_access_token():
    """Mint (or reuse) an OAuth2 access token for FCM. None on failure."""
    now = int(time.time())
    if _token_cache["access_token"] and _token_cache["exp"] - 60 > now:
        return _token_cache["access_token"]

    sa = _load_service_account()
    if not sa:
        return None

    header = {"alg": "RS256", "typ": "JWT"}
    claim = {
        "iss": sa["client_email"],
        "scope": FCM_SCOPE,
        "aud": OAUTH_TOKEN_URI,
        "iat": now,
        "exp": now + 3600,
    }
    signing_input = (
        _b64url(json.dumps(header, separators=(",", ":")).encode())
        + b"."
        + _b64url(json.dumps(claim, separators=(",", ":")).encode())
    )
    try:
        signature = _sign_rs256(signing_input, sa["private_key"])
    except Exception as e:
        logger.error(f"FCM RS256 signing unavailable: {e}")
        return None
    assertion = (signing_input + b"." + _b64url(signature)).decode()

    data = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }).encode()
    req = urllib.request.Request(
        OAUTH_TOKEN_URI,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        logger.error(f"OAuth token HTTPError {e.code}: {e.read().decode()}")
        return None
    except Exception as e:
        logger.error(f"OAuth token error: {e}")
        return None

    token = body.get("access_token")
    if not token:
        return None
    _token_cache["access_token"] = token
    _token_cache["exp"] = now + int(body.get("expires_in", 3600))
    return token


def is_configured() -> bool:
    """True when a usable service account is present."""
    return _load_service_account() is not None


def send_to_token(token, title, body, data=None):
    """Send an FCM HTTP v1 message to one device token.

    `data` (optional) is a flat dict of string-able values delivered as the
    message's data payload (FCM requires all data values to be strings).
    Returns (ok: bool, info: str) — never raises.
    """
    if not token:
        return False, "no_token"

    sa = _load_service_account()
    if not sa:
        return False, "no_service_account"

    access_token = _get_access_token()
    if not access_token:
        return False, "no_access_token"

    project_id = sa["project_id"]
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    message = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
        }
    }
    if data:
        message["message"]["data"] = {k: str(v) for k, v in data.items()}

    payload = json.dumps(message).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return True, resp.read().decode()
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        logger.error(f"FCM send HTTPError {e.code}: {err}")
        return False, f"http_{e.code}"
    except Exception as e:
        logger.error(f"FCM send error: {e}")
        return False, str(e)