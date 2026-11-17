extends SceneTree
## (T-201 diagnostic) Derives the campus-plaque mount table from the resident
## world: each hero's built part-record union AABB + the individual part boxes
## (so a plaque wall_u/mount_y can be picked on REAL wall geometry), the
## committed bake bodies for the hero slots, and the Oswald string widths of
## the candidate plaque texts at the planned letter heights. Run:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/probe_campus_plaques.gd

const WORLD_SCENE: PackedScene = preload("res://scenes/ames_world.tscn")

## hero key -> [record array property name, hero tag ("" = the whole array)]
const HEROES: Dictionary = {
	"campanile": ["campanile_hero_parts", ""],
	"beardshear": ["campus_row_hero_parts", "beardshear"],
	"morrill": ["campus_row_hero_parts", "morrill"],
	"farm_house": ["campus_row_hero_parts", "farm_house"],
	"mu": ["mu_parks_hero_parts", "memorial_union"],
	"parks": ["mu_parks_hero_parts", "parks_library"],
	"marston_tower": ["marston_hero_parts", ""],
	"jack_trice": ["stadium_hero_parts", ""],
	"hilton": ["hilton_hero_parts", ""],
	"city_hall": ["civic_hero_parts", "cityhall"],
	"depot": ["depot_hero_parts", ""],
}

## The committed bake body ids (massing/placeholder) the heroes superseded.
const BAKE_IDS: Dictionary = {
	"campanile": "way/183041212",
	"beardshear": "way/33725619",
	"morrill": "way/158023244",
	"farm_house": "way/158023219",
	"mu": "way/183224150",
	"parks": "way/33725897",
	"marston_tower": "way/861201396",
	"jack_trice": "way/613735866",
	"hilton": "way/180651868",
	"city_hall": "relation/2560369",
	"depot": "way/260524827",
}

## The candidate texts — name (+ year) only, the survey's pinned years.
const TEXTS: Array[String] = [
	"Campanile — 1897",
	"Beardshear Hall — 1906",
	"Morrill Hall — 1891",
	"Farm House — 1860–61",
	"Memorial Union — 1928",
	"Parks Library — 1925",
	"Marston Water Tower — 1897",
	"Jack Trice Stadium — 1975",
	"Hilton Coliseum — 1971",
	"Ames City Hall",
	"Ames Depot — 1906",
	"Reiman Gardens — 1995",
]


func _init() -> void:
	## 1. The committed bake bodies for the hero slots (ALL parts per id —
	## hero slots carry placeholder stacks: block/dome/canopy parts).
	var manifest: Dictionary = AmesBaker.read_manifest(AmesWorld.CHUNKS_DIR)
	var bake: Dictionary = {}
	for entry: Dictionary in manifest.get("chunks", []):
		var doc: Dictionary = AmesBaker.read_chunk(AmesWorld.CHUNKS_DIR,
				str(entry["file"]))
		for m: Dictionary in doc.get("massing", []):
			bake.get_or_add(str(m.get("id", "")), []).append(m)
		for ph: Dictionary in doc.get("placeholders", []):
			bake.get_or_add(str(ph.get("id", "")), []).append(ph)
	## 2. The resident world with its heroes built.
	var world := WORLD_SCENE.instantiate() as AmesWorld
	get_root().add_child(world)
	for i: int in 30:
		await process_frame
		if not world.last_report.is_empty():
			break
	print("world report ready: %s" % [not world.last_report.is_empty()])
	## 3. Per hero: the built union AABB + the individual boxes near ground.
	for key: String in HEROES:
		var arr: Array = world.get(str(HEROES[key][0]))
		var tag := str(HEROES[key][1])
		var u := AABB()
		var first := true
		var parts: Array[Dictionary] = []
		for part: Dictionary in arr:
			if tag != "" and str(part.get("hero", "")) != tag:
				continue
			var p: Vector3 = part["p"]
			var s: Vector3 = part["s"]
			var box := AABB(p - s * 0.5, s)
			u = box if first else u.merge(box)
			first = false
			## Only wall-class boxes tall enough to host a plaque (ground
			## contact or near it, height >= 2.5).
			if s.y >= 2.5:
				parts.append(part)
		parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a["p"]) < str(b["p"]))
		print("%s hero_union min=%s max=%s size=%s" % [key, u.position, u.end, u.size])
		for part: Dictionary in parts:
			var p2: Vector3 = part["p"]
			var s2: Vector3 = part["s"]
			print("    box band=%-14s min=(%.2f, %.2f, %.2f) max=(%.2f, %.2f, %.2f)" % [
					str(part["band"]), p2.x - s2.x * 0.5, p2.y - s2.y * 0.5,
					p2.z - s2.z * 0.5, p2.x + s2.x * 0.5, p2.y + s2.y * 0.5,
					p2.z + s2.z * 0.5])
		for bp: Dictionary in bake.get(str(BAKE_IDS[key]), []):
			print("    bake p=%s s=%s" % [bp.get("p"), bp.get("s")])
	## 4. The Oswald widths: metres at the planned letter heights.
	print("--- text widths (Oswald, cap-true) ---")
	for t: String in TEXTS:
		var wpx := SignText.FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT,
				-1, SignText.FONT_SIZE_PX).x
		var k := wpx / (float(SignText.FONT_SIZE_PX) * SignText.CAP_HEIGHT_EM)
		print("  '%s'  k=%.3f m per letter-m  (w@0.18=%.2f w@0.22=%.2f w@0.28=%.2f)"
				% [t, k, k * 0.18, k * 0.22, k * 0.28])
	quit(0)
