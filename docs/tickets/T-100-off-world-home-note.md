# T-100 — Whisper 'home again' when the off-world guard snaps the pigeon back

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** — (T-036/T-042 landed the guard this decorates)
- **Refs:** sweep 2, ui-ux lane (2026-09-30) · T-036 + T-042 (guard, done) ·
  T-019 (game-time pattern + outline treatment) · T-040 (sibling
  phase-accumulator proposal) · pending human lines
  `VERIFICATION.md:293,297,434-435,476`

## What

Three small hunks, purely additive to the landed guard
(`scripts/player.gd:156-159` — today it does `off_world_resets += 1;
reset_flight(respawn_point)` and says nothing):

1. `scripts/player.gd` — declare `signal off_world_returned` beside the other
   state signals (`scripts/player.gd:14-23`) and emit it once at the guard
   fire, after the reset, so listeners observe the post-snap state:
   `off_world_resets += 1; reset_flight(respawn_point);
   off_world_returned.emit()`.
2. `scenes/main.tscn` — one new HUD Label `%HomeNote` (unique_name_in_owner,
   `visible = false`), sitting under the bread-pointer slot (`HUD/BreadPointer`
   occupies offsets 92–112; the note takes 112–132), text
   `home again — mind the edge`, with the T-019 treatment (14 px, outline 4,
   `Color(0, 0, 0, 0.85)` outline, white 0.75 — the values at
   `scenes/main.tscn:99-102`).
3. `scripts/main.gd` — `@onready var home_note: Label = %HomeNote`, a
   `HOME_NOTE_SECONDS := 2.5` const, a `_home_note_phase: float` accumulator;
   connect `player.off_world_returned` in `_ready()` (beside the other
   connects, `scripts/main.gd:65-81`) to a handler that shows the note and
   zeroes the phase; in `_process(delta)` — the T-019 pulse-phase pattern
   (`scripts/main.gd:106-110`): game time, not wall clock, so it is
   deterministic under `--fixed-fps` and freezes with the world under pause —
   advance the phase while visible and hide + zero once past
   `HOME_NOTE_SECONDS`; `restart_run()` (`scripts/main.gd:265-277`) hides it
   and zeroes the phase so a restart never inherits a stale note.

No input change — the README/VERIFICATION control tables are untouched.
Does **not** claim: no guard-logic change (`off_world_y`, the counter's
semantics, `reset_flight` and the exactly-once contract untouched), no sound,
no camera work.

## Why

Flying past the apron teleports the pigeon to the spawn corridor with zero
player-facing feedback — the camera just cuts. That is exactly the read the
project's own still-pending human gate worries about: "(T-036/T-042) …it reads
as intentional ('came home'), not a teleport glitch" (`VERIFICATION.md:293,
297`, tracked still-pending at `VERIFICATION.md:434-435` and `:476`). The
guard itself is machine-proven (`off_world_fall_respawns` /
`off_world_fall_returns_home`), so this is purely a presentation gap — Main
only learns of the snap through the position change
(`scripts/player.gd:156-159` emits nothing). Honest scope note: the lane's
sessions repeatedly flew toward the apron (4b: "city 512→286 m", 4c: "city
266→151 m") but never crossed the void edge within budget, so the teleport
moment was not witnessed live — the gap is established from the code plus the
pending gate lines above, and the fix's payoff is judged at Gate 3.

## Acceptance criteria

- [ ] `Player` emits `off_world_returned` exactly once per guard fire, and the
      existing exactly-one-fire scenarios (`off_world_fall_respawns`,
      `off_world_fall_returns_home`) pass unchanged — Gate 1b
- [ ] Through the real main scene, the guard fire shows the note on the fire
      frame with the exact text "home again — mind the edge" — Gate 1b only
      (new scenario `off_world_return_shows_note`)
- [ ] The note hides itself after ~2.5 s of advanced game time, on a frame
      boundary, with no further guard fire — Gate 1b only
- [ ] `restart_run()` mid-display hides the note immediately and leaves the
      run unpaused — Gate 1b only
- [ ] The note is styled with the T-019 treatment, sits at the pointer slot
      and stays legible for its whole lifetime — [screenshot], attached to the
      pending T-042 human line at `VERIFICATION.md:297`
- [ ] No gameplay change: `off_world_y`, the reset counter semantics and the
      hunger-drains-through-the-return contract are untouched; no
      input/action change

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b — new scenario
`off_world_return_shows_note`. Registration and shape matter: the existing
`off_world_fall_returns_home` runs the BARE harness player with no HUD
(`tests/sim_test.gd:3312-3348` — it drives `_player`, not a Main), so the new
scenario must be the real-Main variant, on the instanced-`MAIN_SCENE` pattern
the harness already exercises (`tests/sim_test.gd:2536, 2662`), registered in
the unpaused window after the restart scenarios with an unused own-space
offset (e.g. `Vector3(2500, 0, -2500)` — 3500/−3500 and −3500/−3500 are
taken). Steps: instantiate, wait 4 frames, then
`main_game.player.reset_flight(Vector3(0, -10, 0))` (local convention,
`scripts/player.gd:131` — global y −10 is below the −5 guard line) → assert
`off_world_resets == 1` and the note visible with the exact text; advance ~3 s
of game time through awaited frames (the sampling style of the T-019 pulse
arms, `tests/sim_test.gd:2690+`) → assert hidden; drop below the line again,
then call `main_game.restart_run()` mid-display → assert the note hidden and
the tree unpaused; same cleanup tail as the sibling real-Main scenarios. Keep
`off_world_fall_returns_home` itself untouched — the new signal has zero
listeners there, so it passes unchanged. Full suite green. Gate 2 unaffected:
the autoplay's off-world excursions self-heal through the unchanged guard and
it asserts nothing about HUD notes (run it anyway). Gate 3: [screenshot] —
one flown past-the-apron return with the note visible, recorded against the
pending T-042 line (`VERIFICATION.md:297`), so the human pass judges "came
home" WITH the whisper in place.
