class_name AmesBaker
## Offline chunk baker (T-172): turns the committed Ames data pack
## (`data/ames/ames_core.json`, T-171) into per-chunk JSON resources — 256 m
## tiles — under `data/ames/chunks/`, ready for the resident world renderer
## (T-173) to instantiate as chunk-partitioned MultiMeshes.
##
## Bake-then-render (master plan §2): ALL generation cost happens here,
## offline. The runtime only instantiates what is already built. The bake is
## a pure function of the pack: no RNG, no time, no environment — two runs
## on the same machine produce byte-identical files, proven per chunk by the
## SHA-256 determinism manifest (`ames_bake_determinism`, Gate 1b).
##
## What each chunk carries (ames_chunks/v6 — v5 plus the T-207 tree-canopy
## family `trees`; v5 carried the T-206 filler-dressing families `roofs`
## (gable prisms) and `dress` (porch/cornice/parapet/screen/penthouse boxes);
## v3 carried the T-205 trail_quads family; v2 before that carried the T-175
## placeholder family and the massing `a` flag; every family is optional at
## read time):
## - `massing`: ONE axis-aligned box per building footprint — position,
##   size, district and vertex color (city.gd's MultiMesh + vertex-color
##   house style, ported to data), plus `a` (T-175): TRUE when the building
##   is one of the 512 AUTHORED buildings — the renderer gives those boxes
##   collision (the placeholder slots heroes replace in R3, the roof-crumb
##   hosts T-176 files under). Procedural filler gets the census §7.4
##   level ladder (bbox+levels, footprint bands where OSM tags nothing);
##   authored buildings get their bbox massing too — the 8 hero buildings'
##   bbox boxes are SUPERSeded by their true-dim silhouettes (the renderer
##   hides the ids the manifest's `heroes` list names), the rest stay the
##   LOD0 fallback exactly as before. (T-206) every non-hero entry also
##   carries `v` — its district-variant id (see VARIANT_* below); the
##   footprint/height/color fields are UNCHANGED by dressing.
## - `roofs`: (T-206) ONE gable prism per residential house — the §3.6
##   gable/hip roof form over the box top. Unit-prism instances (the
##   renderer's own mesh), `a` = ridge axis ("x"|"z"), `p` = eave center at
##   the box top, `s` = [ridge_len, span, ridge_h] in ridge-axis order, `c`
##   = the shingle color. Visual-only: no collider, no ground record, no
##   occluder, no roof-crumb host (the crumbs keep their T-176 box-top law).
## - `dress`: (T-206) the per-district dressing boxes — porches (deck +
##   canopy, §3.6/the house portraits), cornice bands (§3.2), parapets
##   (§3.3), rooftop mechanical screens (§3.7), penthouses (§3.3) — ONE box
##   each (`role` names it), vertex-colored, visual-only like the roofs.
##   Both families SKIP the hero buildings entirely: the silhouettes
##   supersede 1:1 at every layer (the T-175 law).
## - `ribbons`: street centerlines pre-extruded to asphalt quads at the
##   pack's per-class widths (primary 20 m four-lane … residential 11 m).
## - `lane_quads`: (T-174) center dashes on the four named arterials ONLY
##   (Lincoln Way / Main Street / Duff / Grand — residential streets stay
##   plain asphalt; crosswalk paint is T-180).
## - `water_tris` / `lawn_tris`: Lake LaVerne and the 31 park polygons,
##   ear-clip triangulated offline into world-space triangles.
## - `shore_quads`: (T-174) the lake's mown-lawn shoreline band, extruded
##   OUTWARD from every ring edge, baked BELOW the water top so it can
##   never paint the lake — the shore reads as shore, not as a blue hole.
## - `creek_quads`: College/Ioway centerlines extruded to 6 m water ribbons.
## - `ballast_quads`: the rail centerline extruded to a 5 m ballast strip,
##   SEGMENTED wherever it would run over a crossing road's own asphalt —
##   the 9 at-grade crossings' road ribbons (BOTH carriageways of divided
##   roads) block the ballast geometrically, so the roads show through.
## - `tie_quads`: (T-174) the dark tie/track stripe riding the ballast
##   centerlines (the double main reads as track, not as a gray path),
##   same crossing gaps as the ballast it rides.
## - `ground_quads`: (T-174, dressing v0) the per-district GROUND — a 32 m
##   cell grid over the whole pack range, tinted ONLY where the v0 district
##   rule says a district other than the residential seed stands (the
##   ground plate wears the residential color, so cells and plate never
##   disagree). Per-cell district color from `DISTRICT_GROUND`.
## - `occluders`: one simplified building outline (the bbox rectangle) per
##   massing box — the feed for baked `ArrayOccluder3D`s (T-173).
## - `placeholders`: (T-175) the landmark placeholders as ONE box each per
##   entry — hero silhouette PARTS (true-dim gray masses, `part` names the
##   role: plinth/shaft/head/cap …) and venue FIXUPS (a storefront box at
##   every placed IN-CORE venue POI that is not a pack-marked prop and
##   whose position no authored building's bbox covers — the census §2
##   anchors that OSM never polygonized; the Superdog cart and Carlos
##   Quesadilla's truck are props, the four out-of-core venues are
##   boundary decisions, neither gets a box). These are
##   the slots the R3 hero scenes replace and the shapes the from-the-air
##   recognition bar reads; the renderer draws them, collides them and
##   files them under `ground_height()`.
## - `crossings`: the at-grade rail crossings inside the tile (world facts
##   for R2's traffic graph; machine-checked by `ames_bake_census`).
##
## NOT baked (by ticket): authored hero SCENES (mount at R3, T-185+ — T-175's
## silhouettes are the stand-ins), collision (the renderer builds it from the
## `a` flag + placeholders; T-173's gameplay seam answers ground queries over
## chunk data).
## - `trees`: (T-207) the mapped `natural=tree` points as ONE instance each
##   at the mapped position — `t` names the archetype (oak/boulevard/shore),
##   `p` is the mapped xz at the plate top, `s` the per-axis scale, `a` the
##   yaw, `c` the variation tint. Visual-only (no collision, no occluder, no
##   ground record — the foliage convention); the renderer draws ONE
##   MultiMesh per archetype present from meshes it builds out of
##   `TREE_ARCHETYPES` (the single dim/color source, see that block).
##
## Determinism discipline: pack arrays are consumed in order; every float is
## snapped (positions 0.001 m, colors 0.0001); JSON is serialized with sorted
## keys; files are written in sorted (cx, cz) order; colors are picked by a
## stable hash of the building id (no RNG anywhere).

const SCHEMA := "ames_chunks/v6"
const CHUNK_SIZE := 256.0

## Every per-chunk array family (the `_chunk_at` template, the finalize doc,
## the per-chunk counts and the manifest totals — ONE list, kept in one
## place; v1's eight, the T-174 dressing families, T-175's placeholders,
## T-205's trail_quads, T-206's roofs + dress, and T-207's trees).
const FAMILY_KEYS: Array[String] = [
	"massing", "ribbons", "lane_quads", "water_tris", "shore_quads",
	"creek_quads", "lawn_tris", "ballast_quads", "tie_quads",
	"ground_quads", "trail_quads", "occluders", "placeholders", "crossings",
	"roofs", "dress", "trees",
]

## Bake y conventions (m). Flats stack above 0 so the ground plate (top at
## y 0, T-173) never z-fights: water below creek below lawn below road below
## ballast. CRITICAL for the T-174 dressing: the water/lawn flats render as
## FLAT TRIANGLES at their baked y (no thickness), while every rectangle
## family renders as a 0.02-thick box CENTERED on its baked y — so a box
## family must keep its TOP (`y + 0.01`) strictly below any triangle it
## surrounds, or the coplanar/top-heavy faces depth-fight the water away
## (the first landing had cells topping at exactly the water's 0.02 and the
## lake read as lawn). Stack, by rendered top: plate 0 < cells 0.014 <
## shore 0.018 < water 0.02 < lawn 0.04 < creek-top 0.06 < trail-top 0.07
## (T-205) < ribbon-top 0.09 < ballast/marks-top 0.11 < tie-top 0.13. The
## quarry shore band (T-205) is the ONE shore variant that rides ABOVE the
## lawn: its park-lake hole cut leaves the lawn as the surrounding ground,
## so the band centers on LAWN_Y (top 0.05) — over the lawn, clear of the
## water flat it rings.
const WATER_Y := 0.02
const CREEK_Y := 0.05
const LAWN_Y := 0.04
const RIBBON_Y := 0.08
const BALLAST_Y := 0.1
const GROUND_Y := 0.004 ## District ground cells (T-174): box tops at 0.014.
const SHORE_Y := 0.008 ## Shore band (T-174): box tops at 0.018, under the water.
const QUARRY_SHORE_Y := 0.04 ## Quarry bank (T-205): box tops at 0.05, over the lawn.
const TRAIL_Y := 0.06 ## Trail stripes (T-205): box tops at 0.07, over the creek top.
const MARK_Y := 0.1 ## Lane dashes (T-174): box tops at 0.11, over the ribbon top 0.09.
const TIE_Y := 0.12 ## Tie stripe (T-174): box tops at 0.13, over the ballast top 0.11.

## --- T-174 skeleton-visuals constants --------------------------------------

## District GROUND palettes (dressing v0 — MODELING-SPECS §3 hex estimates,
## tuned by screenshot): the ground color under each district's streets.
## The ground PLATE wears the residential seed (the map's default ground —
## `ames_world.gd` reads this entry); the bake emits ground cells only where
## the v0 rule says another district stands, so plate and cells never
## disagree. Downtown brick-warm (§3.2 mid-brick family); campustown
## scruffy gray (§3.3 cinderblock strip); campus lawn green (§3.7
## campus-in-green — never bare-ground campus); Lincoln Way commercial
## strip asphalt (§3.4, worn/approach aprons); residential seed = the
## T-173 plate color, unchanged.
const DISTRICT_GROUND: Dictionary = {
	"campus": Color(0.4, 0.529, 0.298), ## #66874C campus lawn green.
	"campustown": Color(0.518, 0.494, 0.447), ## #847E72 scruffy gray.
	"downtown": Color(0.627, 0.439, 0.322), ## #A07052 brick-warm sidewalk.
	"lincolnway": Color(0.333, 0.322, 0.298), ## #55524C strip asphalt.
	"residential": Color(0.38, 0.46, 0.3), ## #61754D residential seed (= the plate).
}

## Flat family colors (T-174 additions). The lake keeps the §1.2 olive-brown
## (#46543F, unchanged); the creeks become GREEN-BLUE ribbons (they must not
## read as more lake); the shore is the §1.2 mown shore lawn; the lane dash
## a weathered centerline yellow; the tie stripe a creosote brown-gray.
## T-205 adds the north parks: the trail stripe is MODELING-SPECS §2's
## "Prairie/gravel trail" hex (`nature/04-adahayden-prairie-trail.jpg`) and
## the quarry bank the IMAGE_INDEX nature-note's pale gravel shore ("flat
## quarry-banked shoreline") — a survey estimate, recorded here.
const COLOR_CREEK := Color(0.275, 0.4, 0.388) ## #466663 green-blue (T-174).
const COLOR_SHORE := Color(0.435, 0.561, 0.31) ## #6F8F4F mown shore lawn (§1.2).
const COLOR_LANE_MARK := Color(0.78, 0.7, 0.353) ## #C7B35A centerline yellow.
const COLOR_TIE := Color(0.29, 0.267, 0.227) ## #4A443A tie/track stripe.
const COLOR_TRAIL := Color(0.725, 0.663, 0.518) ## #B9A984 prairie/gravel trail (§2).
const COLOR_QUARRY_BANK := Color(0.659, 0.631, 0.580) ## #A8A194 pale gravel (estimate).

## Lane-dash geometry (m): a 3 m dash / 6 m gap urban centerline, 0.4 m wide
## — real paint would be ~0.15 m, but a HINT must survive a 60 m cruise read.
const MARK_DASH := 3.0
const MARK_PERIOD := 9.0
const MARK_WIDTH := 0.4
## Street NAME fragments that make a street an arterial for the dash rule —
## the ticket's four corridors by name, not class (Main's eastern OSM stretches
## carry residential tags and still get their dash; South Duff/South Grand/
## East Lincoln Way match their corridor). Everything else stays plain asphalt.
const ARTERIAL_NAME_KEYS: Array[String] = ["Lincoln Way", "Main Street", "Duff", "Grand"]

## Shore band width (m): the mown ring between lake water and district ground.
const SHORE_WIDTH := 7.0
## Tie stripe width (m): the double main's per-track dark line on the ballast.
const TIE_WIDTH := 1.6
## District ground cell edge (m): the dressing-v0 grid (256 divides evenly;
## band edges stair-step at this size — a deliberate v0 coarseness).
const GROUND_CELL := 32.0

## Massing height rule. MODELING-SPECS §3.10 heights cap: procedural towers
## are FORBIDDEN — the skyline belongs to Marston (51.2 m), the Campanile
## (33.5 m), Legacy/University/Wilson-Wallace (10–11 lv, 27–40 m). The one
## 100 m `height` tag is the ISU Power Plant STACK, not mass — clamp to 40.
const MASSING_MAX_HEIGHT := 40.0
## Census §7.4 default level heights: 1 lv ≈ 4 m … 4 lv ≈ 14 m (85 % of the
## tagged stock is 1–3 lv); towers beyond 4 lv grow 3 m per level, landing
## 8 lv ≈ 26 m and 11 lv ≈ 35 m inside the census's 27–40 m band.
const LEVEL_LADDER: Array[float] = [4.0, 8.0, 11.0, 14.0]
## Footprint bands (m²) for buildings with no OSM tags at all (census §7.5:
## residential p50 127 m², district rows p50 246–294 m²): 2 / 3 / 4 levels.
const FOOTPRINT_LV_BANDS: Array[float] = [300.0, 1000.0]

## Street widths by class (census §7.3 defaults — the pack carries these per
## entry; the baker reads each street's own `width_m`, this table is only the
## fallback for a hypothetical entry missing it).
const ROAD_WIDTH_BY_CLASS: Dictionary = {
	"primary": 20.0, "secondary": 16.0, "tertiary": 13.0,
	"residential": 11.0, "unclassified": 11.0, "living_street": 9.0,
	"service": 7.0, "trunk": 20.0, "motorway": 24.0,
}

