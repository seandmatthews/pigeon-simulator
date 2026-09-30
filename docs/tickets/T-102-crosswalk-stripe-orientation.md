# T-102 — Zebra stripes run with the traffic: flip T-069's crossing stripes 90°

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-069 (landed — the crossing machinery this corrects)
- **Refs:** owner Gate 3 pass on T-069 (2026-09-30, pilot session `xwalklook` + owner grabs,
  frames kept at `.captures/xwalk-ingame/`); real-world references downloaded to
  `.captures/xwalk-refs/` (`ref08` Singapore layout diagram, `ref01` Bangkok Asok
  intersection, `ref11` Shibuya aerial — zebra bars run ALONG the road, repeating ACROSS it;
  UK Highway Code: 500 mm stripes, 500 mm gaps, longitudinal)

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

- [ ] Gate 1b: the T-069 crossing scenario updated in this change-set asserts the
      longitudinal geometry — per band, bars repeat ACROSS the road at a 1.0 m pitch, each
      bar ~2.4 m along the road × ~0.5 m across — and the same-seed rebuild reproduces the
      spot lists byte-identically with the layout fingerprint equal to the pre-change value
      (zero `_fp` entries), red-before/green-after
- [ ] All T-069 keep-gates stay green: the full suite, determinism trio, walkability and
      flyover scenarios unchanged (zero colliders, zero RNG)
- [ ] [screenshot] Gate 3: walking down a road toward an intersection, the band ahead reads
      as a zebra — bars running away with the road, step-over rungs — matching
      `.captures/xwalk-refs/ref08`; from the air each crossing reads as a ladder with rails
      parallel to traffic (compare `ref11`)

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b full suite with the updated crossing scenario +
Gate 2 (autoplay unchanged) + Gate 3 (the [screenshot] line above, against the reference
photos).

**Pending human playtest (Gate 3):** the stripe orientation reads as a real zebra at eye
level and from the air; nothing else about the crossings changed.
