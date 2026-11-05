# T-167 — Dev tool 1: the hunger lock — pilot verbs freeze and refill the survival clock, so investigation sessions stop dying at the starvation ceiling

- **Status:** done · **Category:** tooling · **Value (1-5):** 4 ·
  **Risk (1-5):** 1
- **Depends on:** nothing (first of the three dev-tool tickets T-167/T-168/
  T-169 — this one lands the shared dispatcher seam the other two extend)
- **Refs:** `scripts/hunger.gd:76-88` (`_physics_process` — the drain law and
  the one-shot `game_over` at zero), `hunger.gd:96-101` (`reset()`), 
  `hunger.gd:43-50` (the clamped value setter — same-value writes stay
  silent, T-075), `hunger.gd:25-28` (`drain_per_second` 0.45 → a full bar
  lasts ≈ 3.7 min of gliding) · `game.gd:189-192` (the Game autoload owns
  Hunger — reachable by name from any script), `game.gd:104-113`
  (`pilot_time_scale` — the boot-flag precedent this ticket's runtime-verb
  approach supersedes for dev toggles) · `tests/capture_recorder.gd:217-282`
  (`_pilot_step()` — the JSONL verb chain: quit/pause/resume/step/key/action;
  the node is PROCESS_MODE_ALWAYS, so commands still flow while the tree is
  frozen — T-140), `capture_recorder.gd:200-216` (the channel's contract
  comment) · `main.gd:226` (`game_over` → `_on_game_over` → the game-over
  screen that PAUSES the tree — the known capture wedge, AGENTS.md
  2026-10-12 defects) · AGENTS.md pilot section (the ~60 wall-min hunger
  budget on 0.1× sessions)

## What

The owner's minimum: unlimited hunger so a pilot session can fly anywhere
and look at what a ticket needs, instead of the 3.7-minute glide clock
ending the investigation (and the 0.1× slow-mo budget capping long sessions
at ~60 wall-minutes). This ticket adds the FIRST slice of a dev-verb family
on the existing pilot channel — no new pipe, no UI:

1. **`Hunger.locked: bool = false`** — when true, `_physics_process`
   returns before the drain line (flap heat freezes too; it is a lock).
   Docstring: dev-only, default off, never written by gameplay code. The
   clamped setter's T-075 silence guarantee means a locked bar emits no
   spurious `changed` signals and the HUD just sits.
2. **Three pilot verbs**, the first members of a single dev family:
   `{"dev":"hunger_lock"}`, `{"dev":"hunger_unlock"}`,
   `{"dev":"hunger_refill"}`. Refill sets `value = max_value` (the setter
   makes a refill-at-full a no-op broadcast). Refill does NOT clear
   `game_over_emitted` — the lock is prevention, not revive (see Not
   claimed).
3. **The shared dev seam: `CaptureRecorder._execute_dev(cmd: Dictionary,
   allowed: bool = _dev_allowed()) -> bool`** — called from `_pilot_step()`
   after the pause/step verbs; returns true when the dict was a dev verb
   (consumed). Every dev verb in T-167/T-168/T-169 dispatches through this
   one method. The gate: `_dev_allowed()` returns
   `OS.is_debug_build()` — in a release export every dev verb logs
   `pilot_dev_refused` and does nothing. CaptureRecorder already ships in
   exports (the 2026-10-17 adversarial review flagged exactly this class of
   leak; re-verify against the export presets when landing) — the gate is
   the standing fix, applied at the family's front door. The `allowed`
   default-arg seam exists because the suite cannot flip
   `OS.is_debug_build()`; tests pass `allowed=false` explicitly and the
   production call site passes nothing.
4. **Events:** `pilot_dev` `{verb, ...}` on success (the ack an agent reads
   via `pilot.py events`); `pilot_dev_unknown` `{verb}` for an unrecognized
   `{"dev":...}` payload (T-168 extends the dispatcher, never bypasses it).
5. **Gate 1b scenario `dev_hunger_lock`** (registered in the
   `sim_test.gd:242` block), driven through `_execute_dev` with explicit
   dicts — no temp command files needed: (a) a player attached and drained
   N ticks records the value drop, then `hunger_lock`, then N more ticks
   with the value bit-identical; (b) `hunger_refill` restores max while
   locked; (c) `hunger_unlock` resumes the drain; (d) with
   `allowed=false`, every verb logs `pilot_dev_refused` and moves no state.
6. **Docs in the same change-set:** the VERIFICATION.md Gate 1b table gets
   the `dev_hunger_lock` row; the AGENTS.md pilot command list gets the
   three verbs (agents discover the family there). `pilot.py` itself needs
   NO change — verbs are plain JSONL lines.

**No reference photos:** dev tooling with no real-world visual counterpart;
no research phase, no image opened.

