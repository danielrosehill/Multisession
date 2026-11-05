"""The line layer: a thin client over Twilio's REST API.

Deliberately stdlib-only. Originating a call is one form POST — `To`, `From`,
and either inline TwiML or a URL — and pulling in an SDK to do that would make
tier 0 heavier than the thing it is meant to be cheaper than.

No SIP anywhere. Outbound Twilio calls do not need it; see
docs/architecture.md § Outbound Twilio calls do not need SIP.
"""

from __future__ import annotations

import base64
import json
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any

from .config import TwilioCredentials

API_ROOT = "https://api.twilio.com/2010-04-01"


class TwilioError(Exception):
    """Twilio rejected the request, or the network did."""


def _request(
    method: str,
    url: str,
    credentials: TwilioCredentials,
    *,
    data: dict[str, Any] | None = None,
    timeout: int = 30,
) -> dict[str, Any]:
    body = urllib.parse.urlencode(data).encode() if data else None
    request = urllib.request.Request(url, data=body, method=method)

    token = base64.b64encode(
        f"{credentials.account_sid}:{credentials.auth_token}".encode()
    ).decode()
    request.add_header("Authorization", f"Basic {token}")
    if body:
        request.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        try:
            parsed = json.loads(detail)
            # Twilio's `code` is the useful half — 21211 is an invalid `To`,
            # 21210 an unverified `From`, and so on.
            message = f"{parsed.get('message', detail)} (code {parsed.get('code')})"
        except json.JSONDecodeError:
            message = detail
        raise TwilioError(f"{method} {url} failed with {exc.code}: {message}") from None
    except urllib.error.URLError as exc:
        raise TwilioError(f"{method} {url} failed: {exc.reason}") from None


@dataclass(frozen=True)
class PlacedCall:
    sid: str
    status: str
    to: str
    from_: str
    raw: dict[str, Any]


def create_call(
    credentials: TwilioCredentials,
    *,
    to: str,
    from_: str,
    twiml: str | None = None,
    url: str | None = None,
    machine_detection: str | None = None,
    timeout_seconds: int = 30,
    record: bool = False,
    status_callback: str | None = None,
) -> PlacedCall:
    """Place the call. This is the irreversible step — D6 gates it upstream."""
    if bool(twiml) == bool(url):
        raise ValueError("Pass exactly one of `twiml` or `url`.")

    payload: dict[str, Any] = {"To": to, "From": from_, "Timeout": timeout_seconds}
    if twiml:
        payload["Twiml"] = twiml
    else:
        payload["Url"] = url
        payload["Method"] = "POST"
    if machine_detection:
        payload["MachineDetection"] = machine_detection
    if record:
        payload["Record"] = "true"
    if status_callback:
        payload["StatusCallback"] = status_callback
        payload["StatusCallbackEvent"] = "completed"

    result = _request(
        "POST",
        f"{API_ROOT}/Accounts/{credentials.account_sid}/Calls.json",
        credentials,
        data=payload,
    )
    return PlacedCall(
        sid=result["sid"],
        status=result["status"],
        to=result["to"],
        from_=result["from"],
        raw=result,
    )


def fetch_call(credentials: TwilioCredentials, call_sid: str) -> dict[str, Any]:
    """Current state of one call, including `answered_by` once AMD has run."""
    return _request(
        "GET",
        f"{API_ROOT}/Accounts/{credentials.account_sid}/Calls/{call_sid}.json",
        credentials,
    )


def list_recordings(credentials: TwilioCredentials, call_sid: str) -> list[dict[str, Any]]:
    result = _request(
        "GET",
        f"{API_ROOT}/Accounts/{credentials.account_sid}/Calls/{call_sid}/Recordings.json",
        credentials,
    )
    return result.get("recordings", [])
