#!/usr/bin/env bash
# Run on your LOCAL machine. Pulls the pre-built image from GHCR on the remote
# host and (re)starts the DF container with persistent saves.
#
# For the steam edition, builds locally (requires Steam credentials) and pushes:
#   DF_EDITION=steam STEAM_USER=x STEAM_PASS=y ./scripts/deploy.sh <host>
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

if [ "$DF_EDITION" = "steam" ]; then
  echo "==> Building steam edition locally (requires Steam credentials)"
  echo "${STEAM_USER:?Set STEAM_USER}" > /tmp/.steam_user
  echo "${STEAM_PASS:?Set STEAM_PASS}" > /tmp/.steam_pass
  trap 'rm -f /tmp/.steam_user /tmp/.steam_pass' EXIT
  HERE="$(cd "$(dirname "$0")/.." && pwd)"
  docker build \
    --platform linux/amd64 \
    --build-arg DF_VERSION="$DF_VERSION" \
    --build-arg DF_EDITION=steam \
    --secret id=steam_user,src=/tmp/.steam_user \
    --secret id=steam_pass,src=/tmp/.steam_pass \
    -f "$HERE/docker/Dockerfile" \
    -t "$IMAGE" "$HERE"
  echo "==> Pushing image to $REGISTRY"
  docker push "$IMAGE"
  rm -f /tmp/.steam_user /tmp/.steam_pass
fi

echo "==> Pulling image on $REMOTE"
ssh "$REMOTE" "docker pull ${IMAGE}"

echo "==> Starting container on $REMOTE"
ssh "$REMOTE" "IMAGE=${IMAGE} bash -s" < "$(dirname "$0")/remote-run.sh"

echo "==> Done. Run ./scripts/connect.sh to tunnel + open it."
