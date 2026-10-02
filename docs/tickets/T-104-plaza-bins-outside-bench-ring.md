# T-104 — Move the spawn plaza's bins outside the bench ring: today they bury into the diagonal benches

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-029, T-093 (both landed — the plaza landmark this layout edits, and the one-body-per-group `Static/Props` structure the new scenario reads)
- **Refs:** owner request (2026-10-02): "bins clip through the four diagonal benches … fix: honor the stated intent — bins on the diagonals but radially outside the bench ring — and add a Gate 1b check that plaza prop colliders don't intersect" · research: [`docs/references/plaza-bench-ring/research.md`](../references/plaza-bench-ring/research.md) (+ its 8 Commons images, [`credits.md`](../references/plaza-bench-ring/credits.md)) · sibling note: [`docs/references/plaza-litter-bin/research.md`](../references/plaza-litter-bin/research.md)

## What

The defect, measured on the live tree (probe run 2026-10-02 — `tests/tools/plaza_probe_tmp.gd`,
headless `City.generate(20260928)` then SAT over the real `Static/Props` colliders):

- `_build_plaza` puts 8 benches on the 8.0 m ring at every 45° azimuth
  (`scripts/city.gd:1078-1081`) and drops the four bins at (±5.5, ±5.5)
  (`scripts/city.gd:1089-1091`) — center radius √(5.5²+5.5²) ≈ 7.778 m, i.e.
  exactly on four of the bench azimuths, 0.22 m radially inside the bench
  centers. The bench collider is a 1.8 × 0.55 × 0.5 box yawed to the ring
  (`_add_bench`, `scripts/city.gd:1162`); the bin collider is a yaw-less 0.55
  axis-aligned box (`_add_bin`, `scripts/city.gd:1180`), so its diagonal faces
  the center (radial half-extent 0.275·√2 ≈ 0.389 m).
- Probe result: **17 plaza prop shapes, and exactly 4 colliding pairs — the
  four diagonal bench×bin pairs, `overlap=true`; the other 28 bench×bin pairs
  and every bench/lamp/plinth pair clear.** The bin spans radially
  [7.389, 8.167] m against the bench's measured radial span [7.100, 8.900] m —
  the bin's outer half sits ~1.07 m inside the bench's inner end; the minimum
  push to separate is ≈ 0.64 m collider / 0.60 m visual, along the bench's
  0.5 m-wide face. (The owner's "~0.28 m" and research.md's "0.38/0.42 m" both
  assumed a tangent bench band [7.75, 8.25]; the same research pass's probe
  measured the bench long axis **radial** — radial_half 0.900, tang_half 0.250 —
  so the published magnitudes are stale. The interpenetration conclusion is
  unchanged and worse. See the correction note under References.)
- The clipped benches are the four *without* elders: the T-020 spawner seats
  its 4 elders on bench indices 0, 2, 4, 6 (cardinal azimuths —
  `tests/sim_test.gd:2125-2128`), so the bins bury into the four free diagonal
  benches (indices 1, 3, 5, 7).

The fix — honor the comment's stated intent ("bins on the diagonals",
`scripts/city.gd:1074`), but radially outside the ring:

- Move the four bins from (±5.5, ±5.5) to **(±7.0, ±7.0)** in the same corner
  loop (`scripts/city.gd:1091`). One-line change; bin geometry, visuals,
  collider size and `_fp` entry shape all unchanged.
