#!/usr/bin/env bash
# List open dead-drop messages in a repo's a2a/ folder.
# As a SessionStart hook its stdout is added to the session's context; it prints nothing when the
# inbox is empty, so repos without mail cost nothing.
# Usage: a2a-inbox.sh [repo-dir]   (default: $CLAUDE_PROJECT_DIR, then $PWD)

repo="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
dir="$repo/a2a"
[ -d "$dir" ] || exit 0

lines=()
for f in "$dir"/*.md; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  [ "$name" = README.md ] && continue
  if [ "$(head -n1 "$f")" = "---" ]; then
    fm=$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")
    status=$(printf '%s\n' "$fm" | sed -n 's/^status:[[:space:]]*//p' | head -n1)
    [ "$status" = open ] || continue
    kind=$(printf '%s\n' "$fm" | sed -n 's/^kind:[[:space:]]*//p' | head -n1)
    subject=$(printf '%s\n' "$fm" | sed -n 's/^subject:[[:space:]]*//p' | head -n1)
    extra=""
    printf '%s\n' "$fm" | grep -q '^schedule:' && extra=", asks you to set a reminder"
    w=$(printf '%s\n' "$fm" | sed -n 's/^watch:[[:space:]]*//p' | head -n1)
    [ -n "$w" ] && [ "$w" != off ] && extra="$extra, asks you to re-check it every $w"
    lines+=("  - a2a/$name (${kind:-note}${extra}): $subject")
  else
    lines+=("  - a2a/$name (status unknown, no front matter)")
  fi
done

[ ${#lines[@]} -eq 0 ] && exit 0
echo "dead-drop: ${#lines[@]} open message(s) from agents in other repos, in $dir."
echo "Read them before other work and handle them with the dead-drop:inbox skill (format: https://github.com/danielrosehill/Claude-Dead-Drop/blob/master/docs/protocol.md):"
printf '%s\n' "${lines[@]}"
