# multisession: lets scripts/close-pane.sh close this terminal pane cleanly.
# Source from ~/.bashrc (scripts/install-close-trap.sh does it). Does nothing unless the closer
# first creates the flag file for this shell's PID, so a stray SIGALRM is ignored.
# Why ALRM: interactive bash runs HUP/INT/TERM/ALRM traps at an idle prompt immediately, but
# defers USR1/USR2 until the next keypress (tested bash 5.3.9). ALRM is the one of those
# nothing else sends to a shell.
trap '[ -e "${XDG_RUNTIME_DIR:-/tmp}/multisession-close.$$" ] && { rm -f "${XDG_RUNTIME_DIR:-/tmp}/multisession-close.$$"; exit 0; }' ALRM
