# T-206 — Ames R5 · filler dressing: anonymous buildings start being Ames

- **Status:** done · **Category:** visual-design · **Ring:** R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-177 (filler is live), independent of R3/R4 timing
  (can move earlier if the owner steers)
- **Refs:** `MODELING-SPECS.md` §3 (the 10 district dressing rules —
  this ticket implements them) · `images/nature/20,21` (the house
  portraits: clapboard + porch rhythm) · `images/campustown/03` (the
  scruffy 2-4 story fabric) · census §1 (levels histogram 1:187,
  2:158, 3:154… the height mix)

## What

The 3,175 procedural buildings stop being gray boxes:

- Per-district variation from the specs' rules: roof pitch variants
  (gabled residential, flat commercial), setback discipline from the
  census, porch hints on residential (the two house portraits'
  read), materials by district (brick-warm downtown, scruff
  Campustown, siding residential, lawn-edge campus).
- The variation is BAKED (T-172's arrays gain a small variant set —
  still MultiMesh, still vertex color, still one draw per chunk);
  the determinism manifest discipline holds.
- No collision changes (footprints identical).

## Why

85 % of the buildings carry 43 % of the visual field; the filler is
the difference between "a map of Ames" and "Ames."

## Acceptance criteria

- [x] District-variant set live in the bake; roof/setback/porch rules
      per the specs; collision untouched
      *(the v5 bake: every non-hero massing entry carries `v` +
      `roofs`/`dress` geometry beside it — 9,163 gable prisms + 7,223
      dressing boxes; footprints machine-pinned identical, authored
      count == pack authored count; see the run record)*
- [x] *(Gate 1b)* `ames_filler_variants`: variant distribution pins
      per district; bake determinism re-manifested
      *(162 PASS / 0 failures on the landed tree; the in-scenario
      re-bake reproduces the committed `total_sha256`
      `3f169916e3ef3d5b5ad2e35b34d0e0145c9aff7b6e063d5187368bc875b270c7`;
      the distribution pinned exactly per district — see the row)*
- [x] Screenshot set: the same Campustown + residential vantage
      before/after (in-ticket)
      *(see the screenshot ledger below; owner eyeball folds into
      T-210 per the Verification line)*
- [x] *(Gate 1/2)* clean
      *(import exit 0 with only the accepted godot_mcp teardown line,
      boot 120 frames exit 0 / zero error lines; autoplay
      `DONE ok=true world=ames crumb_target=40 restart=true`)*

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass (owner
eyeball folded into T-210).

## Run record (2026-11-17, feature/t-206)

### The variant law (tuned values, all deterministic by building-id hash)

