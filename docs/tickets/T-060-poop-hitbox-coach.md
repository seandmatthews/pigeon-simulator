# T-060 — Make the splat humanly possible and coach the lead

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** sweep 2 sessions `uiuxs2b`/`uiuxs2bx` (readings below; captures in the lane worktree's
  gitignored `.captures/`) · T-086 (bigger emissive VISIBLE ball — landed 2026-09-30; this
  ticket is collider-only and must own amending T-086's collider pin, see What) · T-046
  (predicted-impact ring — separate fix, still proposed) · the autoplay's lead pilot,
  `tests/autoplay.gd:326-341` · re-based during the 2026-09-30 backlog audit (the ticket has
  owned the T-086 pin amendment since then); every line number re-verified against the tree
  on 2026-10-01 — when a file has drifted since, re-locate by symbol

## What

Two changes, one ticket, clearly separable in the commit:

1. **Hit tolerance.** `scenes/poop.tscn:16-17`: the `SphereShape3D` "BallShape"
   radius 0.07 → **0.30** (tuned value recorded here). The VISIBLE ball is NOT
   touched — it is already T-086's landed emissive `BallMesh` radius 0.12
   (`scenes/poop.tscn:11-14`, radius at `:13`); this ticket changes the collider
   only. **It must own the T-086 pin amendment in the same change-set:**
   `poop_ball_visible` pins the collider with `absf(collider.radius - 0.07) < 0.005`
   (`tests/sim_test.gd:1515-1517`, inside `_scenario_poop_ball_visible` at `:1500`,
   registered in the suite run list at `:140`) and its VERIFICATION.md row promises
   "the collider stays pinned at its landed 0.07" (`VERIFICATION.md:84`) — re-pin
   both to 0.30 (the pin's purpose — the collider deliberately not equal to the
   0.12 mesh — survives; the overhang direction flips), or criterion 5's "full
   suite green" fails on a landed gate: |0.30 − 0.07| = 0.23 ≥ 0.005. Edit the pin
   clause inside the existing VERIFICATION.md row — it also carries T-086's landed
   mesh/emission/albedo promises — do not replace the row; flip the scenario
   docstring's wording with it (`tests/sim_test.gd:1497-1499` currently says the
   visible ball overhangs the collider). `collision_layer` 32 / `collision_mask` 13
   (`scenes/poop.tscn:29-30`) untouched, so every T-006 / T-007 / T-008 contact
   path keeps its meaning. Contact reach against a tourist becomes 0.30 + 0.25
   (capsule radius, `scenes/tourist.tscn:5-7`, radius at `:6`) = 0.55 m
   center-to-axis vs 0.32 m today — at ~20 m/s closure the timing window roughly
   doubles, ~16 ms → ~27.5 ms one-sided. Cars — the deliberately cheaper target —
   get proportionally easier.
2. **Lead coach.** `scripts/main.gd`, reusing the existing hint slot
   (`HINT_AIR`/`HINT_GROUND` at `scripts/main.gd:12-13`; the slot's only writer
   today is the grounding edge write at `scripts/main.gd:455-456`):
   - `const COACH_POOP := "F poop · release ~15 m early to lead them"` (a ~15 m
     lead is the right order for a 4 m drop at cruise: sqrt(2·4/12) ≈ 0.82 s of
     fall × ~20 m/s), plus `@export var coach_range: float = 30.0` in a new
     "Coach" export group.
   - In `_process`, the hint slot gets one owner: compute
     `eligible := not player.is_grounded and Game.tourist_hits == 0 and
     _tourist_ahead_within(coach_range)`, where the helper scans
     `tourist_spawner.living_tourists()` (`scripts/main.gd:81`; the spawner API
     used at `tests/sim_test.gd:2892` and `tests/autoplay.gd:336`) for one within
     `coach_range` whose flat offset is ahead-ish (`player` flat forward ·
     flat-to-tourist > 0). Then `hint_label.text` = `COACH_POOP` if eligible, else
     the grounding hint (`HINT_GROUND if player.is_grounded else HINT_AIR`). Guard
     the write with a text-changed check so idle frames don't dirty the label —
     the landed pattern to copy is `_update_poop_ready`
     (`scripts/main.gd:275-281`, the T-035/T-055 redundant-write concern).
     `_on_grounding_changed` (`scripts/main.gd:455-456`) keeps its edge write; the
     next `_process` reconciles, so there is no fight and no flicker. T-040's
     `%ComboStrip` (`scripts/main.gd:58`) and T-079's `%ComboNote`
     (`scripts/main.gd:62`) are separate sibling labels — the coach composes with
     the landed HUD work.
   - Keyed on `Game.tourist_hits` (`scripts/game.gd:54`), NOT on any
     `hit_scored`: a car splat must not kill the poop coach. Per-run semantics —
     `reset_run` zeroes `tourist_hits` (`scripts/game.gd:132-139`, zero at `:134`),
     so a fresh run re-teaches; Game has no cross-run save (its only persistence
     is the high score, `scripts/game.gd:32` + beat-save `:158-161`) and none is
     added here.

What this does NOT claim: no release/lead mechanic or cooldown change
(`scripts/player.gd:101`, `poop_cooldown = 1.0`, untouched); no visible-ball
change (T-086's, landed); no bombsight (T-046's); no scoring-values change; no
coach persistence.

