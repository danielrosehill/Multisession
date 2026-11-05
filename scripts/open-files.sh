#!/usr/bin/env bash
# open-files.sh: open a directory in Dolphin, in a new window. Prints one JSON line.
# Usage: open-files.sh [DIR]   (default: current directory)
set -u
dir=$(readlink -f "${1:-$PWD}")
[ -d "$dir" ] || { echo "{\"opened\":false,\"reason\":\"no such directory: $dir\"}"; exit 2; }
command -v dolphin >/dev/null || { echo '{"opened":false,"reason":"dolphin not found"}'; exit 2; }
setsid -f dolphin --new-window "$dir" >/dev/null 2>&1 || { echo '{"opened":false,"reason":"dolphin did not start"}'; exit 2; }
echo "{\"opened\":true,\"dir\":\"$dir\"}"
