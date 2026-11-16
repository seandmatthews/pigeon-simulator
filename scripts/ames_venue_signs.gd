class_name AmesVenueSigns
extends RefCounted
## The Tier-1 venue signs (T-198, R4 · the names a student says first): the
## fourteen VENUES.md §1 names mounted as real SignText signs at their verified
## positions/facings on the resident Ames world — the ticket the whole campaign
## exists for. Twelve in-core venues sign the street wall of the bake body their
## parcel anchor sits in (the Welch 100/200 blocks, the Chamberlain row, the
## Lincoln Way corner cluster, downtown Main's east end), the Superdog cart is
## the one PROP (cart + umbrella + its topper sign, not a building), Hickory
## Park's big-box pylon stands at its S Duff position out on the apron flat,
## and The Cafe's spec rides STAGED — north Ames is outside the v1 bake core,
## so its sign places when T-205 (North — Ada Hayden + The Cafe) extends the
## bake; the dependency is recorded here and in the ticket, not worked around.
##
## Every mount is a literal derived ON this ticket from the committed bake and
## survey (the derivation cited per entry), and `venue_signs_tier1` re-derives
## each one independently from the committed chunk files + the pack — a bake
## drift, a moved sign or a retyped name fails the gate the same night. The
## sign TEXTS are the VENUES.md §1 heading names byte-exact (the ticket's
## exact-match law); the forms follow the survey's exterior descriptions via
## T-197's three typology scenes plus the lettered plaque, colors are
## brand-adjacent ONLY where the description names a scheme, and no logo art
## ships anywhere (names in type only — the legal line).
##
## Mount convention: `face` selects the street wall of the pinned bake body
## (an axis-aligned AABB face — E/W faces run along z, N/S along x), the sign
## root sits one GAP off that plane proud of the wall with its text facing the
## street (`+z` on the yaw), `wall_u` is the sign center's coordinate along the
## wall, `mount_y` the center height. Free-standing forms (`pole`, `cart`)
## stand on the ground at the pack POI position, yawed onto the POI's verified
## facing (`facing_to_yaw`'s convention: the facing vector n, yaw =
## atan2(n.x, n.z) so the text face carries it). The blade reads along its
## street (text on ±x with `+z` = the wall normal), brackets into the wall.

## The three typology scenes (T-197) + the component for plaques/carts.
const SCENE_BOX: PackedScene = preload("res://scenes/sign_box.tscn")
const SCENE_BLADE: PackedScene = preload("res://scenes/sign_blade.tscn")
const SCENE_POLE: PackedScene = preload("res://scenes/sign_pole.tscn")

## The committed bake's chunk directory — the module's own twin of
## `AmesWorld.CHUNKS_DIR` (the mount table reads the bake bodies; carrying the
## path here keeps the module's dependency one-way, world → signs, the same
## law `AmesDataPack.PACK_PATH` follows).
const CHUNKS_DIR := "res://data/ames/chunks"

## Body-root standoff off the wall plane (m) — the body's back face never
## z-fights the wall; the text adds its own SignText.FACE_PROUD on top.
const WALL_GAP := 0.01
## Blade bracket tail behind the board center (m) — the rearmost bracket
## point's local −z reach (board half 0.45 + arm 0.30/2 + 0.15 = 0.75) plus
## the same clearance as WALL_GAP.
const BLADE_STANDOFF := 0.78

## --- the Superdog cart prop (VENUES 1.11: cart + umbrella, not a building) --

