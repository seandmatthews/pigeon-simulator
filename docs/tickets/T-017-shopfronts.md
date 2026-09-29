# T-017 — Shopfront ground floors

- **Milestone:** M2 · **Priority:** P1 · **Size:** S · **Status:** done
- **Depends on:** T-004 (city blockout), T-013 (district palettes)
- **Refs:** `docs/DESIGN.md` → The city · worldbuilding lens (street-level variety)

## What

Every generated building gets a ground-floor shopfront so street canyons read as
shops, not blank office walls:

- A **shop band**: a slightly protruding colored base (2.4 m tall) on the whole
  ground floor, tinted per building from a 4-color shopfront palette.
- A **door** on one street-facing face.
- An **awning** (60% of buildings) over the door: a 1.3 m deep slab at 2.9 m.

## Why

The lens finding behind this ticket: the city reads as "a grid of boxes" at eye
level — the ground floor is identical to the upper floors (one procedural window
texture, `scripts/city.gd` `_facade_material()`), the plaza is a bare slab, and
DESIGN's "café tables / statue square" street life does not exist yet. The shop
band is the cheapest lever that changes every street at once, and it was
prototyped live during the lane review before landing.

## Decisions (from the review pass)

- **Street faces only.** Doors and awnings go on the two lot faces that point
  away from the block center (streets); alley-facing sides stay blank. With
  `lot_gap` = 1.4 m, two alley-facing awnings at the same height would
  interpenetrate (~1.2 m), so alley faces are excluded by construction. The
  1.3 m awning depth is the geometric ceiling — no "deeper if shy" option.
- **Visual-only awnings (no collider).** Consistent with the city's other
  non-interactive decoration; the pigeon flying at street level will pass
  through awnings rather than snag on them. If the Gate 3 line below fails the
  feel-test, thin layer-1 colliders are the fallback.
- **Dedicated RNG stream.** Shopfront rolls draw from their own
  `RandomNumberGenerator` (seeded from the city seed alongside the layout RNG),
  so the existing layout stream is untouched: the default-seed city keeps every
  building, park, bench and bread spot exactly where it was — only the
  shopfront decoration and the appended fingerprint entries are new. (An earlier
  plan reused the shared stream, which would have re-rolled the whole city
  downstream of the first shopfront.)
- **Fingerprint covers shopfronts.** Each building appends its shop color,
  door face and awning flag to the layout fingerprint, so the existing
  same-seed determinism scenarios also pin shopfront variety.

## Acceptance criteria

- [x] Every building carries a shop band, a door on a street-facing face, and
      the seeded share of awnings — machine-verified: `city_shopfronts_present`
      (100% band+door coverage, door face ∈ the lot's two street faces,
      awning count pinned to the seed's deterministic 104/146, palette
      membership).
- [x] The shopfront palette is measurably distinct from all four district
      palettes — machine-verified in the same scenario (mean distance > 0.1).
- [x] Regenerating the same seed reproduces every shopfront identically, and
      the default-seed layout (buildings/parks/benches) is unchanged from
      before this ticket — machine-verified: `city_shopfronts_deterministic`
      plus the existing `city_same_seed_deterministic` fingerprint pair.
- [ ] Gate 3 human lines (below) pass — pending playtest.

## Tuned values (final, `scripts/city.gd`)

| Value | Value | Note |
| ----- | ----- | ---- |
| `SHOPFRONT_PALETTE` | 4 colors | Café red-brown, bakery cream, bookshop green, deli teal; all > 0.1 RGB-distance from each district-palette mean (harness-asserted) |
| Band height / outset | 2.4 m / 0.12 m | 6 cm proud of the facade — reads as a base, stays inside prop clearance |
| `door_size` | 0.95 × 2.05 m | One per building, centered on its street face |
| Awning chance | 0.6 | Seed 20260928 lands on **71.2%** of the 146 buildings (**104/146**) — the harness pins this exact count; retune the pin if the chance changes |
| Awning size | 1.3 m deep × 55% face width | Depth capped by the 1.4 m alley width |
| Awning height | 2.9 m | Street-flight altitude — deliberately collider-free (see Decisions) |

## Verification

- Gate 1 (import + 120-frame boot): clean, exit 0, no errors. Note:
  `--check-only --script res://tests/sim_test.gd` reports pre-existing
  "Identifier not found: Sfx/Game" compile noise (autoload singletons are
  invisible to script-only checks) — it predates this ticket; the suite run is
  the authority for that file.
- Gate 1b: `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
  → exit 0, **65/65 SIM PASS** (`city_shopfronts_present`,
  `city_shopfronts_deterministic` green). Baseline comparison with this
  ticket's changes stashed: 63/63 PASS, exit 0, identical exit-time
  leak/resource notices — nothing weakened, nothing newly leaked.
- Gate 2: run by the orchestrator (not this lane).
- Evidence session (this worktree, pilot harness, session `wt017-evidence`):
  street-level view `.captures/session_wt017-evidence/f00001224.png` (shop
  bands + doors on every building ringing the plaza) and flight-level view
  `.captures/session_wt017-evidence/f00001644.png` (bands and door slots
  readable from a low glide). These two frames are kept; the rest of the
  session's frame stream was pruned after review.

**Pending human playtest (Gate 3):** the four lines added to
`VERIFICATION.md` — shop-row read at street level, bands readable from the air,
shop colors harmonize with the district palettes, and low street flight does
not snag on or visibly pass through awnings.