## District dressing palettes (MODELING-SPECS §3 + §1, hex in comments —
## T-206 re-pinned onto the survey's own §1.10/§1.5/§1.6/§1.7 estimates):
## downtown §3.2 dark-to-mid brick + painted-concrete cream; campustown §3.3
## the §1.5 strip-brick range #96513A…#7C4230 + cinderblock #B9B1A2…#C9C0AE;
## campus §3.7 buff/tan + pale limestone (the §1.2 MU sunlit limestone) +
## dark-red brick; lincolnway §3.4 set-back one-story retail creams + the
## §1.6 strip brick; residential §3.6 the §1.10 siding range #D8CDB4 /
## #EDEAE2 / #B7B7AD + the brick accent #96513A.
const DISTRICT_PALETTES: Dictionary = {
	"campus": [
		Color(0.769, 0.745, 0.69), ## #C4BEB0 pale limestone (MU sunlit).
		Color(0.839, 0.804, 0.706), ## #D6CDB4 buff/tan brick.
		Color(0.541, 0.29, 0.212), ## #8A4A36 dark-red brick.
		Color(0.867, 0.847, 0.788), ## #DDD8C9 pale concrete.
	],
	"campustown": [
		Color(0.588, 0.318, 0.227), ## #96513A strip brick (range head).
		Color(0.486, 0.259, 0.188), ## #7C4230 strip brick (range tail).
		Color(0.722, 0.478, 0.333), ## #B87A55 warm brick mid.
		Color(0.725, 0.694, 0.635), ## #B9B1A2 cinderblock (range head).
		Color(0.788, 0.753, 0.682), ## #C9C0AE cinderblock cream (range tail).
	],
	"downtown": [
		Color(0.541, 0.29, 0.212), ## #8A4A36 dark brick.
		Color(0.659, 0.4, 0.247), ## #A8663F mid brick.
		Color(0.812, 0.773, 0.706), ## #CFC5B4 painted-concrete cream.
		Color(0.788, 0.753, 0.682), ## #C9C0AE painted facade cream (§1.7).
	],
	"lincolnway": [
		Color(0.827, 0.788, 0.714), ## #D3C9B6 retail cream.
		Color(0.761, 0.706, 0.604), ## #C2B49A tan box (§1.6 stucco).
		Color(0.878, 0.851, 0.776), ## #E0D9C6 pale cream.
		Color(0.612, 0.416, 0.282), ## #9C6A48 strip brick (§1.6).
	],
	"residential": [
		Color(0.847, 0.804, 0.706), ## #D8CDB4 tan siding (§1.10).
		Color(0.929, 0.918, 0.886), ## #EDEAE2 cream-white siding (§1.10).
		Color(0.718, 0.718, 0.678), ## #B7B7AD gray siding (§1.10).
		Color(0.588, 0.318, 0.227), ## #96513A brick accent (§1.10).
	],
}

## --- T-206 filler-dressing constants (MODELING-SPECS §3 district rules) -----
##
## The variant law: every non-hero building gets ONE district-variant id (`v`
## on the massing entry) plus its baked dressing geometry (`roofs` prisms and
## `dress` boxes). All picks are the stable id hash — no RNG (the bake's
## determinism discipline). The §3 rules these implement:
## - §3.6 residential grids: 1–2-story GABLE/hip houses (§1.10 portraits:
##   "gabled residential"); porch rhythm as the lot-level hint; the tall
##   (4+ level) slabs keep a flat roof + parapet, like Campustown's
##   side-street apartments.
## - §3.2 downtown rows: the continuous masonry wall wears a CORNICE band
##   ("flat roofs, parapets, cornice band") — every downtown box, cornice
##   stone #D6CDBB (§1.7).
## - §3.3 Campustown strip: the scruffy MIX — parapet / plain flat / rooftop
##   penthouse by hash.
## - §3.7 campus-in-green: flat roofs + MECHANICAL SCREENS on the big blocks
##   ("rooflines: flat + mechanical screens"); the small ones stay plain.
## - §3.4/3.5 Lincoln Way + S Duff strip: set-back ONE-story retail — a
##   hash mix of fascia PARAPET bands and plain flats (the strip's motels
##   and car lots are plainer than downtown's wall).
## Heights gate the gable: the census §1 histogram puts 85 % of tagged stock
## at 1–3 levels (4/8/11 m on the LEVEL_LADDER) — gables ride the ≤ 3-level
## residential band, so no school/apartment slab ever sprouts a house roof
## and the §3.10 heights cap stays untouched (roof geometry is ABOVE the
## massing, never a new tower).

## Roof-variant ids (`v` values; also the `ames_filler_variants` pin set).
const VARIANT_GABLE_LO := "gable_lo"
const VARIANT_GABLE_HI := "gable_hi"
const VARIANT_PARAPET := "parapet"
const VARIANT_CORNICE := "cornice"
const VARIANT_SCREEN := "screen"
const VARIANT_PENTHOUSE := "penthouse"
const VARIANT_FLAT := "flat"

## A residential box gets a gable only at or under this massing height (m) —
## the census §1 level ladder's 3-level rung (11 m) plus a 0.5 snap band.
const GABLE_MAX_HEIGHT := 11.5
## The two pitch classes, as rise/run tan: ≈24° and ≈35° (§1.10 house
## portraits: moderate pitches, no cabins, no gothic steeples).
const GABLE_PITCH_LO := 0.45
const GABLE_PITCH_HI := 0.7
## Eave overhang past the wall line (m) — roofs read deeper than the box.
const GABLE_OVERHANG := 0.4

## House-scale cap for the porch hint (m): the §1.10 p50 footprint 127 m²
## sits around 12 × 10; porches ride houses at most this long dimension —
## a church or barn never grows one.
const PORCH_HOUSE_MAX_DIM := 16.0
## Porch geometry (m): deck slab + flat canopy at the §1.10 portraits'
## one-story porch height.
const PORCH_DEPTH := 2.0
const PORCH_SPAN_FRAC := 0.5
const PORCH_DECK_T := 0.25
const PORCH_CANOPY_TOP := 2.6
const PORCH_CANOPY_T := 0.2
## Chimney geometry (m): the §1.10 LOD's "chimney prop" — a small brick
## stack through the roof plane near the ridge.
const CHIMNEY_SIDE := 0.9
const CHIMNEY_RISE := 1.2
const CHIMNEY_RIDGE_FRAC := 0.3 ## From the ridge end, mirrored by hash.

## Cornice band (m): §3.2's crowning course — proud of the wall both ways.
const CORNICE_OUTSET := 0.4
const CORNICE_HEIGHT := 0.6
const CORNICE_RISE := 0.15
## Parapet band (m): §3.3's low front wall rising past the roof line.
const PARAPET_OUTSET := 0.3
const PARAPET_HEIGHT := 0.4
## Rooftop mechanical screen (m): §3.7's flat + screens campus read; big
## blocks get TWO (hash-mirrored), placed by footprint fraction.
const SCREEN_MIN_AREA := 400.0 ## m² of footprint before a block screens.
const SCREEN_H := 1.6
## Penthouse cap (m): §3.3's rooftop box on the taller infill slabs.
const PENTHOUSE_MAX := 8.0
const PENTHOUSE_H := 2.5

## Variant-set colors (survey hexes, not the gray masses'):
const ROOF_SHINGLES: Array[Color] = [
	Color(0.306, 0.306, 0.322), ## #4E4E52 weathered shingle (§1.10 head).
	Color(0.263, 0.263, 0.286), ## #43434A mid shingle.
	Color(0.227, 0.227, 0.243), ## #3A3A3E dark shingle (§1.10 tail).
]
const DRESS_TRIM := Color(0.929, 0.918, 0.886) ## #EDEAE2 porch trim (§1.10).
const DRESS_BRICK := Color(0.588, 0.318, 0.227) ## #96513A chimney brick.
const DRESS_CORNICE := Color(0.839, 0.804, 0.706) ## #D6CDBB cornice stone (§1.7).
const DRESS_SCREEN := Color(0.612, 0.612, 0.58) ## #9C9C94 weathered screen concrete (§1.3).

## --- T-207 tree-canopy constants --------------------------------------------
##
## The mapped `natural=tree` points become ONE tree instance each at the
## mapped position (±0 m — "the data is the point"): the mapped data decides
## WHERE, the archetype decides WHAT. Three archetypes over the ticket's four
## placements (MODELING-SPECS §3.6/§3.7/§1.9/§1.10 + the ticket refs):
## - OAK (campus lawn + park polygons) — the open-grown broad crown over a
##   thick trunk (`images/campus/20`'s oaks on the lawn); PARK points tint
##   into the GROVE band, the §1.9 Brookside forest's darker summer read
##   (#3E5A32 against the #55703F lawn family).
## - BOULEVARD (everything else — the residential grids incl. campustown/
##   downtown/lincolnway) — the mature yard/street canopy: taller, narrower
##   crown on a longer trunk (`images/nature/20`'s giant over the two-story
##   roof; §1.10 "mature canopy (summer) #55703F dominant").
## - SHORE (within TREE_SHORE_DIST of the Lake LaVerne ring) — the water's
##   low broad willow row on a short trunk (the ticket's LaVerne shore ring;
##   crown hex is §1.9's park-mown yellow-green #7A9450 as the willow
##   estimate — no pinned willow hex exists, recorded here per the survey's
##   estimate discipline).
## The instance color is a per-tree VARIATION tint AROUND the archetype crown
## color (the mesh vertex colors carry the survey hexes; the multiply keeps
## the bark bark — see the renderer's tree material). Per-chunk MultiMesh
## discipline: one draw per chunk PER ARCHETYPE PRESENT (≤ 3), same
## partitioning as the massing. NO collision, NO occluder, NO ground record —
## the canopy is soft (the pigeon brushes through, the foliage convention;
## T-172's NOT-baked list closes here). All picks are the stable index hash —
## no RNG anywhere in the bake.
##
## The census §5 count these close: 5,637 was the v1 box's count; the pack's
## tree layer grew +78 (T-204 south) and +1,038 (T-205 north) to today's
## 6,753 — `ames_data_integrity` pins the v4 pack count, and
## `ames_tree_canopy` pins the bake == pack 1:1.

const TREE_OAK := "oak"
const TREE_BOULEVARD := "boulevard"
const TREE_SHORE := "shore"

## The archetype dims (m) — the SINGLE source the renderer builds its meshes
## from (`AmesWorld._make_tree_meshes` reads this table): trunk prism up
## through the crown bottom, an ellipsoid crown blob at `crown_cy`. The
## per-instance scale band below multiplies every axis.
const TREE_ARCHETYPES: Dictionary = {
	TREE_OAK: {
		"trunk_h": 6.0, "trunk_r": 0.45,
		"crown_cy": 8.6, "crown_rxz": 5.0, "crown_ry": 3.2,
		"crown_color": Color(0.333, 0.439, 0.247), ## #55703F §1.10 dominant canopy.
	},
	TREE_BOULEVARD: {
		"trunk_h": 8.0, "trunk_r": 0.36,
		"crown_cy": 10.8, "crown_rxz": 4.0, "crown_ry": 3.2,
		"crown_color": Color(0.333, 0.439, 0.247), ## #55703F dominant (narrower, taller crown).
	},
	TREE_SHORE: {
		"trunk_h": 4.6, "trunk_r": 0.5,
		"crown_cy": 6.8, "crown_rxz": 5.6, "crown_ry": 2.0,
		"crown_color": Color(0.478, 0.58, 0.314), ## #7A9450 willow yellow-green (§1.9 estimate).
	},
}
const TREE_TRUNK_COLOR := Color(0.43, 0.38, 0.314) ## #6E6152 gray-brown bark (estimate).

## Per-axis instance scale band — young-to-mature spread around the archetype
## dims (three independent hash bands, so height and spread decorrelate).
const TREE_SCALE_LO := 0.82
const TREE_SCALE_HI := 1.18
## The variation tint band (multiplicative around white; the crown color is
## the archetype's, the tint varies it): green channel = luminance, red/blue
## jitter the hue. The PARK grove band darkens into the §1.9 Brookside
## summer-forest read (#55703F × ≈0.8 ≈ #3E5A32).
const TREE_TINT_LO := 0.86
const TREE_TINT_HI := 1.08
const TREE_GROVE_LO := 0.74
const TREE_GROVE_HI := 0.86
const TREE_HUE_JITTER := 0.18 ## Red/blue spread around the luminance (±0.09).

## The shore-ring law: Lake LaVerne's pack lake entries only (the ticket's
## LaVerne shore ring — Ada Hayden's quarry-gravel shore is NOT willow water;
## its shore trees read park/oak), within this distance of any ring segment.
const TREE_SHORE_NAME_TOKEN := "LaVerne"
const TREE_SHORE_DIST := 30.0

## Crown blob tessellation (the renderer's mesh, one table so the bake's
## AABB and the drawn geometry agree): radial segments × rings over the
## ellipsoid — the house-style low-poly read. The trunk hint is a
## TREE_TRUNK_SEGMENTS-sided prism.
const TREE_CROWN_SEGMENTS := 9
const TREE_CROWN_RINGS := 4
const TREE_CROWN_LOBES := 0.16 ## Deterministic radius jitter spread (±0.08).
const TREE_TRUNK_SEGMENTS := 6


