# T-153 — Attribute the favor delta to its cause

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** T-114 (the favor book, landed) · T-116 — `favor_meter_names_the_ceiling`
  owns this exact string, so the change is impossible to land silently ·
  the −1 ambiguity is numerically real:
  `favor_civilian_splat` (`scripts/game.gd:45`) == `favor_steal_table`
  (`scripts/game.gd:48`) == −1.

## What

Every `add_favor` call site already knows its cause; carry a short cause tag
alongside the delta and render it ONLY inside the 2.5 s note window, keeping
the at-rest form byte-identical to T-116's pinned `"Favor: <n> / <max>"`.

Design — the **sibling-signal variant** (`favor_changed` keeps its exact
2-arg payload and emit; extending it in place would break `main.gd:200`'s
handler signature and the harness lambda at `tests/sim_test.gd:9938-9940`):

1. `scripts/game.gd` — new `signal favor_noted(favor: int, delta: int,
   cause: String)`; `add_favor(delta: int, cause: String = "")`
   (`game.gd:288-295`) emits `favor_changed(favor, applied)` exactly as
   today AND `favor_noted(favor, applied, cause)`. `splat_favor`
   (`game.gd:301-311`) passes per-class cause words: `"visitor"` /
   `"visitor car"` / `"civilian"` / `"civilian car"` / `"superfan"` /
   `"superfan car"` — the vehicle suffix uniform, so one word = one class,
   matching T-151's readout vocabulary.
2. `scripts/bread_spawner.gd` — `crumb_favor` (emitted at
   `bread_spawner.gd:301-302` from `_on_crumb_eaten`) gains the cause in its
   payload: `crumb_favor.emit(crumb.favor_delta, cause)`, the cause derived
   from `crumb.favor_delta` against the exports (`"table crumb"` for
   `favor_steal_table`, `"tailgate crumb"` for `favor_steal_visitor` — the
   match is total: `favor_delta != 0` is already the only emit condition).
   ARITY CHANGE with declared re-pins: `tests/sim_test.gd:9660`'s 1-arg
   lambda grows the cause param, and the `_crumb_favor_events` compares at
   `tests/sim_test.gd:9692`, `9707`, `9715` become (delta, cause) pairs.
3. `scripts/main.gd` — the bare relay at `main.gd:199`
   (`crumb_favor.connect(Game.add_favor)`) becomes a 2-arg adapter
   `_on_crumb_favor(delta, cause)` calling `Game.add_favor(delta, cause)`;
   the meter's connection (`main.gd:200`) moves to `favor_noted`.
   `_show_favor` (`main.gd:728-741`) renders the note form
   `"Favor: <n> / <max>  (<+d> <cause>)"` when cause is non-empty, the bare
   `"(<+d>)"` when a causeless add arrives (direct `Game.add_favor` callers),
   and the untouched rest form at delta 0. Window and tint mechanics
   unchanged (2.5 s game-time expiry, gold/red).
4. `scripts/elder.gd:225` — the share spend passes `"elders' share"`.

Target note forms (the plan's examples): `"Favor: 4 / 100  (-2 civilian
car)"` · `"Favor: 5 / 100  (+1 tailgate crumb)"` · `"Favor: 96 / 100  (-4
elders' share)"`.

**Declared same-commit verification points / re-pins** (the plan's claim
that only `favor_meter_names_the_ceiling`'s rest-form assert stays untouched
was insufficient):

- `tests/sim_test.gd:9660` lambda + the event pins at `9692`/`9707`/`9715`
  (the `crumb_favor` arity change).
- `tests/sim_test.gd:9560` (favor_meter gain leg) and `9366`/`9374`
  (splat_favor gain/loss legs) call `add_favor` DIRECTLY with no cause —
  under this spec they stay byte-identical green (empty cause → bare note
  form) and are declared must-stay-green points; an implementation that
  renders a suffix on causeless adds must re-pin them instead.
- `VERIFICATION.md` rows ~132 (`splat_favor_follows_citizen_class`), ~133
  (`elder_bread_gates_on_favor`), ~134 (`bread_steal_favor_deltas`), ~142
  (`favor_meter_names_the_ceiling` — rest/gain/debt forms documented
  unchanged), plus the new row below.

## Why

The favor note shows a bare signed delta (`"(+6)"` / `"(-2)"`) for three
different systems — splats, bread steals and the elders' share — so a `-1`
could be a stolen café crumb, a civilian pedestrian or a civilian car (all
three book exactly −1: `game.gd:45`, `game.gd:48`), and the player cannot
connect action to consequence even with the meter in front of them. The
uiux2 favor notes (`(+6)` gold, `(-2)` red) show the delta with no
attribution. The two non-splat bookers the sim already drives are the
crumb relay (`bread_spawner.gd:301-302` → `main.gd:199`) and the elder
share spend (`elder.gd:225`) — every site that moves favor already knows
why.

## Acceptance criteria

- [ ] (Gate 1b) In `splat_favor_follows_citizen_class`'s per-class rig legs
      (the real chain through Main), after each splat the label's note
      carries the cause word — `"visitor car"` on the parked-visitor leg,
      `"civilian"` on the civilian-tourist leg — and expires back to the
      byte-identical bare rest form (red-before: today's note is bare).
- [ ] (Gate 1b) A causeful direct add (`Game.add_favor(6, "visitor")`)
      renders `"(+6 visitor)"` for the note window; a causeless add keeps
      the exact bare `"(+6)"` / `"(-1)"` forms pinned at
      `tests/sim_test.gd:9560` / `9366` / `9374` green untouched.
- [ ] (Gate 1b) `bread_steal_favor_deltas`' captured events carry the
      causes: the TABLE steal pairs −1 with `"table crumb"`, the tailgate
      drop pairs +1 with `"tailgate crumb"`, ordinary crumbs still emit
      nothing.
- [ ] (Gate 1b) `elder_bread_gates_on_favor` gains a `favor_noted` listener:
      the unblocked share's own emission pairs the
      −(`elder_loaf_cost` × `crumbs_per_share`) delta with
      `"elders' share"` (the scenario's staged unblock add is causeless and
      filtered out).
- [ ] `favor_changed`'s payload is unchanged — `main.gd:200` and the harness
      lambda at `tests/sim_test.gd:9938-9940` green untouched
      (`favor_max_book_clamps_and_flushes` re-runs green).
- [ ] `favor_meter_names_the_ceiling` green untouched: rest form, bare gain
      form, debt form, restart form — the at-rest read did not move.

## Verification

Gate 1 (import + boot) + Gate 1b: extended legs in
`splat_favor_follows_citizen_class` (per-class cause words through the real
chain, note-window expiry), `bread_steal_favor_deltas` (relay causes) and
`elder_bread_gates_on_favor` (share cause), new VERIFICATION.md row
`favor_note_names_the_cause`; full suite green with the declared re-pins.
Gate 2 unaffected (no scoring/balance change — the deltas themselves move
not at all). Gate 3: [screenshot] the note reads `"(-2 civilian car)"` mid-
window in live play and the plain rest form after — owner eyes.
