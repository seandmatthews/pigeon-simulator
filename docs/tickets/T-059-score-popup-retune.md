# T-059 — Retune the world score popup: legible at hit distances, de-cluster chained hits

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** sweep 2 session `uiuxs2pz` (readings below; `f00001440.png`/`f00001452.png` in the
  lane worktree's gitignored `.captures/session_uiuxs2pz/`) · complements T-038 (style tag) and
  T-040 (HUD strip + hit marker) without overlap — T-040 explicitly leaves the world popup
  unchanged (`docs/tickets/T-040-combo-strip-hit-marker.md`, "Does not claim")

## What

Two changes, one commit, both inside the popup's own scene/script:

1. **World size.** `scenes/score_popup.tscn:10`: Label3D `pixel_size` 0.01 →
   **0.015** (`font_size` 96 stays, `scenes/score_popup.tscn:15`). Text height
   goes ~0.96 → ~1.44 m in the world: "+100" at 20 m renders ≈ 30 → 45 px,
   "+300 ×2" at 46 m ≈ 13 → ~20 px; the outline (`outline_size` 28) rides along.
   Record the final values in this ticket on landing; if the implementer trades
   pixel_size against font_size instead, one knob stays at its 0.01/96 baseline
   and both finals get recorded.
2. **Stagger.** `scripts/score_popup.gd`: chained popups inside the 20 s combo
   window rise in lockstep today (same `rise_height` 1.8, `scripts/score_popup.gd:10`)
   and merge into one unreadable line mid-rise. The stagger must live in the
   popup itself because Main passes no index (`scripts/main.gd:214`, kept 3-arg):
   - New `@export var rise_step: float = 0.9` — extra rise per concurrently-live
     earlier popup.
   - In `_ready()` (the popups already join the `score_popups` group,
     `scripts/score_popup.gd:36`): derive an index by scanning
     `get_tree().get_nodes_in_group("score_popups")` and counting valid non-self
     members, capped at 4. Deterministic — no RNG, no flakes — and self-cleaning:
     freed popups stop counting, and `restart_run`'s group sweep
     (`scripts/main.gd:242-243`) drains it between runs.
   - `var rise_total: float` (public, like `label` — the harness asserts it):
     `rise_height + index * rise_step`, used as the float tween's rise target
     (`scripts/score_popup.gd:41`) instead of `rise_height`.

What this does NOT claim: the 1.2 s lifetime untouched (`scripts/score_popup.gd:9`);
the "+N" / "+N ×M" format untouched (`format_text`, `scripts/score_popup.gd:22-25`);
no scoring-values change; no HUD work (T-040's); no style tag (T-038's). T-060 is
what makes these popups occur at all — this ticket only makes each occurrence
count double.

## Why

Scored hits almost never happen (T-060's evidence), so the payoff moment has to
land every time it fires — and today it renders as noise at the distances hits
actually occur. The popup is font_size 96 × pixel_size 0.01 ≈ 0.96 m of
gold-on-dark text (`scenes/score_popup.tscn:10-15`), spawned at the splat by
Main's own path (`scripts/main.gd:212-216`), lifetime 1.2 s rising 1.8 m
(`scripts/score_popup.gd:9-10`). Captured through that real path (env-gated
instrument, since reverted), session `uiuxs2pz` frames f1440/f1452: "+100" at
20 m ≈ 30 px and legible; "+30" at 32 m ≈ 15 px; "+300 ×2" at 46 m ≈ 13 px; and
the rising "+100" and "+300 ×2" billboards merge into a single unreadable line
(`f00001440.png`). Both defects are world-size problems, not HUD problems —
T-040's strip deliberately does not replace the world popup.

## Acceptance criteria

- [ ] At the recorded pixel_size, a "+300 ×2" at 40–46 m renders at least ~1.5×
      taller on screen than today (≈ 13 px → ≥ 20 px) [screenshot: a chained pair
      at 30–45 m reads as two numbers at a glance]
- [ ] Two popups alive inside the combo window carry distinct rise totals,
      exactly `rise_step` apart — they stay two numbers while rising [screenshot]
- [ ] A lone popup rises exactly `rise_height` (index 0) —
      `score_popup_floats_and_fades` passes untouched
- [ ] Both existing `setup()` callers compile unchanged (exactly two exist:
      `scripts/main.gd:214` and `tests/sim_test.gd:1924` — verified)

## Verification

Gate 1 + Gate 1b: extend `_scenario_score_popup` (`tests/sim_test.gd:1921-1934`)
with a chained arm through a REAL Main — instantiate `MAIN_SCENE` offset into its
own space (the `tests/sim_test.gd:2168` pattern), then fire two hits via
`Game.add_tourist_hit()` at two points 8 m apart in depth within one second:
`hit_scored` drives Main's own spawn path (`scripts/main.gd:212-216`). Assert two
live popups, distinct label texts (the chain pays "+100" then "+300 ×2"), and
`rise_total` differing by exactly `rise_step`. The original arm (direct
instantiate, default index 0, time-compressed lifetime) must pass untouched —
`_ready` at index 0 keeps the 1.8 m rise, so the existing `risen` check
(`global_position.y > 2.6` at +16 frames of a 0.5 s lifetime) is unaffected.
VERIFICATION.md: the `score_popup_floats_and_fades` Gate-1b row extended in the
same change-set. Gate 2 (the DONE line reports the popups but asserts no exact
values). Gate 3 [screenshot]: chained pair legible as two numbers at 30–45 m at
cruise.
