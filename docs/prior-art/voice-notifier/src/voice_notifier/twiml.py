"""TwiML rendering.

Two shapes, one per tier:

- **Tier 0** is `<Say>`. Claude writes the words *before* dialling and the call
  itself is a dumb pipe — it is impossible for it to say something unplanned.
- **Tier 1** is `<Connect><ConversationRelay>`, which hands the live call to the
  WebSocket server in `relay_server.py`. The brief does not travel in the TwiML;
  only `brief_id` does, as a custom parameter.

Everything here is a pure function of a `Brief` plus `Settings`, so it can be
inspected with `voice-notifier render-twiml` without touching the phone.
"""

from __future__ import annotations

from xml.sax.saxutils import escape, quoteattr

from .brief import Brief
from .config import Settings

# Twilio's own AMD vocabulary. `human` and `unknown` get the live path;
# everything else is a machine of some description.
MACHINE_ANSWERS = frozenset(
    {
        "machine_start",
        "machine_end_beep",
        "machine_end_silence",
        "machine_end_other",
        "fax",
    }
)


def _say(text: str, language: str) -> str:
    return f"<Say language={quoteattr(language)}>{escape(text)}</Say>"


def render_tier0(brief: Brief, *, voicemail: bool = False) -> str:
    """A one-way spoken announcement.

    `voicemail=True` renders the brief's voicemail wording instead of the live
    greeting and message. That path is only reachable when a public TwiML URL is
    configured, because branching on who answered requires Twilio to ask us
    after the fact — see `docs/deployment.md`.
    """
    language = brief.recipient.get("language", "en-GB")
    parts = ["<Response>"]

    if voicemail:
        text = brief.voicemail_text
        if not text:
            # leave_message is false: say nothing, hang up. Deliberately not an
            # error — declining to talk to an answering machine is a valid brief.
            parts.append("<Hangup/>")
            parts.append("</Response>")
            return "".join(parts)
        parts.append(_say(text, language))
    else:
        parts.append(_say(brief.greeting, language))
        parts.append('<Pause length="1"/>')
        parts.append(_say(brief.message, language))
        closing = brief.data.get("closing")
        if closing:
            parts.append(_say(closing, language))

    parts.append("<Hangup/>")
    parts.append("</Response>")
    return "".join(parts)


def render_tier1(brief: Brief, settings: Settings) -> str:
    """Hand the call to ConversationRelay and carry `brief_id` across."""
    if settings.tier1 is None:
        raise ValueError(
            "This brief is tier 1 but settings.tier1.relay_websocket_url is not set. "
            "Either configure the relay server or downgrade the brief to tier 0."
        )

    tier1 = settings.tier1
    language = brief.recipient.get("language", "en-GB")

    attributes = [
        f"url={quoteattr(tier1.relay_websocket_url)}",
        f"welcomeGreeting={quoteattr(brief.greeting)}",
        f"language={quoteattr(language)}",
        'interruptible="true"',
        'dtmfDetection="false"',
    ]
    if tier1.tts_provider:
        attributes.append(f"ttsProvider={quoteattr(tier1.tts_provider)}")
    if tier1.voice:
        attributes.append(f"voice={quoteattr(tier1.voice)}")

    return (
        "<Response>"
        "<Connect>"
        f"<ConversationRelay {' '.join(attributes)}>"
        f"<Parameter name=\"brief_id\" value={quoteattr(brief.brief_id)}/>"
        "</ConversationRelay>"
        "</Connect>"
        "</Response>"
    )


def render(brief: Brief, settings: Settings, *, answered_by: str | None = None) -> str:
    """Pick the right TwiML for this brief and this answerer.

    `answered_by` is Twilio's AMD verdict, present only when Twilio fetched the
    TwiML from a URL. A machine always gets tier 0, whatever the brief's tier —
    a conversational agent talking to a voicemail greeting is comedy.
    """
    if answered_by in MACHINE_ANSWERS:
        return render_tier0(brief, voicemail=True)
    if brief.tier == 1:
        return render_tier1(brief, settings)
    return render_tier0(brief)
