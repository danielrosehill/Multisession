"""Loading and validating a call brief.

The brief is the third prompt layer and the only per-call surface. Validation
happens here rather than at dial time so that `write-a-call-brief` can check a
brief without going anywhere near the phone.

Two classes of check, kept apart on purpose:

- *Schema* checks (``schema/brief.schema.json``) — shape, types, required keys.
- *Judgement* checks (``lint``) — things that are structurally valid but will
  land badly when spoken aloud. These are warnings, never errors: the operator
  is allowed to write a four-sentence message if they mean to.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from .config import repo_root

REFUSAL_MARKER = "REFUSAL"


class BriefError(Exception):
    """The brief is unusable. Never a warning — this stops the call."""


@dataclass(frozen=True)
class Brief:
    data: dict[str, Any]
    source: Path | None = None

    @property
    def brief_id(self) -> str:
        return self.data["brief_id"]

    @property
    def tier(self) -> int:
        return self.data["tier"]

    @property
    def operator_name(self) -> str:
        return self.data["operator"]["name"]

    @property
    def recipient(self) -> dict[str, Any]:
        return self.data["recipient"]

    @property
    def message(self) -> str:
        return self.data["message"]

    @property
    def greeting(self) -> str:
        """The words spoken the instant the call is answered.

        Generated when absent, because the AI disclosure is not optional and a
        brief that omits the greeting must not silently produce a call that
        opens with the message and no introduction.
        """
        explicit = self.data.get("greeting")
        if explicit:
            return explicit
        return (
            f"Hello {self.recipient['name']}, this is Claude — I'm an AI assistant, "
            f"and {self.operator_name} asked me to give you a quick call."
        )

    @property
    def voicemail_text(self) -> str | None:
        voicemail = self.data.get("voicemail", {})
        if not voicemail.get("leave_message"):
            return None
        return voicemail.get("text")

    def caps(self) -> tuple[int, int]:
        caps = self.data.get("caps", {})
        return int(caps.get("max_turns", 8)), int(caps.get("max_seconds", 120))


def schema_path() -> Path:
    return repo_root() / "schema" / "brief.schema.json"


def load_schema() -> dict[str, Any]:
    with schema_path().open(encoding="utf-8") as handle:
        return json.load(handle)


def validate(data: dict[str, Any], *, source: Path | None = None) -> Brief:
    """Validate against the schema and the cross-field rules, then wrap."""
    try:
        import jsonschema
    except ModuleNotFoundError:  # pragma: no cover - dependency is declared
        raise BriefError(
            "jsonschema is not installed. Run `uv pip install -e .` in the repo root."
        ) from None

    validator = jsonschema.Draft202012Validator(load_schema())
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
    if errors:
        lines = []
        for error in errors:
            where = "/".join(str(part) for part in error.path) or "(root)"
            lines.append(f"  {where}: {error.message}")
        raise BriefError("Brief failed schema validation:\n" + "\n".join(lines))

    brief = Brief(data=data, source=source)

    # Cross-field rules the schema cannot express usefully.
    if brief.tier == 0 and brief.data.get("anticipated_questions"):
        raise BriefError(
            "Tier 0 has no LLM in the call path, so anticipated_questions can never "
            "be consulted. Either drop them or set tier to 1."
        )
    if brief.data.get("voicemail", {}).get("leave_message") and not brief.voicemail_text:
        raise BriefError("voicemail.leave_message is true but voicemail.text is missing.")

    return brief


def load(path: Path) -> Brief:
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        raise BriefError(f"{path} not found.") from None
    except json.JSONDecodeError as exc:
        raise BriefError(f"{path} is not valid JSON: {exc}") from None
    return validate(data, source=path)


# --------------------------------------------------------------------------- #
# Lint — advisory only
# --------------------------------------------------------------------------- #

_VISUAL_ONLY = re.compile(r"[()\[\]]|^\s*[-*•]\s|\bfirstly\b|\bsecondly\b", re.IGNORECASE | re.MULTILINE)
_CLOCK_TIME = re.compile(r"\b\d{1,2}:\d{2}\b")


def lint(brief: Brief) -> list[str]:
    """Advisory warnings about a brief that is valid but will read badly aloud.

    Every rule here comes from `examples/README.md` § Writing a good message.
    The recurring failure is briefs written as prose to be read rather than
    speech to be heard, and none of it is detectable by a schema.
    """
    warnings: list[str] = []
    message = brief.message

    sentences = [s for s in re.split(r"(?<=[.!?])\s+", message.strip()) if s]
    if len(sentences) > 4:
        warnings.append(
            f"message is {len(sentences)} sentences. Past about four, it is an email, "
            f"not a call."
        )

    if _VISUAL_ONLY.search(message):
        warnings.append(
            "message contains structure that only works visually (parentheses, a list "
            "marker, or 'firstly'). The recipient cannot re-read it."
        )

    if _CLOCK_TIME.search(message):
        warnings.append(
            "message contains a clock time like 14:07. Write times the way a person "
            "says them — 'just after two'."
        )

    if brief.tier == 1:
        if not brief.data.get("closing"):
            warnings.append("tier 1 brief has no closing, so the agent will improvise a goodbye.")
        if not brief.data.get("prohibitions"):
            warnings.append(
                "tier 1 brief has no prohibitions. The standing conduct rules still "
                "apply, but nothing covers what would go wrong on THIS call."
            )
        questions = brief.data.get("anticipated_questions") or []
        if not any(q["answer"].startswith(REFUSAL_MARKER) for q in questions):
            warnings.append(
                "no anticipated question resolves to REFUSAL. 'Can you ask "
                f"{brief.operator_name} to call me?' is the most natural thing a "
                "recipient will say and the point where the model is most likely to "
                "drift into 'I'll let them know'. Consider listing it explicitly."
            )

    if not brief.data.get("voicemail", {}).get("leave_message"):
        warnings.append(
            "voicemail.leave_message is false, so a machine answering means the call "
            "is simply dropped. That is a valid choice; make sure it is a choice."
        )
    elif brief.voicemail_text and "AI" not in brief.voicemail_text:
        warnings.append(
            "voicemail.text does not say 'AI'. Every call identifies itself as an AI "
            "in the first sentence — a voicemail is still a call."
        )

    return warnings


def new_brief_id(slug: str, *, now: datetime | None = None) -> str:
    """Mint a brief_id in the form the schema expects: b_YYYYMMDD_HHMM_<slug>."""
    now = now or datetime.now()
    clean = re.sub(r"[^a-z0-9]+", "_", slug.lower()).strip("_") or "call"
    return f"b_{now:%Y%m%d}_{now:%H%M}_{clean}"
