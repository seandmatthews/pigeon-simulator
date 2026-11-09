# Ames Master Plan — rebuilding the city as real Ames, Iowa

**Status: DRAFT v1 — 2026-11-09. Uncommitted; awaiting owner review. Nothing here
is ticketed yet — candidate tickets carry codenames only; IDs are minted by the
forge/pipeline at write time per repo rule.**
Source data: [`docs/references/ames-survey/INDEX.md`](references/ames-survey/INDEX.md)
(ten lanes, QA'd, 90 credited photos, every number sourced). The survey's
`verification/VERIFICATION.md` is the authority when documents disagree.

---

## 0 · Mandate

Owner sign-off 2026-11-08, verbatim intent: **approximate street layout + all
major landmarks, everything to scale; every restaurant and bar loved by ISU
students findable by a pigeon — an alum should fly to where Welch Ave Station
should be and find a building recognizably their bar.** Real as legally
comfortable: real city/street/landmark/venue names; the only exclusions are the
university's **registered marks** (wordmark/logo, Cy depiction, athletics
marks) — recognition rides place, shape, and color.

Tone fence (standing): family-friendly, comedic, silly game about a bird
pooping on people. No dialogue trees, no NPC schedules, no quest machinery.
Jack Trice content is handled with dignity (survey fidelity note F-15).

**OSM licensing note (new obligation):** the world data derives from
© OpenStreetMap contributors (ODbL). Shipping requires visible attribution
("Map data © OpenStreetMap contributors"); the share-alike question for
embedded derived tables gets a one-page read in R1 — attribution itself is
mandatory either way. Photo credits already live per cluster in the survey.

## 1 · The shape of the problem

| | Windrow today | Ames core |
|---|---|---|
| Footprint | 7×7 block grid (~0.04 km²) | **10.6 km²** (4,050 × 2,610 m) — ~250× the area |
| Buildings | ~49 blocks, ≤ 7.1 m lots | 3,737 (512 authored carry 55 % of footprint; 3,175 anonymous, median 127 m²) |
| Streets | one loop grid, 125–140 m blocks (nice coincidence: same block rhythm) | 92.1 km drivable, 191.8 km footway, 727 named citywide |
| Landmarks | four 17.3 m posts | a 33.5 m campanile, a 51.2 m water tower, a 61,500-seat bowl, a lake, a drum |
| Boot | synchronous generate (already a web-perf ticket) | **nothing synchronous left to generate — boot renders baked chunks** |

Consequences, accepted up front:

1. **Desktop-first for the campaign.** The hosted box is dead anyway; the web
   build stays frozen at 899dcd2 until a ring explicitly revisits it.
   Pipeline runs pass `deploy:false` until then.
2. **The suite's fingerprints will be re-derived, repeatedly.** Every ring
   ends in a cutover ticket whose explicit, budgeted job is the re-pin.
   Fighting this tax is harder than scheduling it.
