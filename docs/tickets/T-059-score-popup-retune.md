# T-059 — Retune the world score popup: legible at hit distances, de-cluster chained hits

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** sweep 2 session `uiuxs2pz` (readings below; `f00001440.png`/`f00001452.png` live in the
  lane worktree's gitignored `.captures/session_uiuxs2pz/` and are not in this checkout — the
  absolute pixel figures stay session-recorded, and the size criterion is ratio-derived so it
  stands without them) · complements T-038 (style tag, proposed) and T-040 (HUD combo strip +
  hit marker, **done**) without overlap — T-040 explicitly leaves the world popup unchanged
  (`docs/tickets/T-040-combo-strip-hit-marker.md:43`, "Does **not** claim"), and its landed strip
  writes `combo_strip.text` beside the popup spawn in the same handler (`scripts/main.gd:388-391`)

## What

Two changes, one commit, both inside the popup's own scene/script:

1. **World size.** `scenes/score_popup.tscn:10`: Label3D `pixel_size` 0.01 →
   **0.015** (`font_size` 96 stays, `scenes/score_popup.tscn:15`). Text height
   goes ~0.96 → ~1.44 m in the world: "+100" at 20 m renders ≈ 30 → 45 px,
   "+300 ×2" at 46 m ≈ 13 → ~20 px; the outline (`outline_size` 28,
   `scenes/score_popup.tscn:14`) rides along. Record the final values in this
   ticket on landing; if the implementer trades pixel_size against font_size
   instead, one knob stays at its 0.01/96 baseline and both finals get recorded.
2. **Stagger.** `scripts/score_popup.gd`: chained popups inside the 20 s combo
   window (`scripts/game.gd:21`) rise in lockstep today (same `rise_height` 1.8,
   `scripts/score_popup.gd:10`) and merge into one unreadable line mid-rise. The
   stagger must live in the popup itself because Main passes no index —
   `popup.setup(points, multiplier, pos)`, still 3-arg
   (`scripts/main.gd:385`), inside a handler that now also receives a style bool
   it discards (`_style`, `scripts/main.gd:383`):
   - New `@export var rise_step: float = 0.9` — extra rise per concurrently-live
     earlier popup.
   - In `_ready()` (the popups already join the `score_popups` group,
     `scripts/score_popup.gd:36`): derive an index by scanning
     `get_tree().get_nodes_in_group("score_popups")` and counting valid non-self
     members, capped at 4. Deterministic — no RNG, no flakes — and self-cleaning:
     freed popups stop counting, and `restart_run`'s group sweep
     (`scripts/main.gd:417-418`) drains it between runs.
   - `var rise_total: float` (public, like `label` — the harness asserts it):
     `rise_height + index * rise_step`, used as the float tween's rise target
     (`scripts/score_popup.gd:41`) instead of `rise_height`.

What this does NOT claim: the 1.2 s lifetime untouched (`scripts/score_popup.gd:9`);
the "+N" / "+N ×M" format untouched (`format_text`, `scripts/score_popup.gd:22-25`);
no scoring-values change; no HUD work (T-040's, landed); no style tag (T-038's —
whose plumbing already exists unused: `hit_scored` carries a style bool
(`scripts/game.gd:162`) and Main's handler takes it as `_style` only
(`scripts/main.gd:383`); T-038 turns that discarded bool into a `setup` argument
and a text tag, and nothing here touches it). T-060 is what makes these popups
occur at all — this ticket only makes each occurrence count double.

## Why

Scored hits almost never happen (T-060's evidence), so the payoff moment has to
land every time it fires — and today it renders as noise at the distances hits
actually occur. The popup is font_size 96 × pixel_size 0.01 ≈ 0.96 m of
gold-on-dark text (`scenes/score_popup.tscn:10-15`), spawned at the splat by
Main's own handler (`_on_hit_scored`, `scripts/main.gd:383-386`: instantiate,
`setup`, `add_child`), lifetime 1.2 s rising 1.8 m
(`scripts/score_popup.gd:9-10`). Captured through that real path (env-gated
instrument, since reverted), session `uiuxs2pz` frames f1440/f1452: "+100" at
20 m ≈ 30 px and legible; "+30" at 32 m ≈ 15 px; "+300 ×2" at 46 m ≈ 13 px; and
the rising "+100" and "+300 ×2" billboards merge into a single unreadable line
(`f00001440.png`). Both defects are world-size problems, not HUD problems —
T-040's strip deliberately does not replace the world popup.

## Acceptance criteria

- [x] Gate 1b, chained arm: two popups alive inside one combo window carry
      distinct `rise_total`s exactly `rise_step` apart, with label texts
      "+100" then "+200 ×2" — the bare combo payouts (see Verification)
      *(proven: `SIM PASS score_popup_chain_stagger`)*
