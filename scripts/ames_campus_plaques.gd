class_name AmesCampusPlaques
extends RefCounted
## The Ames campus + civic name plaques (T-201, R4 · the names): the pinned
## building list's NOMINATIVE name plaques, mounted on the R3 heroes the
## resident world actually builds. THE LEGAL LINE, pinned in code and review:
## a plaque reads "Beardshear Hall" (full stop) — the building NAME in plain
## type on the T-090 cream slab, the survey's own completion year allowed as
## historical fact ("Beardshear Hall — 1906"), and NOTHING else: no university
## wordmark, no Cy, no athletics marks, no logo shields, no railroad brands
## (the depot reads "Ames Depot", never "C&NW Depot"). The gate machine-reads
## the excluded-mark list off every text and the geometry itself stays
## plain (one slab + one type face — a logo shield would be a second mesh,
## which the PLAQUE typology cannot produce).
##
## Every mount derives from the LIVE hero part records (`AmesWorld`'s
## `*_hero_parts` arrays — the geometry the player actually flies past, not
## the superseded bake slots), probed on 2026-11-16 with
## `tools/probe_campus_plaques.gd`: each entry pins the wall face PLANE the
## plaque hangs on, its along-wall station, its mount height and its letter
## height (the face-fit law: string width at the cap ≤ face − 0.2), and the
## gate re-derives all of it against the same records — the wall-exists leg
## (the point behind the slab is inside a real hero box), the clip leg (no
## hero box penetrates the slab's own volume — the Beardshear column law),
## the span/top legs and the legibility budget. Reiman Gardens placed with
## T-204 (the bbox south brought the POI in-core and the ticket built the
## conservatory hero its plaque hangs on); The Cafe remains the honest
## staged spec (T-198's staging note names T-205).
##
## Mount convention: wall plaques hang one GAP off their pinned plane with
## the type face reading away from the wall (`face` E/W/N/S of the hero's
## footprint; `plane` is the wall coordinate, `wall_u` the station along it,
## `mount_y` the slab center). The Marston Water Tower is the one free-
## standing entry: its hero is a steel trestle + tank with no wall to hang
## on, so its plaque rides the real ISU-marker form (a base marker on a post
## east of the tower, facing Marston Court — `face: "marker"`).

## The T-090 cream slab (the PLAQUE typology's own body) — plaques stay the
## typology defaults (cream over dark ink, unlit), never a brand color.
const WALL_GAP := 0.01 ## Slab-root standoff off the pinned wall plane (m).

## --- the base marker (the Marston free-standing form) ------------------------

const MARKER_Y := 1.6 ## Marker plaque center height (m).
const MARKER_POST_H := 1.35 ## The post reaches the slab's bottom edge.
const MARKER_POST_THICK := 0.12
const MARKER_POST_COLOR := Color(0.25, 0.25, 0.28) ## The T-134 post gray.

