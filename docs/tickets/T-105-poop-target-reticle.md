# T-105 — One persistent poop target: the live/frozen reticle that replaces the per-drop ring

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-046 (the predicted-impact ring + its analytic march, landed — this ticket replaces it), T-077 (the poop-ready dim convention + `poop_ready` getter, landed), T-018 (the perf budget the live march must stay inside, landed)
- **Refs:** owner request (2026-10-02): replace the per-drop impact marker with ONE persistent target
  reticle (ring + center dot + cross ticks, not a bare circle) with a live mode (airborne, no drop in
  flight — continuously predicting where a release *right now* would land, ~10 Hz, coarser march step)
  and a frozen mode (on F press the target locks at the released drop's predicted impact until that
  drop splats or expires, then resumes live; a new press mid-flight re-snaps to the newest drop);
  hidden grounded, dimmed during the cooldown per T-077 · AND the recorded prediction bias fix: the
  T-046 march is deliberately undamped while the live drop's `linear_damp` lands the real splat
  slightly short (noted at `scripts/poop_marker.gd:100-105`) — as an aiming device the prediction
  must match reality · research: [`docs/references/scope-reticle/research.md`](../references/scope-reticle/research.md)
  (+ its 8 Commons images, [`credits.md`](../references/scope-reticle/credits.md); all 8 opened
  against this ticket 2026-10-02)

## What

Replace T-046's per-drop `PoopMarker` (spawned per press, one-shot march, fades and frees with the
drop) with a single persistent reticle owned by the run: one node, two modes, and the damping fix
folded into the march.

- New `scripts/poop_reticle.gd` (`class_name PoopReticle extends Node3D`) + `scenes/poop_reticle.tscn`
  — visual only, no physics nodes (the PoopMarker precedent, `scripts/poop_marker.gd:2-15`). Delete
  `scripts/poop_marker.gd` + `scenes/poop_marker.tscn` (+ their `.uid` files) — no compat shim; the
  only consumers are `scripts/main.gd` and `tests/sim_test.gd` (`main.gd:30`, `sim_test.gd:16`).
- **Geometry — the circle-dot-with-cardinal-ticks reticle** (the EOTech grammar), all meshes
  unshaded + per-instance `StandardMaterial3D` in T-046's landed family (albedo
  `(0.94, 0.9, 0.78, 0.9)`, emission `(0.85, 0.78, 0.55)` at energy 0.55, transparency, `cast_shadow 0`
  — `scenes/poop_marker.tscn:5-11,23`), one duplicated material shared by all children so the dim
  write is one property:
  - `Ring` — TorusMesh `outer_radius` 0.8 / `inner_radius` 0.6, in the XZ plane (T-046's landed ring,
    kept identical so the on-screen size doesn't jump at the swap).
  - `Dot` — a thin disc at the exact center: CylinderMesh height 0.01, `top/bottom_radius` 0.05
    (Ø 0.1 m ≈ 1/16 of the ring diameter — between the real 1/68 spec dot, invisible at game
    distances, and the 5 MOA ≈ 1/14 visibility-balance dot; research.md §"Real dimensions", dot size
    a Gate 3 call). Never offset from center — that's the reticle contract (research.md
    §"Orientation").
  - 4× `Tick` — BoxMesh 0.02 × 0.01 × 0.3 m, long axis radial (local ±X and ±Z), centered ON the ring
    line at r = 0.7 (the torus mid-wall of 0.6–0.8) at the 12/3/6/9 o'clock positions — symmetric
    about both in-plane axes, tips pointing inward, straddling the ring line (the EOTech photo;
    each tick ≈ 1/5–1/6 of the ring diameter, research.md §"Orientation").
  - No pulse: T-046's ±10 % @ 2 Hz scale pulse (`poop_marker.gd:20-21,71-73`) dies with the marker —
    a real reticle never changes shape, only brightness (research.md §"What the game should copy"),
    and a breathing circle is a worse aiming reference. The reticle sits still.
- **Orientation:** world-space, seated on the predicted surface +Y-along-the-hit-normal via the
  poop.gd decal basis helper (`poop_marker.gd:120-124`), offset along the normal by
  `surface_lift` 0.03 (`poop_marker.gd:18`). World-space stays a deliberate choice: a real reticle
  holds constant ANGULAR size, so a world-space mark is justified as a "marked point on the target",
  not a projected sight (research.md §"copy vs simplify") — and walls/roofs need an in-plane seat a
  HUD overlay can't give. Screen-space was considered and rejected on both counts.
