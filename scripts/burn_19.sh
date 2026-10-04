#!/usr/bin/env bash
# 19×19 self-evolve PK. Each round: MiniMax propose (black and white,
# independent) → Soft gate/probe/swap/heal → one-ply worldline duel →
# keep-better per color. Soft invoke is killed after GO_SOFT_TIMEOUT
# seconds (default 1500 = 25 min). Never prints API keys.
# Not territory. Not Elo. fiber_live only if Soft joins every select.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROUNDS="${GO_BURN_ROUNDS:-3}"
MOVES="${GO_BURN_MOVES:-20}"
TIMEOUT="${GO_SOFT_TIMEOUT:-1500}"
mkdir -p "$ROOT/out"
BOARD="$ROOT/out/pk19_scoreboard.md"
LOG="$ROOT/out/pk19_run.log"
: > "$LOG"
{
  echo "# aura-go 19×19 PK"
  echo
  echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
  echo "Board: 19×19 via go:set-size! 19. Moves per round: ${MOVES}. Rounds: ${ROUNDS}."
  echo "One ply, not a full game and not Elo. Capture-lead plus thin-stone count."
  echo "Worldline: fiber_live only when every select's four fibers join; else host-sequential."
  echo "Liberty weight set! 4→7 mid-match. mutate:rebind is logged; eval-current is skipped (it clears the board)."
  echo
} > "$BOARD"

keyfile="/home/box/.config/aura-build/minimax_api_key"
if [[ ! -s "$keyfile" ]]; then
  echo "burn_19: no MiniMax key" | tee -a "$BOARD" "$LOG"
  exit 1
fi

base_b=""
base_w=""
note="opening"
caps_b="-1"
caps_w="-1"
stones_b="-1"
stones_w="-1"
thin_b="9999"
thin_w="9999"
lead="0"
ok_rounds=0
prop_b=0
prop_w=0

grab() {
  local file="$1" key="$2"
  sed -n "s/^${key}//p" "$file" | tail -n 1
}

