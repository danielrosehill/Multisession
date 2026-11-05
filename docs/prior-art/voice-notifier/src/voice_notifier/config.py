"""Settings, credentials and the recipient allowlist.

Three separate things live here, and the separation is deliberate:

- ``Settings``  — how a call is placed: which line, which hours, where the relay
  server lives.
- ``Recipient`` — who may be called at all. This is the allowlist from D7, and
  the reason it is a file rather than an argument is that Claude must not be
  able to dial a number it inferred from conversation.
- credentials   — resolved at call time from the environment or 1Password.

Live config is ``config/settings.json`` and ``config/recipients.json``, both
git-ignored. The ``.example.json`` files beside them are the committed
templates.
"""

from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, time
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


class ConfigError(Exception):
    """Config is missing, malformed, or contradicts itself."""


def repo_root() -> Path:
    """The repository root, whichever directory the CLI was invoked from."""
    return Path(__file__).resolve().parents[2]


def _read_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        example = path.with_suffix(".example.json")
        hint = f" Copy {example} to {path} and fill it in." if example.exists() else ""
        raise ConfigError(f"{path} not found.{hint}") from None
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{path} is not valid JSON: {exc}") from None


# --------------------------------------------------------------------------- #
# Credentials
# --------------------------------------------------------------------------- #


def resolve_secret(spec: dict[str, str], *, what: str) -> str:
    """Resolve one secret from an ``{"env": ..., "op": ...}`` spec.

    Environment first, 1Password second. Both may be present: the env var wins
    when set, so a shell export overrides the vault without editing config.
    """
    env_name = spec.get("env")
    if env_name:
        value = os.environ.get(env_name)
        if value:
            return value

    op_ref = spec.get("op")
    if op_ref:
        try:
            result = subprocess.run(
                ["op", "read", op_ref],
                capture_output=True,
                text=True,
                check=True,
                timeout=30,
            )
        except FileNotFoundError:
            raise ConfigError(
                f"{what}: `op` is not installed and ${env_name} is unset."
            ) from None
        except subprocess.CalledProcessError as exc:
            raise ConfigError(
                f"{what}: `op read {op_ref}` failed: {exc.stderr.strip()}"
            ) from None
        return result.stdout.strip()

    raise ConfigError(
        f"{what}: no credential source. Set ${env_name} or add an `op` reference."
    )


@dataclass(frozen=True)
class TwilioCredentials:
    account_sid: str
    auth_token: str


# --------------------------------------------------------------------------- #
# Settings
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class CallingHours:
    timezone: str
    earliest: time
    latest: time

    def contains(self, moment: datetime) -> bool:
        local = moment.astimezone(ZoneInfo(self.timezone))
        return self.earliest <= local.time() <= self.latest

    def describe(self) -> str:
        return (
            f"{self.earliest.strftime('%H:%M')}–{self.latest.strftime('%H:%M')} "
            f"{self.timezone}"
        )


@dataclass(frozen=True)
class Tier1Settings:
    relay_websocket_url: str
    tts_provider: str = "ElevenLabs"
    voice: str = ""
    model: str = "claude-opus-5"
    effort: str = "low"


@dataclass(frozen=True)
class Settings:
    operator_name: str
    from_number: str
    from_number_label: str
    credentials_spec: dict[str, dict[str, str]]
    calling_hours: CallingHours
    machine_detection: str = "DetectMessageEnd"
    call_timeout_seconds: int = 30
    record: bool = False
    tier1: Tier1Settings | None = None
    state_dir: Path = field(default_factory=lambda: repo_root() / "var" / "calls")

    def credentials(self) -> TwilioCredentials:
        return TwilioCredentials(
            account_sid=resolve_secret(
                self.credentials_spec.get("account_sid", {}), what="account_sid"
            ),
            auth_token=resolve_secret(
                self.credentials_spec.get("auth_token", {}), what="auth_token"
            ),
        )


def _parse_hhmm(value: str, *, what: str) -> time:
    try:
        hours, minutes = value.split(":")
        return time(int(hours), int(minutes))
    except (ValueError, AttributeError):
        raise ConfigError(f"{what}: expected HH:MM, got {value!r}") from None


