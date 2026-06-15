#!/usr/bin/env bash
# Run on your LOCAL machine. Opens an SSH tunnel to the remote DF and launches
# it in your browser. Re-run anytime; it replaces any stale tunnel on the port.
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <ssh-host>" >&2
  exit 1
fi
REMOTE="$1"
PORT="${PORT:-6080}"
URL="http://localhost:${PORT}/"

# Drop any existing forward on PORT, then establish a fresh background tunnel.
lsof -ti "tcp:${PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
ssh -fNL "${PORT}:localhost:${PORT}" "$REMOTE"
echo "Tunnel up: localhost:${PORT} -> ${REMOTE}:${PORT}"
echo "Opening ${URL}"
( command -v open >/dev/null && open "$URL" ) || echo "Open this URL: ${URL}"