for ((r=1; r<=ROUNDS; r++)); do
  echo "burn_19: round ${r} propose" | tee -a "$LOG"
  bf="$ROOT/out/pk19_black_r${r}.lambda"
  wf="$ROOT/out/pk19_white_r${r}.lambda"
  berr="$ROOT/out/pk19_prop_b_r${r}.stderr"
  werr="$ROOT/out/pk19_prop_w_r${r}.stderr"
  prev_b_arg=()
  prev_w_arg=()
  if [[ -n "$base_b" && -f "$base_b" ]]; then
    prev_b_arg=("$base_b")
  fi
  if [[ -n "$base_w" && -f "$base_w" ]]; then
    prev_w_arg=("$base_w")
  fi
  if ! python3 "$ROOT/scripts/propose_minimax.py" "$bf" 1 "$r" "$note" "${prev_b_arg[@]}" \
      >/tmp/pk19-prop-b.stdout 2>"$berr"; then
    echo "burn_19: black propose failed round ${r}: $(tr '\n' ' ' < "$berr")" | tee -a "$LOG"
    echo "## round ${r}" >> "$BOARD"
    echo "black propose failed (see pk19_prop_b_r${r}.stderr, key redacted)" >> "$BOARD"
    note="propose_fail_black"
    continue
  fi
  if ! python3 "$ROOT/scripts/propose_minimax.py" "$wf" 2 "$r" "$note" "${prev_w_arg[@]}" \
      >/tmp/pk19-prop-w.stdout 2>"$werr"; then
    echo "burn_19: white propose failed round ${r}: $(tr '\n' ' ' < "$werr")" | tee -a "$LOG"
    echo "## round ${r}" >> "$BOARD"
    echo "white propose failed" >> "$BOARD"
    note="propose_fail_white"
    continue
  fi
  # If both sides echoed the same line, ask white once more.
  if cmp -s "$bf" "$wf"; then
    python3 "$ROOT/scripts/propose_minimax.py" "$wf" 2 "$r" "must_differ_from_black" "$bf" \
      >/tmp/pk19-prop-w2.stdout 2>"$werr" || true
  fi
  prop_b=$((prop_b+1))
  prop_w=$((prop_w+1))
  echo "burn_19: black=$(tr -d '\n' < "$bf")" | tee -a "$LOG"
  echo "burn_19: white=$(tr -d '\n' < "$wf")" | tee -a "$LOG"
  {
    echo "## round ${r}"
    echo
    echo "- black proposal: \`$(tr -d '\n' < "$bf")\`"
    echo "- white proposal: \`$(tr -d '\n' < "$wf")\`"
    echo "- baseline caps_b=${caps_b} caps_w=${caps_w} thin_b=${thin_b} thin_w=${thin_w} lead=${lead}"
    echo
  } >> "$BOARD"

  export GO_BURN_ROUNDS=1
  export GO_BURN_MOVES="$MOVES"
  export GO_BURN_SIZE=19
  export GO_PROPOSE=1
  export GO_PROPOSE_FILE_BLACK="$bf"
  export GO_PROPOSE_FILE_WHITE="$wf"
  export GO_BASE_CAPS_B="$caps_b"
  export GO_BASE_CAPS_W="$caps_w"
  export GO_BASE_STONES_B="$stones_b"
  export GO_BASE_STONES_W="$stones_w"
  export GO_BASE_THIN_B="$thin_b"
  export GO_BASE_THIN_W="$thin_w"
  export GO_BASE_LEAD="$lead"
  if [[ -n "$base_b" && -f "$base_b" ]]; then
    export GO_BASE_FILE_BLACK="$base_b"
  else
    unset GO_BASE_FILE_BLACK || true
  fi
  if [[ -n "$base_w" && -f "$base_w" ]]; then
    export GO_BASE_FILE_WHITE="$base_w"
  else
    unset GO_BASE_FILE_WHITE || true
  fi

  round_out="$ROOT/out/pk19_round${r}.txt"
  echo "burn_19: round ${r} soft size=19 moves=${MOVES} timeout=${TIMEOUT}s" | tee -a "$LOG"
  set +e
  timeout --foreground -k 30 "$TIMEOUT" \
    bash "$ROOT/scripts/run_soft.sh" /workspace/aura-go/soft/go/play.aura \
    > "$round_out"
  rc=$?
  set -e
  if [[ "$rc" -eq 124 || "$rc" -eq 137 ]]; then
    echo "burn_19: round ${r} TIMEOUT rc=${rc}" | tee -a "$LOG"
    echo "- soft: TIMEOUT after ${TIMEOUT}s (partial stdout kept in pk19_round${r}.txt)" >> "$BOARD"
    note="timeout"
    continue
  fi
  if ! grep -q 'GO_BURN_OK' "$round_out"; then
    echo "burn_19: round ${r} soft failed rc=${rc}" | tee -a "$LOG"
    echo "- soft: FAIL rc=${rc}" >> "$BOARD"
    note="soft_fail"
    continue
  fi
  ok_rounds=$((ok_rounds+1))
  world=$(grep -E '^WORLD line=' "$round_out" | tail -n 1 || true)
  explain=$(grep -E '^EXPLAIN mid=' "$round_out" | tail -n 1 || true)
  rule=$(grep -E '^RULE mutate=' "$round_out" | tail -n 1 || true)
  score=$(grep -E '^SCOREBOARD ' "$round_out" | tail -n 1 || true)
  caps=$(grep -E '^CAPS ' "$round_out" | tail -n 1 || true)
  alive=$(grep -E '^ALIVE ' "$round_out" | tail -n 1 || true)
  thin=$(grep -E '^THIN ' "$round_out" | tail -n 1 || true)
  keep=$(grep -E '^KEEP ' "$round_out" | tail -n 1 || true)
  lead_line=$(grep -E '^LEAD=' "$round_out" | tail -n 1 || true)
  moves_line=$(grep -E '^MOVES=' "$round_out" | tail -n 1 || true)
  pb=$(grep -E '^PROPOSE_SIDE color=1 ' "$round_out" | tail -n 1 || true)
  pw=$(grep -E '^PROPOSE_SIDE color=2 ' "$round_out" | tail -n 1 || true)
  {
    echo "- soft: GO_BURN_OK rc=0"
    echo "- ${moves_line} ${lead_line}"
    echo "- ${score}"
    echo "- ${caps}"
    echo "- ${alive}"
    echo "- ${thin}"
    echo "- ${keep}"
    echo "- ${pb}"
    echo "- ${pw}"
    echo "- ${rule}"
    echo "- ${world}"
    echo "- ${explain}"
    echo
  } >> "$BOARD"
  echo "burn_19: round ${r} ${world} ${lead_line} ${keep}" | tee -a "$LOG"

  # Persist kept bodies for the next round's baseline.
  live_b="$ROOT/out/pk19_live_black.lambda"
  live_w="$ROOT/out/pk19_live_white.lambda"
  sed -n 's/^LIVE_BLACK //p' "$round_out" | tail -n 1 > "$live_b"
  sed -n 's/^LIVE_WHITE //p' "$round_out" | tail -n 1 > "$live_w"
  if [[ -s "$live_b" ]]; then base_b="$live_b"; fi
  if [[ -s "$live_w" ]]; then base_w="$live_w"; fi
  base_line=$(grep -E '^BASE ' "$round_out" | tail -n 1 || true)
  caps_b=$(sed -n 's/.*caps_b=\([-0-9]*\).*/\1/p' <<< "$base_line" | tail -n 1)
  caps_w=$(sed -n 's/.*caps_w=\([-0-9]*\).*/\1/p' <<< "$base_line" | tail -n 1)
  stones_b=$(sed -n 's/.*stones_b=\([-0-9]*\).*/\1/p' <<< "$base_line" | tail -n 1)
  stones_w=$(sed -n 's/.*stones_w=\([-0-9]*\).*/\1/p' <<< "$base_line" | tail -n 1)
  thin_b=$(sed -n 's/.*thin_b=\([-0-9]*\).*/\1/p' <<< "$base_line" | tail -n 1)
  thin_w=$(sed -n 's/.*thin_w=\([-0-9]*\).*/\1/p' <<< "$base_line" | tail -n 1)
  lead=$(sed -n 's/.*lead=\([-0-9]*\).*/\1/p' <<< "$base_line" | tail -n 1)
  [[ -n "$caps_b" ]] || caps_b="-1"
  [[ -n "$caps_w" ]] || caps_w="-1"
  [[ -n "$stones_b" ]] || stones_b="-1"
  [[ -n "$stones_w" ]] || stones_w="-1"
  [[ -n "$thin_b" ]] || thin_b="9999"
  [[ -n "$thin_w" ]] || thin_w="9999"
  [[ -n "$lead" ]] || lead="0"
  note="lead=${lead} ${keep}"
done

{
  echo "## summary"
  echo
  echo "- completed_rounds: ${ok_rounds}"
  echo "- black_proposals: ${prop_b}"
  echo "- white_proposals: ${prop_w}"
  echo "- finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
} >> "$BOARD"

echo "burn_19: done rounds=${ok_rounds} proposals_b=${prop_b} proposals_w=${prop_w}" | tee -a "$LOG"
if [[ "$ok_rounds" -lt 1 || "$prop_b" -lt 1 || "$prop_w" -lt 1 ]]; then
  exit 1
fi
if ! grep -E 'WORLD line=(fiber_live|host-sequential)' "$BOARD" >/dev/null; then
  echo "burn_19: missing world stamp" | tee -a "$LOG"
  exit 1
fi
if grep -q 'fiber_live' "$BOARD"; then
  :
else
  echo "burn_19: host-sequential (fibers did not all join) — honest, not a failure" | tee -a "$LOG"
fi
exit 0
