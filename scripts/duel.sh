#!/usr/bin/env bash
# Headless Soft dual duel on 9×9 (burn speed). Product default stays 19.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GO_BURN_ROUNDS="${GO_BURN_ROUNDS:-1}"
export GO_BURN_MOVES="${GO_BURN_MOVES:-12}"
export GO_BURN_SIZE="${GO_BURN_SIZE:-9}"
export GO_PROPOSE="${GO_PROPOSE:-0}"
mkdir -p "$ROOT/out"
echo "aura-go duel: size=${GO_BURN_SIZE} moves=${GO_BURN_MOVES} propose=${GO_PROPOSE}"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-go/soft/go/play.aura \
  | tee "$ROOT/out/duel.txt"
