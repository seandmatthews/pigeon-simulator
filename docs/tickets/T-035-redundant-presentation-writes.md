# T-035 — Stop the per-frame redundant presentation writes

- **Milestone:** Sweep backlog · **Status:** superseded (T-055 — this plus the bread-pointer churn) · **Category:** code-optimization · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** — (T-007 and T-019, whose surfaces it touches, are landed)
- **Refs:** `docs/tickets/T-018-performance-budget.md` → Calibration (the honest scale: this is headroom, not a bottleneck) · sweep 1 planning session

## What

Two write loops that run at full rate against work nobody sees:

1. `scripts/tourist.gd:214-216` — `_animate()` (called from `_physics_process`
   every physics tick, `tourist.gd:99`) ends with an unconditional
   `mat.albedo_color = PANIC_TINT if panicking else shirt_color` on each
   tourist's duplicated shirt material (the per-tourist duplicate at
   `tourist.gd:79`, shared by body + both arms via `material_override`). The
   tint is a hard binary switch — calm is always `shirt_color`, panic always
   `PANIC_TINT` — so all but two of the ~18 writes per panic cycle are
   identical rewrites. At full population that is 18 tourists × 60 Hz ≈ 1080
   redundant material writes/s. Cache the state: a `var _tint_panic: bool =
   false` (calm matches `_ready`'s initial `shirt_color` write) and write the
   material only when `panicking != _tint_panic`. The bob/arm/lean/scale
   animation writes in the same function (`tourist.gd:199-213`) stay per-frame —
   they change continuously by design.
2. `scripts/main.gd:83-90` — `Main._process` rebuilds the stats string
   ("Score: %d … ×N combo … Hunger: %d%%") and assigns `stats_label.text` every
   rendered frame (144 fps in the T-018 pilot context) although the content
   changes only when score, combo or the rounded hunger percent moves. Compose
   into a local, keep a `var _stats_cache: String`, assign only on change.
   `_pulse_score` and the hunger-bar tier pulse in the same function are
   untouched.

What this does NOT claim: a measurable frame-time win. The honest scale is
hygiene/headroom — `density_cpu_budget`'s calibrated median is 247.5 ms per 100
physics frames against a 750 ms budget (`sim_test.gd:2415-2419`), so nothing
here is a bottleneck.

## Why

No player-visible problem — this is a hygiene ticket, and it says so. The churn
is pure waste (identical writes at tick rate), and removing it ships with a
proof dividend: today the tourist's red panic flush is only behavior-adjacent
checked (a mood/shout poll, `sim_test.gd:2369`) — no scenario reads the actual
shirt material color, even though the harness already reads
`material_override.albedo_color` elsewhere (`sim_test.gd:939`). The guard lands
together with the first machine proof of the flush.

## Acceptance criteria

- [ ] Extended `tourist_splat_panics_scores` proves the flush: the tourist's
      shirt material albedo equals `shirt_color` while calm and equals
      `PANIC_TINT` mid-panic (exact — the tint is a binary write), read via the
      established `material_override as StandardMaterial3D` pattern
- [ ] The panic flush still reads on screen exactly as before — [screenshot]
      Gate 3 spot-check during the T-007 panic playtest line (arms-up sprint
      with the red flush, then back to the palette shirt)
- [ ] HUD string content unchanged: `hit_shake_and_score_pulse` still sees
      "×2 combo" in `stats_label.text` and the pulse/settle behavior is
      untouched
- [ ] `hud_hunger_warning_tiers` and `density_cpu_budget` stay green (the tier
      pulse is driven by the same `_process`, and the budget re-proves no CPU
      regression)
- [ ] No new @export tunables, no input actions, no scene changes

## Verification

Gate 1 + Gate 1b: extend `tourist_splat_panics_scores` (`sim_test.gd:1318`) —
capture the calm albedo before the drop, sample it inside the existing
120-frame panic poll (the scenario already tracks `mood == PANIC`,
`sim_test.gd:1352-1355`), assert `is_equal_approx(Tourist.PANIC_TINT)`. The
write-SKIP itself gets no direct proof (an identical write omitted is not
observable through the material's value) — the guard is proven by the value
contract above plus the suite staying green; no existing scenario can break
either way, as the change has no physics/signal/input surface. Explicitly
re-run: `tourist_buzz_flinch`, `sfx_splat_yelp_panic_honk`,
`hud_hunger_warning_tiers`, `hit_shake_and_score_pulse` (reads `label.text`
at `sim_test.gd:2210`), `density_cpu_budget`. Gate 2 + Gate 3: the T-007/T-019
human lines already cover both visuals; no new lines beyond the [screenshot]
spot-check above. VERIFICATION.md: update the `tourist_splat_panics_scores`
row's "Proves" text to include the flush assertion.
