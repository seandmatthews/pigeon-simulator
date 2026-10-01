# T-075 — Calm the hunger→HUD write storm: emit only on real change, stop rewriting the bar at tick rate (T-055's missed 4th site)

- **Milestone:** Sweep backlog · **Status:** done · **Category:** code-optimization · **Value (1-5):** 2 · **Risk (1-5):** 2
- **Depends on:** — (T-005 hunger, T-019 HUD tiers and T-010 game-over flow, whose surfaces it touches, are landed; complements T-035/T-055)
- **Refs:** sweep 1 planning lane (code quality & performance) · `docs/tickets/T-035-redundant-presentation-writes.md` and `docs/tickets/T-055-redundant-writes-pointer-churn.md` (the sites they catalog) · line numbers on commit f77da93, this tree

## What

Two change-guards, one commit — `scripts/hunger.gd` and `scripts/main.gd`; no
new exports, no input actions, no scene changes:

1. `scripts/hunger.gd` — the `value` setter (`hunger.gd:37-42`) clamps and
   emits unconditionally on every write, and `_physics_process` subtracts the
   drain every tick (`hunger.gd:77`), so at zero it emits `(0.0, max_value)`
   ~60/s indefinitely in any unpaused context. Guard it: compute the clamped
   value, return early when it equals `_value`, assign and emit otherwise.
   While draining, consecutive ticks always differ (0.45/s ÷ 60 = 0.0075 per
   tick), so live-drain emissions are unchanged; what dies is the at-zero
   storm and redundant same-value writes (e.g. `eat()` at a full bar,
   `hunger.gd:84-86`). This makes the signal's own docstring — "Emitted on
   every value change" (`hunger.gd:11`) — true. Refresh the setter comment
   (`hunger.gd:37`) to match.
