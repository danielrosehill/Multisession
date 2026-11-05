"""The three prompt layers, assembled at ConversationRelay `setup`.

Layers one and two are fixed and identical on every call. They are reviewed
once, carefully, and then not touched — which is the whole value of the split:
the per-call surface Claude composes on the fly is only ever content, never
guardrails.

Layer 2b, the refusal, is verbatim. It is pinned rather than model-composed for
one specific reason: declining runs against the grain of a helpful model, and a
model writing its own refusal will reliably soften it into a promise — *"I'll
make sure Alex knows"* — which is exactly the behaviour the design forbids.

See docs/architecture.md § Prompt composition. Do not paraphrase the strings in
this module; edit them deliberately or not at all.
"""

from __future__ import annotations

from .brief import REFUSAL_MARKER, Brief

PERSONA = """\
You are Claude, an AI assistant. You are speaking on the telephone, on behalf of \
{operator}. You are not {operator} and must never imply that you are. You have \
already introduced yourself as an AI in the greeting; if the person seems confused \
about who they are speaking to, say plainly that you are an AI assistant, not a \
person."""

CONDUCT = """\
Do not commit {operator} to anything, agree to any arrangement, speculate, or \
improvise facts. If you are asked something the brief does not cover, say you \
don't know and that the person should contact {operator} directly. Keep every \
reply to one or two short sentences — this is a phone call, not an essay.

You cannot take a message. This call goes one way. If the person asks you to tell \
{operator} something, to pass anything on, to relay an answer, or to have \
{operator} call them back, you must decline using the wording below. Do not agree, \
do not offer to try, and do not soften it into a maybe. Then close the call warmly.

The refusal is about reliability, not secrecy. Never promise that what they said \
will reach {operator}, and never claim that it will not."""

REFUSAL = """\
I'm sorry — I can't take a message. I'm a one-way notification, so there's no way \
for me to make sure it reaches {operator} properly, and I don't want to tell you it \
will. The best thing is to contact {operator} directly."""


def refusal_text(operator: str) -> str:
    return REFUSAL.format(operator=operator)


def _bullets(items: list[str]) -> str:
    return "\n".join(f"- {item}" for item in items)


def build_brief_layer(brief: Brief) -> str:
    """Layer 3 — written fresh for this call, thrown away afterwards."""
    operator = brief.operator_name
    recipient = brief.recipient
    parts: list[str] = []

    who = f"You are calling {recipient['name']}."
    if recipient.get("relationship"):
        who += f" {recipient['relationship']}"
    parts.append(who)

    parts.append(f"THE MESSAGE — deliver this, in your own words if it flows better:\n{brief.message}")

    questions = brief.data.get("anticipated_questions") or []
    if questions:
        lines = []
        for entry in questions:
            answer = entry["answer"]
            if answer.startswith(REFUSAL_MARKER):
                trailing = answer[len(REFUSAL_MARKER):].lstrip(" —-:").strip()
                rendered = (
                    "Use the fixed no-message wording from your conduct rules, verbatim."
                )
                if trailing:
                    rendered += f" ({trailing})"
            else:
                rendered = answer
            lines.append(f'- If asked "{entry["question"]}" — {rendered}')
        parts.append(
            "ANTICIPATED QUESTIONS — these answers are pre-authorised. Anything not "
            "listed here gets \"I don't know, and "
            f"{operator} is the person to ask\":\n" + "\n".join(lines)
        )

    prohibitions = brief.data.get("prohibitions") or []
    if prohibitions:
        parts.append(
            "PROHIBITIONS FOR THIS CALL, on top of your standing rules:\n"
            + _bullets(prohibitions)
        )

    closing = brief.data.get("closing")
    if closing:
        parts.append(f"HOW TO CLOSE:\n{closing}")

    max_turns, max_seconds = brief.caps()
    parts.append(
        f"LENGTH: aim to be done within {max_turns} of your turns and about "
        f"{max_seconds} seconds. The call will be ended for you at those limits, so "
        f"if you are approaching them, close warmly rather than starting something new."
    )

    return "\n\n".join(parts)


def build_system_prompt(brief: Brief) -> str:
    """The full system prompt for a tier 1 call: persona + conduct + refusal + brief."""
    operator = brief.operator_name
    return "\n\n".join(
        [
            PERSONA.format(operator=operator),
            CONDUCT.format(operator=operator),
            "THE REFUSAL — when declining to take a message, say this and nothing "
            "cleverer:\n" + refusal_text(operator),
            "---",
            build_brief_layer(brief),
        ]
    )
