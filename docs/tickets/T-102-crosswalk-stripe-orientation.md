# T-102 — Zebra stripes run with the traffic: flip T-069's crossing stripes 90°

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-069 (landed — the crossing machinery this corrects)
- **Refs:** owner Gate 3 pass on T-069 (2026-09-30, pilot session `xwalklook` + owner grabs,
  frames kept at `.captures/xwalk-ingame/`); **in-repo references (the source of truth —
  commit `820d304`): `docs/references/zebra-crossing/`** — `research.md` (orientation +
  proportions), `singapore-zebra-layout-diagram.png`, `asok-intersection-bangkok.jpg`,
  `shibuya-crossing-aerial.jpg`, two Showa-dori drone shots; credits in that directory.
  Zebra bars run ALONG the road, repeating ACROSS it (UK Highway Code: 500 mm stripes,
  500 mm gaps, longitudinal)

## What

One geometry change in the `_build_crossings()` pass T-069 added to `scripts/city.gd`: today
each stripe is a box **0.4 m along the road × road_width across**, repeating every 0.5 m ALONG
the road — a transverse piano-key band. Real zebra stripes are the opposite: bars run
longitudinally (with traffic) and repeat across the road. Flip the orientation:

- Per approach band (same 224 band placements, same center line ≈ `road_width * 0.5 + 1.2`
  = 6.2 m out from the node, same skip rules for rim approaches whose band would leave the
  asphalt): stripes are now boxes **2.4 m along the road (the band depth) × 0.5 m across**,
  repeating across the road at a 1.0 m pitch — `road_width / 1.0` ≈ 10 bars per band at
  defaults (≈ 2,240 instances total, up from 1,120; still one MultiMesh draw key, zero
  colliders, zero RNG, zero `_fp` entries — the layout fingerprint stays byte-identical).
- Update T-069's Gate 1b scenario asserts to the longitudinal geometry (bars-per-band across,
  bar extents along the road) — a spec change, so the scenario changes with it
  red-before/green-after inside this change-set; the determinism/fingerprint asserts stay.
- VERIFICATION.md row + ticket index updated in the same change-set.

What this does NOT claim: no band placement, count, collider, RNG or fingerprint change —
same bands, same spots, stripes re-oriented.

## Why

The owner's Gate 3 pass with real-world references showed the crossings read as repeated
give-way lines rather than the iconic zebra pattern — the one polish gap in an otherwise
passing T-069 (bands hug the corners, nothing paints on grass, strong contrast, readable at
eye level and from the air). Longitudinal stripes are what every real crossing uses
(Abbey Road geometry); the fix is a box-dimension swap in one function.

## Acceptance criteria

- [x] Gate 1b: the T-069 crossing scenario updated in this change-set asserts the
      longitudinal geometry — per band, bars repeat ACROSS the road at a 1.0 m pitch, each
      bar ~2.4 m along the road × ~0.5 m across — and the same-seed rebuild reproduces the
      spot lists byte-identically with the layout fingerprint equal to the pre-change value
      (zero `_fp` entries), red-before/green-after
- [x] All T-069 keep-gates stay green: the full suite, determinism trio, walkability and
      flyover scenarios unchanged (zero colliders, zero RNG)
- [x] [screenshot] Gate 3: walking down a road toward an intersection, the band ahead reads
      as a zebra — bars running away with the road, step-over rungs — matching
      `.captures/xwalk-refs/ref08`; from the air each crossing reads as a ladder with rails
      parallel to traffic (compare `ref11`) — agent-side grabs kept at
      `.captures/t102_eyelevel_zebra.png` / `.captures/t102_aerial_ladder.png`,
      accepted by reviewer sign-off (2026-10-01)

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b full suite with the updated crossing scenario +
Gate 2 (autoplay unchanged) + Gate 3 (the [screenshot] line above, against the reference
photos).

**Machine pass (2026-10-01, this change-set, worktree `t-102`):** red-before — with only
the scenario update in the tree, the full Gate 1b suite on the un-flipped builder fails
exactly one scenario, `SIM FAIL city_crosswalks_present: count=1120/2240 geometry=false
y=false clear=true asphalt=false placement=false det=false colliders=0` (91 PASS, exit 1),
and the informational line still prints the pre-change fingerprint `2492360539`.
Green-after — `city_crosswalks_present` PASSes with
`SIM DATA city_crosswalks: bars=2240 bands=224 fingerprint=2492360539` (2,240 bars = 224
bands × 10, fingerprint byte-identical to the pre-T-069 pin), the full suite is 92/92 PASS
with exit 0 (determinism trio, walkability and flyover scenarios untouched and green,
`colliders=0`), Gate 1 `--import` and the 120-frame `--quit-after 120` boot both exit 0,
and Gate 2 autoplay reports `AUTOPLAY DONE ok=true … restart=true` at fps 134. Landed
values: `CROSSWALK_OUTSET 6.2`, `CROSSWALK_BAND_DEPTH 2.4`, `CROSSWALK_BAR_PITCH 1.0`,
`CROSSWALK_BAR_WIDTH 0.5` (bars per band derived as `road_width / pitch` = 10 at the
defaults; band reach 6.2 + 1.2 = 7.4 m unchanged, so the 224 band placements and every
skip rule carry over unchanged).

**Agent-side Gate 3 grabs (pilot session `t102zebra`, kept at `.captures/`):**
`t102_eyelevel_zebra.png` — waddling down the x=16 road toward the (16, −16) node, the
band ahead reads as a zebra: bars running away with the road, step-over rungs, both bands
of the intersection and the side street's band all longitudinal;
`t102_aerial_ladder.png` — frame `f00022464` of the same session, airborne over the
(16, −80) intersection: all four bands read as ladders with rungs parallel to their
traffic. **Gate 3 accepted by reviewer sign-off (2026-10-01):** the stripe orientation
reads as a real zebra at eye level and from the air against the reference photos
(`.captures/xwalk-refs/` ref08/ref11); nothing else about the crossings changed.