- [x] Gate 1b, lone popup: rises exactly `rise_height` (index 0) — the existing
      `score_popup_floats_and_fades` scenario (`VERIFICATION.md:95`) passes
      untouched *(proven: same Gate 1b run, scenario untouched and green)*
- [x] Both existing `setup()` callers compile unchanged (exactly two exist,
      re-counted on this branch 2026-10-02: `scripts/main.gd:385` — 4-arg since
      T-038 landed its `style` arg — and `tests/sim_test.gd:3688`; neither
      edited, both compiled by the green Gate 1b run)
- [x] [screenshot] Gate 3: at the recorded pixel_size a "+300 ×2" at 40–46 m
      renders at least ~1.5× taller on screen than today (≈ 13 px → ≥ 20 px),
      and a chained pair at 30–45 m reads as two numbers at a glance
      *(reviewer sign-off 2026-10-02)*

## Verification

Gate 1 + Gate 1b: extend `_scenario_score_popup`
(`tests/sim_test.gd:3444-3458`) with a chained arm through a REAL Main —
instantiate `MAIN_SCENE` offset into its own space (the
`tests/sim_test.gd:3525-3526` pattern; further exemplars at `:1534-1535`,
`:3614-3615`, `:3755-3756`, `:4067-4068`, `:4196-4197`, `:4283-4284`), then —
seeded by `Game.reset_run()` first, as that template does
(`tests/sim_test.gd:3523-3524`) — fire two hits via `Game.add_tourist_hit()` at
two points 8 m apart in depth within one second: `hit_scored` drives Main's own
spawn path (`scripts/main.gd:110` → `:383-386`). Assert two live popups,
distinct label texts, and `rise_total` differing by exactly `rise_step`.
**Expected labels are the BARE combo values: "+100" then "+200 ×2"** (100 × 1,
then 100 × 2 — `_register_hit` pays `base × combo_multiplier() × bonus` with
the style bonus gated behind `_is_style_hit` (`scripts/game.gd:154-156`,
`:168-171`), and that gate cannot pass here: the seeding `Game.reset_run()`
re-stales `_release_age` to 999 (`scripts/game.gd:74`, `:138`) and it only ever
grows (`scripts/game.gd:86`), so no poop release is ever staged inside the
window). Do not write "+300 ×2" — that figure is a styled payout and is
unreachable by this recipe. The original arm (direct instantiate, default index
0, time-compressed lifetime 0.5 s, `tests/sim_test.gd:3446`) must pass
untouched — `_ready` at index 0 keeps the 1.8 m rise, so the existing `risen`
check (`global_position.y > 2.6`, `tests/sim_test.gd:3452`) is unaffected.
VERIFICATION.md: the `score_popup_floats_and_fades` Gate-1b row extended in the
same change-set. Gate 2: unaffected — and say it plainly: the autoplay never
sees popups at all (its DONE line counts the `juice_effects` group,
`tests/autoplay.gd:144` and `:213-214`; popups join only `score_popups`,
`scripts/score_popup.gd:36`), so no autoplay change is expected or possible
from this ticket. Gate 3 [screenshot]: chained pair legible as two numbers at
30–45 m at cruise.

## Landed values (recorded 2026-10-02)

- **World size, no trade:** `pixel_size` **0.015** with `font_size` **96**
  unchanged (`scenes/score_popup.tscn`) — text height ~0.96 → ~1.44 m; the
  `outline_size` 28 rides along. One knob moved, one at baseline.
- **Stagger:** `rise_step` **0.9** (new export), `rise_height` **1.8**
  unchanged — index 0 rises exactly 1.8 m, index 1 2.7 m, capped at index 4
  (5.4 m); `lifetime` 1.2 s untouched.
- Gates run on this branch: Gate 1 (import/boot/`--check-only` on
  score_popup.gd — exit 0; the `--check-only` failures for autoload-referencing
  scripts are the mode's missing-autoload artifact, reproduced on untouched
  files), Gate 1b (exit 0, 0 failures — `score_popup_floats_and_fades`,
  `score_popup_style_tag_format`, `score_popup_style_tag_live` all untouched
  and green; new `score_popup_chain_stagger` pass), Gate 2 (`AUTOPLAY DONE
  ok=true`, exit 0 — `effects=4`, no popup visibility, as predicted above).
- Gate 3 [screenshot] leg closed by reviewer sign-off 2026-10-02 (the 1.5× leg
  is ratio-derived from the recorded pixel_size; the "reads as two numbers"
  leg passed human review).
