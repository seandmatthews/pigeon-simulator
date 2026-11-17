# T-200 — Ames R4 · street name blades: wayfinding by reading

- **Status:** doing · **Category:** visual-design · **Ring:** R4 The Names ·
  **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-197, T-180 (the intersection set)
- **Refs:** `osm/SUMMARY.md` (spine streets; Lincoln Way becomes East
  Lincoln Way exactly at Duff — the seam is a nice detail) · MUTCD
  green-blade convention (the T-134 speed-sign geometry family) ·
  `images/lincolnway/01` (mast arms at the Welch intersection)

## What

Real street names on green blades at the intersections that matter:

- **The spine set** (pinned): Lincoln Way (+ its East rename at Duff),
  Welch, Hayward, Sheldon, Stanton, Main, Duff, Grand, University,
  Mortensen, 16th, Stange, Clark, Burnett, Douglas — blades at
  spine×spine and spine×collector corners from T-180's set.
- MUTCD-correct form: green blade, white text, the T-134 family's
  sign geometry at blade size; mast-arm or post-mount per corner type.
- Correct directional names where OSM has them (East Lincoln Way,
  South Duff) — the data's names, not invented ones.

## Why

An alum navigating by street names is the second recognition channel
after venue signs — and it's nearly free once T-197 exists.

## Acceptance criteria

- [x] Blades at the pinned corner set; names exact-match the data
      pack's street names (incl. the East Lincoln Way seam)
- [x] *(Gate 1b)* `street_blades_pins`: corner list + text pins
- [x] Screenshot: the Lincoln Way × Welch corner with blades (vs photo)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass; owner
eyeball in T-202.

## Run record (2026-11-16, implementer)

