#!/usr/bin/env bash
# Run on your LOCAL machine. Pulls the pre-built image from GHCR on the remote
# host and (re)starts the DF container with persistent saves.
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <ssh-host>" >&2
  exit 1
fi
REMOTE="$1"
DF_VERSION="${DF_VERSION:-53_14}"
REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-sessa93/remote-df}"
IMAGE="${REGISTRY}/${IMAGE_NAME}:df-${DF_VERSION}"

echo "==> Pulling image on $REMOTE"
ssh "$REMOTE" "docker pull ${IMAGE}"

echo "==> Starting container on $REMOTE"
ssh "$REMOTE" "IMAGE=${IMAGE} bash -s" < "$(dirname "$0")/remote-run.sh"

echo "==> Done. Run ./scripts/connect.sh to tunnel + open it."