3. **The game stays playable at every ring boundary.** Each ring ends with an
   owner-playable demo moment (the ring's "trailer shot").

## 2 · Architecture: bake, then render (stream only if budgets demand)

The one big architectural decision. The generator stops being a boot-time
procedure and becomes a **build step + a runtime**:

- **Data pack** (`data/ames_core.json` v1): distilled from the survey's
  merged OSM dataset + census CSV — street graph (centerlines, widths,
  classes), block/building footprints (box massing: centroid, bbox, levels),
  named-POI anchors (venues, landmarks, with position + facing), water
  polygons, rail centerline + the 9 crossings, park polygons, the 5,637
  tree points. Committed, versioned, assertable.
- **Baker** (headless tool, in `tools/`): data pack → chunk resources
  (256 m tiles): street ribbons, massing boxes (MultiMesh, vertex-colored —
  the house style), water/rail/park flats, chunk-local static collision.
  Deterministic; a hash gate proves byte-stable output.
- **World renderer** (runtime, v1): the baked world is **resident** — chunks
  stay loaded, kept cheap by chunk-partitioned MultiMeshes (frustum-cullable
  groups), per-node visibility ranges (heroes swap to massing boxes, then
  fade), baked occluders per chunk (cities are occlusion's best case), and
  heroes mounting into their chunks as authored children. Streaming
  (load/unload with hysteresis) exists only as an upgrade path behind the
  same world interface — built if the perf gate demands, never on spec.
- **Fallback world:** the Windrow generator stays in the tree, inert behind
  the world flag, until R2's cutover passes — then it is deleted (owner
  fork: delete at R1 vs keep a debug toggle longer).

Why not runtime-generate from data (no bake): boot cost and hitching exactly
where T-129 already hurt us. Why not hand-author: 3,737 buildings is not a
hand-authorable number. Bake-then-render keeps the old synchronously-baked
knowledge where it belongs — offline.

**Coordinate convention (R1 decision):** local meters, origin at Lincoln
Way × Welch (the campus/Campustown seam), +X east, −Z north, Y up. Equirectangular
scaling at lat 42.02 is fine at 10.6 km. Spawn fork below.

**Float-precision check (external review, 2026-11-09):** with that origin the
farthest v1-core point sits ≈ 3.3 km out on one axis (the east edge); with
every R5 extension landed the worst case is still ≈ 3.5 km — inside the
±4 km single-precision comfort zone. If the map ever doubles again,
re-centering the origin is a data-pack version bump, not a refactor —
everything is data-driven.

**Lighting policy:** the sun is the only shadow caster (modest shadow
distance); night is emissive windows + lamp glow, never per-building dynamic
lights. What makes a city melt is draw calls, memory, and lighting — not
area — and this matches the game's existing one-sun setup.

## 3 · Ring strategy

Layer-by-layer, never district-by-district: **R1 makes the whole map exist**
(true streets, true positions, true silhouettes as placeholders), then each
later ring raises one layer of fidelity everywhere. The alternative — finish
campus fully, then Campustown — leaves the game without a city until the
very end and blocks every gameplay system for months.

Each ring: a themed ticket cluster, flag-gated work landing inert, one
**cutover** ticket that flips the default world and re-pins the suite, and
one owner Gate 3 flight. Rings are serial (each depends on the last's
cutover); within a ring, tickets parallelize like the existing
sweep/pipeline lanes (per-ticket worktrees, checkout lock, ID scan).

```
R1 The Map        → "launch, fly Lincoln Way end to end, recognize Ames from the air"
R2 The Life       → "calm traffic on a real arterial; Welch has people on it"
R3 The Landmarks  → "the postcard shot: LaVerne + campanile + bowl from 200 m"
R4 The Names      → "fly to Welch Ave Station; read the sign"
R5 The Town       → "the edges fill in; the town breathes; perf is budgeted"
R6 The Game       → (owner-picked options only) traditions, day/night, feel
```

---

## 4 · R1 — The Map (Ames exists)

*Goal: true skeleton at massing fidelity, flyable, survival loop intact.*
*Exit demo: menu → Space → spawn over Central Campus → fly Lincoln Way
State Ave → Duff at 60 m; the layout reads as Ames; hunger/bread work.*

| Codename | One line |
|---|---|
| R1·data-pack | Distill survey → `data/ames_core.json` + loader API + projection/origin; integrity Gate 1b (counts vs census, sentinel positions — campanile way 183041212 at (−93.64604, 42.02543)); bundle OSM attribution string; the one-page ODbL share-alike read. |
| R1·baker | Headless chunk baker → 256 m tiles (ribbons, massing boxes, flats, chunk collision); determinism hash gate; census scenario (chunk contains its buildings). |
| R1·world-renderer | Resident baked world: chunk-partitioned MultiMeshes, visibility-range LOD swaps (hero → massing → fade), baked occluders, sun-only shadows; perf Gate 1b (frame budget at cruise + low hover over the strip). Behind `world=windrow\|ames` flag; default unchanged. |
| R1·streaming-if-needed | *Conditional — built only if the perf gate fails:* load/unload chunks near the pigeon with hysteresis, behind the same world interface. Not built on spec. |
| R1·skeleton-visuals | Streets/water/rail/parks readable at cruise altitude; ground palettes per district dressing v0; sidewalk hint ribbons downtown/Campustown. |
| R1·placeholders | True-dim gray steles/massing at every authored position (the census's 512 + the top-15 list) so silhouettes and sight-lines already read (campanile spike, Marston beacon, bowl ellipse, Hilton drum). |
| R1·survival-rebase | Bread/crumb/roof-crumb placement from chunk data; hunger pacing sanity (crossing 4 km at 28.8 m/s ≈ 2.3 min — bread must exist district-wide, not plaza-only); spawn placement. |
| R1·cutover | Flip default to Ames; retire Windrow generate path (owner fork: delete now vs debug toggle); **full suite re-pin** (the ~140-check Gate 1b re-derived against chunk data); owner flight + Gate 3 note. |

Absorbs: B-20's "bigger city" half (bird speed stays; city grew instead),
T-129's boot problem (moot: nothing synchronous left to generate).

## 5 · R2 — The Life (systems on the real grid)

*Goal: traffic, signs, pedestrians, parking, and the economy rebased to real
geometry.* *Exit demo: freeze-traffic off, watch calm T-166 traffic hold a
real Lincoln Way intersection; walk (fly low) Campustown at dusk with
pedestrians on Welch.*

| Codename | One line |
|---|---|
| R2·traffic-graph | Car routes from the street graph (arterial/local classes, right-hand); spawn/despawn at chunk edges; the 9 rail crossings as known route facts (gates only — no train event yet). |
| R2·calm-port | Port T-166 etiquette (honk holds, oncoming-gated passes, blinkers) onto graph routes; the freeze_traffic / spawn_car dev verbs re-target. |
| R2·intersections | Crosswalk/stop-sign machine on the real intersection census (start with the 4-way anchors downtown/Campustown + arterial stops; 78 signals → select subset by class). |
| R2·pedestrians | Tourists/elders on activity zones (Campustown strip, downtown Main, Central Campus) — not the full 191 km footway; sit targets at real benches/cafés. |
| R2·parking | Curbside + census-lot spawning (73.6 ha stock); parked-car splat economy respects the T-147 anti-farm line. |
| R2·economy-scale | Favor targets distributed to districts (elder benches at Central Campus; visitor clusters on Welch); bread distribution pass; reticle/readout unchanged. |
| R2·cutover | Suite re-pin (traffic/sign/ped pins) + owner playtest. |

## 6 · R3 — The Landmarks (recognition, per the modeling specs)

*Goal: swap placeholders for hero assets, following MODELING-SPECS.md's
build order.* *Exit demo: 200 m overhead of Lake LaVerne with the campanile
behind and Jack Trice on the horizon — the postcard.* Each ticket: scene(s) +
placement + dims probe (Gate 1b asserts verified numbers) + pilot screenshots
vs reference photos. Grouped 2–3 related heroes per ticket to keep ceremony
down while staying small:

| Codename | Contents (verified dims; fidelity items) |
|---|---|
| R3·lake+swans | Lake LaVerne 236×122 m water + shoreline; **swans restored** (Lancelot & Elaine NPCs, ambient swimmers — F-traditions; owner fork on behavior scope). |
| R3·campanile | 33.5 m buff/tan brick (F-01), 50-bell carillon hint, landable cap (the anchor-cap landing pattern survives). Carillon audio = separate optional ticket. |
| R3·central-campus | 20-ac lawn, two crossing sight axes, Four Seasons fountain — the walkable heart. |
| R3·campus-row-west | Beardshear (green dome, F-03), Morrill, Farm House massing. |
| R3·mu+parks | Memorial Union pale limestone + squat tower (F-02, height model-to-look) + **zodiac decal in Gold Star Hall's floor** (F-traditions, corrected location); Parks Library massing + additions. |
| R3·marston | 51.2 m white steel tank + ISU-seal medallion (F-census) — the flight beacon. |
| R3·stadium-complex | Jack Trice bowl 183×208 m, field N–S (F-04), north grass hillside, west press; tailgate lot massing; Hilton drum 138×105 m ~790 m NE (F-qa). |
| R3·downtown | Bandshell (copper arch over pale mint shells), Main Street fabric refinement, City Hall. |
| R3·civic-towers | Ames city water tanks (bulb-on-stem, AMES diamond + "We're Glad You're Here" — text glyph deferred to R4, shape now). |
| R3·rail-dressing | Depot building (no Amtrak — F-qa), crossing hardware at the 9, corridor textures; yellow SD70ACe coal-drag train asset as a moving landmark on the main line (the census's motion landmark). |
| R3·elevators | SE cluster at 30–40 m placeholder-truthed styling (heights unknowable — flagged). |
| R3·cutover | Suite re-pin + fidelity-pass screenshots vs photos + owner flight. |

## 7 · R4 — The Names (in-world text + the venue moment)

*Goal: the owner's literal acceptance test.* *Exit demo: fly to 207 Welch,
read "Welch Ave Station" on the sign at night.*

| Codename | One line |
|---|---|
| R4·text-capability | Label3D/plaque system + OFL font + the three sign typologies from photos (box, blade, pole); legibility-distance Gate 1b; **in-game credits screen** (OSM attribution + photo CCs live here). |
| R4·signs-tier1 | The 14 Tier-1 venues signed (welchave.com-verified facades; pre-2025 Welch streetscape since the real strip is under reconstruction). |
| R4·signs-tier2-3 | Tiers 2–3; ghost plaques for the mourned-closed list = owner fork (tone check first). |
| R4·street-blades | MUTCD-green name blades for spines (Lincoln Way, Welch, Main, Duff, Grand…) — wayfinding by reading, not memory. |
| R4·campus-plaques | Nominative building names (Campanile, Beardshear Hall…); no wordmarks/logos — the legal line. |
| R4·cutover | Suite re-pin + owner recognition playtest (the "hand it to an alum" test). |

## 8 · R5 — The Town (edges, dressing, breath)

| Codename | One line |
|---|---|
| R5·bbox-east | +~200 m east: Bandshell Park inside the core (census miss), Hickory Park corridor on S Duff. |
| R5·south | +1 km: Reiman Gardens (conservatory 59×88 m WITH the 465 m² Hughes glasshouse split — QA item 1) + Vet Med. |
| R5·north | +1.6 km: Ada Hayden twin lakes, Inis Grove, Moore park. |
| R5·filler-dressing | District dressing rules onto procedural filler (roof pitch, setbacks, palettes, porch rhythm from the two house portraits). |
| R5·trees | 5,637 mapped trees as MultiMesh canopy — the town's cover. |
| R5·tailgates | Static game-day lot dressing (tents, RVs) on the census lots. |
| R5·perf-pass | Budgets and LOD tiers audited; **web revisit fork** (streaming desktop-grade vs web diet; box may be alive by then). |
| R5·cutover | Suite re-pin + owner pass. |

## 9 · R6 — The Game (options; nothing starts without an owner pick)

Parked deliberately, fenced: (a) day/night bar-hours lighting on Campustown
(the Reddit time-of-night ecosystem as *dressing*, not schedules);
(b) traditions easter eggs — campaniling midnight chime moment, zodiac
avoid-dressing, three-laps folklore sign; (c) VEISHEA remembrance handled
with dignity or not at all (owner call); (d) flight feel pass on the big map
(B-20's "slower bird" half — needs a feel probe first); (e) victory-ending
relocation to Central Campus (T-115's ceremony in the real heart).
B-9 perch/verticality and B-4a landmark bonus targets fold here too.

## 10 · Verification & workflow integration

- **Every ring:** flag-gated tickets land inert (gates stay green untouched);
  cutovers carry the re-pin. No ticket mixes "new world data" with "feel
  change" — physics/feel tickets ride the pipeline per the standing rule.
- **New standing gates born in R1:** data-pack integrity census, bake
  determinism, world-render frame budgets, hero-dims probes. These become
  the suite's new pinned floor.
- **Verification plays for real:** pilot sessions (hidden windows, `shot`,
  `--time-scale` for staging screenshots), dev verbs for staging; screenshots
  diffed against the survey's credited photos.
- **Deploy:** `deploy:false` across the campaign while the box is dead;
  hosted stays frozen at 899dcd2 until R5's web fork.
- **Ticket flow:** forge mints each ticket (references already in-repo —
  the survey IS the reference pack), pipeline implements; sweep stays
  available for non-campaign lanes but campaign tickets run owner-steered
  serial-parallel per ring.

## 11 · Open owner forks (answer any, at any ring boundary)

1. **Spawn point:** (a) Central Campus near the campanile (recommended —
   postcard + all systems reachable), (b) over Welch × Lincoln Way
   (immediate strip energy), (c) Lake LaVerne shore (swan adjacency).
2. **Windrow's fate:** delete at R1 cutover (recommended) vs keep behind a
   debug world flag until R2/R3.
3. **Swans' scope:** ambient swimmers only (recommended) vs perchable/landable
   (comedy risk — they're beloved; handle gently) vs splat-able (no).
4. **Ghost plaques for closed venues** (R4): yes as love notes (recommended,
   tone-checked) vs omit.
5. **Web build after R5:** re-diet and redeploy vs desktop-only for a while.
6. **R6 options:** pick any of (a)–(e) or none.

## 12 · Risk register

| Risk | Mitigation |
|---|---|
| Draw calls / memory / lighting — the melt-factors, not area | resident baked world: instancing, visibility-range LOD, baked occlusion, sun-only shadows; budget gates from R1; precedent: public 5 × 5 km / ~70k-house Godot city demos |
| Suite re-pin tax each ring | budgeted inside cutovers; it is scheduled, not fought |
| Feel regressions invisible to gates | every ring ends in an owner Gate 3 flight; pilot screenshots vs photos |
| Scope inflation (the fence) | R6 is pick-only; no schedules/quests anywhere; tickets stay small |
| ODbL/attribution obligations | attribution string from R1; credits screen R4; share-alike read R1 |
| Dead deploy box noise | deploy:false until R5 |
| Token budget | campaign runs on Individual plan pins; rings serial, tickets parallel ≤ 2 |

## 13 · Deliberately out (now and forever, unless the owner re-opens)

Interior spaces of any building; real schedules for any NPC; dialogue;
quest machinery; real registered marks (wordmark/logo/Cy depiction/athletics
marks); traffic simulation beyond calm-dressing fidelity; train-block
*events* as gameplay (the crossings are facts, trains are landmarks).
