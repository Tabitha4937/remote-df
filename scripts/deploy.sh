#!/usr/bin/env bash
# Run on your LOCAL machine. Pulls the pre-built image from GHCR on the remote
# host and (re)starts the DF container with persistent saves.
#
# For the steam edition, builds on the remote host (SteamCMD is x86-only):
#   DF_EDITION=steam STEAM_USER=x STEAM_PASS=y ./scripts/deploy.sh <host>
# If Steam Guard (2FA) is enabled, also set STEAM_GUARD=<code>
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <ssh-host>" >&2
  exit 1
fi
REMOTE="$1"
DF_VERSION="${DF_VERSION:-53_14}"
DF_EDITION="${DF_EDITION:-classic}"
REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-sessa93/remote-df}"
IMAGE="${REGISTRY}/${IMAGE_NAME}:df-${DF_VERSION}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$DF_EDITION" = "steam" ]; then
  IMAGE="remote-df:df-${DF_VERSION}-steam"
  echo "==> Building steam edition on $REMOTE (SteamCMD needs native x86_64)"
  ssh "$REMOTE" "mkdir -p ~/remote-df/docker"
  scp -q "$HERE/docker/Dockerfile" "$REMOTE:~/remote-df/docker/Dockerfile"
  scp -q "$HERE/docker/start.sh"   "$REMOTE:~/remote-df/docker/start.sh"
  scp -q "$HERE/.dockerignore"     "$REMOTE:~/remote-df/.dockerignore"

  ssh "$REMOTE" bash -s <<SCRIPT
    set -euo pipefail
    cd ~/remote-df
    echo '${STEAM_USER:?Set STEAM_USER}' > /tmp/.steam_user
    echo '${STEAM_PASS:?Set STEAM_PASS}' > /tmp/.steam_pass
    echo '${STEAM_GUARD:-}' > /tmp/.steam_guard
    trap 'rm -f /tmp/.steam_user /tmp/.steam_pass /tmp/.steam_guard' EXIT
    docker build \
      --build-arg DF_VERSION=${DF_VERSION} \
      --build-arg DF_EDITION=steam \
      --secret id=steam_user,src=/tmp/.steam_user \
      --secret id=steam_pass,src=/tmp/.steam_pass \
      --secret id=steam_guard,src=/tmp/.steam_guard \
      -f docker/Dockerfile \
      -t ${IMAGE} .
    rm -f /tmp/.steam_user /tmp/.steam_pass /tmp/.steam_guard
SCRIPT

  echo "==> Starting container on $REMOTE"
  ssh "$REMOTE" "IMAGE=${IMAGE} bash -s" < "$(dirname "$0")/remote-run.sh"
else
  echo "==> Pulling image on $REMOTE"
  ssh "$REMOTE" "docker pull ${IMAGE}"

  echo "==> Starting container on $REMOTE"
  ssh "$REMOTE" "IMAGE=${IMAGE} bash -s" < "$(dirname "$0")/remote-run.sh"
fi

echo "==> Done. Run ./scripts/connect.sh to tunnel + open it."
