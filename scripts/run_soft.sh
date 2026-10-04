#!/usr/bin/env bash
# Shared Soft runner: tip aura inside ghcr.io/cybrid-systems/dev:v1.0.9.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AURA_SRC="${AURA_SRC:-/workspace/aura-grok}"
IMG="ghcr.io/cybrid-systems/dev:v1.0.9"
SRC="${1:?aura source path}"
shift || true

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  echo "run_soft: docker not available" >&2
  exit 1
fi

EXTRA=()
if [[ -d /home/box/.config/aura-build ]]; then
  EXTRA+=(-v /home/box/.config/aura-build:/home/box/.config/aura-build:ro)
fi
# Pass through burn / propose env.
for k in GO_BURN_ROUNDS GO_BURN_MOVES GO_BURN_SIZE GO_PROPOSE GO_PROPOSE_FILE \
         GO_PROPOSE_FILE_BLACK GO_PROPOSE_FILE_WHITE \
         MINIMAX_ENV_FILE MINIMAX_BASE_URL MINIMAX_MODEL MINIMAX_API_KEY; do
  if [[ -n "${!k:-}" ]]; then
    EXTRA+=(-e "$k=${!k}")
  fi
done
if [[ -n "${GO_PROPOSE_FILE:-}" && -f "${GO_PROPOSE_FILE}" ]]; then
  EXTRA+=(-v "${GO_PROPOSE_FILE}:${GO_PROPOSE_FILE}:ro")
fi
for pf in GO_PROPOSE_FILE_BLACK GO_PROPOSE_FILE_WHITE; do
  if [[ -n "${!pf:-}" && -f "${!pf}" ]]; then
    EXTRA+=(-v "${!pf}:${!pf}:ro")
  fi
done

exec "${DOCKER[@]}" run --rm -i --entrypoint /usr/local/bin/gosu \
  -v "${AURA_SRC}:/workspace/aura-grok" \
  -v "${ROOT}:/workspace/aura-go" \
  -w /workspace/aura-go \
  -e AURA_PATH=/workspace/aura-grok/lib \
  -e AURA_PIPELINE_STRICT=0 \
  -e AURA_SANDBOX=off \
  -e AURA_BIN=/workspace/aura-grok/build/aura \
  "${EXTRA[@]}" \
  "${IMG}" \
  dev /usr/bin/stdbuf -oL -eL /workspace/aura-grok/build/aura "$SRC" "$@"
