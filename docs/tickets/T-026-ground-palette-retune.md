# T-026 — Re-value the ground planes: stop the sidewalk/plaza blowout, lift the road

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-016, T-013 (both landed — the silhouette gate and the warmth judgement this retune must respect)
- **Refs:** `docs/DESIGN.md` → Art style (warm-sun read); visual-design lane plan, sweep 1 (2026-09-29)

## What

Three constant retunes in `scripts/city.gd:26-29` (values are the plan's, to be
A/B-checked live before landing):

| Constant | Today | Proposed |
| -------- | ----- | -------- |
| `COLOR_SIDEWALK` | (0.62, 0.61, 0.58) | **(0.56, 0.55, 0.53)** |
| `COLOR_PLAZA` | (0.70, 0.66, 0.58) | **(0.60, 0.57, 0.51)** |
| `COLOR_ASPHALT` | (0.24, 0.24, 0.26) | **(0.29, 0.29, 0.31)** |

The two lightest surfaces stop clipping to featureless white in the sun and the
road lifts off near-black, so slabs read as surfaces with tone while lane
dashes (`COLOR_LANE_MARK`, untouched) and car colors keep their pop.

Blast radius (verified this session): the three constants feed material
building only — `COLOR_ASPHALT` into the shared "road" unit-box material
(`scripts/city.gd:313`), sidewalk/plaza into the per-instance vertex-color tint
of the "slab" mesh (`scripts/city.gd:380`). They appear nowhere in the layout
fingerprint (`_fp.append` records positions and plaza/park flags only,
`scripts/city.gd:381`), so `city_same_seed_deterministic` and every other
determinism gate are untouched. `report()`'s guarantees are layout-based. No
physics node is affected.

**The T-016 gate interaction is real and computed** (Euclidean RGB, this
session): at the experiment's sidewalk (0.52, 0.51, 0.49) the pigeon body
(0.38, 0.42, 0.47) sits 0.168 away — BELOW the gated 0.20, so
`pigeon_silhouette_contrast` would fail. Holding sidewalk at (0.56, 0.55, 0.53)
restores 0.230 ≥ 0.20. The stated sidewalk value is therefore not a suggestion:
land it as written (or consciously re-base the T-016 gate in the same
change-set, with a note in the T-016 ticket and VERIFICATION.md — do not let
the suite go red). Other margins at the proposed values, computed: sidewalk ↔
asphalt 0.435; sidewalk luminance − body luminance 0.123 (T-016's ≥ 0.05 gate
holds); the cream facade family is untouched.

## Why

The city's two largest surfaces render as information-free extremes. Play-session
evidence recorded by the lane plan (the cited captures — sessions `vdv1`,
`vdv3`, experiment `vdvx1` — are not present in this repo, so the blow-out
itself is asserted, to be confirmed by the Gate 3 pass): frames f00021240 /
f00021300 show the spawn corridor as white sidewalk over a black road;
`vdv3`'s plaza close-up shows the plaza blown out; the experiment window at
0.52 / 0.58 / 0.30 shows the improvement plainly.

Verified in code (this session): current constants are exactly
`scripts/city.gd:26-29` as tabled above, and the bird body albedo the T-016
gate measures is (0.38, 0.42, 0.47) (`scenes/pigeon_visual.tscn:6`,
`Mat_body`) — which is what makes the sidewalk value load-bearing.

## Acceptance criteria

- [x] `pigeon_silhouette_contrast` (extended, see below) stays green with the
      new sidewalk — body ↔ sidewalk Euclidean ≥ 0.20 measured at ≥ 0.23 with
      the stated values, no gate re-basing needed
- [x] Gate 1b: `pigeon_silhouette_contrast` additionally asserts **sidewalk ↔
      asphalt Euclidean ≥ 0.30** and **sidewalk ↔ `Mat_body` ≥ 0.20**, pinning
      the retune so a future tweak cannot silently re-merge the surfaces
      (computed today: 0.435 and 0.230 at the proposed values; the old pair
      measured 0.619, so the road/sidewalk contrast intentionally narrows but
      stays above the floor)
- [x] All city scenarios stay green unchanged: `city_district_palettes_distinct`,
      `city_shopfronts_present`, `city_shopfronts_deterministic`,
      `city_same_seed_deterministic`, `city_plaza_spawn`,
      `city_street_flyover`, `city_sidewalk_walkable` (colors are absent from
      fingerprints and colliders)
- [ ] [screenshot] Side-by-side with before: sunlit sidewalk and plaza show
      surface tone instead of clipping to white; asphalt reads as road, not
      void; lane dashes and car colors still pop (Gate 3 — human judgement)
- [ ] [screenshot] The city still reads "warm sun" after the retune — the
      T-013 warmth judgement holds over the new ground values (Gate 3 — human
      judgement)

## Landed values & verification (2026-09-29)

Landed exactly as tabled: `COLOR_SIDEWALK` (0.56, 0.55, 0.53), `COLOR_PLAZA`
(0.60, 0.57, 0.51), `COLOR_ASPHALT` (0.29, 0.29, 0.31) — no gate re-basing was
needed. Gate 1b measured at the landed constants (headless suite,
`SIM SUMMARY: 0 failure(s)`, 73/73 green): sidewalk ↔ asphalt **0.435** ≥ 0.30,
sidewalk ↔ body **0.230** ≥ 0.20 (both now pinned inside
`pigeon_silhouette_contrast`); all seven city scenarios above green unchanged.
Gate 2 autoplay green (`AUTOPLAY DONE ok=true`, restart=true, 136 fps avg).
The two [screenshot] criteria are the pending human playtest pass recorded in
VERIFICATION.md's Gate 3 list — machine checks cannot judge the blow-out fix
or the warm-sun read.

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines) · Gate 1b: full suite
green via `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`,
with `pigeon_silhouette_contrast` extended per above (scenario + VERIFICATION.md
table row updated in the same change-set) · Gate 2 (autoplay in the workflow) ·
Gate 3: the two [screenshot] lines above, added to VERIFICATION.md's playtest
list; recorded as pending human pass per the plan (the "no longer blows out"
half is a look judgement, not machine-checkable). If a sidewalk value other
than (0.56, 0.55, 0.53) is chosen, the T-016 gate numbers must be recomputed
and the change recorded in the T-016 ticket in the same commit.
