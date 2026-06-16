#!/usr/bin/env bash
# Run on your LOCAL machine. Syncs the build context to the remote x86-64 host
# and uses Docker Compose there to BUILD and START the container — for either
# edition. Saves persist in a host directory on the remote (bind mount), so they
# survive redeploys and are easy to back up.
#
#   ./scripts/deploy.sh <host>                                   # classic
#   DF_EDITION=steam STEAM_USER=x STEAM_PASS=y ./scripts/deploy.sh <host>
#   DF_EDITION=steam STEAM_USER=x STEAM_PASS=y STEAM_GUARD=ABC123 ./scripts/deploy.sh <host>
#
# Overrides: DF_VERSION, REMOTE_DIR (default ~/remote-df), DF_SAVES_DIR
# (default <remote-dir>/saves on the remote).
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <ssh-host>" >&2
  exit 1
fi
REMOTE="$1"
DF_VERSION="${DF_VERSION:-53_14}"
DF_EDITION="${DF_EDITION:-classic}"
REMOTE_DIR="${REMOTE_DIR:-remote-df}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

# Files the build + compose need on the remote (DF assets download at build time).
echo "==> Syncing build context to $REMOTE:~/$REMOTE_DIR"
ssh "$REMOTE" "mkdir -p ~/$REMOTE_DIR/docker ~/$REMOTE_DIR/secrets ~/$REMOTE_DIR/saves ~/$REMOTE_DIR/backups"
# Copy the whole docker/ dir so new build inputs are always included.
scp -q -r "$HERE/docker/."          "$REMOTE:~/$REMOTE_DIR/docker/"
scp -q "$HERE/docker-compose.yml"   "$REMOTE:~/$REMOTE_DIR/docker-compose.yml"
scp -q "$HERE/.dockerignore"        "$REMOTE:~/$REMOTE_DIR/.dockerignore"

if [ "$DF_EDITION" = "steam" ]; then
  echo "==> Writing Steam credentials to $REMOTE (BuildKit secrets, never imaged)"
  ssh "$REMOTE" "umask 077; \
    printf '%s' '${STEAM_USER:?Set STEAM_USER}' > ~/$REMOTE_DIR/secrets/steam_user; \
    printf '%s' '${STEAM_PASS:?Set STEAM_PASS}' > ~/$REMOTE_DIR/secrets/steam_pass; \
    printf '%s' '${STEAM_GUARD:-}'              > ~/$REMOTE_DIR/secrets/steam_guard"
  SERVICE="df-steam"
else
  SERVICE="df"
fi

echo "==> Building + starting '$SERVICE' on $REMOTE via Docker Compose"
ssh "$REMOTE" "cd ~/$REMOTE_DIR && \
  DF_VERSION='$DF_VERSION' ${DF_SAVES_DIR:+DF_SAVES_DIR='$DF_SAVES_DIR'} \
  docker compose up -d --build $SERVICE"

echo "==> Done. Saves persist on disk at $REMOTE:~/$REMOTE_DIR/${DF_SAVES_DIR:-saves}"
echo "    Run ./scripts/connect.sh $REMOTE to tunnel + open it."
