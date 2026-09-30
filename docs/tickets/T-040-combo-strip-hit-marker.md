# T-040 — HUD combo strip & hit marker: make every scored hit readable

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-009 · T-013 (both done); T-038 (the strip appends the STYLE tag once it lands — land T-038 first, or leave the suffix to it)
- **Refs:** UI/UX lane playtest, sweep 1 (2026-09-29)

## What

Two cheap reinforcing feedbacks at hit time:

- **`%ComboStrip`** — a new Label (unique name in owner) in the HUD
  CanvasLayer, left column below the hint block (below HintLabel's
  `offset_bottom` 88; if T-037's bread pointer lands first, stack beneath
  it), styled like the hint line: 14 px, `outline_size` 4,
  `font_outline_color` `Color(0, 0, 0, 0.85)` (the T-019 treatment,
  `scenes/main.tscn:88-98`). Empty at rest.
- **Wiring (this corrects the idea's sketch):** `hit_scored`
  (`scripts/game.gd:14`) carries points/multiplier/pos/style but NOT the
  target kind, so the kind word must come from the splat handlers
  (`scripts/main.gd:150-157`): `_on_tourist_splatted` stashes
  `_last_hit_kind = "Tourist"` (and fires the marker below),
  `_on_car_splatted` stashes `"Car"`; the synchronous
  `Game.add_*_hit → hit_scored → _on_hit_scored` chain then composes the
  strip text: `"%s +%d" % [kind, points]`, plus `" ×%d"` when the multiplier
  ≥ 2, plus `" STYLE"` once T-038 lands — e.g. `"Tourist +100"`,
  `"Tourist +450 ×3 STYLE"`, `"Car +30"`.
- **Expiry:** new `@export combo_strip_seconds: float = 2.5` — the strip
  clears after that much game time via a phase accumulated in
  `_process(delta)` (the T-019 pulse-phase pattern, `scripts/main.gd:52,91-95`:
  game time, not wall clock — deterministic under `--fixed-fps`, freezes with
  a paused or ended run). `restart_run()` (`scripts/main.gd:187-199`) also
  clears it.
- **Marker ring** — a new one-shot burst scene (e.g. `scenes/hit_marker.tscn`
  on the shared `scripts/one_shot_burst.gd`): a brief high-contrast
  ring/flash spawned at the hit point from the splat handlers, parented to
  the hit body (the `scripts/poop.gd:85-93` parenting pattern, so it rides a
  moving tourist/car for its brief life). It joins the `juice_effects` group
  via `OneShotBurst._ready` (`scripts/one_shot_burst.gd:18`) — the group
  tests/autoplay already count, so no new bookkeeping; the autoplay DONE
  line's `effects` figure reports a peak, not an equality, so one extra burst
  per scored hit only moves the reported number.

Does **not** claim: no scoring change; no change to the world popup or its
1.2 s life (this is reinforcement, not replacement); no new input; no camera
work.

## Why

Today a scored hit's only "what / which / worth" feedback is a world-space
popup that lives 1.2 s and rises 1.8 m (`scripts/score_popup.gd:9-10`) at a
point the pigeon passes in well under a second at the lane-measured 19–24 m/s
— and the chase camera looks forward, so the popup leaves frame early. The
only "which tourist" signal is the red panic flush (`scripts/tourist.gd:26`)
plus a 2.6 s sprint (`scripts/tourist.gd:36-37`), readable only at close range
— the lane's autoplay grab shows tourists as specks from cruise altitude. And
scoring feedback essentially never displays in normal play: the lane observed
~5 minutes across four runs with zero readable scored hits, and the project's
own autoplay DONE line reads `splats=10 … panics=0 … score=0`. Each occurrence
must count.

## Acceptance criteria

- [ ] The HUD has a `%ComboStrip` label under the hint block with the T-019
      outline treatment, empty at run start (Gate 1b)
- [ ] Through the real Main's spawner→Game wiring, a tourist splat shows the
      strip with kind + points ("Tourist +100"; ×N when chained) and a
      following car splat replaces it with "Car +30" — Gate 1b only (needs
      the real relay)
- [ ] The strip clears itself after `combo_strip_seconds` of game time and
      stays cleared — Gate 1b only (game-time expiry is only provable under
      `--fixed-fps`)
- [ ] `restart_run()` clears the strip mid-display (Gate 1b)
- [ ] A scored hit spawns a self-cleaning marker burst at the hit point on
      the hit body, present in the `juice_effects` group (Gate 1b — assert
      via the group, mirroring `juice_splat_burst_fires`)
- [ ] The strip is readable mid-flight wherever the pigeon flew and the
      marker helps the eye find which body panicked — [screenshot]

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b — new scenario
`combo_strip_reports_last_hit` through a real Main instance (own space, the
`_scenario_hud_hunger_tiers` pattern, `tests/sim_test.gd:1864-1948`): pick a
tourist from `tourist_spawner.living_tourists()` and a car from
`car_spawner.living_cars()` and emit `tourist_splatted` / `car_splatted` so
the full handler→Game→hit_scored relay runs without physics; assert the strip
text per hit; advance ~3 s of game time and assert empty; fire one more hit
and call `main_game.restart_run()` to assert the restart clear inside this
scenario (`_scenario_restart_resets` itself stays untouched). Same cleanup
tail as the T-019 window: `free()` → `Game.hunger.player = null` →
`Game.reset_run()`. Full suite green, explicitly `hit_shake_and_score_pulse`
and `density_cpu_budget`. Gate 2: unaffected — the DONE line's `effects`
peak moves informationally only. Gate 3: [screenshot] pass — the strip is
readable at cruise and the marker draws the eye to the hit.
