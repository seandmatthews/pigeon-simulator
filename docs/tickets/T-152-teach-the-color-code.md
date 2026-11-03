# T-152 — Teach the color code where the favor rule already lives

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** T-116 (the win-rule caption — the direct precedent: the win rule
  had the exact same invisibility gap and scene-static copy fixed it) ·
  the T-060 coach machinery (`scripts/main.gd:547-555`) · VERIFICATION.md
  rows `title_screen_teaches_controls` (~156) and
  `favor_meter_names_the_ceiling` (~142).

## What

Extend the two scene-static teach strings. No behavioral code, no input
changes — README/VERIFICATION control tables untouched.

1. **Menu footer** — `scenes/menu.tscn` `Footer` (text at `menu.tscn:109`,
   `"eat bread to survive · splat tourists (100) and cars (30) · max the
   elders' favor to take the town · don't starve · Q quit"`, 122 chars)
   gains the favor-mechanics clause: `"gold-and-black visitors pay favor ·
   splatting locals costs it"` (~62 chars). **Fit constraint:** the window
   is 1280 px wide (`project.godot` `window/size/viewport_width=1280`) and
   the footer is one centered 15 px line — 184+ chars likely overflows and
   a centered label clips both ends. Decision procedure: measure the
   rendered line (Gate 3 screenshot); authorized fallbacks in order —
   (a) shorten the clause to `"gold visitors pay favor · locals cost it"`
   (~159 chars total), (b) merge `"eat bread to survive · don't starve"`
   into `"eat bread or starve"` (−21 chars). Whichever shape lands must
   keep WHO pays (the gold-and-black visitors) and WHO costs (locals).
2. **HUD caption** — `scenes/main.tscn` `%FavorGoal` (text at
   `main.tscn:241`, `"max the elders' favor to take the town"`) gains the
   same one-liner as the moment-to-moment reminder. **Layout constraint:**
   the caption row is boxed 16→500 px (`main.tscn:233-236`) and the HUD's
   right column starts at `offset_left = 504` — the label cannot widen
   rightward. Spec: enable word autowrap on the label and grow
   `offset_bottom` by one 14 px line (two lines total; the space below the
   caption row is free HUD — FavorGoal is the left column's last row).
   Keep font 14 / outline 4 / white @ 0.6 — all pinned by
   `favor_meter_names_the_ceiling` (`tests/sim_test.gd:9556-9558`), and the
   `offset_top >= label.offset_bottom` leg (`9555`) still holds.

**One correction to the plan, load-bearing:** the plan claims "both guards
fail the same night the copy changes" — wrong for the footer. Its guard is
contains-only (`"favor"` + `"town"`, `tests/sim_test.gd:11741-11742`), so
ADDING a clause cannot fail it; only the caption gate (exact text,
`tests/sim_test.gd:9554`) fails. Therefore **tightening the footer guard is
required work in this ticket**, not a courtesy re-pin: extend
`win_rule_ok` in `_scenario_title_screen_teaches_controls` to also require
the teaching (`"visitors"`, `"pay"`, `"locals"`, `"cost"` co-occurring —
legs both authorized copy shapes satisfy), beside the existing favor/town
legs.

**Coach option deliberately excluded:** letting the T-060 coach slot teach a
class line after the first hit contradicts
`coach_hint_shows_until_first_hit`'s pin — `tests/sim_test.gd:2701` requires
`hint.text == MainGame.HINT_AIR` exactly once `tourist_hits == 1` (the slot
must fall back to the plain hint after the first hit). Not in this ticket;
`_update_hint`'s eligibility (`main.gd:550-553`) stays untouched.

## Why

The title footer names the win rule — `"… max the elders' favor to take the
town …"` — and the HUD caption repeats it, but nothing anywhere says HOW
favor moves: that gold-and-black visitors pay it (3 foot / 6 car), locals
cost it (−1 foot / −2 car), and superfans cost eight times as much (−8). A
first-run player discovers the −8 superfan penalty by doing it. The
session-1 title grab shows the footer giving score values for everyone
(`splat tourists (100) and cars (30)`) and favor mechanics for no one; the
caption's full text is the bare win rule (`main.gd:132-137` documents it as
scene-static, no code writer). T-116 is the precedent: the win rule had the
exact same invisibility gap and was fixed with scene-static copy.

## Acceptance criteria

- [ ] (Gate 1b) `title_screen_teaches_controls`'s `win_rule_ok` requires the
      new teaching: footer contains `"visitors"` AND `"pay"` AND `"locals"`
      AND `"cost"` (alongside the favor/town legs) — today's tree FAILS this
      tightened leg (red-before: the guard only checks favor/town,
      `sim_test.gd:11741-11742`).
- [ ] (Gate 1b) `favor_meter_names_the_ceiling`'s caption pin re-pinned to
      the new text with the clause required (`"pay"` + `"cost"` co-occur);
      the font 14 / outline 4 / white @ 0.6 / offset legs unchanged.
- [ ] (Gate 1b) No behavioral code changed: `coach_hint_shows_until_first_hit`
      green untouched; the full suite green apart from the two copy guards.
- [ ] (Gate 3) [screenshot] Title screen: the footer renders on ONE line
      inside 1280 px, nothing clipped at either end.
- [ ] (Gate 3) [screenshot] HUD: the caption reads as a tidy two-line block
      under the meter, no overlap with anything below.

## Verification

Gate 1 (import + boot) + Gate 1b: `title_screen_teaches_controls` (footer
guard tightened — VERIFICATION.md row ~156) and
`favor_meter_names_the_ceiling` (caption re-pin — row ~142) both re-pinned
in the same change-set; full suite green. Gate 2 unaffected (no code on the
static-copy path). Gate 3: the two screenshots above, recorded in this
ticket — copy fit is a look judgement the sim cannot make.
