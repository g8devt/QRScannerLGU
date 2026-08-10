"""Emergency triage endpoint — AI-assisted hotline picker."""
import json
import logging

from helpers.auth import ok, fail, require
from helpers.emergency_triage import triage_emergency

logger = logging.getLogger()


def emergency_triage(cur, data, files, ts):
    """
    Pick the right hotline + first-aid steps for the user's emergency.

    Request fields:
        user_profile_id:     str (required)
        description:         str (required) — what's happening
        region:              str (optional) — e.g. 'BATAAN', 'NCR'
        available_hotlines:  JSON list of {"label": str, "category": str}
                             — the hotlines actually rendered in the app
                             for this user. AI can ONLY recommend labels
                             from this list, so it can never invent
                             phone numbers.

    Response:
        { status: True,
          summary: str,
          category: str,
          steps: [str, ...],
          recommended_labels: [str, ...] }
    """
    try:
        require(data, 'user_profile_id')
        require(data, 'description')

        raw_hotlines = data.get('available_hotlines') or '[]'
        if isinstance(raw_hotlines, str):
            try:
                hotlines = json.loads(raw_hotlines)
            except json.JSONDecodeError:
                return fail('available_hotlines must be valid JSON')
        elif isinstance(raw_hotlines, list):
            hotlines = raw_hotlines
        else:
            return fail('available_hotlines must be a list')

        result = triage_emergency(
            description=str(data.get('description', '')),
            available_hotlines=hotlines,
            region=str(data.get('region') or ''),
        )
        return ok({'status': True, **result})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"emergency_triage error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