- Why (7.0, 7.0): center radius 9.899 m clears the bench ring's outer end
  (8.9 m) by a probe-measured **0.611 m collider / ≈0.65 m visual** paving gap
  — inside the real-world 0.3–1 m bin-beside-bench gap band (sibling bin note)
  and the top of research.md's ADA-ish 0.9–1.2 m clear-space band
  ((6.7, 6.7)–(7.0, 7.0) per axis). Everything else already clears with room:
  outer per-axis extent 7.389 ≪ the 11.0 m slab edge (block_size 22,
  `scripts/city.gd:209`; curb math `scripts/city.gd:483-487`) — on the slab;
  3.96 m from the corner lamps at (±9.8, ±9.8) (`scripts/city.gd:1090`);
  radius 9.899 < `spawn_clear_radius` 12.0 (`scripts/city.gd:221`); 5.0 m from
  the T-029 plaza-anchor drop point (sim offset (4, 0, 3)). Probe-verified
  non-overlapping at this radius; (6.5, 6.5) is NOT enough (bench-corner reach
  on the bin's x/z axes — probe `overlap=true`, gap −0.097), so the radius must
  be ≥ ~6.6 per axis; don't "optimize" it down.
- Zero RNG: `_build_plaza` draws nothing (`scripts/city.gd:1077-1092`), so the
  only layout-stream effect is the four `_fp` bin x/z entries
  (`scripts/city.gd:1182`) — the **layout fingerprint is expected to move**
  (both pins, default and foreign seed), same-seed determinism must not.
- Add the permanent invariant as a Gate 1b scenario (`city_plaza_props_clear`,
  placed after `_scenario_city_plaza_landmark` in the chain,
  `tests/sim_test.gd:221-222`): collect every `CollisionShape3D` under
  `Static/Props` (one body per group, `scripts/city.gd:1282-1293`) whose XZ
  center lies within 16 m of `_plaza_center`, and assert pairwise
  non-intersection — yawed-box SAT for `BoxShape3D`, circle-vs-OBB for
  `CylinderShape3D` (the lamps), requiring Y-range overlap and a 0.01 m touch
  tolerance — plus the intent pins: every bin's inner collider edge ≥ 0.3 m
  from every bench collider (measured 0.611), and every bin on the slab
  (per-axis |center| + 0.389 ≤ 11.0). Assert at the default seed and one
  foreign seed (plaza layout is RNG-free, so both must hold; regenerating the
  same seed reproduces the fingerprint — the elder scenario's double-seed
  shape, `tests/sim_test.gd:2133`).
- Update the stale rationale on `PLAZA_DROP_OFFSET` (`tests/sim_test.gd:72-78`):
  it still says the drop offset clears "the ±5.5 m diagonal bins, still inside
  the 8 m bench ring" — after the fix the bins sit outside the ring; the offset
  point is now 5.0 m clear of the nearest bin, so only the comment's text moves.

What this does NOT claim: no bench re-orientation (the probe shows the plaza
benches read as radial spokes — tangential seating is a separate, unticketed
layout decision that would move every bench yaw `_fp` entry and elder spot); no
ordinary-block prop changes (block bins already avoid benches by construction —
benches on edge midlines, bins on jittered corners, `scripts/city.gd:1131-1149`);
no bin/bench mesh, material or count changes; no physics behavior change
anywhere outside the four moved bin colliders; no city-wide collider
non-intersection claim (the scenario scopes to the plaza).

## Why

The spawn plaza is the first block every player sees and the hub they keep
returning to (T-020 elders, T-029 statue, bread on the bench seats); four bins
half-buried in benches read as broken geometry, not as set dressing. Real
plazas never put a bin on a bench: the reference photos show bins standing on
the paving offset behind the seating line (Pontypridd) or slotted between bench
runs (Moscow VDNKh) — which is exactly "same diagonals, radially outside the
ring" once the bench band is respected. Keeping the bins paired with the
seating line also honors the placement rule the research surfaced (bins go
"adjacent to seating areas") instead of scattering them mid-plaza. The Gate 1b
pairwise check converts the fix from a one-off nudge into a standing invariant:
any future plaza prop (T-029-style landmark parts, new furniture) that
interpenetrates an existing one fails the suite instead of a human's eye.

## Acceptance criteria

- [ ] Gate 1b `city_plaza_props_clear` passes: no pair of plaza `Props`
      colliders (boxes yawed-SAT, lamps circle-vs-OBB, Y-overlap required,
      0.01 m touch tolerance) intersects within 16 m of `_plaza_center`, at the
      default seed and one foreign seed. *(This criterion is only satisfiable
      by the harness scenario — it is the scenario.)*
- [ ] Red-before/green-after holds: on the pre-fix tree the same scenario
      fails reporting exactly the four diagonal bench×bin pairs (probe-verified
      2026-10-02: 4 × `overlap=true`, all other pairs false); after the move it
      passes.
- [ ] The scenario's intent pins hold: bin-to-bench collider gap ≥ 0.3 m
      (measured 0.611 m at (±7.0, ±7.0)) and bins on the slab (per-axis extent
      ≤ 11.0 − 0.389 m), every seed.
- [ ] Both fingerprint pins re-derived with the headless `City.generate` probe
      and moved in the same change-set — `pin_default`/`pin_foreign`
      (`tests/sim_test.gd:1131-1132`), the three literal pin checks
      (`tests/sim_test.gd:3061`, `:3150`, `:3309`) and their move-history
      comment (~`:2944`), plus the pin history in VERIFICATION.md's
      `city_crosswalks_present` row; same-seed regen still reproduces the new
      fingerprint byte-identically.
- [ ] `PLAZA_DROP_OFFSET` comment text updated to the new bin radius
      (`tests/sim_test.gd:72-78`); no numeric change needed (offset point stays
      5.0 m clear).
- [ ] Gate 1 + full Gate 1b suite + Gate 2 green, with the new scenario row
      added to VERIFICATION.md's Gate 1b table in the same change-set.
- [ ] [Gate 3] From plaza eye level and from a low orbit of each diagonal, each
      bin reads as its own object standing on the paving with visible daylight
      to its bench; benches, elders, lamps and the statue read untouched, and
      the ring still reads as a ring with walk-in gaps.

## Verification

Gate 1 (`--import` + boot) · Gate 1b full suite with the new
`city_plaza_props_clear` scenario (row in the Gate 1b table in the same
change-set; red-before failure signature recorded in the ticket before the fix
lands) · Gate 2 autoplay (plaza is on the autoplay route; no behavioral change
expected) · Gate 3, pending human playtest: land at the plaza, walk/orbit all
four diagonals — bins clear of benches with a visible gap, on the slab, nothing
else moved.

**Recorded during ticketing (2026-10-02, probe `tests/tools/plaza_probe_tmp.gd`,
uncommitted):** pre-fix SAT over live `Static/Props` — 17 plaza shapes (8
benches r=8.0 span [7.100, 8.900]; 4 bins r=7.778 span [7.389, 8.167]; 4 lamps
r=13.859; 1 plinth), overlap=true on exactly the 4 diagonal bench×bin pairs;
candidates (6.5, 6.5) → still overlapping (−0.097), (6.8, 6.8) → 0.328 and
(7.0, 7.0) → 0.611 clear.

## References

Research ran for this ticket — [`docs/references/plaza-bench-ring/research.md`](../references/plaza-bench-ring/research.md),
8 images opened for this ticket from [`docs/references/plaza-bench-ring/`](../references/plaza-bench-ring/credits.md)
(all read 2026-10-02). Facts the implementation MUST respect, orientation first:

1. **Benches face the landmark, seats in, backs out** — every ring image
   (`benches-around-bandstand-pontypridd.jpg`, `benches-around-fountain-geograph.jpg`,
   `four-benches-bandstand-battersea.jpg`, `henry-cool-park-benches.jpg`,
   `council-ring-glacial-lakes.jpg`, `moscow-vdnkh-fountain-benches.jpg`). The
   fix must not touch bench positions or yaws — only the bins move.
2. **Bins never share a bench's footprint**: Pontypridd's bin stands just
   behind the bench line on the paving; Moscow's bins slot between bench runs —
   always offset with a visible gap (0.3–1 m per the sibling
   [`plaza-litter-bin/research.md`](../references/plaza-litter-bin/research.md)).
   → bins stay on their diagonal azimuths but radially outside the seating
   line.
3. **The landmark keeps a clear paved apron and rings are gap-ier than solid**
   (Dülmen top-down `dulmen-marktplatz-jubilaeumsbrunnen.jpg`; Pontypridd's
   walk-in gaps): the bin belongs on the slab just beyond the seating line, not
   floating mid-plaza and not crowding the center; the game's ~4.5 m bench gaps
   are fine as-is.

Honesty note, carried from the research note: the only true top-down in the set
(Dülmen) shows café furniture, not benches — the ring-layout facts rest on the
elevated Pontypridd/fountain views plus eye-level shots. And one correction to
that note discovered while ticketing: its orientation bullet calls the game's
bench yaw "tangent", but its own probe measured the bench long axis **radial**
(span [7.1, 8.9] m) — the plaza benches currently read as spokes. That does not
affect this ticket's conclusion (the interpenetration is real either way and
the bins still move out), but the 0.38/0.42 m overlap figures in both research
notes are computed against a tangent band that doesn't exist; treat the probe's
numbers above as authoritative. Bench orientation itself is deliberately out of
scope here.
