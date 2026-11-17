# T-207 — Ames R5 · tree canopy: the 5,637 mapped trees become a skyline of leaves

- **Status:** done · **Category:** visual-design · **Ring:** R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-172 (the bake carries them)
- **Refs:** census §5 (5,637 natural=tree points; 267 ha green) ·
  `images/nature/20` (the mature-canopy read), `images/campus/20`
  (oaks on the snow lawn) · T-148 (haze — the canopy is the fog's
  dance partner)

## What

The town's cover, as the bake's cheapest big win:

- 2–3 tree archetypes (canopy blob + trunk hint; billboard-free —
  low-poly meshes in the house style), distributed at the mapped
  points via per-chunk MultiMesh (one draw per chunk, same as
  massing).
- Campus lawn oaks, residential canopy, park fills, the LaVerne
  shore ring — the mapped data decides where; the archetypes decide
  what.
- Wind sway = optional vertex-shader hint (cheap, no bones); no
  collision (canopy is soft — the pigeon brushes through, the
  existing foliage convention).

## Why

A treeless Ames reads as a render test. The canopy is also the flight
experience's texture at rooftop altitude — where this game actually
lives.

## Acceptance criteria

- [x] 5,637 trees at mapped positions (±0 m — the data is the point);
      archetype mix pinned; per-chunk MultiMesh discipline (draw
      budget holds — T-173's gate re-run)
      *(the count re-pinned onto the pack: 5,637 was the census §5
      v1-bbox count; the layer grew +78 (T-204 south) and +1,038
      (T-205 north) to the v4 total **6,753** (`ames_data_integrity`'s
      own pin) — "the data is the point" lands every mapped node 1:1,
      so the ring closes at the pack total; mix pinned exactly
      {oak 4,587 / boulevard 2,050 / shore 116}; ONE MultiMesh per
      archetype present per tree-bearing tile (126 tiles: 81 single /
      44 double / 1 triple = 172 nodes — the per-chunk discipline
      holds, never a draw per tree); the whole-world ceiling re-pinned
      1900 → 2100 (measured 2001), the pose ceilings kept at 1800
      (measured 841 cruise / 81 hover))*
- [x] *(Gate 1b)* `ames_tree_canopy`: count, archetype mix, chunk draw
      budget re-pin
      *(163 PASS / 0 FAIL, exit 0 — the scenario re-walks the pack into
      per-tile position multisets (the ±0 law), recomputes every
      entry's whole payload (archetype under the v0 rule's priority,
      scale/yaw/tint through the transcribed hash law) and compares
      multiset-for-multiset, pins the mix exactly, proves the render
      mounts 172 tree MMs / 6,753 instances with the sway
      ShaderMaterial, and holds the foliage convention at the API:
      ground_height answers 0.0 at 64 open-lawn trunks (50
      building-covered trunks skipped — a mapped-inside-a-building
      node answers THAT building's own top, the api_seam law, not the
      canopy's); the draw-budget re-pin rides `ames_world_render_budget`
      (1900 → 2100, measured 2001))*
- [x] Screenshot set: campus lawn, residential street, LaVerne shore
      *(see the screenshot ledger below; the owner eyeball folds into
      T-210 per the Verification line)*
- [x] *(Gate 1/2)* clean
      *(Gate 1: `--import` exit 0; 120-frame boot exit 0, zero error
      lines — the one pre-existing ObjectDB-leak warning line is
      byte-identical on the base tree (proven by a base-worktree boot
      run); Gate 2: `AUTOPLAY DONE ok=true world=ames crumb_target=40
      loop_ok=true restart=true` — 34 splats, 4 eaten, tourists=24,
      poses FLAP/GLIDE/PECK/STAND/WADDLE, ambience looping)*

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass.

## Run record (2026-11-17, feature/t-207)

### The count law (the AC's number, re-pinned)

The AC's 5,637 was written off the census §5 v1 core box. The pack's
tree layer grew with the strips — +78 south (T-204), +1,038 north
(T-205, "trees 6,106 → 6,753" in that ticket) — and `ames_data_integrity`
pins the v4 total 6,753. The AC's own principle ("±0 m — the data is
the point") lands EVERY mapped node exactly once, so the ring closes
at the pack total; the lineage is recorded here and in the scenario's
header comment. No tree was invented: the census §9 scatter-SEED law
holds (an unmapped lot stays open).

### The archetype law (tuned values, all deterministic by index hash)

The mapped data decides WHERE, the archetype decides WHAT — three
archetypes over the ticket's four placements, one `TREE_ARCHETYPES`
table in `scripts/ames_baker.gd` (the single dim/color source the bake's
AABB AND the renderer's meshes read):

| Archetype | Placement (the law, in priority order) | Dims (m) | Crown hex |
| --- | --- | --- | --- |
| `shore` | within 30 m of the **Lake LaVerne ring** (the ticket's shore ring; Ada Hayden's quarry-gravel shore deliberately NOT willow water) | trunk 4.6 × r 0.5; crown ry 2.0 at cy 6.8, rxz 5.6 | `#7A9450` (§1.9 park-mown yellow-green as the willow estimate — no pinned willow hex exists) |
| `oak` | inside a **pack park polygon** (the grove tint) or the **campus district** (the v0 rule's anchor/street legs, UNDER its priority order — campustown and downtown bands win) | trunk 6.0 × r 0.45; crown ry 3.2 at cy 8.6, rxz 5.0 | `#55703F` (§1.10 dominant; grove tints darken to §1.9's `#3E5A32` Brookside summer read) |
| `boulevard` | everything else — the residential grids incl. campustown/downtown/lincolnway | trunk 8.0 × r 0.36; crown ry 3.2 at cy 10.8, rxz 4.0 | `#55703F` (`images/nature/20`'s giant over the two-story roof) |

Bark `#6E6152` (estimate). Per-instance: scale axes [0.82..1.18]
independent (sd measured 0.104 = the uniform-band's own 0.1039),
yaw [0..τ), tint = the green-luminance band [0.86..1.08] (grove
[0.74..0.86]) with the ±0.09 red/blue hue jitter — all from
`hash("tree/<index>")` through a splitmix-style integer finalizer (the
band spread; see the red-before notes for why the string-hash spread
didn't survive review with myself). Mix baked exactly: **oak 4,587 /
boulevard 2,050 / shore 116**.

### Baked payload

Schema `ames_chunks/v6` (v5 + the `trees` family). 552 → **553 tiles**
(the tree-only tile (11, 8) joined); payload 11.61 → **12.84 MB**
(budget 40); wall clock ≈ 6.1 s (budget 60). `total_sha256`
`8f93295957b29fa6f1746392efb95b748e405121ec2362326c5357c64d040175`
(two consecutive tool runs identical; the in-scenario re-bakes
reproduce it — the determinism row re-pinned). Districts untouched
(9,480/622/292/272/117 — the canopy regenerated no buildings).

### The render

`scripts/ames_world.gd` builds the three meshes from the baker's table:
a hexagonal trunk hint (6-sided prism, sway weight 0) + a 9×4
latitude-ring ellipsoid crown with a deterministic lobe jitter (±0.08
radius), vertex colors carrying the survey hexes (crown) and bark
(trunk) and COLOR.a carrying the SWAY WEIGHT (crown bottom 0 → top 1).
One shared ShaderMaterial: the wind-sway vertex-shader hint — the
phase derives from the instance origin (`MODEL_MATRIX[3].xz`), the
amplitude rides the instance scale, no bones, no bake data, trunks
rigid; the engine's multimesh path multiplies the baked tint INTO
COLOR, so `COLOR` IS the albedo. Double-sided with declared per-face
normals (the prism discipline — winding can never cull a face; the
shader carries `render_mode cull_disabled` — review round 1 caught it
shipping without, see below; the crown-underside read in
`laverne_crown_read_v2.png` shows no black wedges). ONE MultiMesh per
archetype present per chunk (172 nodes),
fading with the massing band (a tree beyond its houses' fade would
float — the T-206 roofs law). Visual-only: no collider, no occluder,
no ground record, no roof-crumb host.

### Screenshot ledger (pilot hidden windows per T-170)

Session `t207shots` in the worktree's `.captures/` (originals live
there; `dev:teleport` + `reset_flight` hover, the OS `shot` grab fired
right after the teleport ack):

- `campus_lawn.png` — over the Central Campus lawn paths at
  (70, 42, −160) yaw 180: 488 mapped oaks in the window, the broad
  lobed crowns over the lawn plate with the gabled neighborhoods
  reading beyond (`images/campus/20`'s open-grown read).
- `residential_street.png` — the densest mapped boulevard cluster
  (tile (3, −2), 108 trees) at (880, 44, −330) yaw 160: the street
  row + the creek corridor, crowns over the roof lines
  (`images/nature/20`'s mature-canopy read).
- `laverne_shore.png` — over the lake at (130, 24, −115) yaw −80: the
  low broad shore ring hugging the waterline, the T-185 swan in the
  water.
- Companions (RE-SHOT after review round 1's cull fix — session
  `t207rv1fix`; the originals were taken on the pre-fix tree whose
  interiors shipped `cull_back`, superseded): `residential_canopy_overhead_v2.png`
  (INSIDE the crown band at (1040, 26, −760) — the ticket's
  rooftop-altitude texture read, every crown solid around the pigeon)
  and `laverne_crown_read_v2.png` (the crown read over the LaVerne
  shore band, no black wedges, no see-through).
- Review-round-1 evidence (the reviewer's own repro poses, re-shot on
  the FIXED tree — session `t207rv1fix`, teleport + instant `shot`):
  `crown_interior_east.png` — the exact repro crown center
  (72.6, 8.94, −156.96) facing east: the frame FILLED with the crown's
  solid interior (on the pre-fix tree this pose showed lawn, horizon
  haze and fade dither straight through — the reviewer's
  `review_crown_center.png`); `probe_band1_fixed.png` /
  `probe_band2_fixed.png` — the two crown-band probes ((74, 8, −164)
  and (66, 11, −156)) now reading complete canopies.

Owner eyeball (does the canopy read as Ames's green at cruise
altitudes) folds into T-210 per the Verification line.

### Gate runs (all on the landed tree)

- Gate 1: `--import` exit 0; `--quit-after 120` exit 0, zero error
  lines (the pre-existing ObjectDB-leak warning is byte-identical on
  the base tree — proven by a `t207-gateprobe` base-worktree boot).
- Gate 1b: **163 PASS / 0 FAIL, exit 0** (`ames_tree_canopy` new; the
  only stderr lines are the 6 pre-existing `cafe_sitters` probe
  "Node not found" errors, byte-identical to the pre-change baseline).
- Gate 2: `AUTOPLAY DONE ok=true world=ames crumb_target=40
  loop_ok=true restart=true` — 34 splats, 4 crumbs eaten, tourists=24,
  poses FLAP/GLIDE/PECK/STAND/WADDLE, ambience looping.
- Draw budget: mm_nodes measured **2001** (1829 + the 172 tree nodes),
  `DRAW_BUDGET` re-pinned 1900 → 2100; the pose ceilings KEEP their
  1800 const (measured 841 cruise / 81 hover — the poses never see the
  whole world at once). Instances 53,433 → 60,186; buffer 9.9 →
  10.3 MB (budget 400).

### Red-before notes (the honest walk to green)

- Run 1 crashed the new scenario on `mmi.mesh` (the property is
  `multimesh`) and failed the then-stale 1900 ceiling (measured 2001 —
  the re-pin above).
- Run 2 (after the property fix) exposed three law drifts, all fixed
  and re-pinned: (a) the shore prefilter didn't GROW the ring AABBs by
  the 30 m band — 59 shore trees missed; (b) the campus leg ignored
  the v0 rule's PRIORITY — 35 campustown-band trees inside a campus
  anchor's 300 m ring are Campustown boulevards, not lawn oaks; (c)
  the tint recompute ran float64 while the bake's `Color` stores
  float32 channels — ~0.7 % of trees straddle the 1e-4 snap boundary,
  so the round trip through `Color` IS the law (the scenario now
  constructs the tint).
- The first band spread correlated: the polynomial string hash
  perturbs only its LOW bits when the band suffix changes, so every
  band rode ~the same fraction (sx ≈ sy ≈ sz on most trees — found by
  probing two indices' bands: 0.3120117 / 0.3121338 / 0.3122558 —
  adjacent 1/8192 steps). Replaced with a splitmix-style integer
  finalizer over (roll, band); re-baked (new hash above) and measured
  decorrelated (near-equal sx/sy pairs 10.6 % ≈ the coincidence rate).

### Review round 1 (2026-11-17 — the cull fix)

The reviewer played the town (every outside view complete and clean —
campus lawn, shore, under-canopy, cruise all read solid) and caught
the one defect the outside views couldn't: the sway ShaderMaterial
shipped without `render_mode cull_disabled`, so Godot's default
`cull_back` made the crowns SINGLE-SIDED — the canopy VANISHED when
the camera flew inside it (the flown-through read the ticket's own
What calls the game's core: "the pigeon brushes through", "the flight
experience's texture at rooftop altitude"). Live repro: dev-teleport
to the exact crown center of a real baked oak (chunk_0_-1.json tree
`{'t':'oak','p':[72.6,0.0,-156.96],'s':[0.906,1.04,0.871]}` → center
y ≈ 8.94) showed lawn, horizon haze and fade-dithered distant massing
straight through where the crown should be — while the ticket's Render
paragraph and the mesh-builder comments claimed the prism discipline's
double-sided read. THE FIX is the one line the code comments already
promised: `render_mode cull_disabled;` in `TREE_SWAY_SHADER_CODE`
(scripts/ames_world.gd), matching the T-206 prism's
`CULL_DISABLED` StandardMaterial3D. Evidence re-shot on the fixed tree
at the reviewer's own three poses (see the ledger above — the repro
crown center now frames solid interior; the two band probes read
complete), and the two interior companions re-shot (v2). No bake, no
collision, no count, no budget changed — the fix is render-side only.

### Review sign-off

The reviewer played the town on the fixed tree and signed off. Status
flipped to done in this ticket and the index row; the owner's
canopy-at-cruise-altitudes eyeball folds into T-210 per the
Verification line.

## Decisions & forks

- Archetypes = 3 (oak/boulevard/shore) sharing the crown+trunk recipe;
  park fills ride the oak form under the grove tint (the census's
  Brookside/Pammel woods are polygon-level, not node-level — the
  mapped park points ARE the grove seeds).
- The shore ring is LaVerne-only: the ticket names the LaVerne shore;
  Ada Hayden's shore is the quarry-gravel bank read (T-205), not
  willow water — its shore trees read park/oak.
- No procedural scatter: the census §9 law (mapped nodes are scatter
  SEEDS, not an inventory) means an unmapped lot stays open. The
  residential canopy shows where Ames's mappers mapped it; a
  procedural canopy-fill is a future ticket if the owner wants the
  §1.10 "continuous green mat" read everywhere.
- Draw discipline: one MultiMesh per ARCHETYPE PRESENT per chunk
  (≤ 3) rather than one per chunk — a single combined mesh can't
  switch shapes per instance; +172 nodes measured, ceiling re-pinned.