## lawn; asphalt = city.gd's COLOR_ASPHALT; ballast gravel gray).
const COLOR_ASPHALT := Color(0.29, 0.29, 0.31)
const COLOR_WATER := Color(0.275, 0.329, 0.247) ## #46543F olive-brown.
const COLOR_LAWN := Color(0.435, 0.561, 0.31) ## #6F8F4F mown lawn.
const COLOR_BALLAST := Color(0.545, 0.522, 0.471) ## #8B8578 gravel.
const CREEK_WIDTH := 6.0
## Trail stripe widths by pack `kind` (T-205): the mapped cycleway loops read
## as the paved park loop (3 m), the footway/path crushed-rock paths (2 m),
## park connector walks (2.5 m). Survey anchors: LANDMARKS T10's paved loops
## vs ~3.2 km (2 mi) of crushed-rock paths.
const TRAIL_WIDTH_BY_KIND: Dictionary = {
	"cycleway": 3.0, "footway": 2.0, "path": 2.0, "pedestrian": 2.5,
}
const BALLAST_WIDTH := 5.0 ## Single main-line track ballast (bake constant).
## Rail segments are subdivided to at most this length (m) so the crossing
## gaps hug the roads (a sub-segment is skipped whole, so the step bounds the
## gap's slack along the track).
const RAIL_STEP := 8.0
## Street polyline segments whose midpoint sits within this distance of an
## at-grade crossing pos are that crossing's road geometry (BOTH carriageways
## of a divided road — the pack carries one street entry per carriageway).
## Their baked-width ribbons block the ballast.
const CROSSING_ROAD_RADIUS := 30.0
## Hairline the ballast keeps back from the asphalt edge (m): a rail sub-
## segment quad is skipped when it comes within this of a crossing-road
## ribbon quad (SAT test), so road paint never reads through ballast.
const GAP_MARGIN := 0.2

## District rule constants (v0 first pass — deterministic pure geometry over
## the pack's own named data; R5 re-dresses). Campus anchors are landmark
## POI ids; campus streets are the named campus-interior corridors; the
## downtown band pins the Main/5th/6th rows to their x range so no
## elsewhere-named "5th Street" leaks in; campustown is the L/W corridor's
## south side between State and Stanton (census §7.2 centerlines).
const CAMPUS_ANCHOR_IDS: Array[String] = [
	"campanile", "central_campus", "beardshear_hall", "marston_water_tower",
	"parks_library", "memorial_union", "lake_laverne", "hilton_coliseum",
	"jack_trice_stadium",
]
const CAMPUS_STREET_NAMES: Array[String] = [
	"Union Drive", "Morrill Road", "Bissell Road", "Osborn Drive",
	"Pammel Drive", "Campus Avenue",
]
const DOWNTOWN_STREET_NAMES: Array[String] = ["Main Street", "5th Street", "6th Street"]
const DOWNTOWN_X_BAND := Vector2(2150.0, 3350.0)
const CAMPUSTOWN_X_BAND := Vector2(-780.0, 175.0) ## State Ave → Stanton Ave.
const CAMPUSTOWN_Z_BAND := Vector2(-25.0, 150.0) ## South of Lincoln Way.
const DISTRICT_DIST_CAMPUS := 300.0
const DISTRICT_DIST_CAMPUS_STREET := 140.0
const DISTRICT_DIST_SPINE := 90.0
const DISTRICT_DIST_LW := 90.0
const DISTRICT_DIST_LW_BAND := 160.0

## --- T-175 landmark placeholders --------------------------------------------
##
## Every AUTHORED position is occupied (the massing `a` flag = the slot);
## venues whose address anchor OSM never polygonized get a fixup box; the
## from-the-air heroes get TRUE-DIM gray silhouettes as `placeholders` part
## boxes. Dims are the survey's settled numbers (docs/references/ames-survey/
## verification/VERIFICATION.md §5 + MODELING-SPECS §1): campanile 33.5 m
## (shaft ~4.9 sq on a 6.8 m plinth — §1.1, OSM bbox 6.8 × 6.7), Marston
## 51.2 m (tank 12.2 m × 7.3 m dia on lattice legs — §1.4), Jack Trice bowl
## ellipse 183 × 208 m long axis N–S with the north grass-berm wedge
## (V-09/V-11) and the 53 × 113 m N–S pitch, Hilton 12-sided drum 138 × 105 m
## (§1.3), MU 110 × 110 block with the squat corner tower (§1.2 — tower
## height UNKNOWN-model-to-look per V-30, kept squat), Parks 95 × 123 with
## the addition roofline step (§1.4), Beardshear block + oxidized-copper
## dome hint (§1.4), the Durham bandshell arc at its POI position (census
## §5: the park polygon itself lies outside the distilled core — the shell
## is hand-placed), the 1906 depot's long low mass + platform canopy
## (§1.8), plus two municipal water-tank bulbs and the SE grain-elevator
## cluster (LANDMARKS T7/T8 — no sourced position exists, V-30: heights are
## the 30–40 m UNVERIFIED placeholder, positions survey-anchored
## approximations recorded right here). The 8 hero buildings' bbox massing
## is superseded: the renderer hides the ids the manifest's `heroes` list
## carries and draws the silhouettes instead.
const HERO_BUILDING_IDS: Array[String] = [
	"way/183041212", ## Campanile.
	"way/861201396", ## Marston Water Tower.
	"way/613735866", ## Jack Trice Stadium bowl.
	"way/180651868", ## Hilton Coliseum.
	"way/33725619", ## Beardshear Hall.
	"way/183224150", ## Memorial Union.
	"way/33725897", ## Parks Library.
	"way/260524827", ## The 1906 depot (today's "Main Street Station").
	## (T-203) The Durham Bandshell's own OSM way (named "Durham Bandshell",
	## 25.4 × 14.6 m) — outside the v1 core box, so its massing never existed
	## until the bbox east landed it. Its slot is superseded 1:1 by the T-192
	## hero (the copper arch over the mint shells at this exact footprint —
	## `_bandshell_parts` from the park POI), so the way joins the hero set:
	## `_hero_parts` has no case for it (returns empty — the hero's parts are
	## the POI-built arc), and the manifest `heroes` law hides the bbox box
	## exactly like every hero above.
	"way/269752151", ## Durham Bandshell (T-203: the way came inside).
	## (T-204) The Reiman Gardens Conservatory's own OSM way (named "Reiman
	## Gardens Conservatory", 58.7 × 87.8 m — the WHOLE building per QA item
	## 1; Hughes's 465 m² glasshouse is a distinct volume inside it, not this
	## footprint). The bbox east brought it inside as an authored slot; its
	## slot is superseded 1:1 by the T-204 runtime hero (the wing-roof set
	## piece at this exact footprint — `_reiman_boxes` from the slot's own
	## center), so the way joins the hero set: `_hero_parts` has no case for
	## it (returns empty — the hero's parts are the runtime schedule), and
	## the manifest `heroes` law hides the bbox box exactly like every hero
	## above.
	"way/180765068", ## Reiman Gardens Conservatory (T-204: the way came inside).
]

## Venue fixup box (m): the census §2 storefront anchor — 2 levels of
## strip-frontage mass at the address position (footprint 12 × 10, the
## Campustown/downtown row band). Axis-aligned like every massing box.
## (Round 1: the depth is 10 — at the round-1 16 the boxes of the
## Lincoln Way south-frontage venues (Café Beaudelaire, Mr Burrito)
## crossed the road's z 10 edge, and the Superdog CART fixup stood square
## in Welch Ave; every baked fixup now clears every street ribbon quad,
## machine-pinned by the `ames_placeholder_dims` road-clearance arm.)
const VENUE_FIXUP_SIZE := Vector3(12.0, 8.0, 10.0)

## Survey-anchored approximations (V-30 UNVERIFIED — no OSM mapping exists;
## recorded here so a survey fix re-pins one constant):
const CITY_TANK_NORTH_POS := Vector2(2600.0, -1280.0) ## BRET stand-in — north Ames (LANDMARKS T8).
const CITY_TANK_EAST_POS := Vector2(3480.0, 620.0) ## One of T8's "two others", east side.
const ELEVATOR_CLUSTER_POS := Vector2(3420.0, -20.0) ## SE along the UP line (LANDMARKS T7).

## Ring segmentation: the bowl reads round from 36 axis-aligned chord boxes,
## the 12-sided Hilton drum from 12 (§1.3: "low 12-sided concrete drum").
const BOWL_SEGMENTS := 36
const DRUM_SEGMENTS := 12

## Placeholder palette (gray masses — the from-the-air read is the point;
## greens only where the shape IS green: pitch, berms, dome copper).
const HERO_CONCRETE := Color(0.62, 0.62, 0.6) ## Bowl rim, drum, blocks.
const HERO_STEEL := Color(0.45, 0.45, 0.46) ## Lattice legs, depot canopy.
const HERO_LIMESTONE := Color(0.78, 0.76, 0.7) ## Campanile/Beardshear/MU/Parks pale stone.
const HERO_SLATE := Color(0.25, 0.27, 0.31) ## Campanile cap, MU tower cap.
const HERO_COPPER := Color(0.37, 0.56, 0.41) ## Beardshear dome hint.
const HERO_GRASS := Color(0.31, 0.48, 0.23) ## Bowl pitch, north berms.
const HERO_BRICK := Color(0.6, 0.25, 0.19) ## Depot brick.
const HERO_ROOF_TILE := Color(0.69, 0.29, 0.2) ## Depot red tile hip.
const HERO_TANK := Color(0.9, 0.9, 0.88) ## Municipal bulb white.
const HERO_SILO := Color(0.85, 0.82, 0.77) ## Elevator pale concrete.
const HERO_SHELL := Color(0.86, 0.91, 0.86) ## Bandshell pale mint (§1.7).
const HERO_SHELL_ARCH := Color(0.29, 0.35, 0.34) ## Bandshell weathered copper arch.


