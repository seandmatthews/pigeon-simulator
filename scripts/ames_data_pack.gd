class_name AmesDataPack
## Static loader for the committed Ames city database (T-171).
##
## The pack lives at `data/ames/ames_core.json`, distilled offline from the
## ring-0 survey's OSM dataset by `tools/ames_distill.py` (byte-identical on
## every re-run; see the script header). This class parses it once and hands
## out typed slices — the city code consumes it directly; NO autoload (none is
## warranted until a ticket needs a global).
##
## Coordinate convention (master plan §2, mirrored from the distiller):
## local meters, origin at Lincoln Way × Welch, +X east, −Z north, Y up,
## equirectangular scale at lat 42.02. Re-centering is a pack-version bump,
## never a refactor — everything reads origin/scale from `meta()` except this
## class's pinned constants, which `ames_data_integrity` keeps in lockstep
## with the pack.
##
## Facing convention: compass degrees, 0 = north (−Z), 90 = east (+X);
## `facing_to_yaw()` converts to a Godot `rotation.y`.

const PACK_PATH := "res://data/ames/ames_core.json"

## The ODbL attribution obligation (ODBL-NOTE.md). Surfaces in the README
## today; the in-game credits screen lands with T-197 (R4·text-capability).
const ATTRIBUTION := "Map data © OpenStreetMap contributors"

## Coordinate constants — MUST stay equal to the pack's meta (pinned together
## by the `ames_data_integrity` sim scenario, which recomputes them from the
## closed form).
const ORIGIN_LON := -93.65015 ## Lincoln Way × Welch (survey verification §1)
const ORIGIN_LAT := 42.02278 ## Lincoln Way mean lat, Campustown window
const SCALE_LAT := 42.02 ## equirectangular scale latitude
const M_PER_DEG_LAT := 111074.0 ## survey standard at 42.02 N
const M_PER_DEG_LON := 82700.8758 ## 111320 · cos(42.02°)

static var _pack: Dictionary = {}
static var _streets: Array[Dictionary] = []
static var _buildings: Array[Dictionary] = []
static var _pois: Array[Dictionary] = []
static var _water: Array[Dictionary] = []
static var _parks: Array[Dictionary] = []
static var _parking: Array[Dictionary] = []
static var _trees: PackedVector2Array = PackedVector2Array()
static var _rail: Dictionary = {}


