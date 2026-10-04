M0 has no viewport.

Soft owns the 9×9 board, liberties, captures, simple ko, and pass
(`soft/go/world.aura`). A later C program may only:

- spawn the Soft child
- read a `SNAP` frame on stdout
- send `INPUT play <x> <y>` or `INPUT pass`
- draw stones

It must not remove stones, grant a liberty, or clear a ko. There is no
`play.c` in this milestone because there is no `SNAP` yet. Do not add a
second rules implementation here to "try the game".
