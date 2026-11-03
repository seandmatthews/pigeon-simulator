# T-149 — Visitor cars get a roof-level tell: the class reads from the dive

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-121 (done — reserved civilian palette + the flag pins), T-124 (done — the Kenney car bodies the topper sits on)

## What

Add a taxi-sign style roof topper to the car scene and drive it from the existing flag branch — the topper is visible exactly when the flag is, painted the same color the flag gets:

- `scenes/car.tscn`: a new `RoofTopper` MeshInstance3D under `Visual` (sibling of `FlagPole`/`FlagBanner`, `scenes/car.tscn:83-91`) with its own BoxMesh + StandardMaterial3D, size 0.5 × 0.18 × 0.25 m, **`visible = false` at rest** (the flag/cooler hidden-by-default pattern), translation-only transform at the roof center (start near y ≈ 1.4 and sit it on the Kenney body's roof at build time — the y is not machine-pinned; the size floor is, see below). No CollisionShape anywhere near it.
- `scripts/car.gd`: `@onready var _roof_topper: MeshInstance3D = $Visual/RoofTopper`; inside `_show_flag` (`scripts/car.gd:262-268`) paint the topper with the same `banner_color` (duplicate the surface material, set albedo — the banner's exact pattern at `scripts/car.gd:263-266`) and set `_roof_topper.visible = true`.

Because `_show_flag` is called only from the class match (`scripts/car.gd:228-236`) — VISITOR with the pairing-partner color (gold body → `VISITOR_BLACK`, black body → `TEAM_GOLD`) and SUPERFAN with `TEAM_GOLD`, never CIVILIAN — the topper's story is decided by one branch:

- VISITOR cars: visible topper in the partner color (the new dive-angle tell).
- SUPERFAN cars: visible topper in `TEAM_GOLD`, matching their banner and the head-to-toe cardinal stack. (The plan left the superfan treatment open; riding `_show_flag` is the specified answer — flag and topper can never disagree.)
- CIVILIAN cars: no topper, ever.

What this does **not** claim: no physics moves — the body collider stays exactly 1.9 × 1.45 × 4.4 at y 0.725 (`scenes/car.tscn:10-11,65-67`; pinned at `tests/sim_test.gd:8426-8431`) and the FrontZone stays as-is, so splat geometry, the favor chain (`splat_favor_follows_citizen_class`, `tests/sim_test.gd:9260`) and every fleet-count pin are untouched. The flag itself is not enlarged (that was B-16's option b1, already shipped in T-121 — the `civilian_palette_reserved` row pins pole 0.06 × 0.9 × 0.06 / banner 0.62 × 0.9 × 0.03, `VERIFICATION.md:127`). The civilian `BODY_PALETTE` (`scripts/car.gd:45`) is untouched.

## Why

Every class tell that decides the +6 visitor-car jackpot vs the −2 civilian-car spend (`scripts/game.gd:44,46`) is vertical and thin. The banner is a 0.62 × 0.9 × 0.03 m plane (`scenes/car.tscn:25-27`, origin y 2.63) — from the top-down dive/hover, the angle every splat comes from, its visible cross-section is the 3 cm thickness — and the cooler rides bumper height (`scenes/car.tscn:131-132`, y 1.05). The attack-angle read of "is that car a visitor?" collapses to body color alone: exactly the hue-twin false-positive collision B-16 documented and T-121 killed from the civilian side (`docs/IDEAS.md:103-132`; the decision table's "b1 in T-121; b2 rides T-124" at `docs/IDEAS.md:578` — T-124 has landed, so option b2's natural moment is here).

Evidence (sweep-1 visual-design captures, `.captures/` in the visual-design-s1 worktree):

- `session_vd3/f00003828.png` — a gold visitor being splatted (Favor `6 / 100 (+6)` HUD, `Car +30` strip) with its flag occluded by the very bird on its hood — proof that un-remarked gold cars ARE visitors worth jackpot favor.
- `session_vd3/cars_zoom.png` — the black visitor's flag reads instantly against the sky while the gold visitor's flag is invisible at ground level.
- `session_vd3/f00002460.png` — two visitors parked nose-to-tail, the flags barely resolvable at 3–5 m behind.
- The vd2 top-down dive frame that would show the edge-on banner was overwritten by a later grab in-session and is NOT on disk — the 3 cm geometry argument above stands on `scenes/car.tscn` alone, and the Gate 3 line below captures the top-down proof.

The topper's cross-section from directly above is 0.5 × 0.25 m — orders of magnitude past the banner's 3 cm — a real tell at the dive angle.

## Acceptance criteria

- [ ] Every VISITOR car shows a visible roof topper whose material albedo equals the pairing-partner color: gold body → `CitizenClass.VISITOR_BLACK`, black body → `CitizenClass.TEAM_GOLD` (value-locked against the consts, never literals) (Gate 1b, new `citizen_car_roof_topper` leg — red-before: no `RoofTopper` node exists)
- [ ] Every CIVILIAN car has the topper hidden at rest, and every SUPERFAN car's topper albedo is `CitizenClass.TEAM_GOLD`
- [ ] The topper stays a readable sign: its BoxMesh is ≥ 0.4 × 0.12 × 0.2 m (a silent shrink back toward invisibility fails the leg)
- [ ] No physics moves: the car box pin (1.9 × 1.45 × 4.4 at y 0.725) and the Kenney pack-mesh legs (`tests/sim_test.gd:8410-8431`) stay green — the topper is a plain BoxMesh on its own node path, not a pack mesh
- [ ] The T-121 pins stay green: `citizen_classes_readable` and `civilian_palette_reserved` keep their existing behavior, `splat_favor_follows_citizen_class` and the fleet-count pins untouched
- [ ] [screenshot] From a ~10 m hover directly above mixed traffic, each visitor car's class is readable from the roof topper alone — no flag squinting required (Gate 3)
- [ ] [screenshot] At ground level the topper reads as a taxi sign, not a floating box — seated on the roof, no clipping through the flag pole or banner (Gate 3)

## Verification

- **Gate 1:** headless import + boot, both exit 0, zero unexpected ERROR lines.
- **Gate 1b:** extend `_scenario_citizen_classes_readable` (`tests/sim_test.gd:8078`) — the all-visitor / all-superfan / all-civilian car rigs already exist in it (`tests/sim_test.gd:8146-8213`, driven through the spawner share knobs). Add a separate `_check("citizen_car_roof_topper", topper_ok, …)` computed alongside the existing per-rig loops: topper visible + material-override albedo `is_equal_approx` the expected `CitizenClass` const on every visitor/superfan car, hidden on every civilian, plus the size floor. Keep the existing `citizen_classes_readable` `_check` (`tests/sim_test.gd:8235`) semantically untouched so red-before is attributable. Red-before observed on the untouched tree; full suite green after.
- **Gate 2:** autoplay smoke, unchanged.
- **Gate 3:** the two [screenshot] lines; the top-down frame the evidence section lacks must be captured here.
