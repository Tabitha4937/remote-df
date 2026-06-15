#!/usr/bin/env bash
# Run on your LOCAL machine. Syncs build files to the remote host, (re)builds
# the image natively there, and starts the container. DF assets (df/) are
# fetched on the remote on first run so we don't upload ~80MB.
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <ssh-host>" >&2
  exit 1
fi
REMOTE="$1"
DF_URL="${DF_URL:-https://www.bay12games.com/dwarves/df_53_14_linux.tar.bz2}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Ensuring DF assets + dirs on $REMOTE"
ssh "$REMOTE" "
  set -e
  mkdir -p ~/wasm-df/docker ~/wasm-df/scripts ~/wasm-df/df
  if [ ! -f ~/wasm-df/df/dwarfort ]; then
    curl -sL '$DF_URL' -o /tmp/df.tar.bz2 && tar -xjf /tmp/df.tar.bz2 -C ~/wasm-df/df
  fi
"

echo "==> Syncing build files"
scp -q "$HERE/docker/Dockerfile" "$REMOTE:~/wasm-df/docker/Dockerfile"
scp -q "$HERE/docker/start.sh"   "$REMOTE:~/wasm-df/docker/start.sh"
scp -q "$HERE/.dockerignore"     "$REMOTE:~/wasm-df/.dockerignore"
scp -q "$HERE/scripts/remote-run.sh" "$REMOTE:~/wasm-df/scripts/remote-run.sh"

echo "==> Building image natively on $REMOTE"
ssh "$REMOTE" "cd ~/wasm-df && docker build -f docker/Dockerfile -t wasm-df:native ."

echo "==> Starting container on $REMOTE"
ssh "$REMOTE" "bash ~/wasm-df/scripts/remote-run.sh"

echo "==> Done. Run ./scripts/connect.sh to tunnel + open it."
