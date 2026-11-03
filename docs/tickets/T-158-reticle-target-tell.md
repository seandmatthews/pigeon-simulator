# T-158 — Give the poop reticle a target tell: name what the pin is on before the drop

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-105 (the reticle, done) · T-151 (the favor colors + class-named readouts, done)
- **Refs:** T-121's owner misread — *"Sometimes a car is just yellow and its
  wheels are black but it's not a black/yellow target car"*
  (`docs/tickets/T-121-unmistakable-targets.md:5-6`) — the same read failure,
  one step EARLIER in the chain (pre-hit, not post-hit) · T-151 (the post-hit
  naming this ticket extends backwards) · T-154 (the hue-twin precedent: fix
  the read before the payout explains it).

## What

The reticle pins WHERE a drop lands but says nothing about WHAT stands there.
Give it a target tell in live mode: at each live re-march that seats a pin,
run one cheap sphere query on the citizen layers at the pin point and, when a
citizen body is under the pin, tint the ring the favor color that body would
pay — the same code the post-hit readout already speaks.

All changes in `scripts/poop_reticle.gd` + `scenes/poop_reticle.tscn`:

1. **The ring gets its own material.** Today one duplicated material
   (`_mat`, `poop_reticle.gd:51`, duplicated once and applied to all six
   meshes at `poop_reticle.gd:79-83`) drives every reticle mesh, so a tint
   written to it would recolor dot and ticks along with the ring. Give the
   Ring its own `SubResource` material in `poop_reticle.tscn` (same values as
   today's `Mat_reticle`, `poop_reticle.tscn:5-11`) and have `_ready`
   duplicate the two materials separately: `_ring_mat` for `%Ring`, `_mat`
   for dot + ticks. The dim write (`poop_reticle.gd:179-181`) then drives
   BOTH materials' alpha — the existing harness read
   (`_reticle_alpha`, `tests/sim_test.gd:2309-2316`) reads
   `ring.material_override`, so it keeps working only if the ring's own
   material still carries the dim.
2. **New exports, a "Target tell" group:**
   - `tell_body_mask: int = 12` — the npc + vehicle layers (3 | 4; the named
     layers in `project.godot:126-133`). The march itself stays world-only
     per `world_mask = 1` (`poop_reticle.gd:36`) — the tell queries bodies,
     the march never does.
   - `tell_query_radius: float = 1.0` — the sphere radius at the pin point.
     It must reach past the surface: the pin lands on the GROUND (the march
     ray can't hit bodies), so a parked car's hull sits beside the pin, not
     under it. Gate 3 judges the feel.
   - `tell_gain_color: Color = Color(1.0, 0.85, 0.3)` and
     `tell_loss_color: Color = Color(1.0, 0.32, 0.25)` — the exact values of
     `MainGame.FAVOR_GAIN_COLOR` / `FAVOR_LOSS_COLOR` (`scripts/main.gd:37-38`),
     duplicated as exports so the reticle stays decoupled from Main — the
     `dim_alpha` precedent (`poop_reticle.gd:28` duplicates
     `Main.POOP_READY_DIM_ALPHA` with the same justification).
3. **The query.** At each live re-march that seats a pin (inside `_march`'s
   landing branch, `poop_reticle.gd:143-148`, gated `_mode == Mode.LIVE`),
   one `PhysicsDirectSpaceState3D.intersect_shape` with a `SphereShape3D` at
   the seated pin point, mask `tell_body_mask`. Read the first collider that
   answers the duck-typed `citizen_class` (`collider.get("citizen_class")` —
   null-safe; `scripts/tourist.gd:68` and `scripts/car.gd:123` both carry it,
   the same duck-typing the harness relays use). VISITOR → ring albedo rgb
   becomes `tell_gain_color`; CIVILIAN or SUPERFAN → `tell_loss_color`; no
   body or no class → neutral (the scene albedo rgb
   `(0.94, 0.9, 0.78)`, `poop_reticle.tscn:8`). Writes are
   changed-value-guarded (the T-055 rule `_update_visuals` already follows,
   `poop_reticle.gd:174-181`); alpha stays owned by the dim logic — the tell
   tints rgb only.
4. **A class word above the pin.** A small billboarded `Label3D`
   (`%ClassWord`, unique name) ~0.5 m above the ring, added in
   `poop_reticle.tscn`: text `CitizenClass.label(kind)` (the T-151 word
   list), modulated the same tell color, visible only while a tell is active,
   hidden when neutral. Sized to read like the ~12 px HUD scale at typical
   flight height — Gate 3 judges.
5. **Frozen stays neutral.** FROZEN mode never queries and forces neutral:
   the drop is already committed, and coloring a committed pin would claim a
   guarantee about a target the ball may miss. On freeze (`lock_to`,
   `poop_reticle.gd:92-99`) and while frozen, the ring shows the neutral
   albedo and `%ClassWord` hides.

What this does NOT claim: the tell refreshes only per re-march — a citizen
walking under a perfectly still pigeon's pin updates on the player's next
movement (the changed-value guard, `poop_reticle.gd:119`, skips the march —
and so the query — on idle frames); the query claims the FIRST
citizen-classed collider under the pin, not best-of-crowd disambiguation; and
it makes no claim about drop splash radius vs the query radius — the tell is
an aim aid, not a hit predictor.

## Why

The class only appears AFTER the splat, so a player aiming at a jackpot
parked visitor car can hit a stopped civilian car and learn it from a red
readout once the favor is already spent. Session B (pilot capture, this
sweep): a drop landed at p (−6.84, 0.05, −17.83) staged for a parked visitor
car centered (−5.5, −12.05) — 5.9 m off (recomputes to 5.93 m) — and the
first class signal was the post-hit red "Civilian car +30" strip and
"Favor: 4 / 100 (−2)" (captured in the session's `b_splat_repeat.png`; that
grab lives in the eval worktree's capture dir and is not in this checkout —
cited as session evidence per the sweep plan). T-121's refs record the owner
misreading gold-adjacent targets pre-fix (`T-121-unmistakable-targets.md:5-6`)
and T-151 named the class on the post-hit readout (`scripts/main.gd:750-768`);
this ticket moves the same color code to the moment the player still has the
drop in hand. The colors are already the player's vocabulary: gold = favor
gain, red = favor loss (`main.gd:37-38`, rendered by `_on_hit_scored`).

## Acceptance criteria

- [x] (Gate 1b) New scenario `reticle_pin_names_the_target` on the
      `reticle_main_lifecycle` rig (`tests/sim_test.gd:2414-2516`, instanced
      Main in its own space, the T-077 reset_flight-per-frame hover hold,
      nudged ~0.01 m per frame so the changed-value guard re-marches on the
      2-tick cadence): with a share-knob single-class tourist rig and one
      tourist re-placed AT the freshly-read pin point each frame (the rig
      extension — the pin must have a body under it per frame), the ring
      albedo reads `tell_gain_color` over an all-visitor rig, `tell_loss_color`
      over an all-civilian rig, and the scene-neutral rgb with the rig freed
      — read through a `_reticle_ring_rgb` helper on the
      `_reticle_alpha` pattern (`tests/sim_test.gd:2309-2316`).
- [x] (Gate 1b) The frozen leg: one real tap with the visitor body still
      under the pin → the ring albedo stays neutral while `is_frozen`, and
      only relights into the tell after the splat returns the reticle to live.
- [x] (Gate 1b) The existing reticle rows re-run green untouched in the same
      suite pass — `reticle_frozen_pin_matches_damped_fall`,
      `reticle_main_lifecycle`, `reticle_live_refresh_30hz` (their reads are
      pin geometry + alpha; the two-material split keeps the dim write on
      the ring's material).
- [ ] (Gate 3) [screenshot] Pilot grab: reticle over a parked visitor car
      reads gold with the class word at flight height; over a civilian
      pedestrian reads red; a frozen pin mid-fall shows neutral. Recorded in
      this ticket.

## Verification

Gate 1 (import + boot) + Gate 1b: new `reticle_pin_names_the_target`
(VERIFICATION.md row beside the reticle rows, `VERIFICATION.md:104-106`) +
full suite green with the three existing reticle rows explicitly re-run.
Gate 2 unaffected (presentation-only; no tuning constants outside the new
exports). Gate 3: the screenshot legs above plus the feel lines — is the
tell readable at lob range, does the gold/red ring steal attention from the
pin itself, does the class word clutter the aim picture.

## Landed (2026-11-03)

The three Gate 1b criteria machine-verified on the branch build: Gate 1
import exit 0 and boot exit 0 (no error lines beyond the accepted godot_mcp
teardown line), Gate 1b full suite 0 failure(s) exit 0 with all four reticle
rows PASS — `reticle_frozen_pin_matches_damped_fall`, `reticle_main_lifecycle`,
`reticle_live_refresh_30hz` untouched, plus the new `reticle_pin_names_the_target`
(gain gold + "Visitor" word over the all-visitor rig; frozen stays neutral
through the real tap and relights gold after the splat; loss red over the
all-civilian rig; neutral rgb with the body freed, the claim conditioned by
the scenario-side `_classed_body_under` probe). Gate 2 autoplay green
(`AUTOPLAY DONE ok=true restart=true`, 132 fps). Two red-before probes prove
the scenario's teeth: with the tell query disabled the new row FAILs on
exactly the gain/relit/loss legs (frozen/neutral staging legs stay true);
with `lock_to`'s neutral force removed it FAILs on exactly the frozen leg.

Tuned values are the exports as ticketed: `tell_body_mask` 12 (npc+vehicle),
`tell_query_radius` 1.0 m, `tell_gain_color`/`tell_loss_color` byte-equal to
`MainGame.FAVOR_GAIN_COLOR`/`FAVOR_LOSS_COLOR`, the ring on its own scene
material (`Mat_ring`, same values as `Mat_reticle`), and the `%ClassWord`
Label3D at 48 px × 0.005 pixel_size (≈ 0.24 m glyphs — the ~12 px HUD read at
typical flight height), billboarded 0.5 m above the ring with the T-019-style
black outline.

Gate 3 screenshots + feel lines: PENDING owner eyes (the two lines live in
VERIFICATION.md's Gate 3 checklist, unchecked).