- **The STREET typology** (T-197's component, extended in-ticket): the
  fifth family in `SignText.SPEC` — the MUTCD green blade plate
  (default 2.6 × 0.44 × 0.06 m), white lettering on street-name green
  Color(0.043, 0.42, 0.216), UNLIT (retroreflective paint, the T-134
  read — the scenario machine-reads no emission), double-faced ±z (one
  label per side, both directions read correctly), horizontal, 0.22 m
  caps with the lit-box 200 budget → 44.0 m readable. The plate runs
  ALONG its street with faces across it (the MUTCD orientation — the
  scenario pins face-normal ⊥ street axis). `scenes/sign_street.tscn`
  ships the default. New script `scripts/ames_street_blades.gd` derives
  every mount off `AmesTrafficGraph`; `AmesWorld._build_street_blades`
  wires it under the `StreetBlades` root (report key `street_blades`).
- **The corner set derivation** (probed 2026-11-16,
  `tools/probe_street_blades.gd`): every T-180 PINNED anchor whose
  street stock touches the spine set → **70 corners / 85 blades**
  (37 mast-stack / 48 post). The spine keys are the ticket's pinned
  list spelled AS THE DATA SPELLS THEM — the directional renames are
  separate keys because the data names them separately (East Lincoln
  Way, South Duff, South Grand; both 16th spellings). v1 reaches 15 of
  the 19 names; the unreached four (Mortensen Road, Stange Road, South
  16th, Southeast 16th) are the CLOSED ledger the gate pins — an R5
  bake extension that pins one of their corners fails the gate until
  the ledger is consciously re-pinned.
- **The seam corner** (the ticket's nice detail, landed): the merged
  Duff anchor (a=167) carries all four data names — Duff Avenue / East
  Lincoln Way / Lincoln Way / South Duff Avenue — and signs all four,
  stacked k=0..3 under its mast arm; the screenshot set catches
  "Duff Avenue" + "South Duff Avenue" face-on with the L/W pair as the
  interleaved edge-on slivers (each blade reads from its cross street,
  the MUTCD cross-read — which is exactly why the photo-01 vantage down
  Lincoln Way reads "Welch Avenue" on the mast blade).
- **Mount laws:** signal corners → mast-arm stacks hung at 0.30 of the
  arm from the pole, 0.12 under the arm, stacked one plate height + 0.10
  per extra blade — the world's `_queue_signal_mast` derivation with
  the mast consts TWINNED into the module (the one-way dependency law,
  the venue module's `CHUNKS_DIR` precedent); the gate pins twins ==
  world's. All-way corners → the T-134 family post (0.08 section,
  corner-post gray) on the approach's right at `half + 0.2 + 0.6` off
  the asphalt, one separation past the stop sign's own post, plate
  center 3.1 (bottom 2.88, clear of the octagon band's 2.67 top). The
  post outset CLAMPS into its run (never past run end − 0.5): Main ×
  Kellogg's ~10 m kink-split Main runs sign their spine name from the
  clamped post — the paint's coarser `fits` gate (stop_outset + 2.0)
  would have skipped them, and a plate on a post needs less runway than
  a zebra band + stop bar.
- **The text law:** the blade text IS the picked edge's run name —
  byte-exact, never retyped (the gate re-derives it off the graph AND
  the pack street-name set); the plate length fits the name through the
  component's own font metrics (width + 2×0.15, min 1.2 — the overflow
  guard's fit law holds by construction).
- **Gate 1** — `--import` exit 0 (only the documented benign addon
  line); `--quit-after 120` exit 0, zero error lines beyond the addon
  triad (re-run on the final tree).
- **Gate 1b** — full suite `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn`: exit 0, **156 PASS / 0 FAIL** (the new
  `street_blades_pins` row green; every existing row untouched — the
  only red across three runs was this ticket's own row, during its own
  derivation-parity fix).
- **Gate 2** — `godot --path . res://tests/autoplay.tscn`: exit 0,
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
  t=103.0 fps=141 … splats=26 tourists=24 … eaten=7 … restart=true`,
  zero SCRIPT ERROR lines — the full Ames window closes its loop with
  85 blades in the world (in-world text changes nothing about play).
- **Gate 3** — the screenshot set (pilot session `t200blades`, hidden
  window per T-170, `.captures/session_t200blades/shots/`):
  `01_acceptance_lw_welch.png` — the acceptance corner from the photo-01
  vantage (down Lincoln Way at the mast arm, the green blade hanging
  under the signals over the live intersection — vs
  `images/lincolnway/01-lincolnway-welch-intersection-snow.jpg`, the
  mast-arm + green-blade convention the photo shows); `02_welch_blade_
  close.png` — "Welch Avenue" legible on the blade; `03_seam_duff_stack.
  png` + `04_seam_close.png` — the Duff seam's four-name stack;
  `05_post_main_burnett.png` — the post-mount read beside the red stop
  signs in the Main Street canyon. The owner eyeball pass (do the names
  read at flight distances, does the green read as the MUTCD blade)
  folds into T-202 per the Verification line.

## Tuned values (as landed)

`SignText.SPEC[STREET]`: letter 0.22 m · budget 200 → 44.0 m readable ·
body 2.6 × 0.44 × 0.06 (module widens length per name: width + 0.30,
min 1.2) · green Color(0.043, 0.42, 0.216) · text the T-134 sign-face
white Color(0.94, 0.94, 0.92) · unlit · faces ±z. `AmesStreetBlades`:
BLADE_LETTER 0.22 · PLATE_PAD 0.15 · PLATE_MIN_LEN 1.2 · POST_MOUNT_Y
3.1 · POST_SEP 0.6 · POST_THICK 0.08 · POST_COLOR Color(0.25, 0.25,
0.28) · mast twins MAST_ARM_Y 5.6 / MAST_POLE_CLEAR 0.6 /
MAST_POLE_SIDE 0.7 / MAST_ARM_END_CLEAR 1.2 (gate-pinned equal to the
world's) · ARM_BLADE_STATION 0.30 · ARM_BLADE_CLEAR 0.12 ·
ARM_BLADE_STACK_GAP 0.10 · BLADE_RUN_MARGIN 0.5. Corner set data-derived
and pinned: 70 corners / 85 blades (37 mast / 48 post), 15 of 19 spine
names reached in v1.