const CART_BODY := Vector3(1.8, 0.85, 0.9)
const CART_BODY_Y := 0.72
const CART_COUNTER := Vector3(1.95, 0.06, 1.0)
const CART_COUNTER_Y := 1.17
const CART_WHEEL_R := 0.17
const CART_WHEEL_H := 0.08
const CART_WHEELS: Array[Vector3] = [
	Vector3(0.72, CART_WHEEL_R, 0.42), Vector3(-0.72, CART_WHEEL_R, 0.42),
	Vector3(0.72, CART_WHEEL_R, -0.42), Vector3(-0.72, CART_WHEEL_R, -0.42),
]
const CART_MAST_R := 0.025
const CART_MAST_H := 1.7
const CART_MAST_Y := 1.95
const CART_CANOPY_R := 1.05
const CART_CANOPY_TOP_R := 0.12
const CART_CANOPY_H := 0.42
const CART_CANOPY_Y := 2.55
const CART_PLAQUE_Y := 1.55 ## Topper sign between the counter and the canopy.
const CART_STEEL := Color(0.72, 0.72, 0.70)
const CART_UMBRELLA_RED := Color(0.72, 0.10, 0.10)

## --- the mount table (14 entries; the texts are the VENUES §1 names) --------
##
## Derivation, per entry: the bake body (placeholder id or massing way, read
## off the committed chunks), its street-wall face, the sign center along the
## wall, the mount height, the form per the survey's exterior description and
## the letter height (the face-fit law: string width at the cap ≤ face − 0.2 —
## the overflow guard's own law, re-checked in-scenario). Colors are named
## only where VENUES names a scheme; everything else rides the typology
## defaults (alpha-0 = default to the component).
const SIGNS: Array[Dictionary] = [
	{
		"id": "welch_ave_station",
		"venue": "Welch Ave Station",
		"form": "box",
		"body": "massing:way/241365809",
		"face": "E", ## The 200-block street wall (Welch, east curb at ≈ x 6.6).
		"wall_u": 189.28, ## Face center (z span 184.88..193.68).
		"mount_y": 5.7,
		"letter": 0.80, ## 8.089 × 0.80 = 6.47 m ≤ 8.2 — the block-letter band.
		"band": Vector3(8.4, 1.3, 0.35), ## The VENUES 1.1 wide flat band.
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0, ## The night-lit box read (typology default) — the acceptance sign.
		"staged": false,
		"note": "VENUES 1.1 (207 Welch, west side, 200 block): big flat "
			+ "block-letter sign band. The parcel anchor (-35.54, 189.66) sits "
			+ "INSIDE the 200-block west-row building way/241365809 — the sign "
			+ "mounts on ITS street wall, at the anchor's own depth.",
	},
	{
		"id": "paddys_irish_pub",
		"venue": "Paddy's Irish Pub",
		"form": "box",
		"body": "placeholder:paddys_irish_pub",
		"face": "W", ## East side of Welch — the shared facade fronts west.
		"wall_u": 114.6, ## The 124 door side (Welch addresses run southward).
		"mount_y": 6.0,
		"letter": 0.30, ## 7.497 × 0.30 = 2.25 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.2 (124-126 Welch, east side): the pub is the second "
			+ "floor over Sips — two doors, one facade. The venue's own fixup "
			+ "box IS the street wall here (its west face pokes 0.17 past the "
			+ "row building behind it).",
	},
	{
		"id": "sips",
		"venue": "Sips",
		"form": "box",
		"body": "placeholder:paddys_irish_pub", ## The SHARED facade (see note).
		"face": "W",
		"wall_u": 118.6, ## The 126 door side — south of Paddy's door.
		"mount_y": 2.7, ## The below-grade stairwell door's header.
		"letter": 0.22, ## 1.890 × 0.22 = 0.42 ≤ 1.4.
		"band": Vector3(1.6, 0.7, 0.22), ## A small box over the basement door.
		"body_color": Color(0.07, 0.07, 0.08), ## The pitch-black basement read.
		"text_color": Color(0.95, 0.16, 0.12), ## The neon family (dope lights).
		"lit": 2,
		"staged": false,
		"note": "VENUES 1.4 (126 Welch basement): shares 1.2's facade — model "
			+ "ONE building with two doors. The pack POI's facing "
			+ "(nearest_street:Chamberlain, 181.3 deg) is the basement node's "
			+ "survey artifact; the documented mount is the shared Welch wall, "
			+ "south door. this entry is the one deliberate override.",
	},
	{
		"id": "cys_roost",
		"venue": "Cy's Roost",
		"form": "blade",
		"body": "massing:way/241365820",
		"face": "E", ## West side of Welch.
		"wall_u": 92.24,
		"mount_y": 6.4, ## At the parapet line of the 8 m skinny slot.
		"letter": 0.15, ## 10 stacked lines x 1.6667 x 0.15 = 2.50 ≤ 2.6 board.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.3 (121 Welch): flat parapet, the Roost sign stacked "
			+ "vertically — the projecting blade reads it down the street; the "
			+ "letter height is the board-fit tune (stack height = 16.667 x "
			+ "letter for the ten lines, measured in-engine).",
	},
	{
		"id": "mickeys_irish_pub",
		"venue": "Mickey's Irish Pub",
		"form": "box",
		"body": "placeholder:mickeys_irish_pub",
		"face": "E", ## West side of Welch, first bar off campus.
		"wall_u": 46.32,
		"mount_y": 4.2, ## The low pub storefront band.
		"letter": 0.30, ## 7.986 × 0.30 = 2.40 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.055, 0.14, 0.09), ## VENUES 1.5 dark green/black.
		"text_color": Color(0.93, 0.91, 0.86),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.5 (109 Welch): low Irish-pub storefront, dark "
			+ "green/black paint scheme — the genre palette is the description.",
	},
	{
		"id": "ajs_ultra_lounge",
		"venue": "AJ's Ultra Lounge",
		"form": "box",
		"body": "massing:way/246079558",
		"face": "S", ## The entrance faces Chamberlain (VENUES 1.6).
		"wall_u": 113.55,
		"mount_y": 7.5, ## The second-level entry band on the 11 m box.
		"letter": 0.30, ## 7.536 × 0.30 = 2.26 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.09, 0.07, 0.10), ## The pitch-black abyss read.
		"text_color": Color(0.95, 0.16, 0.12),
		"lit": 2,
		"staged": false,
		"note": "VENUES 1.6 (2401 Chamberlain): stair/second-level entry, "
			+ "rooftop patio — the club signs its upper band, black + neon.",
	},
	{
		"id": "outlaws",
		"venue": "Outlaws",
		"form": "box",
		"body": "massing:way/272522425",
		"face": "N", ## The Chamberlain back-street line.
		"wall_u": -89.8,
		"mount_y": 5.8,
		"letter": 0.30, ## 3.562 × 0.30 = 1.07 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.48, 0.12, 0.09), ## The painted-country barn read.
		"text_color": Color(0.93, 0.90, 0.82),
		"lit": 1, ## Painted, not lit — the big painted-country sign.
		"staged": false,
		"note": "VENUES 1.7 (2522 Chamberlain): slim vertical bar box with a "
			+ "big painted-country sign — painted means the lit box OFF.",
	},
	{
		"id": "cafe_beaudelaire",
		"venue": "Café Beaudelaire",
		"form": "box",
		"body": "placeholder:cafe_beaudelaire",
		"face": "N", ## South side of Lincoln Way at the Welch corner.
		"wall_u": -21.5, ## Nudged east: the band's west end clears the
			## overlapping Mr. Burrito fixup box (the two parcel boxes lap).
		"mount_y": 5.6,
		"letter": 0.30, ## 7.536 × 0.30 = 2.26 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.55, 0.10, 0.09), ## The lit corner counter's red.
		"text_color": Color(0.95, 0.93, 0.88),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.8 (2504 Lincoln Way): the lit corner at the head of "
			+ "the strip — neon-ish signage band, lit.",
	},
	{
		"id": "jeffs_pizza_shop",
		"venue": "Jeff's Pizza Shop",
		"form": "box",
		"body": "massing:way/236800163",
		"face": "N", ## South side of Lincoln Way, east of Welch.
		"wall_u": 118.25,
		"mount_y": 5.4, ## The storefront strip under the apartment frontage.
		"letter": 0.30, ## 7.176 × 0.30 = 2.15 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.62, 0.12, 0.10),
		"text_color": Color(0.95, 0.93, 0.88),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.9 (2402 Lincoln Way): storefront strip under the "
			+ "student-apartment frontage — the parcel anchor sits inside the "
			+ "34 m Lincoln Way row building way/236800163, at its street wall.",
	},
	{
		"id": "mr_burrito",
		"venue": "Mr. Burrito",
		"form": "box",
		"body": "placeholder:mr_burrito",
		"face": "N", ## Two doors west of Café B, same corner cluster.
		"wall_u": -29.69,
		"mount_y": 5.2, ## The small glowing storefront, a step lower.
		"letter": 0.28, ## 4.810 × 0.28 = 1.35 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.10, 0.28, 0.16), ## The family-Mexican green.
		"text_color": Color(0.95, 0.55, 0.10),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.10 (2508 Lincoln Way): small glowing storefront, "
			+ "hand-painted-style sign — the lit island in the dark block.",
	},
	{
		"id": "superdog",
		"venue": "Superdog",
		"form": "cart",
		"body": "", ## A PROP at the pack POI (the one moving venue on Welch).
		"face": "poi", ## Yaw carries the POI's verified facing (279.4 deg).
		"wall_u": 0.0,
		"mount_y": 0.0,
		"letter": 0.16, ## The cart topper's sidewalk-scale read (22.4 m).
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.11 (208 Welch): a rolling cart with umbrella and "
			+ "steam — model as a reusable prop. Cart + red umbrella + the "
			+ "cream topper sign, parked at the pack's hand-placed east-curb "
			+ "position, facing the street. (The 200 block maps as a divided "
			+ "two-carriageway section through z 150..185; the pack position "
			+ "sits at the east carriageway's curb — the pack placement is the "
			+ "verified one and stands as placed.)",
	},
	{
		"id": "hickory_park",
		"venue": "Hickory Park",
		"form": "pole",
		"body": "", ## No baked body — the S Duff position is on the apron flat.
		"face": "poi",
		"wall_u": 0.0,
		"mount_y": 0.0,
		"letter": 0.40, ## 5.697 × 0.40 = 2.28 ≤ 2.4 cabinet face.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.12 (1404 S Duff): freestanding big-box restaurant in "
			+ "a sea of parking — the big roadside pylon signs the position "
			+ "now. The POI's S Duff spot sits past the v1 bake's south-east "
			+ "corner (the pack's S Duff polyline ends ≈240 m short of it, "
			+ "tile (13,5) unbaked): the pylon stands the apron flat at the "
			+ "verified position, yawed onto its verified facing — the "
			+ "building itself lands with the R5 east extension (T-203).",
	},
	{
		"id": "the_cafe",
		"venue": "The Cafe",
		"form": "plaque",
		"body": "", ## STAGED ONLY — north Ames is outside the v1 bake core.
		"face": "poi",
		"wall_u": 0.0,
		"mount_y": 5.4,
		"letter": 0.16, ## 3.858 × 0.16 = 0.62 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": true,
		"note": "VENUES 1.13 (2616 Northridge Pkwy): NORTH Ames near the "
			+ "research park — the honest dependency: the v1 bake core ends "
			+ "long south of it (tile (2,-12) unbaked, ≈2.6 km north of the "
			+ "origin), so the sign stages ready here and PLACES when T-205 "
			+ "(North — Ada Hayden + The Cafe) extends the bake. NOT a south-"
			+ "east slot: The Cafe is north, the ticket's own correction.",
	},
	{
		"id": "great_plains_sauce_dough",
		"venue": "Great Plains Sauce & Dough Co.",
		"form": "plaque",
		"body": "massing:way/237834141",
		"face": "W", ## The Douglas street wall of the Main row block.
		"wall_u": -287.52, ## GP's own address depth along the shared wall.
		"mount_y": 5.4,
		"letter": 0.18, ## 14.146 × 0.18 = 2.55 ≤ 2.6 (the widened board).
		"band": Vector3(2.8, 0.6, 0.1), ## The painted signboard, one size up.
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.14 (129 Main, north side at the Douglas corner): "
			+ "classic downtown brick storefront with a painted signboard — "
			+ "the lettered plaque IS the signboard (T-090's slab, cream/ink "
			+ "defaults). The pack facing points at Douglas (the survey's "
			+ "nearest street); VENUES reads the storefront on Main's wall — "
			+ "the pack's verified facing carries the ticket. Wall note: GP's "
			+ "own bake massing (way/237834149) INTERLEAVES with the row "
			+ "neighbor way/237834141 (their AABBs overlap by 0.63 m), so "
			+ "GP's west face is buried inside the block — the signboard "
			+ "hangs on the block's Douglas street wall at GP's address "
			+ "depth, the continuous-Main-Street-wall read VENUES describes.",
	},
]