## Bakes the committed pack into `out_dir` (`res://...` or an absolute or
## user:// path). Wipes stale `chunk_*.json`/`manifest.json` first, writes
## the chunks in sorted (cx, cz) order, then `manifest.json`. Returns the
## manifest Dictionary — `{}` when the pack cannot be loaded (callers treat
## that as "no bake", exactly like the loader contract).
static func bake_to_dir(out_dir: String) -> Dictionary:
	var pack: Dictionary = AmesDataPack.load_pack()
	if pack.is_empty():
		push_error("AmesBaker: no data pack at %s" % AmesDataPack.PACK_PATH)
		return {}
	var dir := DirAccess.open(out_dir.get_base_dir())
	if dir == null:
		push_error("AmesBaker: cannot open %s" % out_dir.get_base_dir())
		return {}
	dir.make_dir_recursive(out_dir.get_file())
	var chunks_dir := DirAccess.open(out_dir)
	if chunks_dir == null:
		push_error("AmesBaker: cannot open %s" % out_dir)
		return {}
	for existing: String in chunks_dir.get_files():
		if existing.begins_with("chunk_") and existing.ends_with(".json") \
				or existing == "manifest.json":
			chunks_dir.remove(existing)

	var ctx: Dictionary = _build_context()
	var tiles: Dictionary = {} ## Vector2i(cx, cz) -> chunk Dictionary.

	# --- buildings: one massing box + one occluder outline each -----------
	# (T-175) each entry carries `a`: the building is one of the 512 AUTHORED
	# buildings — the renderer gives authored boxes collision (the placeholder
	# slots); procedural filler stays visual-only massing. (T-206) each entry
	# also carries `v`: its district-variant id — and the variant's dressing
	# geometry (a `roofs` gable prism and/or `dress` boxes) lands beside it.
	# The hero buildings are SKIPPED by the variant pass entirely: their
	# silhouettes supersede the slot 1:1 at every layer (the T-175 law), and
	# a gable over a hidden box would float over a hero. Footprints and
	# heights are UNCHANGED — the dressing is geometry beside the box, never
	# a new footprint (collision untouched, the ground record reads the same
	# tops).
	for b: Dictionary in AmesDataPack.buildings():
		var centroid: Array = b.get("centroid", [0.0, 0.0])
		var x := float(centroid[0])
		var z := float(centroid[1])
		var size: Array = b.get("bbox_m", [10.0, 10.0])
		var w := maxf(float(size[0]), 2.0)
		var d := maxf(float(size[1]), 2.0)
		var h := _massing_height(b)
		var district := _district_of(x, z, ctx)
		var color := _massing_color(district, str(b.get("id", "")))
		var tile := _chunk_of(x, z)
		var chunk: Dictionary = _chunk_at(tiles, tile)
		(chunk["massing"] as Array).append({
			"id": str(b.get("id", "")),
			"d": district,
			"a": str(b.get("class", "")) == "authored",
			"p": [_r(x), _r(h * 0.5), _r(z)],
			"s": [_r(w), _r(h), _r(d)],
			"c": [_rc(color.r), _rc(color.g), _rc(color.b)],
		})
		var hw := w * 0.5
		var hd := d * 0.5
		(chunk["occluders"] as Array).append([
			_r(x - hw), _r(z - hd), _r(x + hw), _r(z - hd),
			_r(x + hw), _r(z + hd), _r(x - hw), _r(z + hd),
		])
		# (T-206) the variant pass — skipped for the superseded hero slots.
		var bid := str(b.get("id", ""))
		if bid in HERO_BUILDING_IDS:
			continue
		var variant := _variant_of(district, h, w * d, bid)
		(chunk["massing"] as Array)[(chunk["massing"] as Array).size() - 1]["v"] = variant
		if variant == VARIANT_GABLE_LO or variant == VARIANT_GABLE_HI:
			_emit_roof_and_lot(chunk, bid, variant, x, z, w, d, h, color)
		elif variant == VARIANT_CORNICE:
			_emit_dress(chunk, bid, "cornice",
					Vector3(x, h + CORNICE_RISE - CORNICE_HEIGHT * 0.5, z),
					Vector3(w + CORNICE_OUTSET * 2.0, CORNICE_HEIGHT,
							d + CORNICE_OUTSET * 2.0), DRESS_CORNICE)
		elif variant == VARIANT_PARAPET:
			_emit_dress(chunk, bid, "parapet",
					Vector3(x, h + PARAPET_HEIGHT * 0.5, z),
					Vector3(w + PARAPET_OUTSET * 2.0, PARAPET_HEIGHT,
							d + PARAPET_OUTSET * 2.0), _dim(color, 0.9))
		elif variant == VARIANT_SCREEN:
			_emit_roof_screens(chunk, bid, x, z, w, d, h, bid.hash())
		elif variant == VARIANT_PENTHOUSE:
			_emit_dress(chunk, bid, "penthouse",
					Vector3(x, h + PENTHOUSE_H * 0.5, z),
					Vector3(minf(w * 0.4, PENTHOUSE_MAX), PENTHOUSE_H,
							minf(d * 0.4, PENTHOUSE_MAX)), _dim(color, 0.85))

	# --- placeholders (T-175): hero silhouettes + venue fixups ------------
	# Hero parts first (their `p`/`s` are true-dim masses in world
	# coordinates; each carries its `part` role so tests can union the
	# survey-pinned subsets), then one fixup box per placed venue whose
	# position no authored building's bbox covers — recomputed here from the
	# pack (the fixup set is a pure function of the pack, never a hand list).
	for b: Dictionary in AmesDataPack.buildings():
		var bid := str(b.get("id", ""))
		if not bid in HERO_BUILDING_IDS:
			continue
		for part: Dictionary in _hero_parts(bid, b):
			(_chunk_at(tiles, _chunk_of(float(part["p"][0]), float(part["p"][2])))
					["placeholders"] as Array).append(part)
	for poi: Dictionary in AmesDataPack.pois():
		if str(poi.get("kind", "")) != "venue" or not poi.get("placed", false):
			continue
		## (round 1) the pack's own exclusions: `in_core=false` venues (The
		## Cafe, Provisions Lot F, Szechuan House, Hickory Park) are boundary
		## decisions outside the map — a fixup there is a lone collision box
		## on empty plate that silently grows the world bounds everything
		## (the ground plate, the off-world guard) derives from; and a venue
		## the pack marks a PROP (`note` carries "prop" — the Superdog hot-dog
		## CART, Carlos Quesadilla's TRUCK) is street furniture, not a
		## storefront slot: box-ing it walls the street.
		if not poi.get("in_core", false):
			continue
		if str(poi.get("note", "")).contains("prop"):
			continue
		var vx := float(poi["position"][0])
		var vz := float(poi["position"][1])
		if _venue_covered(vx, vz):
			continue
		(_chunk_at(tiles, _chunk_of(vx, vz))["placeholders"] as Array).append({
			"id": str(poi.get("id", "")),
			"part": "fixup",
			"p": [_r(vx), _r(VENUE_FIXUP_SIZE.y * 0.5), _r(vz)],
			"s": [_r(VENUE_FIXUP_SIZE.x), _r(VENUE_FIXUP_SIZE.y), _r(VENUE_FIXUP_SIZE.z)],
			"c": [_rc(HERO_CONCRETE.r), _rc(HERO_CONCRETE.g), _rc(HERO_CONCRETE.b)],
		})
	# The non-building heroes: the bandshell arc at its POI position, the two
	# municipal bulbs and the SE elevator cluster at the recorded
	# approximations (see the const block — V-30, no sourced positions).
	var bandshell_pos := Vector2.ZERO
	for poi: Dictionary in AmesDataPack.pois():
		if str(poi.get("id", "")) == "downtown_bandshell" and poi.get("position") != null:
			bandshell_pos = Vector2(float(poi["position"][0]), float(poi["position"][1]))
	if bandshell_pos != Vector2.ZERO:
		for part: Dictionary in _bandshell_parts(bandshell_pos):
			(_chunk_at(tiles, _chunk_of(float(part["p"][0]), float(part["p"][2])))
					["placeholders"] as Array).append(part)
	for part: Dictionary in _water_tank_parts(CITY_TANK_NORTH_POS, "city_water_tank_north"):
		(_chunk_at(tiles, _chunk_of(CITY_TANK_NORTH_POS.x, CITY_TANK_NORTH_POS.y))
				["placeholders"] as Array).append(part)
	for part: Dictionary in _water_tank_parts(CITY_TANK_EAST_POS, "city_water_tank_east"):
		(_chunk_at(tiles, _chunk_of(CITY_TANK_EAST_POS.x, CITY_TANK_EAST_POS.y))
				["placeholders"] as Array).append(part)
	for part: Dictionary in _elevator_parts(ELEVATOR_CLUSTER_POS):
		(_chunk_at(tiles, _chunk_of(ELEVATOR_CLUSTER_POS.x, ELEVATOR_CLUSTER_POS.y))
				["placeholders"] as Array).append(part)

	# --- streets: centerlines extruded to asphalt ribbons -----------------
	# Arterials (T-174) additionally carry the center-dash lane marks: per
	# non-degenerate segment, dashes at fixed period from the segment start
	# (pure arithmetic on the same polyline the ribbon used).
	for s: Dictionary in AmesDataPack.streets():
		var width := maxf(float(s.get("width_m", 11.0)), 4.0)
		var arterial := _is_arterial(str(s.get("name", "")))
		var pts: Array = s.get("points", [])
		for i: int in range(pts.size() - 1):
			var a: Array = pts[i]
			var b2: Array = pts[i + 1]
			var a2 := Vector2(float(a[0]), float(a[1]))
			var b3 := Vector2(float(b2[0]), float(b2[1]))
			var quad := _extrude_quad(a2, b3, width, RIBBON_Y)
			if quad.is_empty():
				continue
			var mid := (a2 + b3) * 0.5
			(_chunk_at(tiles, _chunk_of(mid.x, mid.y))["ribbons"] as Array).append({"q": quad})
			if arterial:
				var seg := b3 - a2
				var dashes := int(floorf((seg.length() - MARK_DASH) / MARK_PERIOD)) + 1
				var dirn := seg / seg.length()
				for k: int in dashes:
					var m0 := a2 + dirn * (float(k) * MARK_PERIOD)
					var mark := _extrude_quad(m0, m0 + dirn * MARK_DASH, MARK_WIDTH, MARK_Y)
					if mark.is_empty():
						continue
					var mmid := (m0 + m0 + dirn * MARK_DASH) * 0.5
					(_chunk_at(tiles, _chunk_of(mmid.x, mmid.y))["lane_quads"] as Array).append({"q": mark})

	# --- water: Lake LaVerne polygon (triangulated) + creek ribbons -------
	# The lake's ring loops are collected first: College Creek FEEDS the
	# lake, and its centerline runs through the pack's lake polygon — a
	# creek segment whose midpoint lies inside the lake's ring union
	# (even-odd over the split loops: the basin or the Swan Island lawn)
	# paints NO ribbon, because the lake flat is that ground's surface
	# (T-174: the oval must read as one lake, not as a canal crossing it).
	var lake_rings: Array[PackedVector2Array] = []
	for lake: Dictionary in AmesDataPack.water():
		if str(lake.get("kind", "")) == "lake" and lake.has("polygon"):
			lake_rings.append_array(_split_rings(_pack_points(lake.get("polygon", []))))
	for wtr: Dictionary in AmesDataPack.water():
		if str(wtr.get("kind", "")) == "lake" and wtr.has("polygon"):
			var poly := _pack_points(wtr.get("polygon", []))
			# The quarry-banked lakes (T-205) ring their band in PALE GRAVEL
			# at lawn level (the park's lawn hole leaves the band over open
			# ground — see the QUARRY_SHORE_Y note); every other lake keeps
			# the T-174 mown band under the water edge. Per-entry color
			# override rides the flat-family render's `c` field.
			var quarry := str(wtr.get("bank", "")) == "quarry"
			var shore_y := QUARRY_SHORE_Y if quarry else SHORE_Y
			var shore_c: Array = []
			if quarry:
				shore_c = [_rc(COLOR_QUARRY_BANK.r), _rc(COLOR_QUARRY_BANK.g),
						_rc(COLOR_QUARRY_BANK.b)]
			for ring: PackedVector2Array in _split_rings(poly):
				# Shore band (T-174): mown-lawn ring extruded OUTWARD from
				# every ring edge. Baked BELOW the water top so an overlap
				# can never paint the lake — the water flat renders above.
				# (The quarry variant rides at lawn level instead.)
				var ccw := _signed_area(ring) >= 0.0
				for e: int in ring.size():
					var sa := ring[e]
					var sb := ring[(e + 1) % ring.size()]
					var ed := sb - sa
					if ed.length_squared() < 1e-10:
						continue
					var nrm := (Vector2(ed.y, -ed.x) if ccw else Vector2(-ed.y, ed.x)) \
							/ ed.length()
					var q0 := sa + nrm * SHORE_WIDTH
					var q1 := sb + nrm * SHORE_WIDTH
					var shore: Array = [
						_r(q0.x), _r(shore_y), _r(q0.y),
						_r(q1.x), _r(shore_y), _r(q1.y),
						_r(sb.x), _r(shore_y), _r(sb.y),
						_r(sa.x), _r(shore_y), _r(sa.y),
					]
					var smid := (sa + sb) * 0.5
					var entry: Dictionary = {"q": shore}
					if not shore_c.is_empty():
						entry["c"] = shore_c
					(_chunk_at(tiles, _chunk_of(smid.x, smid.y))["shore_quads"] as Array).append(entry)
				for tri: Vector3i in _triangulate(ring):
					var v: Array = [
						_r(ring[tri.x].x), _r(WATER_Y), _r(ring[tri.x].y),
						_r(ring[tri.y].x), _r(WATER_Y), _r(ring[tri.y].y),
						_r(ring[tri.z].x), _r(WATER_Y), _r(ring[tri.z].y),
					]
					var tri_centroid := (ring[tri.x] + ring[tri.y] + ring[tri.z]) / 3.0
					(_chunk_at(tiles, _chunk_of(tri_centroid.x, tri_centroid.y))["water_tris"] as Array).append({"v": v})
		elif str(wtr.get("kind", "")) == "creek":
			var cw := float(wtr.get("width_m", CREEK_WIDTH))
			for line: Array in wtr.get("centerlines", []):
				for i: int in range(line.size() - 1):
					var a: Array = line[i]
					var b3: Array = line[i + 1]
					var quad := _extrude_quad(Vector2(float(a[0]), float(a[1])),
							Vector2(float(b3[0]), float(b3[1])), cw, CREEK_Y)
					if quad.is_empty():
						continue
					var mid := (Vector2(float(a[0]), float(a[1])) + Vector2(float(b3[0]), float(b3[1]))) * 0.5
					if _mid_in_lake(mid, lake_rings):
						continue
					(_chunk_at(tiles, _chunk_of(mid.x, mid.y))["creek_quads"] as Array).append({"q": quad})

	# --- parks: lawn polygon flats ----------------------------------------
	# (T-205) A park entry may carry `holes` (a park-lake's stored ring): the
	# ear clip triangulates the full ring — a simple polygon, no slits — and
	# every park triangle is then CUT against the hole ring's boundary edges
	# (BSP split, both sides kept) with the in-hole remainder dropped. The
	# lawn flat therefore ends at the water's edge: the lake's own water
	# flat (y 0.02) renders UNDER the lawn (y 0.04), so without the cut the
	# lake read as mown lawn.
	for park: Dictionary in AmesDataPack.parks():
		var poly := _pack_points(park.get("polygon", []))
		var holes: Array = park.get("holes", [])
		var hole_rings: Array[PackedVector2Array] = []
		for hole: Array in holes:
			hole_rings.append_array(_split_rings(_pack_points(hole)))
		for ring: PackedVector2Array in _split_rings(poly):
			for tri: Vector3i in _triangulate(ring):
				var tri_poly := PackedVector2Array()
				tri_poly.append(ring[tri.x])
				tri_poly.append(ring[tri.y])
				tri_poly.append(ring[tri.z])
				var pieces: Array[PackedVector2Array] = [tri_poly]
				for hole_ring: PackedVector2Array in hole_rings:
					pieces = _tri_minus_ring(pieces, hole_ring)
				for piece: PackedVector2Array in pieces:
					for pi: int in piece.size() - 2:
						var pa := piece[0]
						var pb := piece[pi + 1]
						var pc := piece[pi + 2]
						var pc_centroid := (pa + pb + pc) / 3.0
						var v: Array = [
							_r(pa.x), _r(LAWN_Y), _r(pa.y),
							_r(pb.x), _r(LAWN_Y), _r(pb.y),
							_r(pc.x), _r(LAWN_Y), _r(pc.y),
						]
						(_chunk_at(tiles, _chunk_of(pc_centroid.x, pc_centroid.y))["lawn_tris"] as Array).append({"v": v})

	# --- trails: the north parks' mapped runs (T-205) ----------------------
	# Gravel stripes extruded along every pack trail run, ribbon-style. The
	# stack sits the stripe top (TRAIL_Y + half thickness = 0.07) above the
	# lawn flats (0.04) and the creek tops (0.06), under the road ribbons
	# (0.09) — a trail crossing a creek reads as the ford/bridge deck it is.
	for trail: Dictionary in AmesDataPack.trails():
		var width := float(TRAIL_WIDTH_BY_KIND.get(str(trail.get("kind", "")), 2.0))
		var pts: Array = trail.get("points", [])
		for i: int in range(pts.size() - 1):
			var a: Array = pts[i]
			var b3: Array = pts[i + 1]
			var quad := _extrude_quad(Vector2(float(a[0]), float(a[1])),
					Vector2(float(b3[0]), float(b3[1])), width, TRAIL_Y)
			if quad.is_empty():
				continue
			var mid := (Vector2(float(a[0]), float(a[1]))
					+ Vector2(float(b3[0]), float(b3[1]))) * 0.5
			(_chunk_at(tiles, _chunk_of(mid.x, mid.y))["trail_quads"] as Array).append({"q": quad})

	# --- trees: the mapped canopy points (T-207) ---------------------------
	# The pack's tree layer becomes ONE instance per mapped node, at the
	# mapped xz (±0 m — the snapped position IS the node), standing on the
	# plate top (the lawn flats top at 0.04 — a trunk base at 0 sits 4 cm
	# into the lawn, invisible). The archetype law: LaVerne shore ring →
	# shore, park polygon → oak (grove tint), campus district → oak, else
	# boulevard — the mapped data decides where, the archetype decides what.
	# Scale/yaw/tint are the stable index hash — the pack carries no ids.
	var lake_rings_shore: Array[PackedVector2Array] = []
	for wtr2: Dictionary in AmesDataPack.water():
		if str(wtr2.get("kind", "")) == "lake" and wtr2.has("polygon") \
				and str(wtr2.get("name", "")).contains(TREE_SHORE_NAME_TOKEN):
			lake_rings_shore.append_array(
					_split_rings(_pack_points(wtr2.get("polygon", []))))
	var park_rings: Array[PackedVector2Array] = []
	for park2: Dictionary in AmesDataPack.parks():
		park_rings.append_array(_split_rings(_pack_points(park2.get("polygon", []))))
	var tree_points := AmesDataPack.trees()
	for ti in tree_points.size():
		var tp := tree_points[ti]
		var tx := tp.x
		var tz := tp.y
		var roll := hash("tree/%d" % ti)
		var archetype := TREE_BOULEVARD
		var grove := false
		if _rings_min_dist(Vector2(tx, tz), lake_rings_shore) <= TREE_SHORE_DIST:
			archetype = TREE_SHORE
		elif _point_in_rings(Vector2(tx, tz), park_rings):
			archetype = TREE_OAK
			grove = true
		elif _district_of(tx, tz, ctx) == "campus":
			archetype = TREE_OAK
		# Per-axis scale band: three independent hash bands spread young to
		# mature (height decorrelated from spread).
		var sx := _tree_scale(roll, 0)
		var sy := _tree_scale(roll, 1)
		var sz := _tree_scale(roll, 2)
		var tint := _tree_tint(grove, roll)
		var yaw := _frac01(roll, 3) * TAU
		(_chunk_at(tiles, _chunk_of(tx, tz))["trees"] as Array).append({
			"t": archetype,
			"p": [_r(tx), 0.0, _r(tz)],
			"s": [_r(sx), _r(sy), _r(sz)],
			"a": _r(yaw),
			"c": [_rc(tint.r), _rc(tint.g), _rc(tint.b)],
		})

	# --- rail: ballast strip, gapped geometrically at crossing roads ------
	# The blocker set is the ACTUAL road geometry near the 9 at-grade
	# crossings: every street polyline segment within CROSSING_ROAD_RADIUS of
	# a crossing pos, extruded at its OWN baked width (so divided roads gap
	# on both carriageways, and the gap clears the full asphalt span, not a
	# radius around one point). A rail sub-segment is skipped whole when its
	# quad would come within GAP_MARGIN of any blocker quad.
	var crossings: Array[Dictionary] = []
	for c: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(c.get("grade", "")) == "at_grade":
			var pos: Array = c.get("pos", [0.0, 0.0])
			crossings.append({
				"pos": Vector2(float(pos[0]), float(pos[1])),
				"road": str(c.get("road_name", "")),
				"cls": str(c.get("road_class", "")),
			})
	var gap_blockers: Array = [] ## Flat ribbon quads of crossing-road segments.
	for s: Dictionary in AmesDataPack.streets():
		var pts: Array = s.get("points", [])
		var width := maxf(float(s.get("width_m",
				ROAD_WIDTH_BY_CLASS.get(str(s.get("class", "")), 11.0))), 4.0)
		for i: int in range(pts.size() - 1):
			var pa := Vector2(float(pts[i][0]), float(pts[i][1]))
			var pb := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var mid := (pa + pb) * 0.5
			for c: Dictionary in crossings:
				if mid.distance_to(c["pos"]) < CROSSING_ROAD_RADIUS:
					var quad := _extrude_quad(pa, pb, width, RIBBON_Y)
					if not quad.is_empty():
						gap_blockers.append(quad)
					break
	for line: Array in AmesDataPack.rail().get("centerlines", []):
		for i: int in range(line.size() - 1):
			var a := Vector2(float(line[i][0]), float(line[i][1]))
			var b4 := Vector2(float(line[i + 1][0]), float(line[i + 1][1]))
			var steps := maxi(1, ceili(a.distance_to(b4) / RAIL_STEP))
			for k: int in steps:
				var sa := a.lerp(b4, float(k) / float(steps))
				var sb := a.lerp(b4, float(k + 1) / float(steps))
				var mid := (sa + sb) * 0.5
				var quad := _extrude_quad(sa, sb, BALLAST_WIDTH, BALLAST_Y)
				if quad.is_empty():
					continue
				var blocked := false
				for blocker: Array in gap_blockers:
					if _quads_overlap(quad, blocker, GAP_MARGIN):
						blocked = true
						break
				if blocked:
					continue
				(_chunk_at(tiles, _chunk_of(mid.x, mid.y))["ballast_quads"] as Array).append({"q": quad})
				# The tie hint (T-174) rides the same unblocked stretch — the
				# double main reads as two dark track lines on the ballast,
				# and the crossing gaps stay honest for the stripe too.
				var tie := _extrude_quad(sa, sb, TIE_WIDTH, TIE_Y)
				if not tie.is_empty():
					(_chunk_at(tiles, _chunk_of(mid.x, mid.y))["tie_quads"] as Array).append({"q": tie})

	# --- at-grade crossings are world facts per chunk ---------------------
	for c: Dictionary in crossings:
		var tile := _chunk_of(c["pos"].x, c["pos"].y)
		(_chunk_at(tiles, tile)["crossings"] as Array).append({
			"pos": [_r(c["pos"].x), _r(c["pos"].y)],
			"road": c["road"],
			"class": c["cls"],
		})

	# --- district ground cells (T-174 dressing v0) -------------------------
	# A 32 m grid over the WHOLE pack tile range, tinted only where the v0
	# district rule says a district OTHER than the residential seed stands —
	# the ground plate wears the residential color, so the uncovered cells
	# ARE the plate and the map never shows a hole. Runs last so the tile
	# range covers every content tile (crossings included). A tile with no
	# tinted cells gains no chunk file at all.
	var lo_t := Vector2i(2147483647, 2147483647)
	var hi_t := Vector2i(-2147483647, -2147483647)
	for tile: Vector2i in tiles:
		lo_t = Vector2i(mini(lo_t.x, tile.x), mini(lo_t.y, tile.y))
		hi_t = Vector2i(maxi(hi_t.x, tile.x), maxi(hi_t.y, tile.y))
	var cells_per_side := int(CHUNK_SIZE / GROUND_CELL)
	var ground_ctx: Dictionary = ctx
	for tx: int in range(lo_t.x, hi_t.x + 1):
		for tz: int in range(lo_t.y, hi_t.y + 1):
			var cells: Array = []
			for iz: int in cells_per_side:
				for ix: int in cells_per_side:
					var ccx := (float(tx) * CHUNK_SIZE) + (float(ix) + 0.5) * GROUND_CELL
					var ccz := (float(tz) * CHUNK_SIZE) + (float(iz) + 0.5) * GROUND_CELL
					var district := _district_of(ccx, ccz, ground_ctx)
					if district == "residential":
						continue
					var col: Color = DISTRICT_GROUND.get(district,
							DISTRICT_GROUND["residential"])
					cells.append({
						"q": [
							_r(ccx - GROUND_CELL * 0.5), _r(GROUND_Y), _r(ccz - GROUND_CELL * 0.5),
							_r(ccx + GROUND_CELL * 0.5), _r(GROUND_Y), _r(ccz - GROUND_CELL * 0.5),
							_r(ccx + GROUND_CELL * 0.5), _r(GROUND_Y), _r(ccz + GROUND_CELL * 0.5),
							_r(ccx - GROUND_CELL * 0.5), _r(GROUND_Y), _r(ccz + GROUND_CELL * 0.5),
						],
						"c": [_rc(col.r), _rc(col.g), _rc(col.b)],
					})
			if cells.is_empty():
				continue
			var tile2 := Vector2i(tx, tz)
			var chunk: Dictionary = _chunk_at(tiles, tile2)
			(chunk["ground_quads"] as Array).append_array(cells)

	# --- finalize chunks: aabb, counts, colors, serialize, hash, write ----
	var array_colors := {
		"ribbons": [_rc(COLOR_ASPHALT.r), _rc(COLOR_ASPHALT.g), _rc(COLOR_ASPHALT.b)],
		"lane_quads": [_rc(COLOR_LANE_MARK.r), _rc(COLOR_LANE_MARK.g), _rc(COLOR_LANE_MARK.b)],
		"water_tris": [_rc(COLOR_WATER.r), _rc(COLOR_WATER.g), _rc(COLOR_WATER.b)],
		"shore_quads": [_rc(COLOR_SHORE.r), _rc(COLOR_SHORE.g), _rc(COLOR_SHORE.b)],
		"creek_quads": [_rc(COLOR_CREEK.r), _rc(COLOR_CREEK.g), _rc(COLOR_CREEK.b)],
		"lawn_tris": [_rc(COLOR_LAWN.r), _rc(COLOR_LAWN.g), _rc(COLOR_LAWN.b)],
		"ballast_quads": [_rc(COLOR_BALLAST.r), _rc(COLOR_BALLAST.g), _rc(COLOR_BALLAST.b)],
		"tie_quads": [_rc(COLOR_TIE.r), _rc(COLOR_TIE.g), _rc(COLOR_TIE.b)],
		"trail_quads": [_rc(COLOR_TRAIL.r), _rc(COLOR_TRAIL.g), _rc(COLOR_TRAIL.b)],
		## (T-206) roofs + dress entries all carry per-entry colors (`c`) —
		## these two are only the renderer's never-fired fallbacks.
		"roofs": [_rc(ROOF_SHINGLES[0].r), _rc(ROOF_SHINGLES[0].g),
				_rc(ROOF_SHINGLES[0].b)],
		"dress": [_rc(DRESS_SCREEN.r), _rc(DRESS_SCREEN.g), _rc(DRESS_SCREEN.b)],
		## ground_quads entries carry per-cell colors (`c`) — the family entry
		## is only the renderer's never-fired fallback (residential seed).
		## shore_quads entries carry `c` too, for the quarry-banked lakes
		## (T-205) whose band overrides the mown family color per entry.
		"ground_quads": [_rc(DISTRICT_GROUND["residential"].r),
				_rc(DISTRICT_GROUND["residential"].g), _rc(DISTRICT_GROUND["residential"].b)],
	}
	var manifest: Dictionary = {
		"schema": SCHEMA,
		"pack": str(pack.get("meta", {}).get("pack", "")),
		"pack_version": int(pack.get("meta", {}).get("version", 0)),
		"pack_schema": str(pack.get("meta", {}).get("schema", "")),
		"attribution": AmesDataPack.ATTRIBUTION,
		"chunk_size": CHUNK_SIZE,
		"bake_tool": "res://tools/bake_ames_chunks.gd",
		"bake_core": "res://scripts/ames_baker.gd",
		"chunks": [],
		"totals": {},
	}
	var tiles_sorted: Array = tiles.keys()
	tiles_sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	var totals: Dictionary = {"chunks": tiles_sorted.size(), "bytes": 0}
	for key: String in FAMILY_KEYS:
		totals[key] = 0
	var district_totals: Dictionary = {}
	for tile: Vector2i in tiles_sorted:
		var chunk: Dictionary = tiles[tile]
		var file := "chunk_%d_%d.json" % [tile.x, tile.y]
		var aabb := _chunk_aabb(chunk)
		var counts := _chunk_counts(chunk)
		var doc: Dictionary = {
			"schema": SCHEMA,
			"chunk": [tile.x, tile.y],
			"tile": {"min": [tile.x * CHUNK_SIZE, tile.y * CHUNK_SIZE],
				"max": [(tile.x + 1) * CHUNK_SIZE, (tile.y + 1) * CHUNK_SIZE]},
			"aabb": aabb,
			"counts": counts,
			"colors": array_colors,
		}
		for key: String in FAMILY_KEYS:
			doc[key] = chunk[key]
		var text := JSON.stringify(doc, "\t")
		var bytes := text.to_utf8_buffer()
		var sha := _sha256(bytes)
		var fa := FileAccess.open(out_dir.path_join(file), FileAccess.WRITE)
		if fa == null:
			push_error("AmesBaker: cannot write %s" % out_dir.path_join(file))
			return {}
		fa.store_string(text)
		fa.close()
		for key: String in FAMILY_KEYS:
			totals[key] += counts[key]
		totals["bytes"] += bytes.size()
		for m: Dictionary in chunk["massing"]:
			var dname := str(m["d"])
			district_totals[dname] = int(district_totals.get(dname, 0)) + 1
		(manifest["chunks"] as Array).append({
			"file": file, "cx": tile.x, "cz": tile.y,
			"sha256": sha, "bytes": bytes.size(),
			"aabb": aabb, "counts": counts,
			"crossings": chunk["crossings"],
		})
	totals["districts"] = district_totals
	manifest["totals"] = totals
	## (T-175) the hero building ids whose bbox massing the placeholder
	## silhouettes supersede — the renderer reads this list and hides those
	## boxes (visual, occluder, ground record and slot collider alike); the
	## silhouettes replace them wholly.
	var heroes: Array[String] = HERO_BUILDING_IDS.duplicate()
	heroes.sort()
	manifest["heroes"] = heroes
	var digest_lines := PackedStringArray()
	for entry: Dictionary in manifest["chunks"]:
		digest_lines.append("%s %s" % [entry["file"], entry["sha256"]])
	digest_lines.sort()
	manifest["total_sha256"] = _sha256("\n".join(digest_lines).to_utf8_buffer())

	var mfa := FileAccess.open(out_dir.path_join("manifest.json"), FileAccess.WRITE)
	if mfa == null:
		push_error("AmesBaker: cannot write manifest.json")
		return {}
	mfa.store_string(JSON.stringify(manifest, "\t"))
	mfa.close()
	return manifest


