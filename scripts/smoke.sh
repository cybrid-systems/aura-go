#!/usr/bin/env bash
# Full Soft smoke: M0 rules + M1 strategy + M2 duel + M3 propose fixture + 19 PK.
# Live MiniMax is optional (GO_M3_PROPOSE_SKIP when no key).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"

echo "smoke: m0"
bash "$ROOT/scripts/smoke_soft.sh"

run() {
  local tag="$1" src="$2" ok="$3"
  echo "smoke: $tag"
  bash "$ROOT/scripts/run_soft.sh" "$src" | tee "$ROOT/out/${tag}.txt"
  if [[ -s "$ROOT/out/${tag}.err" ]]; then
    cat "$ROOT/out/${tag}.err" >&2 || true
  fi
  grep -q "$ok" "$ROOT/out/${tag}.txt"
}

run m1_strategy /workspace/aura-go/soft/go/m1_strategy_smoke.aura GO_M1_STRATEGY_OK
run m2_duel /workspace/aura-go/soft/go/m2_duel_smoke.aura GO_M2_DUEL_OK
grep -E -q 'WORLD line=(host-sequential|fiber_live)' "$ROOT/out/m2_duel.txt"
grep -q 'WINNER mid=' "$ROOT/out/m2_duel.txt"
if grep -q 'WORLD line=fiber_live' "$ROOT/out/m2_duel.txt"; then
  grep -E -q 'joins=[1-9][0-9]*/' "$ROOT/out/m2_duel.txt"
fi
run m3_propose /workspace/aura-go/soft/go/m3_propose_smoke.aura GO_M3_PROPOSE_OK

keyfile="/home/box/.config/aura-build/minimax_api_key"
if [[ ! -s "$keyfile" ]]; then
  echo "GO_M3_PROPOSE_SKIP"
else
  echo "smoke: live MiniMax propose"
  live="$ROOT/out/live_place.lambda"
  if python3 "$ROOT/scripts/propose_minimax.py" "$live" 1 \
      >/tmp/go-propose.stdout 2>/tmp/go-propose.stderr; then
    cat /tmp/go-propose.stderr >&2 || true
    test -s "$live"
    head -c 200 "$live"
    echo
    export GO_PROPOSE_FILE="$live"
    export GO_BURN_ROUNDS=1
    export GO_BURN_MOVES=8
    export GO_BURN_SIZE=9
    export GO_PROPOSE=1
    bash "$ROOT/scripts/run_soft.sh" /workspace/aura-go/soft/go/play.aura \
      | tee "$ROOT/out/live_burn.txt"
    grep -q 'GO_BURN_OK' "$ROOT/out/live_burn.txt"
    echo "GO_M3_PROPOSE_LIVE_OK"
  else
    cat /tmp/go-propose.stderr >&2 || true
    echo "GO_M3_PROPOSE_LIVE_FAIL" >&2
    exit 1
  fi
fi

echo "smoke: 19pk"
bash "$ROOT/scripts/smoke_19.sh"

echo "smoke: GO_SMOKE_OK"
