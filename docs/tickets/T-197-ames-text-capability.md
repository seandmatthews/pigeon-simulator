# T-197 — Ames R4 · text capability: in-world signs become possible

- **Status:** doing · **Category:** code-optimization · **Ring:** R4 The Names ·
  **Value (1-5):** 5 · **Risk (1-5):** 4
- **Depends on:** T-196 (heroes carry the signs)
- **Refs:** `docs/AMES-MASTERPLAN.md` §7 · T-090 (the blank-signboard
  convention this RETIRES deliberately) · `venues/VENUES.md` exterior
  descriptions (sign typologies) · `images/campustown/`, `images/downtown/07`
  (box/blade/pole typology refs) · legal tiering (ames-campaign memory
  + master plan §0)

## What

The game renders ZERO in-world text today (T-090's convention). R4's
first ticket builds the capability, deliberately scoped:

1. **`scripts/sign_text.gd`** — a Label3D-based sign component:
   mesh plaque/box/blade/pole body + rendered text face; unshaded or
   SDF font at distance; legibility budget (readable at X m for a
   given letter height — pinned per typology).
2. **One OFL font** (candidate: a condensed grotesque for bar signs +
   a clean sans for plaques — exact pick in-ticket with license file
   bundled under `assets/fonts/` + credits entry).
3. **The three typologies as scenes**: box sign (Campustown's lit
   boxes), blade sign (downtown neon-ish verticals), pole sign (Lincoln
   Way's big-box poles) — geometry per the photo refs, text via the
   component.
4. **Credits screen** (menu, minimal): OSM attribution ("Map data ©
   OpenStreetMap contributors"), the photo CC credits (the survey's
   CREDITS.md files summarized), font license — the ODbL obligation
   lands here.
5. **No gameplay text changes**: HUD/menus untouched; in-world only.

## Why

"I fly to Welch Ave Station and find my bar" requires letterforms.
This ticket is deliberately hero-free — pure capability + the legal
screen — so every later sign ticket is content, not plumbing.

## Acceptance criteria

- [ ] The component + three typology scenes exist and place into any
      slot; text legible at the pinned distances (per typology)
- [ ] Font license bundled; credits screen live with OSM + photo
      attributions
- [ ] *(Gate 1b)* `sign_text_legibility`: per-typology letter-height →
      readable-distance pins; `credits_screen_content`: the three
      attribution classes present
- [ ] T-090's blank-plaques elsewhere unchanged (adoption is
      per-ticket, not global)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + two rows · Gate 2 · Gate 3: screenshots of each
typology in-situ (test placements), owner eyeball pass folded into
T-202.