## Convenience read for the renderer/tests: parses `manifest.json` inside
## `dir`. Returns `{}` when absent — no bake yet.
static func read_manifest(dir: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(dir.path_join("manifest.json"))
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Reads one chunk file (`chunk_<cx>_<cz>.json`) from `dir`.
static func read_chunk(dir: String, file: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(dir.path_join(file))
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## The chunk tile holding a world xz point: floor division by CHUNK_SIZE
## (floor, NOT int-truncation — negative tiles must round down).
static func _chunk_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CHUNK_SIZE), floori(z / CHUNK_SIZE))


static func _chunk_at(tiles: Dictionary, tile: Vector2i) -> Dictionary:
	if not tiles.has(tile):
		var fresh := {}
		for key: String in FAMILY_KEYS:
			fresh[key] = []
		tiles[tile] = fresh
	return tiles[tile]


## Census §7.4 level ladder (see LEVEL_LADDER) + the §3.10 heights cap.
static func _massing_height(b: Dictionary) -> float:
	var h: Variant = b.get("height_m")
	if h != null:
		return clampf(float(h), 2.5, MASSING_MAX_HEIGHT)
	var lv: Variant = b.get("levels")
	if lv != null:
		return _level_height(int(roundf(clampf(float(lv), 1.0, 11.0))))
	var size: Array = b.get("bbox_m", [10.0, 10.0])
	var area := float(size[0]) * float(size[1])
	if area < FOOTPRINT_LV_BANDS[0]:
		return _level_height(2)
	if area < FOOTPRINT_LV_BANDS[1]:
		return _level_height(3)
	return _level_height(4)


