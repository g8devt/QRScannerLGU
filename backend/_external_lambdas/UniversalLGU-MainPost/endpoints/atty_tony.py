"""Atty Tony AI chat endpoint — Bataan branch only."""
import json
import logging
from helpers.auth import ok, fail, require
from helpers.atty_tony import chat_atty_tony

logger = logging.getLogger()


def atty_tony_chat(cur, data, files, ts):
    """Turn-based chat with Atty Tony AI.

    Request fields:
        user_profile_id: str (required)
        history: JSON-encoded list of {"role": "user"|"model", "text": str}
                 OR a plain `message: str` for single-turn queries.

    Response: { status: True, reply: str }
    """
    try:
        logger.info(
            f"atty_tony_chat called | keys={list(data.keys())} "
            f"user_profile_id={data.get('user_profile_id')!r} "
            f"history_len={len(data.get('history') or '')} "
            f"message_len={len(data.get('message') or '')}"
        )
        require(data, 'user_profile_id')

        history = []
        raw_history = data.get('history')
        if raw_history:
            if isinstance(raw_history, str):
                try:
                    history = json.loads(raw_history)
                except json.JSONDecodeError:
                    return fail('history must be valid JSON')
            elif isinstance(raw_history, list):
                history = raw_history
            else:
                return fail('history must be a list of {role,text}')

        # Accept a single-turn shortcut: just `message`.
        message = (data.get('message') or '').strip()
        if message and not history:
            history = [{'role': 'user', 'text': message}]
        elif message:
            history.append({'role': 'user', 'text': message})

        if not history:
            return fail('Either `message` or `history` is required')

        # Defensive cap — last 12 turns is plenty of context and keeps
        # latency + token spend bounded.
        if len(history) > 12:
            history = history[-12:]

        reply = chat_atty_tony(history)
        return ok({'status': True, 'reply': reply})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"atty_tony_chat error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
