#!/usr/bin/env bash
# Exit 0 iff candidate prints CAPTURE=1 / KO_BLOCK=0 / GO_M0_OK and defines go:place!.
set -euo pipefail
CAND="${1:-}"
if [[ -z "$CAND" || ! -f "$CAND" ]]; then
  echo "usage: verify.sh <candidate.aura>" >&2
  exit 2
fi

src="$(cat "$CAND")"
if ! printf '%s\n' "$src" | grep -qE '\(define[[:space:]]+\(go:place!([[:space:]]|\))'; then
  echo "verify fail: missing (define (go:place! …)" >&2
  exit 1
fi

AURA_SRC="${AURA_SRC:-/workspace/aura-grok}"
IMG="ghcr.io/cybrid-systems/dev:v1.0.9"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

run_aura() {
  local cand="$1"
  if [[ -n "${AURA_BIN:-}" && -x "${AURA_BIN}" ]] && "${AURA_BIN}" -e '(display 1)' >/dev/null 2>&1; then
    AURA_SANDBOX="${AURA_SANDBOX:-off}" AURA_PIPELINE_STRICT="${AURA_PIPELINE_STRICT:-0}" \
      AURA_PATH="${AURA_PATH:-$AURA_SRC/lib}" \
      "$AURA_BIN" "$cand" 2>&1 || true
    return
  fi
  if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
  elif sudo docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
  else
    echo "verify fail: no usable AURA_BIN and no docker" >&2
    exit 2
  fi
  local abs
  abs="$(cd "$(dirname "$cand")" && pwd)/$(basename "$cand")"
  "${DOCKER[@]}" run --rm --entrypoint /usr/local/bin/gosu \
    -v "$AURA_SRC":/workspace/aura-grok \
    -v "$ROOT":/workspace/aura-go \
    -v "$abs":/tmp/candidate.aura:ro \
    -w /workspace/aura-go \
    -e AURA_PATH=/workspace/aura-grok/lib \
    -e AURA_PIPELINE_STRICT=0 \
    -e AURA_SANDBOX=off \
    "$IMG" \
    dev /workspace/aura-grok/build/aura /tmp/candidate.aura 2>&1 || true
}

out="$(run_aura "$CAND")"
printf '%s\n' "$out"
ok=1
printf '%s\n' "$out" | grep -qE 'CAPTURE[[:space:]]*=[[:space:]]*1' || ok=0
printf '%s\n' "$out" | grep -qE 'KO_BLOCK[[:space:]]*=[[:space:]]*0' || ok=0
printf '%s\n' "$out" | grep -q 'GO_M0_OK' || ok=0
if printf '%s\n' "$out" | grep -qiE '\berror:|\bunbound variable\b'; then
  ok=0
fi
if [[ "$ok" -eq 1 ]]; then
  echo "verify ok CAPTURE=1 KO_BLOCK=0 GO_M0_OK"
  exit 0
fi
echo "verify fail (expected CAPTURE=1 / KO_BLOCK=0 / GO_M0_OK + go:place!)" >&2
exit 1
