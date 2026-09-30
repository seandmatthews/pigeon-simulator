# T-098 — Give the bread pointer an up/down cue — roof crumbs currently point into walls

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** — (T-037 landed the pointer; T-032 landed the roof crumbs it stumbles over)
- **Refs:** sweep 2, ui-ux lane (2026-09-30) · T-037 (pointer, done) · T-032
  (roof spots, done) · T-057 (rewrites the same function's chevron math —
  land-order agnostic, see What) · sessions `uiuxs4b` (failure frame) /
  `uiuxs4c` (throwaway proof)

## What

Annotate the bread pointer's text with a vertical cue. In `scripts/main.gd`
`_aim_bread_pointer` (`scripts/main.gd:166-176`), before writing
`bread_pointer.text` (`scripts/main.gd:168`):

- `var dy := target.y - player.global_position.y`
- Append `" ▲"` when `dy > POINTER_CLIMB_CUE_M`, `" ▼"` when
  `dy < -POINTER_CLIMB_CUE_M`, nothing otherwise — a new const
  `POINTER_CLIMB_CUE_M := 3.0` beside MainGame's other HUD consts (the
  `scripts/main.gd:21-32` block). Readouts become e.g. "bread 21 m ▲".
- Suppress the cue in city mode: give `_aim_bread_pointer` an optional
  `with_climb_cue: bool = false` and pass `true` only from the bread call
  site (`scripts/main.gd:159-160`); the city call site
  (`scripts/main.gd:153`) stays byte-identical — the city target is always at
  street level, and an off-city "city 131 m ▲" would be noise.

Harness, same commit: `_pointer_distance_m` (`tests/sim_test.gd:2507-2511`)
returns −1.0 for any text that is not exactly three space-separated parts
ending in "m", and every existing numeric assert on the pointer goes through
it — so it must accept an optional fourth part equal to "▲" or "▼" (still
−1.0 otherwise). One-function change; all existing callers keep working.

Coordination note: T-057 (proposed) rewrites this same function's chevron-aim
math and the same Gate 1b scenario's bearing arms — while explicitly keeping
"text/distance/mode" unchanged. The suffix hunk and T-057's rewrite touch
disjoint lines; whichever lands second rebases a trivially separable hunk.
This ticket changes neither the chevron nor the selection.

Does **not** claim: `nearest_crumb` stays pure 3D-nearest
(`scripts/bread_spawner.gd:59-67`) — the cue only annotates the named target,
it never re-aims or re-ranks; no spawner, crumb or eating change; no new
tunable beyond the const; no input change.

## Why

Since T-032 every building roof carries a crumb spot — `bread_spots` grew
533 → 679 at the M1 seed (`VERIFICATION.md:109`), so 146 of 679 spots (~21%)
sit on roofs. `nearest_crumb` is pure 3D-nearest, so a grounded pigeon is
regularly told "bread 21 m" about a crumb sitting on a roof: the chevron
points into a blank facade and the metres count toward something invisible
and unreachable from the street. Live failure frame
`session_uiuxs4b/f00015600.png`: grounded, a blank wall fills the frame,
chevron into the wall, "bread 21 m". Proven live as a throwaway (session
`uiuxs4c`, the same 6-line edit this ticket specs): "bread 14 m ▼" while
airborne over a street crumb (f00001368.png), no arrow once level/grounded
(f00002100.png, f00002400.png), zero SCRIPT ERRORs in godot.log; the edit was
reverted afterwards (worktree clean at ee84292).

## Acceptance criteria

- [x] With the named crumb more than 3 m above the pigeon the readout ends
      " ▲"; more than 3 m below it ends " ▼"; within ±3 m it carries no
      arrow — Gate 1b only (three new arms in the extended pointer scenario)
- [x] City mode never carries an arrow — the off-city readout stays exactly
      "city <n> m" — Gate 1b only
- [x] Selection is unchanged: the existing arms of
      `hud_bread_pointer_tracks_nearest_crumb` (query-vs-scan, distance,
      re-aim, style) pass unchanged, proving the cue annotates rather than
      re-aims — Gate 1b
- [x] `_pointer_distance_m` parses both shapes and every existing numeric
      pointer assert stays green — Gate 1b (landed in the same commit as the
      suffix)
