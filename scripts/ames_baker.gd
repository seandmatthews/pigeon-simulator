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
## What each chunk carries (ames_chunks/v1):
## - `massing`: ONE axis-aligned box per building footprint — position,
##   size, district and vertex color (city.gd's MultiMesh + vertex-color
##   house style, ported to data). Procedural filler gets the census §7.4
##   level ladder (bbox+levels, footprint bands where OSM tags nothing);
##   authored buildings get their bbox massing too — heroes REPLACE them at
##   mount time (T-185+), so the massing doubles as the LOD0 fallback.
## - `ribbons`: street centerlines pre-extruded to asphalt quads at the
##   pack's per-class widths (primary 20 m four-lane … residential 11 m).
##   Paint (lane marks) is T-174, not here.
## - `water_tris` / `lawn_tris`: Lake LaVerne and the 31 park polygons,
##   ear-clip triangulated offline into world-space triangles.
## - `creek_quads`: College/Ioway centerlines extruded to 6 m water ribbons.
## - `ballast_quads`: the rail centerline extruded to a 5 m ballast strip,
##   SEGMENTED wherever it would run over a crossing road's own asphalt —
##   the 9 at-grade crossings' road ribbons (BOTH carriageways of divided
##   roads) block the ballast geometrically, so the roads show through.
## - `occluders`: one simplified building outline (the bbox rectangle) per
##   massing box — the feed for baked `ArrayOccluder3D`s (T-173).
## - `crossings`: the at-grade rail crossings inside the tile (world facts
##   for R2's traffic graph; machine-checked by `ames_bake_census`).
##
## NOT baked (by ticket): heroes/landmarks (mount as authored scenes,
## T-175/T-185+), the 5,637 tree points (R5·tree canopy), collision
## (T-173's gameplay seam answers ground queries over chunk data).
##
## Determinism discipline: pack arrays are consumed in order; every float is
## snapped (positions 0.001 m, colors 0.0001); JSON is serialized with sorted
## keys; files are written in sorted (cx, cz) order; colors are picked by a
## stable hash of the building id (no RNG anywhere).

const SCHEMA := "ames_chunks/v1"
const CHUNK_SIZE := 256.0

## Bake y conventions (m). Flats stack above 0 so a later ground plate
## (T-174's ground palettes) can sit at y 0 without z-fighting: water below
## creek below lawn below road below ballast.
const WATER_Y := 0.02
const CREEK_Y := 0.05
const LAWN_Y := 0.04
const RIBBON_Y := 0.08
const BALLAST_Y := 0.1

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

	# --- streets: centerlines extruded to asphalt ribbons -----------------
	for s: Dictionary in AmesDataPack.streets():
		var width := maxf(float(s.get("width_m", 11.0)), 4.0)
		var pts: Array = s.get("points", [])
		for i: int in range(pts.size() - 1):
			var a: Array = pts[i]
			var b2: Array = pts[i + 1]
			var quad := _extrude_quad(Vector2(float(a[0]), float(a[1])),
					Vector2(float(b2[0]), float(b2[1])), width, RIBBON_Y)
			if quad.is_empty():
				continue
			var mid := (Vector2(float(a[0]), float(a[1])) + Vector2(float(b2[0]), float(b2[1]))) * 0.5
			(_chunk_at(tiles, _chunk_of(mid.x, mid.y))["ribbons"] as Array).append({"q": quad})

	# --- water: Lake LaVerne polygon (triangulated) + creek ribbons -------
	for wtr: Dictionary in AmesDataPack.water():
		if str(wtr.get("kind", "")) == "lake" and wtr.has("polygon"):
			var poly := _pack_points(wtr.get("polygon", []))
			for ring: PackedVector2Array in _split_rings(poly):
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

	# --- at-grade crossings are world facts per chunk ---------------------
	for c: Dictionary in crossings:
		var tile := _chunk_of(c["pos"].x, c["pos"].y)
		(_chunk_at(tiles, tile)["crossings"] as Array).append({
			"pos": [_r(c["pos"].x), _r(c["pos"].y)],
			"road": c["road"],
			"class": c["cls"],
		})

	# --- finalize chunks: aabb, counts, colors, serialize, hash, write ----
	var array_colors := {
		"ribbons": [_rc(COLOR_ASPHALT.r), _rc(COLOR_ASPHALT.g), _rc(COLOR_ASPHALT.b)],
		"water_tris": [_rc(COLOR_WATER.r), _rc(COLOR_WATER.g), _rc(COLOR_WATER.b)],
		"creek_quads": [_rc(COLOR_WATER.r), _rc(COLOR_WATER.g), _rc(COLOR_WATER.b)],
		"lawn_tris": [_rc(COLOR_LAWN.r), _rc(COLOR_LAWN.g), _rc(COLOR_LAWN.b)],
		"ballast_quads": [_rc(COLOR_BALLAST.r), _rc(COLOR_BALLAST.g), _rc(COLOR_BALLAST.b)],
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
	var totals: Dictionary = {
		"massing": 0, "ribbons": 0, "water_tris": 0, "creek_quads": 0,
		"lawn_tris": 0, "ballast_quads": 0, "occluders": 0, "crossings": 0,
		"chunks": tiles_sorted.size(), "bytes": 0,
	}
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
			"massing": chunk["massing"],
			"ribbons": chunk["ribbons"],
			"water_tris": chunk["water_tris"],
			"creek_quads": chunk["creek_quads"],
			"lawn_tris": chunk["lawn_tris"],
			"ballast_quads": chunk["ballast_quads"],
			"occluders": chunk["occluders"],
			"crossings": chunk["crossings"],
		}
		var text := JSON.stringify(doc, "\t")
		var bytes := text.to_utf8_buffer()
		var sha := _sha256(bytes)
		var fa := FileAccess.open(out_dir.path_join(file), FileAccess.WRITE)
		if fa == null:
			push_error("AmesBaker: cannot write %s" % out_dir.path_join(file))
			return {}
		fa.store_string(text)
		fa.close()
		for key: String in ["massing", "ribbons", "water_tris", "creek_quads",
				"lawn_tris", "ballast_quads", "occluders", "crossings"]:
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
		tiles[tile] = {
			"massing": [], "ribbons": [], "water_tris": [], "creek_quads": [],
			"lawn_tris": [], "ballast_quads": [], "occluders": [], "crossings": [],
		}
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
	for quad_key: String in ["ribbons", "creek_quads", "ballast_quads"]:
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
	for key: String in ["massing", "ribbons", "water_tris", "creek_quads",
			"lawn_tris", "ballast_quads", "occluders", "crossings"]:
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
