#!/usr/bin/env bash
# Guarded runner: enforces CPU and wall time limits on a command.
# Usage: guarded_run.sh <cpu_sec> <wall_sec> -- <cmd> [args...]
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "usage: $0 <cpu_sec> <wall_sec> -- <cmd> [args...]" >&2
  exit 64
fi

CPU_SEC="$1"; shift
WALL_SEC="$1"; shift
DELIM="$1"; shift
if [[ "$DELIM" != "--" ]]; then
  echo "third argument must be --" >&2
  exit 64
fi

ulimit -S -t "$CPU_SEC" || true

if command -v gtimeout >/dev/null 2>&1; then
  exec gtimeout "$WALL_SEC" "$@"
else
  python3 - "$WALL_SEC" "$@" <<'PY'
import sys, subprocess
wall = int(sys.argv[1])
cmd = sys.argv[2:]
try:
    p = subprocess.run(cmd, timeout=wall)
    sys.exit(p.returncode)
except subprocess.TimeoutExpired:
    print("timeout: wall exceeded", file=sys.stderr)
    sys.exit(124)
PY
fi

