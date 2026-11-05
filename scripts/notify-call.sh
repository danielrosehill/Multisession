#!/usr/bin/env bash
# notify-call.sh: place an outbound Vapi call about this Claude session. Skill: skills/notify.
#
# Usage: notify-call.sh <user|contact name> --confirm --reason "..." [--repo R] [--idle-minutes N] [--brief FILE]
#        notify-call.sh <user|contact name> --dry-run --reason "..."   print the payload, call nothing
#
# Reads the "notify" block of ~/.config/multisession/config.json. VAPI_API_KEY comes from the
# environment and is never read from a file. Prints the call ID, or the payload on --dry-run.
# Exit: 10 no --confirm, 11 not enabled, 12 unknown target or no number, 13 no assistant,
#       14 no phone number ID, 15 no reason, 16 a contact outside 08:00-21:00 their time,
#       20 Vapi refused, 2 bad usage. Calls are capped at 120 seconds.
set -euo pipefail
cfg="${MULTISESSION_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/multisession/config.json}"
target="${1:-}"; [ -n "$target" ] && shift || { echo "usage: notify-call.sh <user|name> --confirm --reason ..." >&2; exit 2; }
confirm=0; dry=0; reason=""; repo=""; idle=""; brief=""
while [ $# -gt 0 ]; do
  case "$1" in
    --confirm) confirm=1; shift ;;
    --dry-run) dry=1; shift ;;
    --reason) reason="${2:-}"; shift 2 ;;
    --repo) repo="${2:-}"; shift 2 ;;
    --idle-minutes) idle="${2:-}"; shift 2 ;;
    --brief) brief=$(jq -c . "${2:-}") || { echo "notify-call: bad --brief file" >&2; exit 2; }; shift 2 ;;
    *) echo "notify-call: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ "$confirm" = 1 ] || [ "$dry" = 1 ] || { echo "notify-call: --confirm required" >&2; exit 10; }
[ -n "$reason" ] || { echo "notify-call: --reason is required: what is Claude stuck on?" >&2; exit 15; }
[ -f "$cfg" ] || { echo "notify-call: no config at $cfg" >&2; exit 11; }
[ "$(jq -r '.notify.call_enabled // false' "$cfg")" = true ] || { echo "notify-call: notify.call_enabled is not true" >&2; exit 11; }

user=$(jq -r '.notify.user_name // "the user"' "$cfg")
if [ "$target" = user ]; then
  name=$user; phone=$(jq -r '.notify.user_phone // ""' "$cfg"); role="the user themselves"
else
  entry=$(jq -c --arg n "$target" '[.notify.contacts[]? | select((.name // "" | ascii_downcase) == ($n | ascii_downcase))][0] // empty' "$cfg")
  [ -n "$entry" ] || { echo "notify-call: no contact named '$target' in notify.contacts" >&2; exit 12; }
  name=$(jq -r '.name' <<<"$entry"); phone=$(jq -r '.phone // ""' <<<"$entry"); role=$(jq -r '.role // "a contact"' <<<"$entry")
  # The recipient carries the cost of this call, so there is no override. Their time, not ours.
  tz=$(jq -r '.tz // ""' <<<"$entry"); hour=$(TZ="${tz:-$(date +%Z)}" date +%-H)
  [ "$hour" -ge 8 ] && [ "$hour" -lt 21 ] || { echo "notify-call: it is ${hour}:00 for $name; contacts are called 08:00-21:00 only" >&2; exit 16; }
fi
aid=$(jq -r '.notify.vapi.assistant_id // ""' "$cfg"); pid=$(jq -r '.notify.vapi.phone_number_id // ""' "$cfg")
[ -n "$phone" ] || { echo "notify-call: no phone number for $target" >&2; exit 12; }
[ -n "$aid" ] || { echo "notify-call: no notify.vapi.assistant_id" >&2; exit 13; }
[ -n "$pid" ] || { echo "notify-call: no notify.vapi.phone_number_id" >&2; exit 14; }

payload=$(jq -n --arg aid "$aid" --arg pid "$pid" --arg num "$phone" --arg cn "$name" --arg un "$user" \
  --arg role "$role" --arg reason "$reason" --arg repo "$repo" --arg idle "$idle" --arg brief "$brief" \
  '{assistantId:$aid, phoneNumberId:$pid, customer:{number:$num, name:$cn},
    assistantOverrides:{maxDurationSeconds:120, variableValues:{user_name:$un, callee_name:$cn,
      callee_role:$role, reason:$reason, repo:$repo, idle_minutes:$idle, brief:$brief}}}')
[ "$dry" = 1 ] && { echo "$payload"; exit 0; }

: "${VAPI_API_KEY:?VAPI_API_KEY is not set}"
resp=$(curl -fsS -X POST https://api.vapi.ai/call -H "Authorization: Bearer $VAPI_API_KEY" \
  -H "Content-Type: application/json" -d "$payload" 2>&1) || { echo "notify-call: Vapi refused: $resp" >&2; exit 20; }
jq -r '.id // empty' <<<"$resp"