2. `scripts/main.gd` — `_on_hunger_changed` (`main.gd:174-188`) answers every
   emission by rewriting both ProgressBar fields (`hunger_bar.max_value` and
   `.value`, `main.gd:174-176`) although the drain moves the visible bar
   0.45%/s. Guard it: skip the `max_value` write when it already equals the
   argument, and write `hunger_bar.value` only when the rounded percent
   (`roundi(fraction * 100.0)`) OR `hud_warning_tier` changes — the tier half
   matters because a tier boundary can cross while the rounded percent stands
   still (50.4% → percent 50, tier 0; 49.98% → percent 50, tier 1). Track the
   last shown percent in a private `var _hunger_percent_shown: int = -1` (−1
   so the `_ready` re-fire at `main.gd:85` paints the initial full bar). The
   tier-change branch that repaints/parks the bar (`main.gd:185-188`) and the
   `_process` pulse (`main.gd:96-100`) are untouched, as is the stats line
   (T-035/T-055's site). The docstring at `main.gd:168-173` — which today
   claims the handler "only touches state on a tier CHANGE" while it rewrites
   the bar on every emission — is rewritten to describe the guarded contract.
   The explicit re-fires (`main.gd:85`, `main.gd:248`) stay: the handler is
   idempotent against the cache, so a skipped write only happens when the bar
   already shows that state.

What this does NOT claim: a measurable frame-time win — the honest scale is
hygiene/headroom, exactly as T-035/T-055 state (`density_cpu_budget`'s
calibrated median is 247.5 ms per 100 physics frames against the 750 budget).
In real play game over pauses the tree (the score screen owns the pause,
`main.gd:223-227`), so the at-zero storm is a live cost in unpaused contexts —
the sim harness, autoplay, any future non-pausing fail flow — and pure waste
everywhere; the per-tick bar rewrite while draining is the genuine in-run
cost.

## Why

120 redundant signal dispatches + Control writes per second for a bar whose
visible value moves 0.0075/tick. Code facts verified by read: the setter emits
unconditionally per write (`hunger.gd:37-42`); the drain writes `value` every
physics tick and clamps at zero, re-emitting while unpaused (`hunger.gd:77`);
Main rewrites both bar fields per emission (`main.gd:174-176`) under a
docstring that claims it doesn't (`main.gd:168-173`). T-035 catalogs the
tourist tint and the stats string; T-055 adds `nearest_crumb` — this
hunger→HUD path is in neither. Main is the `changed` signal's sole listener
(grep across `scripts/`: only `main.gd:71`; `sim_test.gd:2289` says the same
of the T-019 window), and the T-019 scenario only ever writes distinct probe
values (80/40/20/8, `sim_test.gd:2311`), so the setter guard cannot desync it.

## Acceptance criteria

- [x] Gate 1b `hunger_game_over_once` extended: after the game-over latch and
      the existing eat/drain-back leg (`sim_test.gd:815-817`), attach a
      `changed` counter (the member-var lambda pattern, `sim_test.gd:809-810`),
      run 120 further frames with the player still attached, and assert ZERO
      emissions (today: ~120, one per tick, `hunger.gd:77` →
      `hunger.gd:37-42`)
- [x] `hud_hunger_warning_tiers` stays green unchanged: distinct probes
      (`sim_test.gd:2311`) survive the setter guard, tier repaint/park on tier
      change is untouched, and the tier-OR-percent guard still catches a
      boundary crossed at a standing percent
- [x] `hunger_drain_flap_vs_glide`, `crumb_eaten_grounded_only`,
      `crumbs_respawn`, `restart_resets_run`,
      `restart_same_seed_skips_rebuild` and `density_cpu_budget` stay green
      unchanged (eat/restore paths read `value` directly; reset re-fires the
      handler explicitly, `main.gd:85`, `main.gd:248`)
- [x] Tier colors and the pulse animation look exactly as before —
      [screenshot] Gate 3 spot-check riding the pending T-019 human pass
      (bar/tier visuals through warn → danger → critical and back)
      (reviewer sign-off 2026-10-01; the machine half — tier modulates, pulse
      rates, rest-color restore — is covered unchanged by
      `hud_hunger_warning_tiers`; the T-019 look-and-feel pass itself remains
      pending and unchanged by this ticket)
- [x] Docstrings updated: `hunger.gd:11`/`hunger.gd:37` and
      `main.gd:168-173` describe the real emit/write contract
- [x] No new @export tunables, no input actions, no scene changes

## Verification

Gate 1 + Gate 1b: full suite headless (the documented command); the extended
`hunger_game_over_once` is the new proof; explicitly re-run
`hud_hunger_warning_tiers`, `hunger_drain_flap_vs_glide`,
`crumb_eaten_grounded_only`, `crumbs_respawn`, `restart_resets_run`,
`restart_same_seed_skips_rebuild`, `density_cpu_budget` (quiet machine — it
false-FAILs under load per its own warning, `sim_test.gd:2875-2876`).
VERIFICATION.md: update the `hunger_game_over_once` row's "Proves" text
(`VERIFICATION.md:71`) to include the zero-emissions-at-zero assertion.
Gate 2 + Gate 3 (the [screenshot] line above).

## Landed (2026-10-01, worktree t-075)

- `scripts/hunger.gd` — the `value` setter computes the clamped candidate and
  returns early when it equals `_value`; `changed` fires only on a real change.
  While draining, consecutive ticks always differ, so live-drain emissions are
  unchanged; the at-zero storm and same-value writes (e.g. `eat()` at a full
  bar) go silent. Signal and setter docstrings state the real contract.
- `scripts/main.gd` — `_on_hunger_changed` skips the `max_value` write when it
  already equals the argument, and writes `hunger_bar.value` only when
  `roundi(fraction * 100.0)` OR `hud_warning_tier` changes, tracked in
  `var _hunger_percent_shown: int = -1` (−1 so the `_ready` re-fire paints the
  initial full bar). Tier repaint/park and the `_process` pulse untouched; the
  explicit re-fires in `_ready`/`restart_run` stay (idempotent against the
  caches). Handler docstring rewritten to the guarded contract.
- No new @export tunables, no input actions, no scene changes (diff touches
  only `hunger.gd`, `main.gd`, `sim_test.gd`, `VERIFICATION.md`, this ticket
  and the index row).
- Tuned values: none — every behavior constant is untouched (`drain_per_second`
  0.45, `flap_drain_multiplier` 2.0, `grounded_drain_multiplier` 0.6, the
  T-019 tier thresholds/colors/pulse rates, `max_value`/`start_value` 100).
  The only new state is `_hunger_percent_shown: int` — a write-guard cache,
  not a tunable.
- `hud_hunger_warning_tiers` gained a standing-percent boundary arm (existing
  assertions untouched): 50.4% → 49.98% — percent 50 throughout, tier 0 → 1 —
  must still rewrite `hunger_bar.value` and repaint the tier, pinning the
  tier-OR-percent half of the guard (a percent-only guard would strand the bar
  at 50.4).
- Measured: pristine-tree suite 93 PASS / 0 FAIL (density median 240.4 ms);
  with only the sim-test extension landed, `hunger_game_over_once` FAILed
  red-before with `changed_fires=120` — exactly one storm emission per tick,
  as predicted; with the guards, the full suite is green again (93 PASS /
  0 FAIL, density median 238.4 ms against the 750 budget on the quiet
  machine), including all seven explicitly re-run scenarios. Gate 1
  `--import` + 120-frame boot clean. Gate 2 autoplay `AUTOPLAY DONE ok=true …
  restart=true` at fps 132 — the starve → score-screen → restart loop ran
  through the guarded paths.
- The Gate 3 [screenshot] line (tier colors and pulse look exactly as before
  through warn → danger → critical and back) rides the pending T-019 human
  pass — the machine half of that contract (tier modulates, pulse rates,
  rest-color restore) is covered unchanged by `hud_hunger_warning_tiers`.
  The ticket was accepted with reviewer sign-off (2026-10-01); the T-019
  standalone look-and-feel pass itself remains pending, unchanged by this
  ticket.
