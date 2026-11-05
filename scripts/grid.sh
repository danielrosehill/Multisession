#!/usr/bin/env bash
# grid.sh: open one new Konsole window tiled with 2 or 4 panes, each a named Claude or a plain shell.
# Prints one JSON line.
#
# Usage: grid.sh --dir DIR --panes NAME,NAME[,NAME,NAME] [--wait SECONDS]
#   --panes  2 or 4 comma-separated entries. A name starts a Claude with that peer name. "-" is a
#            plain shell. Order: 2 = left, right. 4 = top left, top right, bottom left, bottom right
#   --wait   seconds to wait for every Claude to register (default 45)
#   MULTISESSION_LAUNCH_CMD (env, testing only): run this instead of claude, with MS_NAME set
#
# Why not `konsole -e claude` and split that: createSplit starts the new pane with the source pane's
# command, and Konsole refuses Session.runCommand by default. So every pane here is a plain shell
# that claims a pending launch file, as in spawn-session.sh. The first pane has to claim too, and
# its file must name a D-Bus service that does not exist yet: a wrapper writes the file with its own
# PID, then execs Konsole, which keeps that PID. The hook matches it against the shell's parent.
# Needs the shell hook in ~/.bashrc, from this version or later.
# Exit 0 = opened; 2 = refused or failed (JSON says why).
set -u
dir="$PWD"; panes=""; wait_s=45
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --panes) panes="$2"; shift 2 ;;
    --wait) wait_s="$2"; shift 2 ;;
    *) echo "{\"launched\":false,\"reason\":\"unknown argument $1\"}"; exit 2 ;;
  esac
done
fail() { echo "{\"launched\":false,\"reason\":\"$1\"}"; exit 2; }

dir=$(readlink -f "$dir"); [ -d "$dir" ] || fail "no such directory: $dir"
IFS=, read -r -a names <<< "$panes"
case "${#names[@]}" in 2|4) ;; *) fail "--panes needs 2 or 4 entries" ;; esac
for n in "${names[@]}"; do [ "$n" = "-" ] || [[ "$n" =~ ^[A-Za-z0-9._-]+$ ]] || fail "bad pane name: $n"; done
command -v konsole >/dev/null || fail "konsole not found"
q=$(command -v qdbus6 || command -v qdbus || true); [ -n "$q" ] || fail "qdbus6/qdbus not found"
grep -qF 'multisession/rc.sh' "$HOME/.bashrc" 2>/dev/null || fail "shell hook not installed: run scripts/install-shell-hooks.sh"
grep -qF 'target-pid' "${XDG_CONFIG_HOME:-$HOME/.config}/multisession/rc.sh" 2>/dev/null || fail "shell hook is too old for grids: run scripts/install-shell-hooks.sh"

# As in spawn-session.sh: a window started from inside Claude must not inherit its identity.
while IFS='=' read -r v _; do case "$v" in CLAUDE*|KONSOLE_*) unset "$v" ;; esac; done < <(env)

ld="${XDG_RUNTIME_DIR:-/tmp}/multisession-launch"; mkdir -p "$ld"; chmod 700 "$ld"
sids=()
# The body of a launch file for pane $1, on stdout.
body() {
  local n="${names[$1]}" sid cmd
  if [ "$n" = "-" ]; then cmd=":"; sids[$1]=""
  else
    sid=$(cat /proc/sys/kernel/random/uuid); sids[$1]=$sid
    if [ -n "${MULTISESSION_LAUNCH_CMD:-}" ]; then cmd="export MS_NAME=$(printf %q "$n"); $MULTISESSION_LAUNCH_CMD"
    else cmd="claude --name $(printf %q "$n") --session-id $sid"; fi
  fi
  echo "# created: $(date +%s)"
  echo "# multisession grid pane $1"
  echo "cd -- $(printf %q "$dir") && $cmd"
}

# Pane 0: the wrapper adds the target line, because only it knows the PID.
first="$ld/grid-first.$$"; body 0 > "$first"
nohup setsid bash -c '
  f=$1; d=$2; pf="$3/pending.$(date +%s%N).$$"
  { echo "# target-pid: $$"; cat "$f"; } > "$pf.tmp" && mv "$pf.tmp" "$pf"; rm -f "$f"
  exec konsole --separate --workdir "$d"' _ "$first" "$dir" "$ld" >/dev/null 2>&1 &
kp=$!
svc="org.kde.konsole-$kp"; win=/Windows/1
W() { "$q" "$svc" "$win" "org.kde.konsole.Window.$@" 2>/dev/null; }
views() { W viewHierarchy | sed 's/([0-9]*)//g' | grep -oE '[0-9]+' | sort -n; }

ok=false; for i in $(seq 60); do [ -n "$(W sessionList)" ] && [ -n "$(views)" ] && { ok=true; break; }; sleep 0.25; done
[ "$ok" = true ] || fail "the new Konsole window did not appear on D-Bus as $svc"

# Split view $1 ($2: true = left/right, false = top/bottom) for pane $3. Sets newview.
split() {
  local before pf; before=$(views)
  pf="$ld/pending.$(date +%s%N).$$"
  { echo "# target-pid: $kp"; body "$3"; } > "$pf.tmp" && mv "$pf.tmp" "$pf"
  [ "$(W createSplit "$1" "$2" | tr -d '[:space:]')" = "true" ] || { rm -f "$pf"; fail "Konsole createSplit failed for pane $3 (window left open, konsole pid $kp)"; }
  for i in $(seq 40); do [ -e "$pf" ] || break; sleep 0.25; done
  [ -e "$pf" ] && { rm -f "$pf"; fail "pane $3 did not claim its launch (window left open, konsole pid $kp)"; }
  newview=""; for i in $(seq 20); do
    newview=$(comm -13 <(echo "$before") <(views) | tail -1); [ -n "$newview" ] && break; sleep 0.1
  done
  [ -n "$newview" ] || fail "could not find the view of pane $3 (window left open, konsole pid $kp)"
}

a=$(views | head -1)
split "$a" true 1; b=$newview
if [ "${#names[@]}" = 4 ]; then
  split "$a" false 2
  split "$b" false 3
fi

# Ready = every Claude has registered as a peer, the same test as a spawn-session.sh window.
want=0; for n in "${names[@]}"; do [ "$n" = "-" ] || want=$((want + 1)); done
ready=false; have=0; end=$(( $(date +%s) + wait_s ))
while [ -z "${MULTISESSION_LAUNCH_CMD:-}" ] && [ "$(date +%s)" -lt "$end" ]; do
  have=0
  for s in $(W sessionList); do
    p=$("$q" "$svc" "/Sessions/$s" org.kde.konsole.Session.processId 2>/dev/null | tr -d '[:space:]')
    for c in $(pgrep -P "$p" -x claude 2>/dev/null); do [ -f "$HOME/.claude/sessions/$c.json" ] && have=$((have + 1)); done
  done
  [ "$have" -ge "$want" ] && { ready=true; break; }
  sleep 0.5
done

j=""; for i in "${!names[@]}"; do
  j+="${j:+,}{\"name\":\"${names[$i]}\",\"session_id\":\"${sids[$i]:-}\"}"
done
echo "{\"launched\":true,\"dir\":\"$dir\",\"mode\":\"grid\",\"konsole_pid\":$kp,\"panes\":[$j],\"claudes_registered\":$have,\"messaging_ready\":$ready}"