static func _level_height(levels: int) -> float:
	if levels <= LEVEL_LADDER.size():
		return LEVEL_LADDER[levels - 1]
	return LEVEL_LADDER[LEVEL_LADDER.size() - 1] + 3.0 * float(levels - LEVEL_LADDER.size())


## The v0 district rule (priority order: campustown, downtown, campus,
## lincolnway, residential — see the constant block). Distances are to
## nearest stored polyline point of the named street families.
static func _district_of(x: float, z: float, ctx: Dictionary) -> String:
	if x >= CAMPUSTOWN_X_BAND.x and x <= CAMPUSTOWN_X_BAND.y \
			and z >= CAMPUSTOWN_Z_BAND.x and z <= CAMPUSTOWN_Z_BAND.y \
			and _min_dist(x, z, ctx["lw_pts"]) < DISTRICT_DIST_LW_BAND:
		return "campustown"
	if x >= DOWNTOWN_X_BAND.x and x <= DOWNTOWN_X_BAND.y \
			and _min_dist(x, z, ctx["main_pts"]) < DISTRICT_DIST_SPINE:
		return "downtown"
	if _min_dist(x, z, ctx["campus_anchors"]) < DISTRICT_DIST_CAMPUS \
			or _min_dist(x, z, ctx["campus_street_pts"]) < DISTRICT_DIST_CAMPUS_STREET:
		return "campus"
	if _min_dist(x, z, ctx["lw_pts"]) < DISTRICT_DIST_LW \
			or _min_dist(x, z, ctx["duff_pts"]) < DISTRICT_DIST_SPINE:
		return "lincolnway"
	return "residential"


## Stable per-building palette pick: the id's hash chooses within the
## district palette — pure function of the pack, no RNG.
static func _massing_color(district: String, id: String) -> Color:
	var palette: Array = DISTRICT_PALETTES.get(district, DISTRICT_PALETTES["residential"])
	return palette[id.hash() % palette.size()]


## --- T-206 filler-dressing builders (pure pack/const arithmetic) -----------


## The district-variant law (see the constants block for the §3 citations).
## `roll` spreads the hash bits so pitch, porch and chimney picks decorrelate:
## pitch takes bit 0, the lot bucket the next band, the porch side another.
## Every pick is a pure function of the pack id — no RNG (determinism).
static func _variant_of(district: String, h: float, area: float, id: String) -> String:
	var roll := id.hash()
	match district:
		"residential":
			if h <= GABLE_MAX_HEIGHT:
				return VARIANT_GABLE_HI if roll % 2 == 0 else VARIANT_GABLE_LO
			return VARIANT_PARAPET ## The 4+ level slabs: flat + parapet (§3.3 read).
		"downtown":
			return VARIANT_CORNICE ## §3.2: the continuous cornice band.
		"campus":
			if area >= SCREEN_MIN_AREA:
				return VARIANT_SCREEN ## §3.7: flat + mechanical screens.
			return VARIANT_PARAPET if roll % 3 == 0 else VARIANT_FLAT
		"campustown":
			var bucket := (roll / 2) % 5 ## 2/5 parapet, 2/5 flat, 1/5 penthouse.
			if bucket < 2:
				return VARIANT_PARAPET
			if bucket < 4:
				return VARIANT_FLAT
			return VARIANT_PENTHOUSE
		_:
			return VARIANT_PARAPET if roll % 2 == 0 else VARIANT_FLAT ## §3.4/3.5 strip.


