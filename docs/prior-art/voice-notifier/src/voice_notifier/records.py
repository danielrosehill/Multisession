"""Call records — one JSON file per call, under `state_dir`.

The record is written before dialling and appended to afterwards, by two
different processes: the CLI places the call, the relay server (if the call is
tier 1) writes the transcript back. `brief_id` is the join key, because it is
the only identifier that exists on both sides — Twilio's call SID does not
reach the relay server until the WebSocket `setup` message arrives.

Volume here is one call at a time, so scanning the directory is the right
amount of machinery. Do not add an index.
"""

from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .brief import Brief
from .config import Settings


def _path(settings: Settings, brief_id: str) -> Path:
    return settings.state_dir / f"{brief_id}.json"


def _write_atomic(path: Path, payload: dict[str, Any]) -> None:
    """Write via a temp file in the same directory, then rename.

    The relay server may be reading this file while the CLI writes it. A rename
    on the same filesystem is atomic, so a reader sees either the old record or
    the new one, never a half-written one.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=path.parent, delete=False, suffix=".tmp"
    )
    try:
        with handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(handle.name, path)
    except BaseException:
        Path(handle.name).unlink(missing_ok=True)
        raise


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def create(settings: Settings, brief: Brief, **fields: Any) -> dict[str, Any]:
    """Open a record at dial time."""
    record = {
        "brief_id": brief.brief_id,
        "tier": brief.tier,
        "created_at": _now(),
        "operator": brief.operator_name,
        "recipient": {
            "key": brief.recipient["key"],
            "name": brief.recipient["name"],
            "number": brief.recipient["number"],
        },
        "brief": brief.data,
        "call_sid": None,
        "status": "pending",
        "answered_by": None,
        "transcript": [],
        "refusals": 0,
        "ended_reason": None,
        **fields,
    }
    _write_atomic(_path(settings, brief.brief_id), record)
    return record


def update(settings: Settings, brief_id: str, **fields: Any) -> dict[str, Any]:
    record = load_by_brief_id(settings, brief_id)
    if record is None:
        raise FileNotFoundError(f"No call record for brief_id {brief_id!r}.")
    record.update(fields)
    record["updated_at"] = _now()
    _write_atomic(_path(settings, brief_id), record)
    return record


def append_turn(settings: Settings, brief_id: str, speaker: str, text: str) -> None:
    """Append one utterance to the transcript.

    The transcript is oversight material, not instruction — see
    docs/plan.md § The transcript is not a return channel.
    """
    record = load_by_brief_id(settings, brief_id)
    if record is None:
        return
    record.setdefault("transcript", []).append(
        {"at": _now(), "speaker": speaker, "text": text}
    )
    record["updated_at"] = _now()
    _write_atomic(_path(settings, brief_id), record)


def load_by_brief_id(settings: Settings, brief_id: str) -> dict[str, Any] | None:
    path = _path(settings, brief_id)
    if not path.exists():
        return None
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_by_call_sid(settings: Settings, call_sid: str) -> dict[str, Any] | None:
    for record in list_records(settings):
        if record.get("call_sid") == call_sid:
            return record
    return None


def load(settings: Settings, identifier: str) -> dict[str, Any] | None:
    """Look up by brief_id or by Twilio call SID, whichever the caller has."""
    return load_by_brief_id(settings, identifier) or load_by_call_sid(settings, identifier)


def list_records(settings: Settings) -> list[dict[str, Any]]:
    if not settings.state_dir.exists():
        return []
    records = []
    for path in sorted(settings.state_dir.glob("*.json")):
        try:
            with path.open(encoding="utf-8") as handle:
                records.append(json.load(handle))
        except json.JSONDecodeError:
            continue
    records.sort(key=lambda r: r.get("created_at", ""), reverse=True)
    return records


def latest(settings: Settings) -> dict[str, Any] | None:
    records = list_records(settings)
    return records[0] if records else None
