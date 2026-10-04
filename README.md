# aura-go

Aura Go is a live Soft world. The board (default **19×19**), liberties,
captures, and simple ko are a Soft FlatAST program. A thin C viewport,
later, only blits `SNAP` frames and turns keys into `INPUT` lines. M0 has
no C binary: the rules already run headless.

`go:set-size!` accepts `2`..`19`. The fast smoke and the aura-build dogfood
exercise stay on **9×9**. That is a regression board, not the product board.

Design: [`docs/DESIGN.md`](docs/DESIGN.md). Milestone: [`docs/m0.md`](docs/m0.md).
Repo: https://github.com/cybrid-systems/aura-go

Also an [aura-build](https://github.com/cybrid-systems/aura-build) dogfood
stub under `examples/dogfood/`.

This is not an Elo project. The product, same as aura-tetris, is the Aura
loop: propose a strategy, search worldlines, select-best, and leave an
auditable `EXPLAIN`. M0 is only the rules the loop will own. There is no
territory engine yet (`go:empty-count` is not a score).

## Soft smoke

Image `ghcr.io/cybrid-systems/dev:v1.0.9`, Soft tip binary
`/workspace/aura-grok/build/aura` (host GLIBC is often too old — smoke always
runs Soft inside Docker with `--entrypoint /usr/local/bin/gosu`). Needs
`AURA_SANDBOX=off`.

```bash
bash scripts/smoke_soft.sh    # 9×9 regression + 19×19 place/capture/ko/suicide → GO_M0_OK GO_19_OK
```

Manual Soft run:

```bash
sudo docker run --rm --entrypoint /usr/local/bin/gosu \
  -v /workspace/aura-grok:/workspace/aura-grok \
  -v "$PWD":/workspace/aura-go \
  -w /workspace/aura-go \
  -e AURA_PATH=/workspace/aura-grok/lib \
  -e AURA_PIPELINE_STRICT=0 \
  -e AURA_SANDBOX=off \
  ghcr.io/cybrid-systems/dev:v1.0.9 \
  dev /workspace/aura-grok/build/aura /workspace/aura-go/soft/go/m0_smoke.aura
```


## Dual duel + MiniMax burn (Soft)

Soft owns the board and two place-fn slots (`go:place-black` /
`go:place-white`). Each side hot-strategy:swap! / heal! independently.
Select-best is one-ply over legal moves; the stamp is `host-sequential`
(never a fake `fiber_live`). Burn prefers **9×9** for speed; the product
default board stays **19×19**.

```bash
bash scripts/smoke.sh     # M0 + M1 strategy + M2 duel + M3 propose (+ live MiniMax if key)
bash scripts/duel.sh      # one 9×9 dual duel, no propose
bash scripts/burn.sh      # propose→gate→play→score rounds (MiniMax when key present)
```

Env for play/burn: `GO_BURN_ROUNDS`, `GO_BURN_MOVES`, `GO_BURN_SIZE` (default 9),
`GO_PROPOSE` (0|1), `GO_PROPOSE_FILE` (fixture path). Host MiniMax:
`scripts/propose_minimax.py` reads `~/.config/aura-build/minimax.env` — never
commit keys. Capture-lead is the burn scoreboard, not territory and not Elo.

| Path | Role |
|------|------|
| `soft/go/strategy.aura` | dual place-fn slots, gate, probe, swap, heal, EXPLAIN |
| `soft/go/duel.aura` | same-board select-best duel, host-sequential |
| `soft/go/propose.aura` | file / host MiniMax propose per color |
| `soft/go/burn.aura` | self-evolve keep-better loop |
| `soft/go/play.aura` | burn entry |
| `scripts/propose_minimax.py` | host HTTP → lambda file |
| `scripts/duel.sh` / `burn.sh` / `smoke.sh` | runners |

## Engine

| Path | Role |
|------|------|
| `soft/go/world.aura` | board (default 19×19, `go:set-size!`), place, liberties, capture, suicide, simple ko, pass |
| `soft/go/rules.aura` | dialect tag (`japanese-simple-ko-NxN`), empty-count stub (not a score) |
| `soft/go/m0_smoke.aura` | 9×9 regression then a 19×19 sequence → `GO_M0_OK` and `GO_19_OK` |
| `c/README.md` | viewport is not in M0 |
| `examples/dogfood/` | 9×9 GOAL / stub / verify for `aura-build llm-dogfood` |

Rules dialect for M0: **Japanese-style simplified**, not Chinese superko and
not a full Japanese ruleset. See `docs/m0.md`.

- Default size is 19. `(go:set-size! n)` for an integer `n` in `2`..`19` clears the board and repacks `N*N` cells. Storage is capped at 361.
- Black plays first. Colors alternate. `1` black, `2` white, `0` empty.
- A play captures orthogonal opponent groups that then have zero liberties.
- Suicide (own group still has zero liberties after captures) is illegal and leaves the board unchanged.
- Simple ko: if the move captured exactly one stone and the capturer is a single stone with exactly one liberty, the opponent may not play that point on the immediate next move. Any other successful move or a pass clears the ban.
- Two passes in a row are counted (`*passes*`). M0 does not end the game or score it.
- No komi. `go:empty-count` is not territory.

## Soft tip

- Binary: `/workspace/aura-grok/build/aura`
- Image: `ghcr.io/cybrid-systems/dev:v1.0.9`
- Env: `AURA_SANDBOX=off AURA_PIPELINE_STRICT=0 AURA_PATH=/workspace/aura-grok/lib`

Soft is not Restricted mode. M0 does not call `hot-strategy` and does not
stamp `fiber_live`.

License: Apache-2.0

---

# aura-go（中文）

活世界在 Soft：默认 **19×19** 棋盘、气、提子、简单劫。`(go:set-size! n)`
可改成 2..19，冒烟和 dogfood 仍用 **9×9** 做回归，那不是产品棋盘。C 以后只做
`SNAP` 绘制和 `INPUT`，M0 没有 C 程序。不是 Elo 项目，也还没有数目引擎。
产品环路与 aura-tetris 相同：propose → 世界线搜索 → select-best → 可审计
`EXPLAIN`。M0 先把规则交给 Soft。

```bash
bash scripts/smoke_soft.sh   # 9×9 回归 + 19×19 落子/提子/劫/禁自杀，结尾 GO_M0_OK 与 GO_19_OK
```

规则是简化日本规则，不是中国超级劫：禁自杀；只禁「上一手提恰好一子，且提子方是恰好一气的单子」时的立即回提。双气以上的提子不设劫。没有贴目，没有终局数目。详见 `docs/m0.md`。

镜像 `ghcr.io/cybrid-systems/dev:v1.0.9`，Soft 二进制 `/workspace/aura-grok/build/aura`。
仓库：https://github.com/cybrid-systems/aura-go