## A color stepped toward dark (the parapet/penthouse read: the building's
## own hue, one shade down — stays deterministic and palette-true).
static func _dim(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


## One `dress` box (porch deck/canopy, cornice, parapet, screen, penthouse):
## the placeholders entry shape minus collision — visual-only dressing.
static func _emit_dress(chunk: Dictionary, id: String, role: String,
		center: Vector3, size: Vector3, color: Color) -> void:
	(chunk["dress"] as Array).append({
		"id": id,
		"role": role,
		"p": [_r(center.x), _r(center.y), _r(center.z)],
		"s": [_r(size.x), _r(size.y), _r(size.z)],
		"c": [_rc(color.r), _rc(color.g), _rc(color.b)],
	})


## The gabled house's full variant payload (§3.6): the roof prism (a closed
## 5-face solid the renderer scales per instance), plus the hash-picked lot
## hints — porch deck + canopy and/or chimney. The prism rides ridge-ALONG
## the longer footprint axis (`a` = "x"|"z"), its eaves overhanging the wall
## line by GABLE_OVERHANG; the ridge height is pitch × half the wall span
## (the overhang stays level — eaves at the box top). The shingle color is
## the id hash into ROOF_SHINGLES; hint picks reuse decorrelated hash bands.
static func _emit_roof_and_lot(chunk: Dictionary, id: String, variant: String,
		x: float, z: float, w: float, d: float, h: float, wall: Color) -> void:
	var roll := id.hash()
	var ridge_x := w >= d
	var ridge_len := (w if ridge_x else d) + GABLE_OVERHANG * 2.0
	var span := (d if ridge_x else w) + GABLE_OVERHANG * 2.0
	var ridge_h := (GABLE_PITCH_HI if variant == VARIANT_GABLE_HI else GABLE_PITCH_LO) \
			* span * 0.5
	var shingle: Color = ROOF_SHINGLES[(roll / 4) % ROOF_SHINGLES.size()]
	(chunk["roofs"] as Array).append({
		"id": id,
		"a": "x" if ridge_x else "z",
		"p": [_r(x), _r(h), _r(z)],
		"s": [_r(ridge_len), _r(span), _r(ridge_h)],
		"c": [_rc(shingle.r), _rc(shingle.g), _rc(shingle.b)],
	})
	# Lot hints (house-scale only — the PORCH_HOUSE_MAX_DIM gate).
	var max_dim := maxf(w, d)
	if max_dim > PORCH_HOUSE_MAX_DIM:
		return
	var bucket := (roll / 2) % 10 ## 0-3 porch, 4-6 chimney, 7-8 both, 9 plain.
	var porch := bucket < 4 or (bucket >= 7 and bucket <= 8)
	var chimney := (bucket >= 4 and bucket <= 6) or (bucket >= 7 and bucket <= 8)
	if chimney:
		var along := (0.5 - CHIMNEY_RIDGE_FRAC) * (w if ridge_x else d)
		if (roll / 32) % 2 == 1:
			along = -along
		var cx := x + (along if ridge_x else 0.0)
		var cz := z + (0.0 if ridge_x else along)
		_emit_dress(chunk, id, "chimney",
				Vector3(cx, h + (ridge_h + CHIMNEY_RISE) * 0.5, cz),
				Vector3(CHIMNEY_SIDE, ridge_h + CHIMNEY_RISE, CHIMNEY_SIDE),
				DRESS_BRICK)
	if porch:
		var along_facade := w if ridge_x else d ## The ridge runs the facade.
		var across := d if ridge_x else w
		var side := 1.0 if (roll / 64) % 2 == 0 else -1.0
		var px := x + (0.0 if ridge_x else side * (across * 0.5 + PORCH_DEPTH * 0.5))
		var pz := z + (side * (across * 0.5 + PORCH_DEPTH * 0.5) if ridge_x else 0.0)
		var pw := (along_facade * PORCH_SPAN_FRAC) if ridge_x else PORCH_DEPTH
		var pd := PORCH_DEPTH if ridge_x else (along_facade * PORCH_SPAN_FRAC)
		_emit_dress(chunk, id, "porch_deck", Vector3(px, PORCH_DECK_T * 0.5, pz),
				Vector3(pw, PORCH_DECK_T, pd), _dim(wall, 0.85))
		_emit_dress(chunk, id, "porch_canopy",
				Vector3(px, PORCH_CANOPY_TOP - PORCH_CANOPY_T * 0.5, pz),
				Vector3(pw, PORCH_CANOPY_T, pd), DRESS_TRIM)


## The §3.7 campus mechanical screens: two rooftop boxes on the big blocks,
## placed by footprint fraction and hash-mirrored (a stable skyline read).
static func _emit_roof_screens(chunk: Dictionary, id: String, x: float, z: float,
		w: float, d: float, h: float, roll: int) -> void:
	var sx := -1.0 if roll % 2 == 0 else 1.0
	var sz := -1.0 if (roll / 2) % 2 == 0 else 1.0
	_emit_dress(chunk, id, "screen",
			Vector3(x + sx * w * 0.22, h + SCREEN_H * 0.5, z + sz * d * 0.18),
			Vector3(w * 0.3, SCREEN_H, d * 0.3), DRESS_SCREEN)
	_emit_dress(chunk, id, "screen",
			Vector3(x - sx * w * 0.18, h + SCREEN_H * 0.5, z - sz * d * 0.22),
			Vector3(w * 0.2, SCREEN_H, d * 0.25), DRESS_SCREEN)


## --- T-175 placeholder builders (pure pack/const arithmetic) ---------------


## TRUE when an authored building's bbox massing covers the point — the
## venue-fixup rule: a placed venue POI whose address anchor OSM never
## polygonized gets its own fixup slot; one riding an authored building
## uses that building's slot and gets nothing.
static func _venue_covered(vx: float, vz: float) -> bool:
	for b: Dictionary in AmesDataPack.buildings():
		if str(b.get("class", "")) != "authored":
			continue
		var c: Array = b.get("centroid", [0.0, 0.0])
		var s: Array = b.get("bbox_m", [0.0, 0.0])
		if absf(vx - float(c[0])) <= float(s[0]) * 0.5 \
				and absf(vz - float(c[1])) <= float(s[1]) * 0.5:
			return true
	return false


## One placeholder box entry (the massing entry's shape: id, role, center,
## size, snapped color).
static func _part(id: String, part: String, center: Vector3, size: Vector3,
		color: Color) -> Dictionary:
	return {
		"id": id,
		"part": part,
		"p": [_r(center.x), _r(center.y), _r(center.z)],
		"s": [_r(size.x), _r(size.y), _r(size.z)],
		"c": [_rc(color.r), _rc(color.g), _rc(color.b)],
	}


## The hero silhouettes: per-building part lists at the survey's settled
## dims (see the const block for the citations). `b` is the pack building
## (centroid/bbox anchor the stacks; the settled heights are literals, not
## the OSM tags — census §3 records several bogus `height` defaults).
static func _hero_parts(id: String, b: Dictionary) -> Array:
	var centroid: Array = b.get("centroid", [0.0, 0.0])
	var cx := float(centroid[0])
	var cz := float(centroid[1])
	var parts: Array = []
	match id:
		"way/183041212": ## Campanile — 33.5 m slender stack (§1.1).
			var plinth := Vector3(6.8, 2.0, 6.7) ## The OSM bbox includes the plinth.
			var shaft := Vector3(4.9, 24.4, 4.9) ## "keep the shaft ~5 m".
			var head := Vector3(6.0, 4.5, 5.9) ## The belfry.
			var cap := Vector3(5.0, 2.6, 4.9) ## The pyramidal cap's mass — its top is the LANDABLE pad.
			var y := 0.0
			parts.append(_part(id, "plinth", Vector3(cx, y + plinth.y * 0.5, cz), plinth, HERO_LIMESTONE))
			y += plinth.y
			parts.append(_part(id, "shaft", Vector3(cx, y + shaft.y * 0.5, cz), shaft, HERO_LIMESTONE))
			y += shaft.y
			parts.append(_part(id, "head", Vector3(cx, y + head.y * 0.5, cz), head, HERO_LIMESTONE))
			y += head.y
			parts.append(_part(id, "cap", Vector3(cx, y + cap.y * 0.5, cz), cap, HERO_SLATE))
			y += cap.y ## 33.5 exactly.
			if absf(y - 33.5) > 0.001:
				push_error("AmesBaker: campanile stack %f != settled 33.5" % y)
		"way/861201396": ## Marston — 51.2 m tank on lattice legs (§1.4).
			var leg := Vector3(0.9, 36.0, 0.9)
			for sx: float in [-2.4, 2.4]:
				for sz: float in [-2.4, 2.4]:
					parts.append(_part(id, "legs",
							Vector3(cx + sx, leg.y * 0.5, cz + sz), leg, HERO_STEEL))
			parts.append(_part(id, "tank", Vector3(cx, 36.0 + 6.1, cz),
					Vector3(7.3, 12.2, 7.3), HERO_TANK)) ## 12.2 m tall × 7.3 dia.
			parts.append(_part(id, "cap", Vector3(cx, 48.2 + 1.5, cz),
					Vector3(5.2, 3.0, 5.2), HERO_STEEL)) ## Conical cap's mass — top 51.2.
		"way/613735866": ## Jack Trice — bowl ellipse 183 × 208, N–S (V-09).
			parts.append_array(_ring_parts(id, "bowl",
					Vector2(cx, cz), 91.5, 104.0, BOWL_SEGMENTS, 20.0, 14.0, HERO_CONCRETE))
			parts.append(_part(id, "pitch", Vector3(cx, 0.3, cz),
					Vector3(53.0, 0.6, 113.0), HERO_GRASS)) ## MidAmerican Field, N–S.
			## The north grass-berm wedge (V-11: GA berms in the NE/NW corners).
			parts.append(_part(id, "berm", Vector3(cx - 42.0, 4.0, cz - 113.0),
					Vector3(60.0, 8.0, 24.0), HERO_GRASS))
			parts.append(_part(id, "berm", Vector3(cx + 42.0, 4.0, cz - 113.0),
					Vector3(60.0, 8.0, 24.0), HERO_GRASS))
		"way/180651868": ## Hilton — 12-sided drum 138 × 105 (§1.3).
			parts.append_array(_ring_parts(id, "drum",
					Vector2(cx, cz), 69.0, 52.5, DRUM_SEGMENTS, 12.0, 20.0, HERO_CONCRETE))
			parts.append(_part(id, "roof", Vector3(cx, 21.5, cz),
					Vector3(118.0, 3.0, 90.0), HERO_CONCRETE)) ## Shallow arc roof's mass.
		"way/33725619": ## Beardshear — block + oxidized-copper dome hint (§1.4).
			var size: Array = b.get("bbox_m", [41.0, 66.0])
			var block := Vector3(float(size[0]), 14.0, float(size[1]))
			parts.append(_part(id, "block", Vector3(cx, 7.0, cz), block, HERO_LIMESTONE))
			parts.append(_part(id, "dome", Vector3(cx + 12.0, 16.0, cz),
					Vector3(9.0, 4.0, 9.0), HERO_COPPER)) ## Drum over the east entrance.
			parts.append(_part(id, "dome_cap", Vector3(cx + 12.0, 19.0, cz),
					Vector3(6.0, 2.0, 6.0), HERO_COPPER))
		"way/183224150": ## Memorial Union — block + squat corner tower (§1.2).
			var size: Array = b.get("bbox_m", [110.0, 110.0])
			var block := Vector3(float(size[0]), 20.0, float(size[1]))
			parts.append(_part(id, "block", Vector3(cx, 10.0, cz), block, HERO_LIMESTONE))
			## The SW corner tower (Lincoln Way × Morrill Rd/Lynn — V-08), squat
			## per §1.2's photos; the tower height is UNKNOWN-model-to-look (V-30).
			var corner_x := cx - block.x * 0.5 + 5.0
			var corner_z := cz + block.z * 0.5 - 5.0
			parts.append(_part(id, "tower", Vector3(corner_x, 13.0, corner_z),
					Vector3(10.0, 26.0, 10.0), HERO_LIMESTONE))
			parts.append(_part(id, "tower_cap", Vector3(corner_x, 27.5, corner_z),
					Vector3(8.0, 3.0, 8.0), HERO_SLATE))
		"way/33725897": ## Parks Library — block + addition roofline step (§1.4).
			var size: Array = b.get("bbox_m", [95.0, 123.0])
			var block := Vector3(float(size[0]), 24.0, float(size[1]))
			parts.append(_part(id, "block", Vector3(cx, 12.0, cz), block, HERO_LIMESTONE))
			parts.append(_part(id, "addition", Vector3(cx, 28.0, cz - block.z * 0.25),
					Vector3(block.x * 0.5, 8.0, block.z * 0.4),
					Color(0.65, 0.66, 0.68))) ## The 1960s–80s pavilion's dark concrete.
		"way/260524827": ## The 1906 depot — long low brick mass, tile hip, canopy (§1.8).
			var size: Array = b.get("bbox_m", [92.0, 20.0])
			var block := Vector3(float(size[0]), 7.0, float(size[1]))
			parts.append(_part(id, "wall", Vector3(cx, 3.5, cz), block, HERO_BRICK))
			parts.append(_part(id, "roof", Vector3(cx, 8.25, cz),
					Vector3(block.x * 0.95, 2.5, block.z * 0.85), HERO_ROOF_TILE))
			## The platform canopy rides the rail (north) face.
			parts.append(_part(id, "canopy", Vector3(cx, 3.6, cz - block.z * 0.5 - 1.0),
					Vector3(block.x * 0.92, 0.8, 4.0), HERO_STEEL))
	return parts


## One axis-aligned ring around an ellipse (the bowl, the drum): each segment
## is the chord box covering its arc, shifted INWARD half its width so the
## ring's union AABB lands ON the survey envelope (the OSM way bbox is the
## OUTER edge of both). Returns the part list.
static func _ring_parts(id: String, part: String, center: Vector2, rx: float,
		rz: float, segments: int, width: float, height: float,
		color: Color) -> Array:
	var parts: Array = []
	for k: int in segments:
		var a0 := TAU * float(k) / float(segments)
		var a1 := TAU * float(k + 1) / float(segments)
		var p0 := Vector2(center.x + rx * cos(a0), center.y + rz * sin(a0))
		var p1 := Vector2(center.x + rx * cos(a1), center.y + rz * sin(a1))
		var mid := (p0 + p1) * 0.5
		var ext := Vector2(absf(p1.x - p0.x) + width, absf(p1.y - p0.y) + width)
		var from_center := mid - center
		var inward := from_center / maxf(from_center.length(), 0.001) * (width * 0.5)
		var box_center := Vector3(mid.x - inward.x, height * 0.5, mid.y - inward.y)
		parts.append(_part(id, part, box_center, Vector3(ext.x, height, ext.y), color))
	return parts


## The Durham bandshell: a pale semicircular shell arc (opening east onto
## the park) + the stage slab — hand-placed at the POI position (census §5:
## the park polygon itself is outside the distilled core).
static func _bandshell_parts(pos: Vector2) -> Array:
	var parts: Array = []
	for k: int in 7:
		var ang := PI * 0.5 + PI * float(k) / 6.0 ## 90°..270°: the west half circle.
		parts.append(_part("downtown_bandshell", "shell",
				Vector3(pos.x + 6.5 * cos(ang), 4.0, pos.y + 6.5 * sin(ang)),
				Vector3(3.2, 8.0, 3.2), HERO_SHELL))
	parts.append(_part("downtown_bandshell", "stage",
			Vector3(pos.x, 0.6, pos.y), Vector3(8.0, 1.2, 10.0), HERO_CONCRETE))
	return parts


## One municipal water-tank bulb (LANDMARKS T8: mushroom bulb on a stem).
static func _water_tank_parts(pos: Vector2, id: String) -> Array:
	var parts: Array = []
	parts.append(_part(id, "stem",
			Vector3(pos.x, 8.0, pos.y), Vector3(3.0, 16.0, 3.0), HERO_STEEL))
	parts.append(_part(id, "bulb",
			Vector3(pos.x, 22.0, pos.y), Vector3(20.0, 12.0, 20.0), HERO_TANK))
	parts.append(_part(id, "cap",
			Vector3(pos.x, 29.0, pos.y), Vector3(7.0, 2.0, 7.0), HERO_TANK))
	return parts


## The SE grain-elevator cluster (LANDMARKS T7): a pale silo bank +
## headhouse + attached steel bins, heights the 30–40 m UNVERIFIED
## placeholder (V-30).
static func _elevator_parts(pos: Vector2) -> Array:
	var parts: Array = []
	for k: int in 4:
		parts.append(_part("grain_elevators", "silo",
				Vector3(pos.x - 13.5 + 9.0 * float(k), 17.0, pos.y),
				Vector3(7.0, 34.0, 7.0), HERO_SILO))
	parts.append(_part("grain_elevators", "headhouse",
			Vector3(pos.x, 19.0, pos.y - 8.0), Vector3(10.0, 38.0, 10.0), HERO_SILO))
	parts.append(_part("grain_elevators", "bin",
			Vector3(pos.x - 8.0, 6.0, pos.y + 8.0), Vector3(5.0, 12.0, 5.0), HERO_SILO))
	parts.append(_part("grain_elevators", "bin",
			Vector3(pos.x + 8.0, 6.0, pos.y + 8.0), Vector3(5.0, 12.0, 5.0), HERO_SILO))
	return parts


## The T-174 lane-dash rule: a street is an arterial when its NAME carries
## one of the ticket's four corridor fragments (`ARTERIAL_NAME_KEYS`) —
## name-based, not class-based, so Main's residential-tagged eastern
## stretches stay Main and keep their dash.
static func _is_arterial(name: String) -> bool:
	for key: String in ARTERIAL_NAME_KEYS:
		if name.contains(key):
			return true
	return false


## Separating-axis test on two convex quads (flat `[[x, y, z] × 4]` corner
## arrays; only x/z are tested). Returns true when the quads come within
## `margin` on every axis — i.e. they overlap or sit closer than the margin.
## Used to keep ballast off crossing-road asphalt (both carriageways).
static func _quads_overlap(a: Array, b: Array, margin: float) -> bool:
	for q: Array in [a, b]:
		var n := 4
		for i: int in n:
			var p := Vector2(float(q[i * 3]), float(q[i * 3 + 2]))
			var r := Vector2(float(q[((i + 1) % n) * 3]), float(q[((i + 1) % n) * 3 + 2]))
			var e := r - p
			var len_sq := e.length_squared()
			if len_sq < 1e-12:
				continue
			var axis := Vector2(-e.y, e.x) / sqrt(len_sq)
			var a_lo := INF
			var a_hi := -INF
			var b_lo := INF
			var b_hi := -INF
			for k: int in 4:
				var da := axis.dot(Vector2(float(a[k * 3]), float(a[k * 3 + 2])))
				var db := axis.dot(Vector2(float(b[k * 3]), float(b[k * 3 + 2])))
				a_lo = minf(a_lo, da)
				a_hi = maxf(a_hi, da)
				b_lo = minf(b_lo, db)
				b_hi = maxf(b_hi, db)
			if maxf(a_lo - b_hi, b_lo - a_hi) > margin:
				return false ## Separated by more than the margin.
	return true


## One asphalt-width quad across segment a→b at height y: `[[x,y,z] × 4]` —
## empty when the segment is degenerate.
static func _extrude_quad(a: Vector2, b: Vector2, width: float, y: float) -> Array:
	var dir := b - a
	if dir.length_squared() < 1e-10:
		return []
	var n := (Vector2(-dir.y, dir.x) / dir.length()) * (width * 0.5)
	return [
		_r(a.x + n.x), _r(y), _r(a.y + n.y),
		_r(a.x - n.x), _r(y), _r(a.y - n.y),
		_r(b.x - n.x), _r(y), _r(b.y - n.y),
		_r(b.x + n.x), _r(y), _r(b.y + n.y),
	]


## Ear-clipping triangulation of a simple polygon — indices into `pts`,
## consistent winding with the input ring. Falls back to a fan from vertex 0
## when no ear is found (deterministic; the split rings below are simple).
static func _triangulate(pts: PackedVector2Array) -> Array[Vector3i]:
	var tris: Array[Vector3i] = []
	var n := pts.size()
	if n < 3:
		return tris
	var ring: Array[int] = []
	for i: int in n:
		ring.append(i)
	if _signed_area(pts) < 0.0:
		ring.reverse()
	var guard := 0
	while ring.size() > 2 and guard < 10000:
		guard += 1
		var clipped := false
		for i: int in ring.size():
			var i0 := ring[(i - 1 + ring.size()) % ring.size()]
			var i1 := ring[i]
			var i2 := ring[(i + 1) % ring.size()]
			var cross := (pts[i1] - pts[i0]).cross(pts[i2] - pts[i1])
			if cross <= 1e-9:
				continue ## Reflex or collinear corner — not an ear.
			var ear_clear := true
			for j: int in ring:
				if j == i0 or j == i1 or j == i2:
					continue
				if _point_in_tri(pts[j], pts[i0], pts[i1], pts[i2]):
					ear_clear = false
					break
			if not ear_clear:
				continue
			tris.append(Vector3i(i0, i1, i2))
			ring.remove_at(i)
			clipped = true
			break
		if not clipped:
			for i: int in range(1, ring.size() - 1): ## Fan fallback.
				tris.append(Vector3i(ring[0], ring[i], ring[i + 1]))
			break
	return tris


## Cut the hole out of a convex triangle by BSP-style splitting against the
## hole RING's own boundary edges: every piece the segment crosses is split
## by the edge's LINE (both sides kept — the pieces tile the triangle), and
## after the walk the pieces whose centroid sits inside the ring are
## dropped. Deterministic, area-conserving, and bounded: only the ring's
## boundary edges split, never a triangulation's interior web.
static func _tri_minus_ring(pieces: Array[PackedVector2Array],
		ring: PackedVector2Array) -> Array[PackedVector2Array]:
	var aabb_lo := Vector2(INF, INF)
	var aabb_hi := Vector2(-INF, -INF)
	for piece: PackedVector2Array in pieces:
		for v: Vector2 in piece:
			aabb_lo = aabb_lo.min(v)
			aabb_hi = aabb_hi.max(v)
	for e: int in ring.size():
		var a := ring[e]
		var b := ring[(e + 1) % ring.size()]
		var seg_lo := a.min(b)
		var seg_hi := a.max(b)
		if seg_hi.x < aabb_lo.x or seg_lo.x > aabb_hi.x \
				or seg_hi.y < aabb_lo.y or seg_lo.y > aabb_hi.y:
			continue
		var nrm := (b - a).normalized()
		var next_pieces: Array[PackedVector2Array] = []
		for p: PackedVector2Array in pieces:
			if not _convex_poly_crosses_seg(p, a, nrm, b):
				next_pieces.append(p)
				continue
			if OS.has_environment("T205_DEBUG"):
				print("DEBUG split at hole edge %d: piece n=%d" % [e, p.size()])
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i: int in p.size():
				var cur := p[i]
				var nxt := p[(i + 1) % p.size()]
				var d_cur := (cur - a).cross(nrm)
				var d_nxt := (nxt - a).cross(nrm)
				if d_cur <= 0.0:
					left.append(cur)
				else:
					right.append(cur)
				if (d_cur <= 0.0) != (d_nxt <= 0.0):
					var hit := cur.lerp(nxt, d_cur / (d_cur - d_nxt))
					left.append(hit)
					right.append(hit)
			if left.size() >= 3:
				next_pieces.append(left)
			if right.size() >= 3:
				next_pieces.append(right)
		pieces = next_pieces
	var kept: Array[PackedVector2Array] = []
	var rings: Array[PackedVector2Array] = [ring]
	for p: PackedVector2Array in pieces:
		var c := Vector2.ZERO
		for v2: Vector2 in p:
			c += v2
		c /= float(p.size())
		if not _mid_in_lake(c, rings):
			kept.append(p)
	return kept


## TRUE when the segment a→b (direction `nrm`) properly crosses the convex
## polygon's interior: some edge pair straddles the line on both sides AND
## the crossing span overlaps the segment's span.
static func _convex_poly_crosses_seg(p: PackedVector2Array, a: Vector2,
		nrm: Vector2, b: Vector2) -> bool:
	var t_lo := INF
	var t_hi := -INF
	var poly_lo := INF
	var poly_hi := -INF
	for i: int in p.size():
		var d := (p[i] - a).cross(nrm)
		poly_lo = minf(poly_lo, d)
		poly_hi = maxf(poly_hi, d)
	if poly_lo > 0.0 or poly_hi < 0.0:
		return false ## The whole polygon is on one side of the line.
	var along := (b - a).normalized()
	var seg_len := (b - a).length()
	for i: int in p.size():
		var cur := p[i]
		var nxt := p[(i + 1) % p.size()]
		var d_cur := (cur - a).cross(nrm)
		var d_nxt := (nxt - a).cross(nrm)
		if (d_cur <= 0.0) != (d_nxt <= 0.0):
			var t := d_cur / (d_cur - d_nxt)
			var hit := cur.lerp(nxt, t)
			var s := (hit - a).dot(along)
			t_lo = minf(t_lo, s)
			t_hi = maxf(t_hi, s)
	if t_lo == INF:
		return false
	return t_hi > 1e-9 and t_lo < seg_len - 1e-9


## Packs a JSON point list (`[[x, z], ...]`) into a PackedVector2Array.
static func _pack_points(list: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p: Array in list:
		pts.append(Vector2(float(p[0]), float(p[1])))
	return pts


## Splits a stored polygon vertex sequence into SIMPLE open rings at
## repeated locations. OSM ways joined into one sequence produce
## self-touching rings — Lake LaVerne is two ways sharing a seam edge, so
## the raw sequence walks a double loop through two repeated vertices and a
## naive ear clip double-covers the lake. The walk closes a loop each time
## a location repeats (the shared vertex stays to continue the remainder);
## the returned rings carry no duplicate closure point.
static func _split_rings(raw: PackedVector2Array) -> Array[PackedVector2Array]:
	var pts := _dedup_consecutive(raw)
	var loops: Array[PackedVector2Array] = []
	var cur := PackedVector2Array()
	var seen: Dictionary = {}
	for p: Vector2 in pts:
		var key := str(p.x) + "," + str(p.y)
		if seen.has(key):
			var j: int = seen[key]
			var loop := PackedVector2Array()
			for k: int in range(j, cur.size()): ## Shared vertex at BOTH ends.
				loop.append(cur[k])
			loop = _dedup_consecutive(loop) ## The first==last closure dup goes.
			if loop.size() >= 3:
				loops.append(loop)
			cur = cur.slice(0, j + 1) ## Shared vertex stays; walk continues after it.
			seen.clear()
			for k: int in cur.size():
				seen[str(cur[k].x) + "," + str(cur[k].y)] = k
		else:
			seen[key] = cur.size()
			cur.append(p)
	if cur.size() >= 3:
		loops.append(cur)
	return loops


static func _dedup_consecutive(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		if out.is_empty() or out[out.size() - 1] != p:
			out.append(p)
	return out


## Even-odd point-in-ring (ray cast) — the creek-over-lake skip rule's probe:
## TRUE when `p` sits inside ANY one ring's boundary, so a lake basin OR the
## island loop both count (the whole basin paints no creek ribbon).
static func _mid_in_lake(p: Vector2, rings: Array[PackedVector2Array]) -> bool:
	for ring: PackedVector2Array in rings:
		var n := ring.size()
		if n < 3:
			continue
		var inside := false
		for i: int in n:
			var a := ring[i]
			var b := ring[(i + 1) % n]
			if (a.y > p.y) != (b.y > p.y):
				var x_at := a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
				if p.x < x_at:
					inside = not inside
		if inside:
			return true
	return false


static func _signed_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i: int in pts.size():
		var q := pts[(i + 1) % pts.size()]
		a += pts[i].cross(q)
	return a * 0.5


static func _point_in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p - a).cross(b - a)
	var d2 := (p - b).cross(c - b)
	var d3 := (p - c).cross(a - c)
	var has_neg := d1 < -1e-9 or d2 < -1e-9 or d3 < -1e-9
	var has_pos := d1 > 1e-9 or d2 > 1e-9 or d3 > 1e-9
	return not (has_neg and has_pos)


## Nearest distance from (x, z) to any stored point of a polyline cloud.
static func _min_dist(x: float, z: float, pts: PackedVector2Array) -> float:
	var best := 1e18
	for p: Vector2 in pts:
		var d := (p.x - x) * (p.x - x) + (p.y - z) * (p.y - z)
		if d < best:
			best = d
	return sqrt(best)


## --- T-207 tree-canopy builders (pure pack/const arithmetic) ----------------


## TRUE when `p` sits inside ANY of the rings (even-odd ray crossing — the
## park-membership leg of the archetype law; holes stay outside their own
## ring, which is the honest read for a park-lake island).
static func _point_in_rings(p: Vector2, rings: Array[PackedVector2Array]) -> bool:
	for ring: PackedVector2Array in rings:
		if _point_in_ring(p, ring):
			return true
	return false


static func _point_in_ring(p: Vector2, ring: PackedVector2Array) -> bool:
	var inside := false
	var n := ring.size()
	var j := n - 1
	for i in n:
		var a := ring[i]
		var b := ring[j]
		if (a.y > p.y) != (b.y > p.y) \
				and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


## Nearest distance from `p` to any ring's SEGMENTS (the shore-ring law: the
## lake polygons' vertices are sparse, so a vertex-only distance would
## misread the band — point-to-segment is the honest ring distance).
static func _rings_min_dist(p: Vector2, rings: Array[PackedVector2Array]) -> float:
	var best := 1e18
	for ring: PackedVector2Array in rings:
		for i in ring.size():
			var d := _seg_dist(p, ring[i], ring[(i + 1) % ring.size()])
			if d < best:
				best = d
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-12:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Per-axis tree scale in [TREE_SCALE_LO, TREE_SCALE_HI] — band `k` picks the
## hash field so the axes decorrelate.
static func _tree_scale(roll: int, k: int) -> float:
	return TREE_SCALE_LO + (TREE_SCALE_HI - TREE_SCALE_LO) * _frac01(roll, k)


## The variation tint: green = luminance over the band (the grove band darker
## — the §1.9 Brookside summer-forest read), red/blue jittered around it.
## Bark rides the same tint — bark × near-white stays bark.
static func _tree_tint(grove: bool, roll: int) -> Color:
	var lo := TREE_GROVE_LO if grove else TREE_TINT_LO
	var hi := TREE_GROVE_HI if grove else TREE_TINT_HI
	var lum := lo + (hi - lo) * _frac01(roll, 4)
	var rj := 1.0 - TREE_HUE_JITTER * 0.5 + TREE_HUE_JITTER * _frac01(roll, 5)
	var bj := 1.0 - TREE_HUE_JITTER * 0.5 + TREE_HUE_JITTER * _frac01(roll, 6)
	return Color(lum * rj, lum, lum * bj)


## Band `k`'s fraction into [0, 1) — a splitmix-style integer finalizer over
## (roll, band). The first draft re-hashed the roll as a STRING per band and
## the bands came out correlated: the polynomial string hash perturbs only
## its low bits when the band suffix changes, so every band rode ~the same
## fraction (sx ≈ sy ≈ sz on most trees). The finalizer avalanches both
## inputs — GDScript int64 arithmetic wraps deterministically, no RNG.
static func _frac01(roll: int, k: int) -> float:
	var h := roll ^ (k * -7046029254386353131) ## 0x9E3779B97F4A7C15 as signed.
	h = (h ^ (h >> 30)) * -4658895280553007687 ## 0xBF58476D1CE4E5B9.
	h = (h ^ (h >> 27)) * -7905916399975552669 ## 0x94D049BB133111EB.
	h = h ^ (h >> 31)
	return float((h >> 11) & 0x1FFF) / 8192.0


## Precomputed point clouds for the district rule + crossing gap table.
static func _build_context() -> Dictionary:
	var anchors := PackedVector2Array()
	for poi: Dictionary in AmesDataPack.pois():
		if str(poi.get("id", "")) in CAMPUS_ANCHOR_IDS and poi.get("position") != null:
			var pos: Array = poi["position"]
			anchors.append(Vector2(float(pos[0]), float(pos[1])))
	var campus_pts := PackedVector2Array()
	var main_pts := PackedVector2Array()
	var lw_pts := PackedVector2Array()
	var duff_pts := PackedVector2Array()
	for s: Dictionary in AmesDataPack.streets():
		var sname := str(s.get("name", ""))
		if sname in CAMPUS_STREET_NAMES:
			_append_points(campus_pts, s)
		if sname in DOWNTOWN_STREET_NAMES:
			_append_points(main_pts, s)
		if sname == "Lincoln Way":
			_append_points(lw_pts, s)
		if sname.contains("Duff"):
			_append_points(duff_pts, s)
	return {
		"campus_anchors": anchors, "campus_street_pts": campus_pts,
		"main_pts": main_pts, "lw_pts": lw_pts, "duff_pts": duff_pts,
	}


static func _append_points(into: PackedVector2Array, street: Dictionary) -> void:
	for p: Array in street.get("points", []):
		into.append(Vector2(float(p[0]), float(p[1])))


## Chunk AABB over everything written into it (xz of all geometry plus the
## massing boxes' full height). The accumulator is a `[min, max]` Array —
## GDScript Vectors pass by value, Arrays by reference.
static func _chunk_aabb(chunk: Dictionary) -> Dictionary:
	var acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
	for m: Dictionary in chunk["massing"]:
		var p: Array = m["p"]
		var s: Array = m["s"]
		_aabb_grow(acc, Vector3(float(p[0]) - float(s[0]) * 0.5, 0.0,
				float(p[2]) - float(s[2]) * 0.5))
		_aabb_grow(acc, Vector3(float(p[0]) + float(s[0]) * 0.5,
				float(p[1]) + float(s[1]) * 0.5,
				float(p[2]) + float(s[2]) * 0.5))
	for ph: Dictionary in chunk["placeholders"]: ## (T-175) hero masses join the AABB.
		var pp: Array = ph["p"]
		var ps: Array = ph["s"]
		_aabb_grow(acc, Vector3(float(pp[0]) - float(ps[0]) * 0.5, 0.0,
				float(pp[2]) - float(ps[2]) * 0.5))
		_aabb_grow(acc, Vector3(float(pp[0]) + float(ps[0]) * 0.5,
				float(pp[1]) + float(ps[1]) * 0.5,
				float(pp[2]) + float(ps[2]) * 0.5))
	for dr: Dictionary in chunk["dress"]: ## (T-206) dressing boxes join the AABB.
		var dp: Array = dr["p"]
		var ds: Array = dr["s"]
		_aabb_grow(acc, Vector3(float(dp[0]) - float(ds[0]) * 0.5, 0.0,
				float(dp[2]) - float(ds[2]) * 0.5))
		_aabb_grow(acc, Vector3(float(dp[0]) + float(ds[0]) * 0.5,
				float(dp[1]) + float(ds[1]) * 0.5,
				float(dp[2]) + float(ds[2]) * 0.5))
	for quad_key: String in ["ribbons", "lane_quads", "shore_quads",
			"creek_quads", "ballast_quads", "tie_quads", "ground_quads"]:
		for q: Dictionary in chunk[quad_key]:
			_aabb_flat(acc, q["q"])
	for tri_key: String in ["water_tris", "lawn_tris"]:
		for t: Dictionary in chunk[tri_key]:
			_aabb_flat(acc, t["v"])
	for rf: Dictionary in chunk["roofs"]: ## (T-206) gable prisms join the AABB:
		## the prism rides its eave center `p` with `s` = [len, span, ridge_h]
		## in RIDGE-AXIS order (`a` = "x" lengths along X), so grow by the
		## full eave rectangle up to the ridge top.
		var rp: Array = rf["p"]
		var rs: Array = rf["s"]
		var rlen_x := float(rs[0]) if str(rf["a"]) == "x" else float(rs[1])
		var rlen_z := float(rs[1]) if str(rf["a"]) == "x" else float(rs[0])
		_aabb_grow(acc, Vector3(float(rp[0]) - rlen_x * 0.5, float(rp[1]),
				float(rp[2]) - rlen_z * 0.5))
		_aabb_grow(acc, Vector3(float(rp[0]) + rlen_x * 0.5,
				float(rp[1]) + float(rs[2]), float(rp[2]) + rlen_z * 0.5))
	for tr: Dictionary in chunk["trees"]: ## (T-207) the canopy joins the AABB:
		## grow by the tree's own archetype extent under its baked scale —
		## the ellipsoid crown reads circular, so x and z use their own axes'
		## scale and the top is (crown_cy + crown_ry) × sy (the yaw spins the
		## trunk facets, never the crown envelope).
		var tp: Array = tr["p"]
		var ts: Array = tr["s"]
		var spec2: Dictionary = TREE_ARCHETYPES[str(tr["t"])]
		var ext_x := float(spec2["crown_rxz"]) * float(ts[0])
		var ext_z := float(spec2["crown_rxz"]) * float(ts[2])
		var top := (float(spec2["crown_cy"]) + float(spec2["crown_ry"])) * float(ts[1])
		_aabb_grow(acc, Vector3(float(tp[0]) - ext_x, 0.0, float(tp[2]) - ext_z))
		_aabb_grow(acc, Vector3(float(tp[0]) + ext_x, top, float(tp[2]) + ext_z))
	var lo: Vector3 = acc[0]
	var hi: Vector3 = acc[1]
	return {"min": [_r(lo.x), _r(lo.y), _r(lo.z)], "max": [_r(hi.x), _r(hi.y), _r(hi.z)]}


static func _aabb_grow(acc: Array, v: Vector3) -> void:
	acc[0] = (acc[0] as Vector3).min(v)
	acc[1] = (acc[1] as Vector3).max(v)


static func _aabb_flat(acc: Array, flat: Array) -> void:
	for i: int in range(0, flat.size(), 3):
		_aabb_grow(acc, Vector3(float(flat[i]), float(flat[i + 1]), float(flat[i + 2])))


static func _chunk_counts(chunk: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for key: String in FAMILY_KEYS:
		counts[key] = (chunk[key] as Array).size()
	return counts


## Position snap (1 mm) — deterministic serialization, keeps files small.
static func _r(v: float) -> float:
	return snappedf(v, 0.001)


## Color snap (4 decimals) — a palette color survives the round trip exactly.
static func _rc(v: float) -> float:
	return snappedf(v, 0.0001)


static func _sha256(bytes: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(bytes)
	return hc.finish().hex_encode()
