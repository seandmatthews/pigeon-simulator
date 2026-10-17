# T-121 — Unmistakable targets: reserve black-and-gold for the visitors, grow the flag

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-16) · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** owner report 2026-10-16: *"Sometimes a car is just yellow and its
  wheels are black but it's not a black/yellow target car."*
  `scripts/car.gd:23-27` — the civilian `BODY_PALETTE` holds a gold
  `Color(0.93, 0.78, 0.25)` and a near-black `Color(0.22, 0.24, 0.26)`,
  hue-twins of `CitizenClass.TEAM_GOLD` / `VISITOR_BLACK`;
  `scenes/car.tscn` `Mat_tire` — one shared near-black tire material on every
  car, so "black wheels" discriminates nothing; `scripts/car.gd:115-121`
  (`_show_flag`); the T-113 class colors (`scripts/citizen_class.gd`).

## What

Civilian cars can spawn in colors that read as visitor black-and-gold at a
glance, while the visitors' real tells (flag + banner, trunk cooler) are too
small to save it. Two-part fix:

1. **Reserve the combo.** Drop the gold and near-black entries from the
   civilian `BODY_PALETTE` (7 → 5 colors). Pure data — the T-113 class-quota
   machinery (`_begin_class_quota` / `_assign_class`) is untouched; civilians
   keep the palette round-robin draw.
2. **Grow the true tell.** Taller flag pole + larger banner so a visitor car
   reads from ahead, behind, and at distance. Keep the scene contract: flag
   meshes hidden by default, `_show_flag` raises and paints them. (The roof
   topper idea deliberately waits for T-124, where the car model gets
   rebuilt anyway.)

If any sim scenario pins the old palette contents (seeded paint draws),
update the pinned values in the same change — mechanical, not a bar
re-derivation.

**Route note:** presentation-only → direct-loop eligible. Re-check the read
from the air after T-124's model swap.

## Acceptance criteria

- [ ] *(Gate 1b)* a scenario pins the civilian palette contents (the 5
      remaining colors, gold/near-black absent) and the flag mesh sizes, so a
      silent revert fails
- [ ] *(Gate 1b)* across the seeded-spawn scenarios no civilian car wears a
      TEAM_GOLD-hue or VISITOR_BLACK-hue body; class quotas unchanged
      (T-113 scenarios green untouched)
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 3)* aerial grabs from typical flight heights: gold civilians
      with dark tires no longer occur, visitor flags read at distance —
      before/after screenshots recorded here
