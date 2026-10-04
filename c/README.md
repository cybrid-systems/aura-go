M0 has no viewport.

Soft owns the board (default 19×19, `(go:set-size! n)` for 2..19), liberties,
captures, simple ko, and pass (`soft/go/world.aura`). A later C program may only:

- spawn the Soft child
- read a `SNAP` frame on stdout
- send `INPUT play <x> <y>` or `INPUT pass`
- draw stones

It must not remove stones, grant a liberty, or clear a ko. There is no
`play.c` in this milestone because there is no `SNAP` yet. Do not add a
second rules implementation here to "try the game". The 9×9 smoke is a
regression, not a second board inside C.