## The Tier-1 count the ticket names (the scenario pins the table's shape).
const TIER1_COUNT := 14


## Builds the PLACED signs under `root` (a plain Node3D — the world supplies
## it) and returns one record per placed sign for the gate + the world report:
## {id, venue, form, pos, yaw, node, cart} — pack-frame coordinates (the world
## node IS the pack frame). Staged entries (The Cafe) build nothing.
static func build(root: Node3D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for entry: Dictionary in SIGNS:
		if bool(entry["staged"]):
			continue
		var sign: SignText
		var pos := Vector3.ZERO
		var yaw := 0.0
		match str(entry["form"]):
			"cart":
				var cart := _build_cart(root, entry)
				sign = cart["sign"]
				pos = cart["pos"]
				yaw = float(cart["yaw"])
				var rec := _record(entry, sign, pos, yaw)
				rec["cart"] = true
				rec["cart_parts"] = int(cart["parts"])
				records.append(rec)
				continue
			"box":
				sign = SCENE_BOX.instantiate() as SignText
			"blade":
				sign = SCENE_BLADE.instantiate() as SignText
			"pole":
				sign = SCENE_POLE.instantiate() as SignText
			_:
				sign = SignText.new()
				sign.typology = SignText.Typology.PLAQUE
		var mount := _mount(entry)
		pos = mount[0]
		yaw = mount[1]
		_dress(sign, entry)
		sign.name = "Sign_%s" % entry["id"]
		sign.position = pos
		sign.rotation = Vector3(0.0, yaw, 0.0)
		root.add_child(sign)
		records.append(_record(entry, sign, pos, yaw))
	return records


## One mount record (the gate's read; node kept live for the tree walk).
static func _record(entry: Dictionary, sign: SignText, pos: Vector3,
		yaw: float) -> Dictionary:
	return {
		"id": entry["id"],
		"venue": entry["venue"],
		"form": entry["form"],
		"body": entry["body"],
		"face": entry["face"],
		"wall_u": entry["wall_u"],
		"mount_y": entry["mount_y"],
		"letter": entry["letter"],
		"band": entry["band"],
		"staged": false,
		"note": entry["note"],
		"pos": pos,
		"yaw": yaw,
		"node": sign,
	}


## The mount transform for a table entry: the wall-face standoff for the AABB
## faces, or the ground at the POI for the free-standing forms. Returns
## [Vector3 position, float yaw]. Yaw law: the text face (+z local) carries
## the street-facing normal n — yaw = atan2(n.x, n.z).
static func _mount(entry: Dictionary) -> Array:
	var face := str(entry["face"])
	if face == "poi":
		var poi := _poi(entry["id"])
		var n := _facing_normal(float(poi["facing_deg"]))
		return [Vector3(float(poi["position"][0]), 0.0,
				float(poi["position"][1])), atan2(n.x, n.z)]
	var size := _band_size(entry)
	var stand := size.z * 0.5 + WALL_GAP
	if str(entry["form"]) == "blade":
		stand = BLADE_STANDOFF ## The bracket tail clears the wall, not the board.
	var u := float(entry["wall_u"])
	var y := float(entry["mount_y"])
	match face:
		"E":
			var x := _face_plane(entry) + stand
			return [Vector3(x, y, u), atan2(1.0, 0.0)]
		"W":
			var x := _face_plane(entry) - stand
			return [Vector3(x, y, u), atan2(-1.0, 0.0)]
		"N":
			var z := _face_plane(entry) - stand
			return [Vector3(u, y, z), atan2(0.0, -1.0)]
		_:
			var z := _face_plane(entry) + stand
			return [Vector3(u, y, z), atan2(0.0, 1.0)]


## The pinned street-wall plane coordinate of the entry's bake body (the AABB
## face the sign hangs on; the blade adds its bracket standoff on top).
## The gate re-derives these planes from the committed chunk files.
static func _face_plane(entry: Dictionary) -> float:
	var selector := str(entry["body"])
	var parts := selector.split(":")
	var body := _bake_body(parts[0], parts[1])
	var p: Array = body["p"]
	var s: Array = body["s"]
	match str(entry["face"]):
		"E":
			return float(p[0]) + float(s[0]) * 0.5
		"W":
			return float(p[0]) - float(s[0]) * 0.5
		"N":
			return float(p[2]) - float(s[2]) * 0.5
		_:
			return float(p[2]) + float(s[2]) * 0.5


## The bake body record (placeholder or massing) by selector — the committed
## chunk documents hold it; walks every chunk file once and caches.
static var _bake_cache: Dictionary = {}


static func _bake_body(kind: String, id: String) -> Dictionary:
	if _bake_cache.is_empty():
		var manifest: Dictionary = AmesBaker.read_manifest(CHUNKS_DIR)
		for chunk_entry: Dictionary in manifest.get("chunks", []):
			var doc: Dictionary = AmesBaker.read_chunk(CHUNKS_DIR,
					str(chunk_entry["file"]))
			for ph: Dictionary in doc.get("placeholders", []):
				_bake_cache["placeholder:%s" % str(ph.get("id", ""))] = ph
			for m: Dictionary in doc.get("massing", []):
				_bake_cache["massing:%s" % str(m.get("id", ""))] = m
	if not _bake_cache.has("%s:%s" % [kind, id]):
		push_error("AmesVenueSigns: bake body %s:%s not found" % [kind, id])
		return {}
	return _bake_cache["%s:%s" % [kind, id]]


## The entry's body dims (the band override or the typology default).
static func _band_size(entry: Dictionary) -> Vector3:
	var band: Vector3 = entry["band"]
	if band != Vector3.ZERO:
		return band
	var typology := _typology_of(entry)
	return SignText.SPEC[typology]["body"] as Vector3


## The SignText typology a table form rides.
static func _typology_of(entry: Dictionary) -> int:
	match str(entry["form"]):
		"box":
			return SignText.Typology.BOX
		"blade":
			return SignText.Typology.BLADE
		"pole":
			return SignText.Typology.POLE
		_:
			return SignText.Typology.PLAQUE


## Applies the entry's tuning to a sign before it enters the tree (the
## component builds in _ready, so every export lands first).
static func _dress(sign: SignText, entry: Dictionary) -> void:
	sign.typology = _typology_of(entry)
	sign.text = str(entry["venue"])
	sign.letter_height = float(entry["letter"])
	var band: Vector3 = entry["band"]
	if band != Vector3.ZERO:
		sign.body_scale = band
	var body_col: Color = entry["body_color"]
	if body_col.a > 0.0:
		sign.body_color = body_col
	var text_col: Color = entry["text_color"]
	if text_col.a > 0.0:
		sign.text_color = text_col
	sign.lit_mode = int(entry["lit"])


## The compass facing vector n (0 = north (-z), 90 = east (+x)).
static func _facing_normal(facing_deg: float) -> Vector3:
	var rad := deg_to_rad(facing_deg)
	return Vector3(sin(rad), 0.0, -cos(rad))


## The pack POI record for a venue id (positions/facings stay data, never
## retyped here).
static func _poi(id: String) -> Dictionary:
	for p: Dictionary in AmesDataPack.pois():
		if str(p.get("id", "")) == id:
			return p
	push_error("AmesVenueSigns: pack POI %s not found" % id)
	return {}


## The Superdog cart prop (VENUES 1.11): steel body on four wheels, counter
## top, the red umbrella on its mast, and the cream topper sign carrying the
## name. Visual-only (the T-197 scope guard — the signs carry no colliders and
## the cart that hosts one doesn't either). Returns {sign, pos, yaw, parts}.
static func _build_cart(root: Node3D, entry: Dictionary) -> Dictionary:
	var poi := _poi(entry["id"])
	var n := _facing_normal(float(poi["facing_deg"]))
	var yaw := atan2(n.x, n.z)
	var cart := Node3D.new()
	cart.name = "Cart_%s" % entry["id"]
	cart.position = Vector3(float(poi["position"][0]), 0.0,
			float(poi["position"][1]))
	cart.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(cart)
	var parts := 0
	parts += _cart_box(cart, "Body", CART_BODY,
			Vector3(0.0, CART_BODY_Y, 0.0), CART_STEEL)
	parts += _cart_box(cart, "Counter", CART_COUNTER,
			Vector3(0.0, CART_COUNTER_Y, 0.0),
			CART_STEEL.lerp(Color(0.85, 0.83, 0.78), 0.5))
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.25, 0.25, 0.27)
	for i: int in CART_WHEELS.size():
		var wheel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = CART_WHEEL_R
		mesh.bottom_radius = CART_WHEEL_R
		mesh.height = CART_WHEEL_H
		mesh.material = steel
		wheel.name = "Wheel%d" % (i + 1)
		wheel.mesh = mesh
		wheel.position = CART_WHEELS[i]
		wheel.rotation = Vector3(0.0, 0.0, PI * 0.5) ## Axis along x.
		cart.add_child(wheel)
		parts += 1
	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = CART_MAST_R
	mast_mesh.bottom_radius = CART_MAST_R
	mast_mesh.height = CART_MAST_H
	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.25, 0.25, 0.27)
	mast_mesh.material = mast_mat
	mast.name = "Mast"
	mast.mesh = mast_mesh
	mast.position = Vector3(0.0, CART_MAST_Y, 0.0)
	cart.add_child(mast)
	parts += 1
	var canopy := MeshInstance3D.new()
	var canopy_mesh := CylinderMesh.new() ## The cone-frustum umbrella read.
	canopy_mesh.top_radius = CART_CANOPY_TOP_R
	canopy_mesh.bottom_radius = CART_CANOPY_R
	canopy_mesh.height = CART_CANOPY_H
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = CART_UMBRELLA_RED
	canopy_mat.roughness = 0.8
	canopy_mesh.material = canopy_mat
	canopy.name = "Canopy"
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, CART_CANOPY_Y, 0.0)
	cart.add_child(canopy)
	parts += 1
	var sign: SignText = SignText.new()
	_dress(sign, entry)
	sign.name = "Sign_%s" % entry["id"]
	sign.position = Vector3(0.0, CART_PLAQUE_Y, 0.0)
	cart.add_child(sign)
	return {"sign": sign, "pos": cart.position, "yaw": yaw, "parts": parts}


## One named cart part box; returns 1 so the caller can count parts.
static func _cart_box(parent: Node3D, part_name: String, size: Vector3,
		pos: Vector3, col: Color) -> int:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	mesh.material = mat
	part.name = part_name
	part.mesh = mesh
	part.position = pos
	parent.add_child(part)
	return 1