## --- the plaque table (the ticket's pinned building list) --------------------
##
## Fields: `text` = name (+ " — year") only (the year only where the survey
## pins one); `hero` = the world part-record key (the mount law's subject);
## `face`/`plane`/`wall_u`/`mount_y` = the wall mount; `letter` the cap
## height; `band` the slab override (ZERO = the typology's 2.2 × 0.5 × 0.08);
## `staged` entries build nothing. Years, per the survey (LANDMARKS unless
## noted): Campanile 1897 · Beardshear 1906 ("completed 1906") · Morrill 1891
## · Farm House 1860–61 ("Built 1860–61") · MU 1928 · Parks 1925 · Marston
## 1897 · Jack Trice 1975 · Hilton 1971 · depot 1906 (MODELING-SPECS §1.8,
## "the 1906 C&NW depot" — the BRAND stays off the text) · Reiman 1995 ·
## City Hall name-only (the survey pins no completion year — the ticket's
## "may appear" law leaves it off rather than inventing one).
const PLAQUES: Array[Dictionary] = [
	{
		"id": "campanile",
		"text": "Campanile — 1897",
		"hero": "campanile",
		"face": "S", ## The plinth's plain brick face, toward the MU approach.
		"plane": -291.08, ## The plinth box south face (c.y + 3.35).
		"wall_u": 340.17, ## The footprint center.
		"mount_y": 1.1, ## On the 2.0 m plinth, clear of the trim ring (y ≤ 0.25).
		"letter": 0.22, ## 8.668 × 0.22 = 1.91 ≤ 2.0 — the slab face-fit.
		"band": Vector3.ZERO,
		"staged": false,
		"note": "LANDMARKS C1 (built 1897, 33.5 m on the 16×16 ft base). The "
			+ "hero's entrance arch owns the WEST face (T-186's schedule), so "
			+ "the plaque takes the plinth's plain south face at the "
			+ "footprint center, under the shaft (the probe's box walk).",
	},
	{
		"id": "beardshear",
		"text": "Beardshear Hall — 1906",
		"hero": "beardshear",
		"face": "E", ## The lawn frontage — the dome's entrance side (C3).
		"plane": 164.96, ## The portico pavilion face (ex + 2.2, T-188).
		"wall_u": -378.61, ## The entry bay center (the portico's own z).
		"mount_y": 5.4, ## ABOVE the entry door slab (its glass tops 4.1),
			## flanked clear of the columns (their inner faces ±1.1 from u).
		"letter": 0.16, ## 11.278 × 0.16 = 1.80 ≤ 2.0 — the column gap law.
		"band": Vector3.ZERO,
		"staged": false,
		"note": "LANDMARKS C3 (completed 1906, the green dome over the EAST "
			+ "entrance). The portico carries 4 columns (9 m, z −383.71 and "
			+ "−377.41 faces) flanking the entry door slab (z −379.71..−377.51, "
			+ "to 4.1 m): between-column gaps are 1.9 m — under the slab — so "
			+ "the plaque hangs above the door on the pavilion face, the "
			+ "carved-name position the real facade uses.",
	},
	{
		"id": "morrill",
		"text": "Morrill Hall — 1891",
		"hero": "morrill",
		"face": "W", ## The campus E row fronts the quad on its west wall.
		"plane": 158.03, ## The hero brick box west face (the probe's walk).
		"wall_u": -494.61, ## The footprint center.
		"mount_y": 2.2, ## On the 9.6 m wall, below the slate roof band.
		"letter": 0.22, ## 9.041 × 0.22 = 1.99 ≤ 2.0 — the slab face-fit.
		"band": Vector3.ZERO,
		"staged": false,
		"note": "LANDMARKS C8 (built 1891, second-oldest). The west wall is "
			+ "the quad-facing street wall (C8's Central Campus E row read); "
			+ "the T-188 turret rides the SE corner, clear of the patch.",
	},
	{
		"id": "farm_house",
		"text": "Farm House — 1860–61",
		"hero": "farm_house",
		"face": "S", ## The main block's south gable wall, next to the wing.
		"plane": -483.76, ## The main brick box south face.
		"wall_u": 504.9, ## The 4.9 m strip west of the south wing (x ≤ 507.42).
		"mount_y": 2.9, ## 1.5 above the knoll top (1.4) — porch-eye height.
		"letter": 0.16, ## 11.188 × 0.16 = 1.79 ≤ 2.0 — the slab face-fit.
		"band": Vector3.ZERO,
		"staged": false,
		"note": "LANDMARKS C9 (built 1860–61, NHL 1966). The real front porch "
			+ "owns the west face (the probe's porch-post row + the door/window "
			+ "trim crowd it — no 2.2 m clear patch between the posts), so the "
			+ "plaque takes the main block's south wall in the strip the south "
			+ "wing leaves open (the wing starts at x 507.42).",
	},
	{
		"id": "mu",
		"text": "Memorial Union — 1928",
		"hero": "mu",
		"face": "S", ## Lincoln Way — the front door of campus (2229 Lincoln Way).
		"plane": -43.56, ## The entry apron's OWN proud face (the apron box
			## reaches 0.02 past the main block's −43.58 — the clip law mounts
			## on the outermost face).
		"wall_u": 313.02, ## The entry bay under the corner tower (the apron).
		"mount_y": 2.4, ## On the 4.6 m entry apron band.
		"letter": 0.22, ## 11.150 × 0.22 = 2.45 ≤ 2.6 — the widened slab.
		"band": Vector3(2.8, 0.6, 0.1),
		"staged": false,
		"note": "LANDMARKS C5 (opened Sept 23, 1928; 2229 Lincoln Way at "
			+ "Morrill/Lynn). The T-189 entry apron (x 311.52..314.52, to 4.6 m, "
			+ "proud 0.02 of the main block) IS the entrance bay — the plaque "
			+ "rides the apron's own outer face (−43.56), the plane the clip "
			+ "law mounts on.",
	},
	{
		"id": "parks",
		"text": "Parks Library — 1925",
		"hero": "parks",
		"face": "E", ## The entry bay facing Morrill Rd / the campanile axis.
		"plane": 157.4, ## The entry bay's outer door-slab face (probe walk).
		"wall_u": -593.85, ## The bay's own z center.
		"mount_y": 2.6, ## On the 5.5 m entry slab, above eye height.
		"letter": 0.22, ## 9.928 × 0.22 = 2.18 ≤ 2.6 — the widened slab.
		"band": Vector3(2.8, 0.6, 0.1),
		"staged": false,
		"note": "LANDMARKS C4 (the 1925 limestone original, named Parks 1984). "
			+ "The T-189 east entry bay (z −595.55..−592.15) faces the "
			+ "campanile axis across the lawn; the plaque rides the bay's "
			+ "outermost face (the door slab reaching x 157.40).",
	},
	{
		"id": "marston_tower",
		"text": "Marston Water Tower — 1897",
		"hero": "marston_tower",
		"face": "marker", ## Free-standing: no wall on a trestle + tank.
		"plane": 0.0,
		"wall_u": 0.0,
		"mount_y": MARKER_Y,
		"marker_pos": Vector3(-42.5, MARKER_Y, -467.96), ## East of the hero
			## union (its east legs reach x −43.83), on the Marston Court side.
		"letter": 0.16, ## 13.452 × 0.16 = 2.15 ≤ 2.2 — the widened slab.
		"band": Vector3(2.4, 0.5, 0.08),
		"staged": false,
		"note": "LANDMARKS C2 (erected 1897, NRHP; the ISU landscape marker "
			+ "30-01 the survey cites IS a base marker). The hero is trestle "
			+ "legs + braces + the tank — nothing hangs on it — so the plaque "
			+ "is the marker form: a post east of the tower, facing Marston "
			+ "Court (the POI's Bissell facing is the nearest-street "
			+ "artifact; the court is east).",
	},
	{
		"id": "jack_trice",
		"text": "Jack Trice Stadium — 1975",
		"hero": "jack_trice",
		"face": "W", ## University Blvd — the stadium's frontage side (C6).
		"plane": 1100.74, ## The OUTERMOST west face: the bowl band boxes reach
			## 0.05 west of the press tower base (the probe's walk).
		"wall_u": 997.23, ## The west press tower's own z center.
		"mount_y": 3.0, ## On the press tower's concrete base (0..12 m).
		"letter": 0.20, ## 12.281 × 0.20 = 2.46 ≤ 2.6 — the widened slab.
		"band": Vector3(2.8, 0.6, 0.1),
		"staged": false,
		"note": "LANDMARKS C6 (opened Sept 20, 1975 as Cyclone Stadium, "
			+ "renamed 1997 — the name is the nomination story, nominative). "
			+ "The west face fronts University Blvd; the plaque hangs on the "
			+ "press tower base at the sideline center. No athletics marks "
			+ "anywhere — the plain name is the whole legal point here.",
	},
	{
		"id": "hilton",
		"text": "Hilton Coliseum — 1971",
		"hero": "hilton",
		"face": "E", ## The T-191 east entry portico face (the seal side).
		"plane": 1340.97, ## The drum boxes' east face (the probe's walk).
		"wall_u": 197.47, ## The portico pair's center (posts at z 186.42/208.52).
		"mount_y": 3.0, ## Under the seal medallion (y 11.4..14.6), inside the
			## portico's 22 m bay.
		"letter": 0.22, ## 10.931 × 0.22 = 2.40 ≤ 2.6 — the widened slab.
		"band": Vector3(2.8, 0.6, 0.1),
		"staged": false,
		"note": "LANDMARKS C7 (opened Dec 2, 1971). The T-191 east entry "
			+ "portico carries the seal silhouette at 11.4 m; the plaque rides "
			+ "the drum face under it, between the portico posts — the plain "
			+ "name, no athletics marks.",
	},
	{
		"id": "city_hall",
		"text": "Ames City Hall",
		"hero": "city_hall",
		"face": "E", ## The Clark face (the T-192 cartouche entry's face).
		"plane": 2720.58, ## The civic brick box east face.
		"wall_u": -405.0, ## NORTH of the cartouche (z −402.27..−393.27) —
			## a 1.6 m clear gap keeps both reads separate.
		"mount_y": 2.2, ## On the 14 m brick block, beside the entry stone.
		"letter": 0.22, ## 6.546 × 0.22 = 1.44 ≤ 2.0 — the slab face-fit.
		"band": Vector3.ZERO,
		"staged": false,
		"note": "LANDMARKS T3 (City Hall, 515 Clark Ave, in the Main Street "
			+ "Historic District). The survey pins NO completion year — the "
			+ "ticket's \"dates may appear\" law leaves it OFF rather than "
			+ "inventing one: the text is the name alone. The plaque rides the "
			+ "cartouche's face north of the T-192 entry stone.",
	},
	{
		"id": "depot",
		"text": "Ames Depot — 1906",
		"hero": "depot",
		"face": "S", ## The TRACK face (T-194's correction: the Clinton main
			## is SOUTH of the footprint; the platform canopy rides this face).
		"plane": -175.04, ## The depot wall's south face (the probe's walk).
		"wall_u": 2647.89, ## Mid-span between the canopy posts at x 2642.88
			## and 2652.90 — the post at 2652.90 would cover the slab center.
		"mount_y": 2.2, ## Under the canopy soffit (the slab bottom is 3.2).
		"letter": 0.22, ## 9.529 × 0.22 = 2.10 ≤ 2.2 — the widened slab.
		"band": Vector3(2.4, 0.5, 0.08),
		"staged": false,
		"note": "T-194 (the 1906 depot — MODELING-SPECS §1.8's \"1906-era\" "
			+ "read; today's Main Street Station). NO railroad brand marks: "
			+ "the text is \"Ames Depot\" — never C&NW, never UP (the "
			+ "ticket's excluded list names the railroad brands). The plaque "
			+ "hangs under the platform canopy on the track face, clear of "
			+ "the canopy posts; Cornbred's live venue sign keeps the Main "
			+ "face (T-199), the historical name takes the rails side.",
	},
	{
		"id": "reiman_gardens",
		"text": "Reiman Gardens — 1995",
		"hero": "reiman_gardens",
		"face": "E", ## University Blvd — the arrival face (the town's south gate).
		"plane": 984.35, ## The T-204 envelope's east face (slot center 955.0 + 29.35).
		"wall_u": 1241.5, ## (Round 2 re-station) The open-walk bay south of the
			## Butterfly Wing bake box (its south face z 1233.56 buried the v1
			## station 1233.08 — the slab stood inside that mass and read only
			## from south-of-the-Wing approaches); the mount now faces the
			## open arrival walk the canopy shares.
		"mount_y": 2.6, ## On the 10 m glass wall, above eye height.
		"letter": 0.20, ## 21 chars — the widened depot slab; face-fit 2.35 ≤ 2.6.
		"band": Vector3(2.8, 0.6, 0.1),
		"staged": false,
		"note": "LANDMARKS C10 (1995, current site; 1407 University Blvd, the "
			+ "town's south gate). PLACED by T-204 (South — Reiman Gardens): "
			+ "the bbox south brought the POI in-core and the ticket built the "
			+ "conservatory hero (the whole 59 × 88 m building per QA item 1, "
			+ "Hughes's 465 m² glasshouse a distinct volume inside it); the "
			+ "plaque hangs on the hero's east glass face, the University Blvd "
			+ "arrival read. Was the table's staged spec (the T-201 staging "
			+ "note) — The Cafe now carries the staged law alone."
	},

]


