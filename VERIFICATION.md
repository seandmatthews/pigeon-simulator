# VERIFICATION.md

How we prove the game still works. A change is **done** only when the gates below pass
for whatever you touched *and* nothing else regressed.

**Godot binary:** `~/bin/Godot_v4.7.2-stable_win64_console.exe` (use this variant in
terminals — it prints output properly). Commands below say `godot` as shorthand;
substitute the full path if it's not on your PATH.

## Gate 1 — Headless smoke tests (run after every change, takes seconds)

From the repo root:

```bash
# 1. Reimport all resources — must exit 0, no ERROR / SCRIPT ERROR lines
godot --headless --path . --import

# 2. Boot the main scene for 120 frames — must exit on its own, no errors
godot --headless --path . --quit-after 120

# 3. (When touching a single script) syntax check
godot --headless --path . --check-only --script res://scripts/player.gd
```

**Pass =** all commands exit 0 and output contains no `ERROR`, `SCRIPT ERROR` or
`Parse Error` lines. Warnings are acceptable but worth cleaning up.

## Gate 2 — Editor run (before marking any gameplay ticket done)

Open the project in Godot and press **F5** (or run `godot --path .`). Confirm:

- [ ] Boots straight into the playable scene; Debugger → Errors tab is empty
- [ ] No warning spam on boot or during ~30 s of play

## Gate 3 — Manual playtest (run the full list before closing any ticket)

Keep this table in sync with `project.godot` and `README.md`:

| Input | Action |
| ----- | ------ |
| W / S | pitch up / down |
| A / D | turn left / right |
| Space | flap |
| F | poop *(not implemented — T-006)* |
| Shift | boost *(not implemented)* |
| Esc | pause *(not implemented — T-010)* |

Playtest checklist (grows as tickets land):

- [ ] Pigeon falls under gravity, flaps with Space, steers with A/D and W/S
- [ ] Pigeon lands on the ground and does not fall through the world
- [ ] HUD hunger ticks down over time
- [ ] Camera does not clip through the ground while landing
- [ ] Closing and restarting the game produces no errors

## Known issues

- Placeholder art everywhere: the pigeon is a gray sphere, the city is a green plane
  (tracked in T-004 and T-011).
