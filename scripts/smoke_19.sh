#!/usr/bin/env bash
# 19×19 PK smoke: size, liberty reason, rule weight, honest worldline.
# No MiniMax. Does not claim fiber_live unless the joins are real.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"
echo "smoke_19: 19x19 duel"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-go/soft/go/m19_pk_smoke.aura \
  | tee "$ROOT/out/m19_pk.txt"
grep -q 'GO_19_PK_OK' "$ROOT/out/m19_pk.txt"
grep -q 'SIZE=19' "$ROOT/out/m19_pk.txt"
grep -q 'LIB_WEIGHT=7' "$ROOT/out/m19_pk.txt"
grep -q 'RULE mutate=' "$ROOT/out/m19_pk.txt"
grep -E -q 'WORLD line=(fiber_live|host-sequential) backend=' "$ROOT/out/m19_pk.txt"
if grep -q 'WORLD line=fiber_live' "$ROOT/out/m19_pk.txt"; then
  grep -E -q 'joins=[1-9][0-9]*/[1-9][0-9]*' "$ROOT/out/m19_pk.txt"
fi
echo "smoke_19: GO_19_PK_OK"