- **The damping fix (the aiming contract).** The march stops being "deliberately undamped"
  (`poop_marker.gd:100-105`): every predicted point uses the damped closed form under the drop's
  exports — with g = `fall_gravity` 12 down (`scripts/poop.gd:18`) and d = the effective linear damp
  the live body actually carries (`physics/3d/default_linear_damp`, stock 0.1; Poop sets none and
  `project.godot` has no override — grep-verified 2026-10-02, matching T-046's note):
  `p(t) = p0 + (v0 − G/d)·(1 − e^(−d·t))/d + (G/d)·t`, `G = (0, −g, 0)`; guard d ≈ 0 back to the pure
  parabola. At T-046's measured release (y₀ ≈ 18.6 m, |v₀| = 12 m/s, closed-form estimate, not
  machine-integrated) this moves the pin ~1.3–1.5 m nearer than the old undamped point (T-046's own
  note said "~1.5 m" for its 20 m release; same direction — "the real splat lands slightly short of
  the ring"). Terminal
  velocity under d = 0.1 is g/d = 120 m/s, so damping is a mild shortening at lob range, not a
  flight-model change.
- **Modes** (driver in `_physics_process`, fixed 60 Hz ticks — deterministic under `--fixed-fps`,
  freezes under pause like every physics-driven thing):
  - **Live** (airborne, no drop in flight): re-march a HYPOTHETICAL release at ~10 Hz
    (`live_refresh_hz` 10 → every 6th physics tick) with a coarser step (`live_march_step` 0.1 s vs
    the frozen 0.05 s): p₀ = the exact point `_try_poop` would spawn at
    (`player.global_position − player.global_transform.basis.y * player.poop_drop_offset`,
    `scripts/player.gd:404`), v₀ = `player.velocity` (`scripts/player.gd:405`), g/damp/lifetime from
    the preloaded `poop.tscn` exports (instantiate-not-added once in `_ready`, read, free — no
    mirrored constants). Skip the re-march when neither position nor velocity changed since the last
    one (the T-055/T-077 changed-value-guard concern). **Ray budget:** a refresh costs
    `max_lifetime / step` segments worst-case = 120 rays, typically 13–23 (10–30 m releases); at 10 Hz
    that's ≤ ~20 rays/frame amortized at 60 fps — noise against T-018's calibrated 2.5 ms physics
    frame with ~3× headroom to the 750 ms/100-frame budget (T-018 §Calibration). `density_cpu_budget`
    (`tests/sim_test.gd:6470`) re-run as the named gate. No surface within `max_lifetime` (a lob off
    the world) → hidden — T-046's honest "no predicted ground" answer (`poop_marker.gd:79-81`).
  - **Frozen** (from F press until that drop dies): `Main._on_player_pooped(poop)`
    (`scripts/main.gd:438-442`) swaps the marker spawn for `poop_reticle.lock_to(poop)` — snapshot
    the drop's p₀/v₀ once (the T-046 `track()` shape, `poop_marker.gd:55-60`) and march ONCE at
    `frozen_march_step` 0.05 on the first physics frame after the call (space queries are illegal
    mid-step — the mechanism T-046 already proved, `poop_marker.gd:51-54,69-70`). The pin then holds
    absolutely: no chase, no re-march (a press mid-flight re-snaps to the newest drop by construction
    — Main's handler fires per press). Poll `is_instance_valid(_locked)` per physics frame
    (`poop_marker.gd:66`); on splat OR `max_lifetime` expiry (indistinguishable, both end-of-job —
    T-046's honest read) return to live. The reticle NEVER frees mid-run — persistence is the point.
  - **Visibility & brightness:** grounded (`player.is_grounded`, `scripts/player.gd:144-145`) →
    hidden entirely (pooping is air-only, `scripts/player.gd:397-399`); airborne → visible in whichever
    mode applies, alpha 1.0 — or `dim_alpha` 0.25 while the cooldown runs
    (`player.poop_ready == false`, `scripts/player.gd:149-150`), T-077's dim convention and the same
    0.25 value as `POOP_READY_DIM_ALPHA` (`scripts/main.gd:48`; duplicated as an export with a
    comment tying the two — real sights dim for dawn/dusk rather than vanish, research.md
    §"Common variants"). Alpha/visibility writes changed-value-guarded. No restart-specific code:
    `restart_run()` frees the locked drop (the `poops` loop, `scripts/main.gd:540-541`), the validity
    poll flips the reticle to live, and `reset_flight` returns the player to AIR with a zeroed
    cooldown — the next tick drives the right state, exactly T-077's self-healing argument.
- **Wiring:** instance `poop_reticle.tscn` in `scenes/main.tscn` (child of the Main root, sibling of
  Player/City, `unique_name_in_owner` → `@onready var poop_reticle: PoopReticle = %PoopReticle` on
  Main, the `%PoopReady` accessor precedent, `scripts/main.gd:75`). Remove `POOP_MARKER_SCENE`
  (`scripts/main.gd:30`), the marker spawn in `_on_player_pooped` (`main.gd:439-441`), and the
  `poop_markers` free loop in `restart_run()` (`main.gd:542-543` — no group, no loop; the node
  persists across restarts by design). The player stays decoupled: the reticle reads the player and
  drops, never the reverse.
- **Gate 1b rework** — T-046's two scenarios are rewritten, not added beside:
  - `reticle_frozen_pin_matches_damped_fall` (bare `_player` rig): `_set_up(true, Vector3(0, 20, 0),
    Vector3(0, 0, -12))` + one `_tap("poop")` (`sim_test.gd:1813-1814` shape), direct
    `poop_reticle.tscn` instantiation + `lock_to(drop)` (`sim_test.gd:1824-1826` shape): the frozen
    pin is within **0.5 m** of an impact recomputed INDEPENDENTLY in the scenario by the DAMPED
    closed form from the drop's own p₀/v₀ (read fresh at lock, never through the reticle's march —
    the no-self-test rule, `sim_test.gd:1822`). This is the damping-fix leg: the old undamped point
    sits ~1.3–1.5 m from the damped impact at this release — well outside the bar — so the leg FAILS
    an unfixed march. Plus two
    legs in the same scenario: the pin is stable while the drop falls (re-read ≥ 30 frames later,
    drift ≤ 0.05 m — frozen means frozen), and after the splat the reticle is back in live mode
    within 0.5 s while still alive itself.
  - `reticle_main_lifecycle` (real-Main rig, the T-077 instanced-Main pattern at T-046's
    (4500, 0, 4500) corner, `sim_test.gd:1873-1874`; bare pigeon parked grounded first
    `sim_test.gd:1871-1872`): hold Main's pigeon at a constant-velocity hover (the
    `reset_flight`-per-frame hold, `sim_test.gd:1882-1884`) → exactly ONE reticle in live mode whose
    pin sits within **1.0 m** of the hypothetical damped impact of the hover state (looser bar: the
    10 Hz refresh may lag one tick); one REAL `_tap("poop")` → frozen mode, dimmed ≈ 0.25 immediately
    (T-077's dim assertion shape, `sim_test.gd:1939-1940`); hover high enough (10 m) that the
    cooldown expires BEFORE the drop lands → back to alpha 1.0 while still frozen; the drop splats →
    live mode, and the group/node count never changed (persistence — the anti-assertion to T-046's
    "group empties again"); land the pigeon → hidden; `restart_run()` mid-freeze → the reticle
    recovers on its own (visible live again — the T-077 restart leg, `sim_test.gd:1993-2000`).
  - Register both beside the other poop scenarios in `_run_scenarios` (`tests/sim_test.gd:142+`).
    Remove `POOP_MARKER_SCENE` from `sim_test.gd:16`.
  - VERIFICATION.md: replace T-046's two rows (`VERIFICATION.md:88-89`) with the two new scenarios
    and add the Gate 3 lines below, in the same change-set.

What this does NOT claim: no change to drop physics or any T-006/T-086 code path — `poop.tscn`,
`fall_gravity`, `max_lifetime`, the ball, splat and hit resolution untouched; no change to
`_try_poop`, `poop_cooldown` or when pooping works; no HUD changes (the T-077 F glyph stays exactly
as it is; T-060's coach hint untouched); no sound; T-040's hit-marker ring is a different object and
stays; no screen-space reticle and no constant-angular-size scaling (the world-space mark is the
stated choice); no input actions touched (no controls-table change). The live prediction is stale by
up to one refresh (0.1 s) against a maneuvering player by design — that residual is feel, and it is
a Gate 3 judgement, not a machine leg.

## Why

The core scoring verb still aims blind. T-046's ring only exists AFTER you commit: between presses —
and on every fresh approach — there is no feedback for the question the whole loop hinges on, "if I
released NOW, where would it land?". You fly the glide guessing at an arc you must mentally
integrate, then a ring pops to judge a decision already made. T-060 had to teach a text heuristic
("release ~15 m early") because the world gave nothing better. The live reticle turns leading a
target into flying the dot onto the target — skill you can practice, not arithmetic you do under
time pressure; the frozen mode then keeps the commitment honest (the pin you released on stays until
the drop resolves, so you can see the miss as YOURS, and a re-press under cooldown re-targets the
newest drop instead of orphaning it). Persistent-one-node also reads calmer than T-046's
spawn-judge-vanish rhythm: one steady mark instead of a marker blinking in and out of existence per
press. And the ring has been landing honestly wrong: the march plotted an undamped arc while the
live drop's `linear_damp` 0.1 shortens every lob — T-046 recorded the real splat ~1.5 m short of the
ring at a 20 m release (`poop_marker.gd:100-105`, VERIFICATION.md:294) and waved it through as
bombsight tolerance. Fine for decoration; wrong for the aiming device the ring is actually used as.
As a reticle, prediction must match reality or the player learns to aim at a lie.

## Acceptance criteria

- [ ] Gate 1b: `reticle_frozen_pin_matches_damped_fall` — bare rig, direct instantiation +
      `lock_to(drop)` after a real tap from `_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -12))`:
      frozen pin within 0.5 m of the scenario's independent DAMPED closed-form recompute (analytic
      check: the damped impact at this release sits ~1.3–1.5 m nearer than T-046's measured undamped
      (0, 0, −21.54) — the leg fails the unfixed march by construction); pin stable (≤ 0.05 m drift)
      through the fall; back to live within 0.5 s of the splat with the reticle still alive
- [ ] Gate 1b: `reticle_main_lifecycle` — real-Main rig: exactly one reticle node for the WHOLE
      scenario through live (hover pin within 1.0 m of the hover's hypothetical damped impact) →
      frozen + dimmed 0.25 on a real tap → alpha 1.0 again once the cooldown expires with the drop
      still airborne → live again on splat → hidden when grounded → live again after
      `restart_run()` mid-freeze
- [ ] Full Gate 1b suite green unchanged elsewhere: the six original `poop_*` scenarios
      (`tests/sim_test.gd:1608,1622,1639,1676,1719,1760`), `poop_ball_visible` (`:1791`),
      `poop_ready_indicator_tracks_cooldown`, `restart_resets_run` / `restart_same_seed_skips_rebuild`
      (`:4909`), and `density_cpu_budget` (`:6470`) — the named T-018 gate for the live march's ray cost
- [ ] PoopMarker fully removed (`scripts/poop_marker.gd`, `scenes/poop_marker.tscn`, `.uid` files,
      `main.gd:30`, `main.gd:439-441`, `main.gd:542-543`, `sim_test.gd:16`) with no dangling
      references — proven by Gate 1 clean and the suite green
- [ ] VERIFICATION.md carries the two replacement Gate 1b rows and the Gate 3 lines below in the
      same change-set; T-046's rows (`:88-89`) and its Gate 3 screenshot line (`:294`, including the
      undamped-bias judgement note) are retired by the replacement, and T-046's index row is marked
      superseded (T-105) when this lands
- [ ] [screenshot] At cruise the reticle reads as ring + center dot + four cardinal ticks (not a bare
      circle) against road AND grass, and the splat lands inside the ring at play distances — the
      damped agreement is the point; the old "splat short of the ring" note must not reproduce (Gate 3 — human judgement)
- [ ] [screenshot] The live→frozen→live handover reads correctly in real flight: the mark follows the
      glide's intent before the press, holds the released point while the ball falls, and resumes
      following after the splat; the cooldown dim (0.25) is distinguishable from the live full state
      at a glance, and grounded hides the mark entirely (Gate 3 — human judgement)

## Verification

Gate 1 (import + 120-frame boot; deliberately NO `--check-only` leg — `lock_to(drop: Poop)` drags
`scripts/poop.gd` into the compile and check-only dies on the known repo-wide `Sfx` breakage for
exactly the reason T-046 recorded, `VERIFICATION.md:385-390`) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` (`VERIFICATION.md:31`) with the
two rewritten scenarios and the untouched poop/HUD/restart/perf rows re-run explicitly · Gate 2
(autoplay unchanged: `_tourist_in_lead`'s lead-shot math (`tests/autoplay.gd:326`) predicts its own
impact and now also sees a mark BEFORE releasing — no autoplay script change expected, DONE line
unchanged) · Gate 3: the two [screenshot] lines above added to VERIFICATION.md's playtest list in
the same change-set (the second can be judged in the same session as T-040's pending combo-strip
lines — dive, press, watch the hold).

## References

Research ran for this ticket — the note and all 8 images were opened and read 2026-10-02 (this
session). Facts the implementation MUST respect, orientation first:

1. **Reticle geometry/orientation** — the ring is concentric with the aim axis, the dot sits at the
   EXACT center, never offset; the four ticks sit at the 12/3/6/9 o'clock positions, symmetric about
   both in-plane axes, tips pointing inward, CROSSING the ring line, each ≈ 1/5–1/6 of the ring
   diameter. Source images:
   [`docs/references/scope-reticle/eotech-512-reticle-through-hood.jpg`](../references/scope-reticle/eotech-512-reticle-through-hood.jpg)
   (red ring + center dot + four cardinal ticks crossing the ring — the game's exact proposal) ·
   [`docs/references/scope-reticle/ps90-circle-dot-through-window.jpg`](../references/scope-reticle/ps90-circle-dot-through-window.jpg)
   (the soft emissive circle-dot over a bright sky — the "readable against anything" target look).
2. **Proportions** — real spec: EOTech 68 MOA ring with a 1 MOA dot (dot = 1/68 of ring diameter);
   5 MOA ≈ 1/14 is the visibility/obscuration balance point — the game's Ø 0.1 m dot in the 1.6 m
   ring sits in that band (1/68 would be invisible at game distances). NO ballistic apparatus: the
   variant sheet's drop ladders/holdover dots hang BELOW center with range labels — deliberately
   omitted (the live/frozen pair replaces them). Source images:
   [`docs/references/scope-reticle/eotech-hws-reticle-variants.png`](../references/scope-reticle/eotech-hws-reticle-variants.png)
   (cardinal-tick circle-dots AND the below-center ballistic ladders we drop) ·
   [`docs/references/scope-reticle/m91-scope-crosshair-view.jpg`](../references/scope-reticle/m91-scope-crosshair-view.jpg)
   (the crosshair family the ticks quote — thin lines crossing at center).
3. **One shape, brightness only** — a real reticle never changes shape or gains a "lock" state, only
   brightness (stepped dim for dawn/dusk rather than hiding); therefore: identical geometry and one
   emissive color in both modes, dim (not hide) during cooldown, hide only where no sight exists
   (grounded), no pulse. The world-space mark is a "marked point", not a projected sight — a real
   reticle holds constant angular size, which a world-space ring deliberately does not. Source
   images:
   [`docs/references/scope-reticle/aimpoint-compm2-tube-sight.png`](../references/scope-reticle/aimpoint-compm2-tube-sight.png)
   (plain-dot tube sight — the "brightness only" family) ·
   [`docs/references/scope-reticle/leica-reflex-sight-combiner-glass.jpg`](../references/scope-reticle/leica-reflex-sight-combiner-glass.jpg)
   (the tilted combiner glass — the projection hardware we abstract away) ·
   [`docs/references/scope-reticle/eotech-projection-diagram.png`](../references/scope-reticle/eotech-projection-diagram.png)
   (lamp → tilted optics → collimator path — why the image appears painted on the target) ·
   [`docs/references/scope-reticle/revi-c12a-gunsight-section.jpg`](../references/scope-reticle/revi-c12a-gunsight-section.jpg)
   (the gunsight behind the "bombsight" name in `poop_marker.gd:5` — the historical third family) ·
   note [`docs/references/scope-reticle/research.md`](../references/scope-reticle/research.md)
   §"What the game should copy vs simplify" (the copy/simplify list this What follows, including the
   world-space-vs-screen-space fork and the frozen-mode-has-no-real-referent caveat — the lock is a
   game affordance, don't dress it as realism).
