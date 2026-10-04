#!/usr/bin/env bash
# Self-evolve burn: host MiniMax propose → Soft gate → play → score.
# 9×9 by default for speed. Full board: scripts/burn_19.sh (SIZE=19).
# Never prints API keys.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GO_BURN_ROUNDS="${GO_BURN_ROUNDS:-3}"
export GO_BURN_MOVES="${GO_BURN_MOVES:-10}"
export GO_BURN_SIZE="${GO_BURN_SIZE:-9}"
export GO_PROPOSE="${GO_PROPOSE:-1}"
mkdir -p "$ROOT/out"
echo "aura-go burn: rounds=${GO_BURN_ROUNDS} size=${GO_BURN_SIZE} moves=${GO_BURN_MOVES} propose=${GO_PROPOSE}"

if [[ "${GO_PROPOSE}" == "1" && -z "${GO_PROPOSE_FILE:-}" && -z "${GO_PROPOSE_FILE_BLACK:-}" ]]; then
  keyfile="/home/box/.config/aura-build/minimax_api_key"
  if [[ -s "$keyfile" ]]; then
    echo "burn: host MiniMax propose for black/white"
    python3 "$ROOT/scripts/propose_minimax.py" "$ROOT/out/go_strategy_black.lambda" 1 \
      >/tmp/go-burn-prop-b.stdout 2>"$ROOT/out/go_propose_black.stderr"
    python3 "$ROOT/scripts/propose_minimax.py" "$ROOT/out/go_strategy_white.lambda" 2 \
      >/tmp/go-burn-prop-w.stdout 2>"$ROOT/out/go_propose_white.stderr"
    export GO_PROPOSE_FILE_BLACK="$ROOT/out/go_strategy_black.lambda"
    export GO_PROPOSE_FILE_WHITE="$ROOT/out/go_strategy_white.lambda"
    echo "burn: black=$(tr -d '\n' < "$GO_PROPOSE_FILE_BLACK")"
    echo "burn: white=$(tr -d '\n' < "$GO_PROPOSE_FILE_WHITE")"
  else
    echo "burn: no MiniMax key; propose disabled" >&2
    export GO_PROPOSE=0
  fi
fi

bash "$ROOT/scripts/run_soft.sh" /workspace/aura-go/soft/go/play.aura \
  | tee "$ROOT/out/burn.txt"
grep -q 'GO_BURN_OK' "$ROOT/out/burn.txt"
echo "burn: GO_BURN_OK"
