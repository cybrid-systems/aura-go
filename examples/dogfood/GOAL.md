# aura-go dogfood — success predicate

Write a small **Aura Soft** program that implements Go capture helpers and
prints exactly these lines (each plus a trailing newline):

```
CAPTURE=1
KO_BLOCK=0
GO_M0_OK
```

## Semantics

Board is **9×9**. Cells: `0` empty, `1` black, `2` white. Orthogonal
neighbors. Black plays first, then colors alternate.

Deterministic sequence (no RNG):

1. Start empty.
2. Play `B(0,0)`, `W(1,0)`, `B(1,1)`, `W(3,0)`, `B(4,4)`, `W(2,1)`.
   White at `(1,0)` now has **one** liberty.
3. `B(2,0)` captures that one white stone. Print `CAPTURE=1`.
4. `W(1,0)` is illegal simple ko (the capturer is a single stone with one
   liberty). The call returns 0. Print `KO_BLOCK=0`.
5. Print `GO_M0_OK`.

Suicide is illegal. A capture of a group that is not a one-stone atari
does not set ko. Do not print a territory score.

## Required structure

- Must define `(define (go:place! …) …)` and use it for the moves above
  so capture and the ko rejection are real (not only hardcoded display
  strings).
- Prefer `display` / `newline` / `set!` / vectors for the board.
- Hardcoding only the three display literals without a board is a fail.

## Why stub starts wrong

`stub.aura` places the ko stone and still reports a legal recapture, and
it prints `GO_M0_BAD`.