## Parses the committed pack (once) into typed static caches. Returns the
## whole pack Dictionary (`{}` on failure — callers must treat that as
## "no Ames world", which keeps the Windrow world the only world until R1's
## renderer lands).
static func load_pack() -> Dictionary:
	if not _pack.is_empty():
		return _pack
	var text := FileAccess.get_file_as_string(PACK_PATH)
	if text.is_empty():
		push_error("AmesDataPack: cannot read %s" % PACK_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or (parsed as Dictionary).is_empty():
		push_error("AmesDataPack: %s is not a JSON object" % PACK_PATH)
		return {}
	_pack = parsed
	_streets.clear()
	for e: Dictionary in _pack.get("streets", []):
		_streets.append(e)
	_buildings.clear()
	for e: Dictionary in _pack.get("buildings", []):
		_buildings.append(e)
	_pois.clear()
	for e: Dictionary in _pack.get("pois", []):
		_pois.append(e)
	_water.clear()
	for e: Dictionary in _pack.get("water", []):
		_water.append(e)
	_parks.clear()
	for e: Dictionary in _pack.get("parks", []):
		_parks.append(e)
	_parking.clear()
	for e: Dictionary in _pack.get("parking", []):
		_parking.append(e)
	_rail = _pack.get("rail", {})
	_trees = PackedVector2Array()
	for p: Array in _pack.get("trees", []):
		_trees.append(Vector2(p[0], p[1]))
	return _pack


static func meta() -> Dictionary:
	return load_pack().get("meta", {})


## WGS84 lon/lat -> local meters. THE transform (the GDScript twin of the
## distiller's `to_local`; constants pinned above).
static func wgs84_to_local(lon: float, lat: float) -> Vector3:
	return Vector3((lon - ORIGIN_LON) * M_PER_DEG_LON, 0.0,
			-(lat - ORIGIN_LAT) * M_PER_DEG_LAT)


## Local meters -> WGS84 lon/lat (inverse; y ignored).
static func local_to_wgs84(pos: Vector3) -> Vector2:
	return Vector2(ORIGIN_LON + pos.x / M_PER_DEG_LON,
			ORIGIN_LAT - pos.z / M_PER_DEG_LAT)


## Compass facing (0 = north, 90 = east) -> Godot yaw radians.
static func facing_to_yaw(facing_deg: float) -> float:
	return -deg_to_rad(facing_deg)


static func streets() -> Array[Dictionary]:
	load_pack()
	return _streets


static func buildings() -> Array[Dictionary]:
	load_pack()
	return _buildings


static func pois() -> Array[Dictionary]:
	load_pack()
	return _pois


## POIs of one tier. Venues carry tier 1–3; landmarks carry their "Top 15
## from the air" rank (1–15), so `kind` disambiguates ("venue" default —
## the tier concept belongs to the venue inventory).
static func pois_of(tier: int, kind: String = "venue") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in pois():
		if int(p.get("tier", -1)) == tier and str(p.get("kind", "")) == kind:
			out.append(p)
	return out


static func venues() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in pois():
		if str(p.get("kind", "")) == "venue":
			out.append(p)
	return out


static func landmarks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in pois():
		if str(p.get("kind", "")) == "landmark":
			out.append(p)
	return out


static func water() -> Array[Dictionary]:
	load_pack()
	return _water


static func rail() -> Dictionary:
	load_pack()
	return _rail


static func parks() -> Array[Dictionary]:
	load_pack()
	return _parks


## The amenity=parking stock (T-182) — the census §3 layer, distilled verbatim
## (480 areas / 73.6 ha; 19 tailgate-zone lots; the `kind` field carries the
## OSM `parking` subtype — `street_side` / `lane` are the curb bay stock).
static func parking() -> Array[Dictionary]:
	load_pack()
	return _parking


## Tree scatter seeds (x, z local meters) — 5,637 mapped `natural=tree` nodes
## (census §5); wooded polygons carry the rest.
static func trees() -> PackedVector2Array:
	load_pack()
	return _trees


static func building_by_id(id: String) -> Dictionary:
	for b: Dictionary in buildings():
		if str(b.get("id", "")) == id:
			return b
	return {}


## Nearest street centerline to a world position (y ignored). Returns
## `{}`-adjacent Dictionary `{name, class, width_m, km, distance_m, point}`
## where `point` is the closest point ON the centerline — or an empty
## Dictionary when the pack has no streets.
static func nearest_street(pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d2 := INF
	for s: Dictionary in streets():
		var pts: Array = s.get("points", [])
		for i: int in range(pts.size() - 1):
			var a: Array = pts[i]
			var b: Array = pts[i + 1]
			var ax: float = a[0]
			var az: float = a[1]
			var dx: float = b[0] - ax
			var dz: float = b[1] - az
			var l2 := dx * dx + dz * dz
			var t := 0.0
			if l2 > 1e-12:
				t = clampf(((pos.x - ax) * dx + (pos.z - az) * dz) / l2, 0.0, 1.0)
			var px := ax + t * dx
			var pz := az + t * dz
			var d2 := (pos.x - px) * (pos.x - px) + (pos.z - pz) * (pos.z - pz)
			if d2 < best_d2:
				best_d2 = d2
				best = {
					"name": s.get("name", ""),
					"class": s.get("class", ""),
					"width_m": s.get("width_m", 0.0),
					"km": s.get("km", 0.0),
					"distance_m": sqrt(d2),
					"point": Vector3(px, 0.0, pz),
				}
	return best