**Not claimed:** no revive from an already-fired game over (the latch stays
true; once the game-over screen is up the tree is paused and restart is the
exit — revive touches the T-010 flow and buys little once locking is
one verb away); no HUD lock indicator (the bar just sits; agents read the
`pilot_dev` event, the owner knows what they typed); no change to any drain
constant or the T-075 signal contract; no in-game console; no score/favor
cheats (T-169's call verb covers one-offs once it lands); no tourist/elder/
car verbs (T-168).

## Why

Every investigation session today runs on a timer: the 0.45/s drain ends a
leisurely look-around in minutes, and at 0.1× time-scale the budget is ~60
wall-minutes per run — enough to interrupt a mid-investigation staging
session and lose the setup. The game-over screen then PAUSES the tree,
which is the exact state where screenshots wedge (the 2026-10-12 defect
record). The hunger lock removes the ceiling and the death path from every
future session, for the price of one bool and three JSONL verbs on a
channel that already exists. It is also the ticket that lands the
dispatcher seam (`_execute_dev` + the debug-build gate) so the verb pack
(T-168) and the call verb (T-169) are pure additions.

## Acceptance criteria

- [x] `Hunger.locked` exists (default false, dev-only docstring); locked
      `_physics_process` performs no drain and no state write
- [x] `CaptureRecorder._execute_dev(cmd, allowed = _dev_allowed())` is the
      single dev-verb seam, gated on `OS.is_debug_build()` in production;
      `_pilot_step()` routes `{"dev":...}` dicts to it and continues on
      false (non-dev dicts unaffected)
- [x] The three verbs work from a live pilot session, including while the
      tree is PAUSED (PROCESS_MODE_ALWAYS — verbs flow when frozen)
- [x] *(Gate 1b)* new `dev_hunger_lock` scenario registered in the
      `_run_scenarios` block (`sim_test.gd:242` neighbors) with the four
      legs above; the full suite stays 0 failures:
      `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
- [x] *(Gate 1b bite)* recorded when landed: with the drain forced
      (or `drain_per_second` hand-raised for the run) the locked leg reads
      a bit-identical value across N ticks while the unlocked leg drops —
      both lines recorded in this ticket
- [x] *(Gate 1)* `godot --headless --path . --import` and the 120-frame
      boot exit clean, zero ERROR lines
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`) —
      proves the default-off lock changes nothing for real runs
- [x] VERIFICATION.md Gate 1b row + AGENTS.md pilot verb list updated in
      the same change-set
- [x] *(Gate 3)* none — pure dev tool, no player-visible change; the
      `locked` flag and the verbs are unreachable in a release export
      (verified by the allowed=false leg + the debug-build gate), so there
      is no human-judgement surface to playtest

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with
`dev_hunger_lock` registered and its row added to the Gate 1b table in
`VERIFICATION.md`, plus the AGENTS.md pilot verb list · Gate 2 autoplay ·
Gate 3 explicitly none (see the criterion above for why that is honest).

## Recorded (2026-11-05, landed run)

- **Gate 1b bite** (the scenario's `SIM DATA` line, `drain_per_second`
  hand-raised to 60/s for the run, restored after — the ticket's
  forced-drain leg):
  `SIM DATA dev_hunger_lock: unlocked drain over 90 ticks = 90.00 (drain_per_second 60/s forced), locked delta over 90 ticks = 0.000000 (changed_fires=0), refill-at-locked lands exactly max: true, resumed drop over 90 ticks = 90.00`
  followed by `SIM PASS dev_hunger_lock` — the unlocked leg drops 90.00
  units while the locked leg is bit-identical (Δ 0.000000, zero `changed`
  emissions) across the same 90 ticks, refill lands exactly max, unlock
  resumes the 90-unit drop. Full suite: 172 passes, `SIM SUMMARY: 0
  failure(s)`, exit 0 (the 5 `route_exhausted` CarSpawner double-connect
  ERRORs are pre-existing suite noise — a stashed base run shows the same
  5 lines and 0 failures).
- **Live pilot session** (`pilot.py`, session `t167check`, real windowed
  run): `{"ev":"pilot_dev","locked":true,"t_ms":13560,"value":97.78,"verb":"hunger_lock"}`
  → hunger reads exactly 97.78 at frames 2451/2452 after ~15 s of real
  play including two 120-frame flap holds (flap events fired — flap heat
  active, bar still frozen) → `{"dev":"hunger_refill"}` → hunger 100.0 →
  `{"pause":true}` then `{"dev":"hunger_lock"}` through the channel while
  frozen (the queued flap press shows `pilot_press_deferred` — verbs flow
  while the tree is PAUSED) → `{"resume":true}` → hunger still exactly
  100.0 → `{"ev":"pilot_dev","locked":false,"t_ms":70000,"value":100.0,"verb":"hunger_unlock"}`
  → 6 s later hunger 98.36 (the 0.45/s drain law back in charge). The
  refusal and unknown acks from the Gate 1b leg:
  `{"ev":"pilot_dev_refused","reason":"not_allowed","verb":"hunger_lock"}`
  (×3 verbs) and `{"ev":"pilot_dev_unknown","verb":"definitely_not_a_verb"}`.
- **Export-preset re-check** (the ticket's "re-verify when landing"):
  `export_presets.cfg` is `export_filter="all_resources"` with no
  `tests/` exclusion — CaptureRecorder does ship in exports, so the
  `OS.is_debug_build()` gate at the family's front door is the load-bearing
  fix, exactly as the 2026-10-17 adversarial review demanded.

**Final tuned values:** none retuned — this ticket introduces no gameplay
constants. The shipped surface is `Hunger.locked` (default `false`), the
drain law `drain_per_second` 0.45 / `flap_drain_multiplier` 2.0 /
`flap_heat_seconds` 0.7 / `grounded_drain_multiplier` 0.6 all untouched, and
the Gate 1b forced-drain `60.0` is run-scoped test scaffolding (set inside
`_scenario_dev_hunger_lock`, restored before the check).

**Accepted by reviewer sign-off on the landed tree 2026-11-05** — the
reviewer accepted T-167; the ticket flips to done in this same change-set,
and the machine evidence above (Gate 1b bite line, live pilot session,
export-preset re-check) is the record it signed off on.
