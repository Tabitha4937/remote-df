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
AUDIO_PORT="${AUDIO_PORT:-8080}"
URL="http://localhost:${PORT}/vnc.html?autoconnect=1&resize=scale"

# Drop any existing forward on PORT/AUDIO_PORT, then establish fresh tunnels.
lsof -ti "tcp:${PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
lsof -ti "tcp:${AUDIO_PORT}" 2>/dev/null | xargs kill -9 2>/dev/null || true
ssh -fNL "${PORT}:localhost:${PORT}" -L "${AUDIO_PORT}:localhost:${AUDIO_PORT}" "$REMOTE"
echo "Tunnel up: localhost:${PORT} -> ${REMOTE}:${PORT} (VNC)"
echo "           localhost:${AUDIO_PORT} -> ${REMOTE}:${AUDIO_PORT} (audio)"
echo "Opening ${URL}"
echo "Audio stream: http://localhost:${AUDIO_PORT}"
( command -v open >/dev/null && open "$URL" ) || echo "Open this URL: ${URL}"
