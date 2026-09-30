# T-055 — Stop the per-frame redundant presentation writes and the HUD pointer's per-frame array churn

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** — (T-007 and T-019, whose surfaces it touches, are landed) · implements **T-035** plus one extension the ticket missed
- **Refs:** `docs/tickets/T-018-performance-budget.md` → Calibration (the honest scale: headroom, not a bottleneck) · sweep 2 planning lane · line numbers on commit b76ec96, this tree

## What

Three per-frame write/allocation loops that run at full rate against work nobody
sees. One commit, three local edits — no new exports, no input changes, no scene
changes:

1. `scripts/tourist.gd` — cache the panic tint. `_animate()` (called every physics
   tick from `tourist.gd:99`) ends with an unconditional
   `mat.albedo_color = PANIC_TINT if panicking else shirt_color` on each tourist's
   duplicated shirt material (`tourist.gd:214-216`; the per-tourist duplicate at
   `tourist.gd:79`, shared by body + both arms via `material_override`). The tint is
   a hard binary — calm is always `shirt_color`, panic always `PANIC_TINT`
   (`tourist.gd:26`) — so at full population that is ~18 tourists × 60 Hz ≈ 1080
   identical writes/s. Add `var _tint_panic: bool = false` (false matches `_ready`'s
   initial `shirt_color` write, `tourist.gd:80`) and write the material only when
   `panicking != _tint_panic`, keeping the `if mat != null` guard. The
   bob/arm/lean/scale writes in the same function (`tourist.gd:199-213`) stay
   per-frame — they change continuously by design.
2. `scripts/main.gd` — cache the HUD stats string. `Main._process` rebuilds
   "Score: %d … ×N combo … Hunger: %d%%" and assigns `stats_label.text` every
   rendered frame (`main.gd:88-95`) although the content changes only when score,
   combo or the rounded hunger percent moves. Compose into a local, keep
   `var _stats_cache: String`, assign only on change. `_pulse_score` and the
   hunger-bar tier pulse in the same function are untouched.
3. `scripts/bread_spawner.gd` — make `nearest_crumb()` allocation-free (the
   extension beyond T-035). `Main._update_bread_pointer` calls
   `bread_spawner.nearest_crumb(pigeon_pos)` every rendered frame (`main.gd:144`),
   and `nearest_crumb` (`bread_spawner.gd:59-67`) routes through `living_crumbs()`
   (`bread_spawner.gd:50-52`) — a `filter` + `duplicate` that allocate two arrays
   (~`target_count` = 40 entries each) per call, whose result is discarded after the
   nearest scan (and re-filtered for every physics-tick caller). Iterate `_crumbs` in
   place with an `is_instance_valid(crumb)` skip instead. The contract is preserved
   exactly: return the nearest LIVING crumb, `null` when none is alive; pruning of
   `_crumbs` stays `living_crumbs()`'s job — `nearest_crumb` just stops paying for a
   private copy.

What this does NOT claim: a measurable frame-time win. The honest scale is
hygiene/headroom — `density_cpu_budget`'s calibrated median is 247.5 ms per 100
physics frames against the 750 ms budget (`sim_test.gd:2855-2861`), so nothing here
is a bottleneck. The write-SKIP itself gets no direct machine proof (an identical
write omitted is not observable through the material's value) — the guard is proven
by the value contract below plus the suite staying green; no existing scenario can
break either way, as the changes have no physics/signal/input surface.

## Why

Identical material writes and throwaway array allocations at tick/render rate. The
code facts are verified by direct read: the binary tint rewrites every physics tick
(above); the stats string rebuilds every rendered frame for content that moves at
human pace (above); the pointer's nearest-crumb scan allocates two arrays per
rendered frame (above). The planning lane's measured 78-93 fps in windowed sessions
is not re-capturable from this tree — the churn is a code fact at whatever fps the
machine renders. Attached dividend: today the tourist's red panic flush is only
behavior-adjacent checked — `tourist_splat_panics_scores` asserts mood/velocity/score
only (`sim_test.gd:1561-1573`); no scenario reads the actual shirt material color,
even though the harness already reads a `material_override` albedo elsewhere (cafe
sitter, `sim_test.gd:1415`; splat fade, `sim_test.gd:983`). The tint guard lands
together with the first machine proof of the flush.

## Acceptance criteria

- [ ] Extended `tourist_splat_panics_scores` proves the flush: the tourist's shirt
      material albedo equals `shirt_color` while calm and equals
      `Tourist.PANIC_TINT` mid-panic (exact — the tint is a binary write), read via
      the established `material_override as StandardMaterial3D` pattern
- [ ] `nearest_crumb()` stays behavior-identical:
      `hud_bread_pointer_tracks_nearest_crumb` stays green unchanged — its
      independent-scan contract (`spawner.nearest_crumb(at)` matches a scan over
      `living_crumbs()`, `sim_test.gd:2197-2198`) and the empty-spawner null arm
      (`sim_test.gd:2265-2266`) both still hold
- [ ] HUD string content unchanged: `hit_shake_and_score_pulse` still sees
      "×2 combo" in `stats_label.text` (`sim_test.gd:2642-2652`) and the
      pulse/settle behavior is untouched
- [ ] `hud_hunger_warning_tiers` and `density_cpu_budget` stay green (the tier pulse
      is driven by the same `_process`, and the budget re-proves no CPU regression)
- [ ] The panic flush still reads on screen exactly as before — [screenshot] Gate 3
      spot-check during the T-007 panic playtest line (arms-up sprint with the red
      flush, then back to the palette shirt)
- [ ] No new @export tunables, no input actions, no scene changes

## Verification

Gate 1 + Gate 1b: extend `tourist_splat_panics_scores` (`_scenario_tourist_splat`,
`sim_test.gd:1518-1574`) — capture the calm albedo before the drop, sample it inside
the existing 120-frame panic poll (`sim_test.gd:1552-1560`, the scenario already
tracks `mood == PANIC`), assert `is_equal_approx(Tourist.PANIC_TINT)`; the calm arm
asserts the tourist's own `shirt_color` (spawner-assigned by palette index,
`tourist_spawner.gd:115`). Explicitly re-run: `tourist_buzz_flinch`,
`sfx_splat_yelp_panic_honk`, `hud_bread_pointer_tracks_nearest_crumb`,
`hud_hunger_warning_tiers`, `hit_shake_and_score_pulse`, `density_cpu_budget`
(quiet machine — it false-FAILs under fleet load, per its own warning at
`sim_test.gd:2874-2876`). Gate 2 + Gate 3: the T-007/T-019 human lines already cover
both visuals; no new lines beyond the [screenshot] spot-check above. VERIFICATION.md:
update the `tourist_splat_panics_scores` row's "Proves" text to include the flush
assertion.
