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
## What each chunk carries (ames_chunks/v3 — v2 plus the T-175 placeholder
## family and the massing `a` flag; every family is optional at read time):
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
##   LOD0 fallback exactly as before.
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
## silhouettes are the stand-ins), the 5,637 tree points (R5·tree canopy),
## collision (the renderer builds it from the `a` flag + placeholders;
## T-173's gameplay seam answers ground queries over chunk data).
##
## Determinism discipline: pack arrays are consumed in order; every float is
## snapped (positions 0.001 m, colors 0.0001); JSON is serialized with sorted
## keys; files are written in sorted (cx, cz) order; colors are picked by a
## stable hash of the building id (no RNG anywhere).

const SCHEMA := "ames_chunks/v3"
const CHUNK_SIZE := 256.0

## Every per-chunk array family (the `_chunk_at` template, the finalize doc,
## the per-chunk counts and the manifest totals — ONE list, kept in one
## place; v1's eight, the T-174 dressing families, and T-175's
## placeholders).
const FAMILY_KEYS: Array[String] = [
	"massing", "ribbons", "lane_quads", "water_tris", "shore_quads",
	"creek_quads", "lawn_tris", "ballast_quads", "tie_quads",
	"ground_quads", "occluders", "placeholders", "crossings",
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
## shore 0.018 < water 0.02 < lawn 0.04 < creek-top 0.06 < ribbon-top 0.09
## < ballast/marks-top 0.11 < tie-top 0.13.
const WATER_Y := 0.02
const CREEK_Y := 0.05
const LAWN_Y := 0.04
const RIBBON_Y := 0.08
const BALLAST_Y := 0.1
const GROUND_Y := 0.004 ## District ground cells (T-174): box tops at 0.014.
const SHORE_Y := 0.008 ## Shore band (T-174): box tops at 0.018, under the water.
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
const COLOR_CREEK := Color(0.275, 0.4, 0.388) ## #466663 green-blue (T-174).
const COLOR_SHORE := Color(0.435, 0.561, 0.31) ## #6F8F4F mown shore lawn (§1.2).
const COLOR_LANE_MARK := Color(0.78, 0.7, 0.353) ## #C7B35A centerline yellow.
const COLOR_TIE := Color(0.29, 0.267, 0.227) ## #4A443A tie/track stripe.

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

## District dressing palettes (MODELING-SPECS §3 + §1.2, hex in comments —
## the first-pass read; R5·filler-dressing re-dresses onto these data):
## downtown §3.2 dark-to-mid brick + painted-concrete cream; campustown §3.3
## cinderblock/brick storefront mix; campus §3.7 buff/tan + pale limestone
## (the §1.2 MU sunlit limestone) + dark-red brick; lincolnway §3.4 set-back
## one-story retail creams; residential §3.6 tan/cream/gray siding + brick
## accent. Roof shingle #4E4E52 rides T-174 (single-box massing here).
const DISTRICT_PALETTES: Dictionary = {
	"campus": [
		Color(0.769, 0.745, 0.69), ## #C4BEB0 pale limestone (MU sunlit).
		Color(0.839, 0.804, 0.706), ## #D6CDB4 buff/tan brick.
		Color(0.541, 0.29, 0.212), ## #8A4A36 dark-red brick.
		Color(0.867, 0.847, 0.788), ## #DDD8C9 pale concrete.
	],
	"campustown": [
		Color(0.612, 0.357, 0.263), ## #9C5B43 brick storefront.
		Color(0.722, 0.478, 0.333), ## #B87A55 warm brick.
		Color(0.776, 0.749, 0.659), ## #C6BFA8 painted block.
		Color(0.557, 0.522, 0.471), ## #8E8578 cinderblock gray.
	],
	"downtown": [
		Color(0.541, 0.29, 0.212), ## #8A4A36 dark brick.
		Color(0.659, 0.4, 0.247), ## #A8663F mid brick.
		Color(0.812, 0.773, 0.706), ## #CFC5B4 painted-concrete cream.
	],
	"lincolnway": [
		Color(0.827, 0.788, 0.714), ## #D3C9B6 retail cream.
		Color(0.761, 0.706, 0.604), ## #C2B49A tan box.
		Color(0.878, 0.851, 0.776), ## #E0D9C6 pale cream.
	],
	"residential": [
		Color(0.847, 0.796, 0.663), ## #D8CBA9 tan siding.
		Color(0.894, 0.863, 0.784), ## #E4DCC8 cream siding.
		Color(0.706, 0.682, 0.635), ## #B4AEA2 gray siding.
		Color(0.659, 0.4, 0.247), ## #A8663F brick accent.
	],
}

## Flat colors (MODELING-SPECS §1.2 lake olive-brown overcast + mown shore
## lawn; asphalt = city.gd's COLOR_ASPHALT; ballast gravel gray).
const COLOR_ASPHALT := Color(0.29, 0.29, 0.31)
const COLOR_WATER := Color(0.275, 0.329, 0.247) ## #46543F olive-brown.
const COLOR_LAWN := Color(0.435, 0.561, 0.31) ## #6F8F4F mown lawn.
const COLOR_BALLAST := Color(0.545, 0.522, 0.471) ## #8B8578 gravel.
const CREEK_WIDTH := 6.0
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
	# slots); procedural filler stays visual-only massing.
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
			for ring: PackedVector2Array in _split_rings(poly):
				# Shore band (T-174): mown-lawn ring extruded OUTWARD from
				# every ring edge. Baked BELOW the water top so an overlap
				# can never paint the lake — the water flat renders above.
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
						_r(q0.x), _r(SHORE_Y), _r(q0.y),
						_r(q1.x), _r(SHORE_Y), _r(q1.y),
						_r(sb.x), _r(SHORE_Y), _r(sb.y),
						_r(sa.x), _r(SHORE_Y), _r(sa.y),
					]
					var smid := (sa + sb) * 0.5
					(_chunk_at(tiles, _chunk_of(smid.x, smid.y))["shore_quads"] as Array).append({"q": shore})
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
	for park: Dictionary in AmesDataPack.parks():
		var poly := _pack_points(park.get("polygon", []))
		for ring: PackedVector2Array in _split_rings(poly):
			for tri: Vector3i in _triangulate(ring):
				var tri_centroid := (ring[tri.x] + ring[tri.y] + ring[tri.z]) / 3.0
				var v: Array = [
					_r(ring[tri.x].x), _r(LAWN_Y), _r(ring[tri.x].y),
					_r(ring[tri.y].x), _r(LAWN_Y), _r(ring[tri.y].y),
					_r(ring[tri.z].x), _r(LAWN_Y), _r(ring[tri.z].y),
				]
				(_chunk_at(tiles, _chunk_of(tri_centroid.x, tri_centroid.y))["lawn_tris"] as Array).append({"v": v})

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
		## ground_quads entries carry per-cell colors (`c`) — the family entry
		## is only the renderer's never-fired fallback (residential seed).
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
	for quad_key: String in ["ribbons", "lane_quads", "shore_quads",
			"creek_quads", "ballast_quads", "tie_quads", "ground_quads"]:
		for q: Dictionary in chunk[quad_key]:
			_aabb_flat(acc, q["q"])
	for tri_key: String in ["water_tris", "lawn_tris"]:
		for t: Dictionary in chunk[tri_key]:
			_aabb_flat(acc, t["v"])
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