## Why

The core scoring verb essentially never fires. Geometry today: a 0.07 m poop
collider (`scenes/poop.tscn:17`) must graze a 0.25 m-radius strolling capsule
(`scenes/tourist.tscn:6`) while you lead a target at cruise — summed tolerance
0.32 m at ~20 m/s ≈ a ~16 ms window, with `poop_cooldown` 1.0
(`scripts/player.gd:101`) allowing one attempt per second. Session evidence: 25+
airborne drops across `uiuxs2b`/`uiuxs2bx` landing 5–40 m from tourist clusters,
zero hits; and the project's OWN pilot — the Gate-2 autoplay, which predicts
impact points and pulls the trigger when a tourist lines up
(`tests/autoplay.gd:326-341`, the 1.5 m predictive tolerance at `:339`) —
finished "splats=10 … panics=0 honks=0 score=0" (the 10 are ground splats): the
project's own pilot has never scored. DESIGN.md's scoring table (100/30, combos,
+50% style) is unreachable content. A planning-time experiment with a temporary
1.5 m hitbox turned near-misses into hits (the point of the experiment), but even
open-loop bombing still missed by metres — the skill is unlearnable without
feedback, hence the coach line riding the existing hint slot.

## Acceptance criteria

- [ ] A drop aimed at a WALKING tourist's predicted position (predicted from the
      tourist's live velocity and the 12 m/s fall, `scripts/poop.gd:18`) connects
      with ≤ 0.4 m lateral aim error — under the 0.55 m contact reach
- [ ] The same drop aimed 1.5 m lateral of the predicted position does NOT
      connect: the lead stays a skill, not a shotgun (a ground splat may fire;
      no tourist splat, no panic)
- [ ] `tourist_splat_panics_scores` — the frozen-target lob (`tests/sim_test.gd:2880`,
      path frozen at `:2917`, checked at `:2945-2947`) — still connects and scores
      end to end
- [ ] Airborne within `coach_range` ahead of a living tourist with zero tourist
      hits, the hint slot shows the coach line; grounded shows the ground hint
      regardless; after the first tourist hit the coach never shows again that run
- [ ] Full Gate-1b suite green (111 `_check`s today), explicitly
      `poop_inherits_and_arcs` (`tests/sim_test.gd:1342`),
      `poop_grounded_no_drop` (`:1356`), `poop_cooldown_blocks_stream` (`:1373`),
      `poop_splats_ground_and_fades` (`:1410`), `poop_splats_wall` (`:1453`),
      `poop_event_reaches_any_body` (`:1486`),
      `tourist_splat_panics_scores` (`:2945`),
      `car_splat_honk_and_continue` (`:3208`), `density_cpu_budget` (`:5049`) —
      with `poop_ball_visible` green under its RE-PINNED collider assertion (the
      0.07 → 0.30 amendment owned in What)

## Verification

Gate 1 + Gate 1b, two new scenarios (Gate 1's `--check-only` leg on
`scripts/player.gd` stays out of the plan — it is broken repo-wide,
`VERIFICATION.md:385-386`):

- `coach_hint_shows_until_first_hit` through a real Main: instantiate
  `MAIN_SCENE` in its own space (the `tests/sim_test.gd:4067-4069` pattern) and
  read `main_game.hint_label` (`:4072`); seat a tourist via a tight-band
  `TouristSpawner` (the `tests/sim_test.gd:2884-2890` pattern), `reset_flight`
  (`scripts/player.gd:150`) airborne ~20 m ahead of it → hint reads
  `COACH_POOP`; `Game.add_tourist_hit(pos)` (the synthetic relay
  `tests/sim_test.gd:2914-2916` uses) → hint reads `HINT_AIR` again; land
  grounded → `HINT_GROUND` regardless of coach eligibility.
- `poop_hits_tourist_within_lead_window`: a tourist KEEPING its stroll loop;
  drop from 4 m above the predicted spot (fall ≈ 0.82 s at `fall_gravity` 12,
  `scripts/poop.gd:18`; predict with the tourist's live velocity at release —
  the autoplay formula, `tests/autoplay.gd:326-341`) → `tourist_splatted` fires
  and the tourist panics; repeat aimed 1.5 m lateral of the prediction → no
  tourist splat, mood never PANIC. (Reformulated from the plan's "±1.5 m lateral
  error" positive arm, which was numerically impossible: contact reach is
  0.55 m, so 1.5 m serves as the NEGATIVE arm instead — 0.95 m of clean margin.)

VERIFICATION.md: two new Gate-1b rows + Gate 3 lines in the same change-set,
plus the `poop_ball_visible` row amendment (collider pin 0.07 → 0.30, edited in
place inside the existing row at `VERIFICATION.md:84`) owned in What. Gate 2:
run normally — the DONE line (`tests/autoplay.gd:144`) reports `panics`/`honks`
and those counts may rise now that the pilot's 1.5 m predictive tolerance
connects; the gate's pass criteria (frozen-world score screen, restart check)
are unchanged.
Gate 3 [screenshot]: coach line visible in flight near pedestrians; the dropping
reads as T-086's landed bright dot mid-air (that ticket owns visibility).