## Builds the PLACED plaques under `root` (a plain Node3D — the world supplies
## it) and returns one record per placed plaque for the gate + the world
## report: {id, text, hero, face, plane, wall_u, mount_y, letter, band, pos,
## yaw, node} — world-local (pack-frame) coordinates. Staged entries
## (Reiman Gardens) build nothing. The world's hero part records are the
## mount data's source (see the class doc); this builder itself needs none
## of them — the literals ARE the pins, the gate re-derives against the
## records.
static func build(root: Node3D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for entry: Dictionary in PLAQUES:
		if bool(entry["staged"]):
			continue
		var sign := SignText.new()
		sign.typology = SignText.Typology.PLAQUE
		sign.text = str(entry["text"])
		sign.letter_height = float(entry["letter"])
		var band: Vector3 = entry["band"]
		if band != Vector3.ZERO:
			sign.body_scale = band
		var pos := Vector3.ZERO
		var yaw := 0.0
		match str(entry["face"]):
			"marker":
				pos = entry["marker_pos"]
				yaw = atan2(1.0, 0.0) ## Facing east (Marston Court).
			"E":
				pos = Vector3(float(entry["plane"]) + _stand(entry),
						float(entry["mount_y"]), float(entry["wall_u"]))
				yaw = atan2(1.0, 0.0)
			"W":
				pos = Vector3(float(entry["plane"]) - _stand(entry),
						float(entry["mount_y"]), float(entry["wall_u"]))
				yaw = atan2(-1.0, 0.0)
			"N":
				pos = Vector3(float(entry["wall_u"]), float(entry["mount_y"]),
						float(entry["plane"]) - _stand(entry))
				yaw = atan2(0.0, -1.0)
			_:
				pos = Vector3(float(entry["wall_u"]), float(entry["mount_y"]),
						float(entry["plane"]) + _stand(entry))
				yaw = atan2(0.0, 1.0)
		sign.name = "Plaque_%s" % entry["id"]
		sign.position = pos
		sign.rotation = Vector3(0.0, yaw, 0.0)
		root.add_child(sign)
		if str(entry["face"]) == "marker":
			_post_mesh(root, str(entry["id"]), pos)
		records.append({
			"id": entry["id"],
			"text": entry["text"],
			"hero": entry["hero"],
			"face": entry["face"],
			"plane": entry["plane"],
			"wall_u": entry["wall_u"],
			"mount_y": entry["mount_y"],
			"marker_pos": entry.get("marker_pos", Vector3.ZERO),
			"letter": entry["letter"],
			"band": entry["band"],
			"pos": pos,
			"yaw": yaw,
			"node": sign,
		})
	return records


## The slab-root standoff off the wall plane (half the slab thickness + the
## gap; the text adds its own FACE_PROUD on top).
static func _stand(entry: Dictionary) -> float:
	var band: Vector3 = entry["band"]
	var thick := band.z if band != Vector3.ZERO \
			else (SignText.SPEC[SignText.Typology.PLAQUE]["body"] as Vector3).z
	return thick * 0.5 + WALL_GAP


## The free-standing marker's post (the Marston form): one square post from
## the ground to the slab's bottom edge. Visual-only (the T-197 scope).
static func _post_mesh(root: Node3D, plaque_id: String, slab_pos: Vector3) -> void:
	var post := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(MARKER_POST_THICK, MARKER_POST_H, MARKER_POST_THICK)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MARKER_POST_COLOR
	mat.roughness = 0.7
	mesh.material = mat
	post.name = "MarkerPost_%s" % plaque_id
	post.mesh = mesh
	post.position = Vector3(slab_pos.x, MARKER_POST_H * 0.5, slab_pos.z)
	root.add_child(post)