District → variant (`v` on the massing entry; the §3 rules cited
inline in `scripts/ames_baker.gd`'s T-206 constant block):

| District | Rule | Variants (baked counts) |
| --- | --- | --- |
| residential ≤ 11.5 m (≤ 3 census levels) | §3.6/§1.10 the gabled house | `gable_lo` (0.45 rise-run) 4,560 · `gable_hi` (0.7) 4,603 |
| residential > 11.5 m | the tall slabs read §3.3-style | `parapet` 316 |
| downtown (all) | §3.2 the continuous cornice band, stone `#D6CDBB` | `cornice` 271 |
| campus ≥ 400 m² | §3.7 flat + mechanical screens (2 boxes, hash-mirrored) | `screen` 156 (312 boxes) |
| campus < 400 m² | §3.7 small blocks stay plain / parapet 1-in-3 | `flat` 82 · `parapet` 47 |
| campustown | §3.3 the scruff mix 2-2-1 | `parapet` 47 · `flat` 47 · `penthouse` 23 |
| lincolnway | §3.4 the strip mix 1-1 | `parapet` 319 · `flat` 302 |

Lot hints on the gabled house-scale (≤ 16 m) stock: porch 6/10 (deck
+ canopy pair), chimney 5/10 (brick `#96513A`, through the ridge at
30 % span), plain 1/10 — 2,100 porch pairs + 1,688 chimneys baked.
Gable geometry: eaves overhang 0.4 m past the wall line, ridge height
= pitch × half the wall span, one prism instance per roof (the
renderer's unit-prism mesh, double-sided, per-face normals), fading
with the massing band. District palettes re-pinned onto the survey's
own §1.10/§1.5/§1.6/§1.7 hexes (residential `#D8CDB4`/`#EDEAE2`/
`#B7B7AD` + brick accent `#96513A`; campustown `#96513A`…`#7C4230`
brick + `#B9B1A2`/`#C9C0AE` block; downtown + painted cream `#C9C0AE`;
lincolnway + strip brick `#9C6A48`). Shingle palette `#4E4E52` /
`#43434A` / `#3A3A3E` (§1.10's weathered-asphalt range).

### Setback discipline

The footprints themselves ARE the census setback data and are
UNTOUCHED — the bake's massing `p`/`s` still recompute byte-close from
the pack (machine-pinned within the JSON round-trip tolerance), the
authored count is unchanged (the collision feed identical; procedural
filler stays visual-only massing), and the district totals equal the
v4 distribution (9,480/622/292/272/117). The per-district front
treatments ride the census setback classes: the residential porch hint
(the 11 m-street class, house portraits `images/nature/20,21`), the
downtown flush wall + cornice (the hard 12.4 m row), the Campustown
parapet/penthouse mix (the 16.6 m p50 with the Cy's-Roost outliers
untouched), the Lincoln Way plain/fascia retail mix (the set-back
strip, the anti-downtown).

### Baked payload

Schema `ames_chunks/v5` (v4 + `roofs` + `dress` family keys). Same
552-tile set; payload 8.26 → 11.61 MB (budget 40); bake wall clock
4.1 s (budget 60). `total_sha256`
`3f169916e3ef3d5b5ad2e35b34d0e0145c9aff7b6e063d5187368bc875b270c7`
(re-pinned in the `ames_bake_determinism` row; the v4 hash recorded
there as history). Whole-world draw ceiling re-pinned 1800 → 1900
(measured 1130 → 1829 — two more families on the gabled/dressed
tiles; the two gameplay pose ceilings KEEP their own 1800 const:
measured 732 cruise / 71 hover). Instances 37,047 → 53,433; buffer
8.8 → 9.9 MB (budget 400 MB).

### Screenshot ledger (the before/after set, same vantages)

Pilot hidden windows per T-170, the OS `shot` grab; poses teleported
(`dev:teleport`, `reset_flight` hover), the shot fired immediately
after the teleport ack so the grab rides the hover window. Stored in
`.captures/session_t206shots/`. PROVENANCE (corrected in review
round 1): the before originals live in the MAIN checkout's
`.captures/` (`session_t206before`, `session_t206b2`,
`session_t206bcamp` — the worktree does not contain them); the after
originals live in the worktree's `.captures/` (`session_t206after`
and its retake sessions). The FIRST run's Campustown before grab was
taken too late and caught the bird already GROUNDED (session
`t206b2`: teleport acked t=6612 ms, `grounded` event t=7277 ms — the
shot's HUD reads "Grounded! … city 0 m", the strip out of frame);
that image is superseded by the round-1 RETAKE from the base code at
the exact recorded pose — session `t206bcamp`: teleport acked
t=15842 ms, `grounded` event t=21201 ms, the shot grabbed in between
(the airborne HUD, the strip in frame). The other three shots are
the original run's honest grabs (the residential pair airborne right
after their teleport: "city 933 m" before / "930 m" after).

- `before_campustown.png` / `after_campustown.png` — the Welch strip
  from (0, 42, 60) yaw 180: before, flat gray/tan boxes; after, the
  brick-warm storefronts and the gabled neighborhoods reading beyond
  the strip.
- `before_residential.png` / `after_residential.png` — the east
  residential grid from (600, 34, 600) yaw 150: before, flat boxes on
  the lawn plate; after, dark shingle gables (both pitch classes),
  ridge-line chimneys, porch deck+canopy hints, the siding range +
  brick accents.

Owner eyeball (do the filler districts read as Ames at cruise
altitudes) folds into T-210 per the Verification line.

### Gate runs (all on the landed tree)

- Gate 1: `--import` exit 0 (only the accepted godot_mcp teardown
  line; the worktree's per-machine `addons/godot_mcp/` copy restored —
  it had been copied FLAT into `addons/`, breaking the autoload path,
  re-nested and re-ignored); `--quit-after 120` exit 0, zero error
  lines.
- Gate 1b: 162 PASS / 0 failures, exit 0 (`ames_filler_variants` new;
  the only stderr lines are the 6 pre-existing `cafe_sitters` probe
  "Node not found" errors, byte-identical to the pre-change baseline
  run).
- Gate 2: `AUTOPLAY DONE ok=true world=ames crumb_target=40
  loop_ok=true restart=true` — 34 splats, 4 crumbs eaten, tourists=24,
  poses FLAP/GLIDE/PECK/STAND/WADDLE, ambience looping, the restart
  beat labels_ok=true.

### Red-before notes (the honest walk to green)

- Run 1 failed 4 arms: 5,317 "footprint changed" (the scenario's
  float EQUALITY compared JSON round-tripped values against fresh
  recomputes — Godot prints both at 14 significant digits so the
  1-ulp storage noise printed identically while comparing unequal;
  fixed with the census row's 0.002 tolerance convention); the
  porch/chimney law recompute missing the `PORCH_HOUSE_MAX_DIM` ≤ 16 m
  gate (5,499 vs 2,100 — the scenario now transcribes the gate);
  `ames_world_render_budget`'s whole-world ceiling 1829 > 1800 (the
  re-pin above — the gameplay pose budgets untouched).
- The prism mesh shipped once with 3 bottom normals for 6 vertices
  (surface rejected at `add_surface_from_arrays`, every chunk's roof
  family silently surface-less at the count level); fixed to 6, and
  the prism made double-sided (cull disabled, declared per-face
  normals carry the shading) after the first AFTER screenshots read
  black wedges on culled slopes.

### Review sign-off

Reviewer round 1 fixed the Campustown before shot (retaken at the
recorded aerial pose from base code — see the ledger's provenance
note) and was otherwise accepted; the reviewer played the game and
signed off. Status flipped to done in this ticket and the index row;
the owner's filler-dressing eyeball folds into T-210 per the
Verification line.
