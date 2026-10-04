# aura-go — design (Aura-native)

The product is a live Soft FlatAST world: the board, liberties, captures,
ko, and (later) the score are Soft definitions in one Aura process. A thin
C program will be a viewport. It is not the game. M0 does not ship that
viewport.

This is the same loop aura-tetris and aura-parkour already play. Soft emits
a snapshot, the viewport blits it, keys come back as `INPUT` lines, and
strategy bodies are swapped with `hot-strategy:swap!` / `hot-strategy:heal!`.
M0 stops before the swap. The rules it needs are already Soft.

## One sentence

Placing stones is hygiene. The game is: Soft owns the 9×9 position, a
move policy can be hot-swapped, a proposal is gated before it sticks, and
worldlines pick a move without restarting the process or teaching C the
rules. M0 is the position.

## North star

From the AlphaGo System-1 / System-2 split, adapted to Aura dogfood, not
to a rating chase:

1. **System 1 (later).** A proposed policy body — hand-written, or a gated
   MiniMax lambda — scores legal moves. It does not write the board.
2. **System 2 (later).** Several worldlines search from the same position.
   Soft select-best commits one move. The stamp is `fiber_live` only when
   the fibers actually join; otherwise `host-sequential`. Never fake
   `fiber_live`.
3. **Audit.** `EXPLAIN mid=` `reason=` says why that move won (capture,
   ko threat, liberty, pass). C does not invent the reason.
4. **Heal.** A bad proposal probe restores the last good policy. The board
   is not retconned.

Start at 9×9 (the smoke is a handful of scripted points, not a full game).
19×19 and Elo are non-goals.

## Aura loop (target; M0 is the rules box only)

```
keys → C (blit + INPUT only)          [not in M0]
         │  INPUT play x y | pass | quit
         ▼
      soft/go/world.aura
         │  legal? place, capture, simple ko
         ▼
      stdout: SNAP … END               [not in M0]
         │  board, to-play, ko point, last capture, mid/reason
         ▼
      C draws. It does not remove stones.
```

M0's driver is `soft/go/m0_smoke.aura`, which calls `go:place!` / `go:pass!`
directly and prints evidence lines. No `SNAP` yet, so there is nothing for
C to get wrong.

## Soft vs C

| Soft owns | C may do (later) |
|-----------|------------------|
| 9×9 matrix, color to play | ANSI blit of the SNAP |
| liberties, capture, suicide, simple ko | pointer / keys → `INPUT` |
| pass count | nothing about eyes or ko |
| (M1) policy slot and EXPLAIN | nothing about which move won |

C must not keep a second board.

## Soft ≠ Restricted

| | This product | Not this product |
|--|----------------|------------------|
| World | FlatAST workspace defines | A native plugin / `.so` region |
| Swap (M1) | `std/hot-strategy` | `std/hot-update` (`aot:reload`) |
| Heal (M1) | `hot-strategy:heal!` | `std/heal` mid-move surgery |
| Sandbox | **off** when a future seed uses `set-code` | Restricted mode as the play loop |
| Fibers | honest `fiber_live` or `host-sequential` | a label with no join |

M0 does not register a hot-strategy and does not spawn a fiber. Saying
otherwise would be the fake this file exists to forbid.

## Rules the world actually implements

See `docs/m0.md` for the scripted sequence. Short form:

- Board is 9×9. Orthogonal neighbors only. `(0,0)` is the top-left of the printed rows.
- `go:place!` rejects the wrong color, an occupied point, a ko ban, and a suicide.
- Captures are removed before the suicide test, so a play that takes stones and lives is legal.
- Simple ko is the immediate single-stone recapture described in `docs/m0.md`. It is not positional superko.
- `go:pass!` clears ko, flips the side to play, and increments `*passes*`.

`rules.aura` only adds `go:dialect` and `go:empty-count`. Scoring is not
implemented. An empty-point count must not be reported as a result.

## M1 sketch

Still 9×9. Still no Elo.

- `SNAP v1` / `INPUT play <x> <y>` / `INPUT pass` and a C blit that refuses to edit the vector.
- `go:place-fn` hot-strategy: a body `(lambda (board color) …)` or a cheaper summary (liberty delta, capture size) returning a number. Gate rejects `set!`, `board` writes, `eval`, `load`, `shell`, `http`, `mutate:`. Probe, else `heal!`.
- One select-best over the legal moves of the side to play (a few plies, not MCTS on 19×19). Reason tags: `capture`, `ko_ban`, `suicide`, `pass`, `fill`.
- Worldline stamp stays `host-sequential` until four real joins exist. Do not print `fiber_live` early.
- Optional: swap a score helper (Chinese area or Japanese territory, komi as data). `*caps-*` stay the only capture counters; the helper does not `set!` them.
- MiniMax propose stays outside Soft (host Python writes a lambda, Soft gates it). No key in the repo, no key on stdout.

## Non-goals

- Not a second GNU Go. No tsumego book, no rating, no 19×19 by default.
- Not a plugin moat. No AOT region whose point is to hide the rules in C.
- Not C-authoritative capture "for latency".
- Not Chinese superko, bent-four, or seki in M0. Those need an explicit later dialect, not a silent change inside `go:place!`.

## Files

| Path | Role |
|------|------|
| `soft/go/world.aura` | board and M0 rules |
| `soft/go/rules.aura` | dialect tag, empty-count stub |
| `soft/go/m0_smoke.aura` | `GO_M0_OK` |
| `scripts/smoke_soft.sh` | Docker Soft runner |
| `c/README.md` | why there is no `play.c` yet |
| `examples/dogfood/` | optional aura-build exercise |

## 短中文

产品是活的 Soft 世界，不是又一个 C 围棋。M0 只有规则：9×9、气、提子、
禁自杀、简单劫、弃权。C 只在以后把 `SNAP` 画出来。

简单劫不是中国超级劫：仅当上一手恰好提一子、且提子的那一块是单子且只剩
一口气时，对方下一手不能下在该点。更大的一块被打吃后回提（扑）不禁。

M1 再加热策略门、select-best、`EXPLAIN`。`fiber_live` 只有真正 join 成功
才印。Soft 不是 Restricted，也不是 AOT 插件。不做 19×19 Elo。
