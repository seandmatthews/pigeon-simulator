# T-154 — Retire the amber civilian shirt — the last gold hue-twin

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** — (builds on the landed T-121 reservation law; independent of T-151)
- **Refs:** T-121 (`docs/tickets/T-121-unmistakable-targets.md` — the car
  hue-twin fix, done; its Gate 3 aerial line *"visitor flags read at
  distance"* still pending owner eyes, ticket lines 48-50) · the class
  colors (`scripts/citizen_class.gd:6-8`) · the car-paint precedent
  (VERIFICATION.md `civilian_palette_reserved`, row ~127).

## What

Swap `SHIRT_PALETTE[1]` in `scripts/tourist.gd:31-35` — `Color(0.95, 0.68,
0.20)` (amber) — for the deep orange `Color(0.95, 0.42, 0.08)`. Measured
Euclidean RGB distances (recomputed this session over
`tourist.gd:31-35` vs `citizen_class.gd:6-8`): amber→`TEAM_GOLD` **0.239**
(the hue-twin); the replacement clears **0.392** from `TEAM_GOLD`, **0.934**
from `VISITOR_BLACK`, **0.410** from `SUPERFAN_CARDINAL`.

Exactly 8 entries stay, so nothing downstream moves: the `index % size`
round-robin draw (`scripts/tourist_spawner.gd:92`,
`scripts/cafe_spawner.gd:125`), the seeded class multisets (within-run
`shirt_color.to_html()` rows at `tests/sim_test.gd:7885`, `7971`, `7992` —
both sides move together), and every index/membership-derived pin
(`tests/sim_test.gd:3475`, `8137`, `8577`).

**Reserved-law shape — one correction to the plan:** the plan names "a tone
in the maroon/deep-orange family" clearing ≥ 0.30 from BOTH team colors,
omitting `SUPERFAN_CARDINAL`. Maroons sit 0.19–0.28 from cardinal (my
matrix; the eval measured 0.213–0.234 for its samples) — worse twins than
the 0.239 being fixed, on the −8 class — and a set-wide cardinal bar is NOT
cleanly available: the existing red shirt is itself **0.272** from cardinal
(any bar > 0.272 fails red; any bar < ~0.25 admits maroons). So:

- The new entry `[1]` is pinned ≥ 0.30 from **all three** class colors
  (deep orange qualifies: 0.392 / 0.934 / 0.410).
- The set-wide bar stays gold+black at 0.30 for all 8 entries — today every
  non-amber entry already clears it (worst: red 0.590 gold, purple 0.787
  black); only amber fails.
- A code comment at the palette documents the cardinal constraint so the
  next palette edit doesn't re-derive it the hard way.

## Why

For visitors that carry no foam finger, shirt color is the only
per-pedestrian tell at flight distance — and one civilian palette entry
sits 0.239 Euclidean from `TEAM_GOLD`, less than half the next-worst margin
(red 0.590) and barely over the project's own reserved bar for car paints
(0.20, measured worst 0.61 — VERIFICATION.md `civilian_palette_reserved`).
T-121 fixed exactly this hue-twin failure for cars but the pedestrian shirt
kept it; its refs record the owner already misidentifying gold-adjacent
cars pre-fix, and its Gate 3 aerial check ("visitor flags read at
distance") is still pending owner eyes — the uiux2 session could not
confirm the yellow visitor car's flag until the +6 favor landed, the same
read failing in live play. T-151 names the class in the readout after the
hit; this ticket fixes the read BEFORE it.

## Acceptance criteria

- [ ] (Gate 1b) New scenario `civilian_shirt_palette_reserved` mirroring
      `civilian_palette_reserved`'s constants-level shape
      (`tests/sim_test.gd:8250-8272`, the `_rgb_dist` helper): `Tourist.
      SHIRT_PALETTE` holds exactly 8 entries; every entry ≥ 0.30 Euclidean
      from `TEAM_GOLD` and `VISITOR_BLACK`; entry `[1]` additionally ≥ 0.30
      from `SUPERFAN_CARDINAL`. Red-before: today's amber measures 0.239
      and fails the first leg.
- [ ] (Gate 1b) `citizen_classes_spawn_deterministic` re-runs green in the
      same suite pass — the equal-size swap moved no seeded draw.
- [ ] (Gate 1b) The cafe-sitter tint law (`tests/sim_test.gd:3475`) and the
      civilian membership legs (`tests/sim_test.gd:8137`) green untouched —
      every palette consumer reads by index or membership.
- [ ] (Gate 3) [screenshot] Pilot grab of an amber-free crowd beside a
      gold-torso visitor at typical flight height, recorded in this ticket
      alongside T-121's still-open aerial line.

## Verification

Gate 1 (import + boot) + Gate 1b: new `civilian_shirt_palette_reserved`
(VERIFICATION.md row beside `civilian_palette_reserved`, ~127) + full suite
green with `citizen_classes_spawn_deterministic`, `citizen_classes_readable`
and `cafe_sitters_on_the_rig` explicitly re-run in the same pass. Gate 2
unaffected (presentation-only — one color literal). Gate 3: the pilot grab
above; cross-link the screenshot from T-121's pending aerial note so the
two look-checks close together.