- [ ] The arrowed readout stays legible under the T-019 treatment at 14 px —
      [screenshot]: grounded before a building, chevron at the roofline,
      " ▲" readable at a glance
      *(pending human playtest — see Verification record)*
- [x] No gameplay change: bread_spawner, crumbs and eating untouched;
      `project.godot` untouched

## Verification record (2026-09-30)

- Tuned value: `POINTER_CLIMB_CUE_M := 3.0` (`scripts/main.gd:33`), exactly as
  spec'd. City call site left byte-identical; bread call site passes `true`.
- Gate 1: `--import` and `--quit-after 120` both exit 0. First gate round
  failed on missing-`addons/godot_mcp` autoload errors (reproduced identically
  on the pristine base via `git stash`, so never from this change): the
  worktree lacked the per-machine addon that `.gitignore:29-31` says every
  checkout needs on disk ("project.godot references the MCPRuntimeProbe
  autoload"). Fix: synced `addons/godot_mcp/` from the main checkout —
  untracked on purpose (the addon is documented per-machine tooling), matching
  5 of 6 sibling worktrees. Re-run with the addon live: boot is fully clean
  (exit 0, zero ERROR lines — the earlier ObjectDB leak ERROR was the failed
  autoload); import exits 0 with ONE residual line, `ERROR: 33 resources
  still in use at exit`, byte-identical to the main checkout's own `--import`
  output (verified by running the same command there) — upstream baseline of
  the addon-wired project, not of this branch. `--check-only --script` cannot
  see autoload singletons in this environment (untouched scripts
  `tourist.gd`/`player.gd` fail the same way), so the effective compile gates
  here are the boot and the suite.
- Gate 1b: `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
  — all 81 scenarios pass, `SIM SUMMARY: 0 failure(s)`, exit 0. First run
  caught a real placement bug: the ▲ arm's first clear street spot sat past
  half the city span, where the slot correctly flips to "city" and drops the
  cue — the arm now constrains its ground column to ≤ 0.35 × `city_span`.
  Measured: " ▲" arm true 9.8 m over a grounded pigeon; " ▼" arm true 11.7 m
  → "bread 12 m ▼"; level arm bare ("bread 3 m"); city arm bare
  ("city 141 m"). All cue arms decided against `_scan_nearest_crumb`, never
  `nearest_crumb()`.
- Gate 2: autoplay `AUTOPLAY DONE ok=true … restart=true`, exit 0, no
  `SCRIPT ERROR` (descent logic homes on its own scan, unaffected, as the
  ticket predicted — confirmed by running it).
- Gate 3: the [screenshot] legibility line (▲ readable at a glance at 14 px
  before a roofline) is a human-judgement check — still pending; recorded in
  VERIFICATION.md's Gate 3 checklist and Known issues.

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b — extend
`hud_bread_pointer_tracks_nearest_crumb` (`tests/sim_test.gd:2533-2650`,
registered at `tests/sim_test.gd:130`, real Main at its own-space offset)
with three arms plus the suppression assert, all decided against the
scenario's independent-scan oracle (`_scan_nearest_crumb`) rather than the
implementation's own choice:

1. **▲ arm:** ground the pigeon, `drop_crumb()` a crumb ~10 m above its
   position (`BreadSpawner.drop_crumb`, `scripts/bread_spawner.gd:107` — the
   T-020 hand-placed path); if the scan names a different nearest, nudge the
   pigeon along a bounded search toward the placed crumb's ground column (the
   same determinism style as the scenario's y < 0.3 pre-filter) until the
   placed crumb IS the scanned nearest; assert the text ends " ▲" and the
   parsed distance is within 1 m of the true 3D distance.
2. **▼ arm:** `reset_flight` ~10–12 m above a street crumb; scan-decide the
   nearest the same way; assert " ▼" and the distance.
3. **level arm:** the existing hover position (crumb within ±3 m vertically)
   additionally asserts no trailing arrow.
4. **city arm:** the existing city-mode assert additionally requires no
   trailing arrow.

All deterministic under --fixed-fps like the parent scenario. Full suite
green. Gate 2 unaffected: the autoplay homes on its own `_nearest_crumb` scan
(`tests/autoplay.gd:405-409`) and asserts nothing about the pointer text —
selection is unchanged, so its descent logic cannot move (run it anyway).
Gate 3: [screenshot] line — grounded before a roof crumb, the " ▲" reads at a
glance and the facade stops looking like a lie.