def load_settings(path: Path | None = None) -> Settings:
    path = path or repo_root() / "config" / "settings.json"
    raw = _read_json(path)

    for required in ("operator_name", "from_number", "credentials", "calling_hours"):
        if required not in raw:
            raise ConfigError(f"{path}: missing required key {required!r}.")

    hours_raw = raw["calling_hours"]
    hours = CallingHours(
        timezone=hours_raw.get("timezone", "UTC"),
        earliest=_parse_hhmm(hours_raw.get("earliest", "08:00"), what="calling_hours.earliest"),
        latest=_parse_hhmm(hours_raw.get("latest", "21:00"), what="calling_hours.latest"),
    )

    tier1_raw = raw.get("tier1") or {}
    tier1 = (
        Tier1Settings(
            relay_websocket_url=tier1_raw["relay_websocket_url"],
            tts_provider=tier1_raw.get("tts_provider", "ElevenLabs"),
            voice=tier1_raw.get("voice", ""),
            model=tier1_raw.get("model", "claude-opus-5"),
            effort=tier1_raw.get("effort", "low"),
        )
        if tier1_raw.get("relay_websocket_url")
        else None
    )

    state_dir = Path(raw.get("state_dir", "var/calls"))
    if not state_dir.is_absolute():
        state_dir = repo_root() / state_dir

    return Settings(
        operator_name=raw["operator_name"],
        from_number=raw["from_number"],
        from_number_label=raw.get("from_number_label", "Claude"),
        credentials_spec=raw["credentials"],
        calling_hours=hours,
        machine_detection=raw.get("machine_detection", "DetectMessageEnd"),
        call_timeout_seconds=int(raw.get("call_timeout_seconds", 30)),
        record=bool(raw.get("record", False)),
        tier1=tier1,
        state_dir=state_dir,
    )


# --------------------------------------------------------------------------- #
# Allowlist
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Recipient:
    key: str
    name: str
    number: str
    relationship: str = ""
    language: str = "en-GB"


class NotOnAllowlist(Exception):
    """The recipient is absent from the allowlist, or its number disagrees.

    Raised rather than returned so that no code path can dial past it by
    forgetting to check a boolean.
    """


def allowlist_path() -> Path:
    return repo_root() / "config" / "recipients.json"


def load_allowlist(path: Path | None = None) -> dict[str, Recipient]:
    path = path or allowlist_path()
    raw = _read_json(path)
    entries = raw.get("recipients")
    if not isinstance(entries, list):
        raise ConfigError(f"{path}: expected a top-level `recipients` array.")

    allowlist: dict[str, Recipient] = {}
    for entry in entries:
        try:
            recipient = Recipient(
                key=entry["key"],
                name=entry["name"],
                number=entry["number"],
                relationship=entry.get("relationship", ""),
                language=entry.get("language", "en-GB"),
            )
        except KeyError as exc:
            raise ConfigError(f"{path}: recipient entry missing {exc}.") from None
        if recipient.key in allowlist:
            raise ConfigError(f"{path}: duplicate recipient key {recipient.key!r}.")
        allowlist[recipient.key] = recipient
    return allowlist


def check_allowed(key: str, number: str, allowlist: dict[str, Recipient]) -> Recipient:
    """Return the allowlist entry, or raise.

    Both halves matter. The key proves the operator nominated this person; the
    number match proves the brief is dialling the person the key names, and not
    a number Claude reconstructed from somewhere else in the session.
    """
    recipient = allowlist.get(key)
    if recipient is None:
        known = ", ".join(sorted(allowlist)) or "(allowlist is empty)"
        raise NotOnAllowlist(
            f"Recipient {key!r} is not on the allowlist. Known keys: {known}. "
            f"Add them with `voice-notifier recipients add` before calling."
        )
    if recipient.number != number:
        raise NotOnAllowlist(
            f"Recipient {key!r} is on the allowlist as {recipient.number}, but the "
            f"brief says {number}. Refusing to dial. Fix the brief, or update the "
            f"allowlist deliberately if the number really changed."
        )
    return recipient
