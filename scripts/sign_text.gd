class_name SignText
extends Node3D
## In-world sign component (T-197, R4 · text capability) — the game's first
## rendered letterforms. One component builds a sign body per typology
## (plaque / lit box / neon-ish blade / big-box pole) and mounts the rendered
## text face(s) on it with Label3D, at a pinned letter height with a pinned
## legibility budget: `readable_distance()` is the distance the text stays
## readable from, derived per typology from the actual rendered capital-letter
## height (letter_height × budget, both pinned in the spec table below).
##
## The bundled typeface is Oswald (a condensed grotesque — bar boxes, blades
## and plaques all read well in it), an OFL font shipped under
## `assets/fonts/` with its license file alongside. Letter height means the
## rendered CAPITAL height, not the em box: pixel_size is derived through
## CAP_HEIGHT_EM (the font's own sCapHeight/unitsPerEm, parsed from the TTF —
## 810/1000 = 0.81), so the legibility budget applies to real letterforms.
##
## Scope guard (this ticket is deliberately hero-free): visual-only dressing —
## NO collision body of any kind (the T-090 plaque decision; a placement that
## needs a collider adds its own), no venue content (T-198+ places real
## names), no HUD/menu text (untouched), and T-090's blank plaques on the
## Windrow seam stay untouched — adoption is per-ticket.
##
## Mount convention: PLAQUE/BOX/BLADE roots sit at their body CENTER (mount
## −z / −z-back / −z-brackets against the wall); POLE roots stand on the
## GROUND at the pole base. Text faces: plaque +z, box +z, blade ±x (reads
## both directions along the street), pole ±z.

## The bundled OFL typeface (one file; license `assets/fonts/OFL.txt`).
const FONT: FontFile = preload("res://assets/fonts/oswald_variable.ttf")
## Atlas rasterization size (px) — pixel_size maps atlas px → metres below.
const FONT_SIZE_PX := 96
## Oswald's capital-height fraction of the em, parsed from the bundled TTF
## (OS/2.sCapHeight 810 over head.unitsPerEm 1000 — the sim scenario re-parses
## the file and pins this constant against its own read).
const CAP_HEIGHT_EM := 0.81
## Text faces sit this far proud of their body face plane (m) — no z-fight.
const FACE_PROUD := 0.01

## Sign families (T-197 §What: plaque + the three photo-ref typologies).
enum Typology { PLAQUE, BOX, BLADE, POLE }

## Per-typology spec. All values pinned (sim `sign_text_legibility`):
## - `letter_h` — default capital-letter height (m) when `letter_height` is 0.
## - `budget` — legibility budget, metres of readable distance per metre of
##   capital height. Calibrated per typology from the photo reads: plaques are
##   sidewalk-close reads (140), lit boxes high-contrast street reads (200),
##   blades oblique verticals read slower (160), pole cabinets are the
##   drive-by big-box read (260). Pinning the BUDGET (not the distance) keeps
##   the law one knob: a later ticket retuning a letter height moves its
##   readable distance with it, in the same proportion.
## - `body` — the body slab size (m); pole sizes its parts below.
## - faces — text-face normals with the label yaw that reads from each.
const SPEC := {
	Typology.PLAQUE: {
		"letter_h": 0.16,
		"budget": 140.0,
		"body": Vector3(2.2, 0.5, 0.08), ## T-090's plaque slab, lettered at last.
		"body_color": Color(0.92, 0.87, 0.74), ## The T-090 cream.
		"text_color": Color(0.13, 0.12, 0.10),
		"lit": false,
		"emission": 0.0,
		"faces": [{"n": Vector3(0, 0, 1), "yaw": 0.0}],
		"vertical": false,
		"text": "AMES",
	},
	Typology.BOX: {
		"letter_h": 0.30,
		"budget": 200.0,
		"body": Vector3(3.0, 1.0, 0.25), ## Campustown's flat lit box (photo 01).
		"body_color": Color(0.93, 0.91, 0.86),
		"text_color": Color(0.09, 0.15, 0.24),
		"lit": true,
		"emission": 0.9,
		"faces": [{"n": Vector3(0, 0, 1), "yaw": 0.0}],
		"vertical": false,
		"text": "BOX SIGN",
	},
	Typology.BLADE: {
		"letter_h": 0.28,
		"budget": 160.0,
		"body": Vector3(0.14, 2.6, 0.9), ## Downtown's vertical board (photo 07).
		"body_color": Color(0.07, 0.07, 0.08),
		"text_color": Color(0.95, 0.16, 0.12),
		"lit": true,
		"emission": 1.4,
		"faces": [{"n": Vector3(1, 0, 0), "yaw": PI * 0.5},
				{"n": Vector3(-1, 0, 0), "yaw": -PI * 0.5}],
		"vertical": true,
		"text": "SIGN",
	},
	Typology.POLE: {
		"letter_h": 0.55,
		"budget": 260.0,
		"body": Vector3(2.6, 2.6, 0.4), ## Lincoln Way's big-box cabinet (photo 04).
		"body_color": Color(0.92, 0.92, 0.90),
		"text_color": Color(0.09, 0.15, 0.24),
		"lit": true,
		"emission": 0.8,
		"faces": [{"n": Vector3(0, 0, 1), "yaw": 0.0},
				{"n": Vector3(0, 0, -1), "yaw": PI}],
		"vertical": false,
		"text": "POLE", ## Short by design — big cabinets carry short words
		## (the photo-04 read); "POLE SIGN" at this letter height overflows.
	},
}

## Pole-cabinet specifics (root at the ground; dims off the photo-04 read).
const POLE_HEIGHT := 6.0 ## Pole tops just above the cabinet — the photo read.
const POLE_RADIUS := 0.175
const POLE_CABINET_Y := 4.4 ## Cabinet center height (cabinet top 5.7).

@export_group("Sign")
## The sign family — geometry, palette, faces and budget all ride it.
@export var typology: Typology = Typology.PLAQUE
## The lettering (uppercase reads best at distance). Empty → the typology's
## pinned default text. Blades stack the letters upright, top to bottom.
@export_multiline var text: String = ""
## Rendered capital-letter height (m). 0 → the typology's pinned default.
@export var letter_height: float = 0.0
## Body dims override (m; x = face width for the overflow law). ZERO → the
## typology's pinned dims (T-198's venue knob: the real bands a sign ticket
## needs — Welch Ave Station's 8.4 m block-letter band — stay in-system, one
## export, the legibility budget and the overflow guard riding the real size).
@export var body_scale: Vector3 = Vector3.ZERO
## Body/text albedo overrides. Any alpha-0 color = "typology default".
@export var body_color: Color = Color(0, 0, 0, 0)
@export var text_color: Color = Color(0, 0, 0, 0)
## 0 = typology default (boxes/blades/poles lit, plaques not), 1 = off, 2 = on.
@export_enum("Default", "Off", "On") var lit_mode: int = 0

## The effective capital height this sign letters at (the export or default).
func effective_letter_height() -> float:
	var spec: Dictionary = SPEC[typology]
	return letter_height if letter_height > 0.0 else spec["letter_h"]

## The legibility budget: metres from which this sign's lettering stays
## readable — capital height × the typology's pinned metres-per-metre factor.
func readable_distance() -> float:
	return effective_letter_height() * SPEC[typology]["budget"]

## The letters actually laid on the faces (the export or the default).
func display_text() -> String:
	var t := text.strip_edges()
	return t if not t.is_empty() else SPEC[typology]["text"]


func _ready() -> void:
	_build()


## --- the build (all geometry in code — scenes stay translation-only) --------


func _build() -> void:
	var spec: Dictionary = SPEC[typology]
	var body_col: Color = body_color if body_color.a > 0.0 else spec["body_color"]
	var text_col: Color = text_color if text_color.a > 0.0 else spec["text_color"]
	var lit: bool = spec["lit"]
	match lit_mode:
		1: lit = false
		2: lit = true
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_col
	body_mat.roughness = 0.6
	if lit:
		body_mat.emission_enabled = true
		body_mat.emission = body_col
		body_mat.emission_energy_multiplier = spec["emission"]
	var size: Vector3 = spec["body"] if body_scale == Vector3.ZERO else body_scale
	match typology:
		Typology.PLAQUE, Typology.BOX:
			_box_part("Body", size, Vector3.ZERO, body_mat)
		Typology.BLADE:
			## The vertical board with its rounded top (the photo-07 silhouette)
			## and the two bracket arms reaching back toward the wall (−z).
			_box_part("Board", size, Vector3.ZERO, body_mat)
			var cap := CylinderMesh.new()
			cap.top_radius = size.z * 0.5
			cap.bottom_radius = size.z * 0.5
			cap.height = size.x
			cap.material = body_mat
			var cap_inst := MeshInstance3D.new()
			cap_inst.name = "Cap"
			cap_inst.mesh = cap
			cap_inst.position = Vector3(0.0, size.y * 0.5, 0.0)
			cap_inst.rotation = Vector3(0.0, 0.0, PI * 0.5) ## Axis along x.
			add_child(cap_inst)
			var arm_mat := StandardMaterial3D.new()
			arm_mat.albedo_color = Color(0.16, 0.16, 0.17)
			for y: float in [-0.65, 0.65]:
				_box_part("Bracket", Vector3(size.x, 0.06, 0.30),
						Vector3(0.0, y, -size.z * 0.5 - 0.15), arm_mat)
		Typology.POLE:
			## Ground-rooted: the pole under the double-faced cabinet.
			var pole := CylinderMesh.new()
			pole.top_radius = POLE_RADIUS
			pole.bottom_radius = POLE_RADIUS
			pole.height = POLE_HEIGHT
			var pole_mat := StandardMaterial3D.new()
			pole_mat.albedo_color = Color(0.10, 0.10, 0.11)
			pole_mat.roughness = 0.7
			pole.material = pole_mat
			var pole_inst := MeshInstance3D.new()
			pole_inst.name = "Pole"
			pole_inst.mesh = pole
			pole_inst.position = Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)
			add_child(pole_inst)
			_box_part("Cabinet", size, Vector3(0.0, POLE_CABINET_Y, 0.0), body_mat)
	var letter: float = effective_letter_height()
	var content := display_text()
	var content_lines: String = content
	if spec["vertical"]:
		var stacked := PackedStringArray()
		for c: String in content:
			stacked.append(c)
		content_lines = "\n".join(stacked)
	for i: int in spec["faces"].size():
		_add_face("Face%d" % (i + 1), spec["faces"][i], letter, text_col,
				content_lines, size)
	_warn_overflow(content, letter, size)


## One rendered text face: an unshaded Label3D at FACE_PROUD off its body
## plane, pixel_size derived so the rendered CAPITAL height is exactly
## `letter` metres (px = FONT_SIZE_PX × CAP_HEIGHT_EM).
func _add_face(face_name: String, face: Dictionary, letter: float,
		text_col: Color, content: String, body_size: Vector3) -> void:
	var label := Label3D.new()
	label.name = face_name
	label.text = content
	label.font = FONT
	label.font_size = FONT_SIZE_PX
	label.pixel_size = letter / (float(FONT_SIZE_PX) * CAP_HEIGHT_EM)
	label.modulate = text_col
	label.shaded = false
	label.outline_size = 0
	var n: Vector3 = face["n"]
	var center := Vector3.ZERO
	if typology == Typology.POLE:
		center = Vector3(0.0, POLE_CABINET_Y, 0.0) ## Faces ride the cabinet.
	label.position = center + n * _face_proud(body_size)
	label.rotation = Vector3(0.0, face["yaw"], 0.0)
	add_child(label)


## The proud offset along the face normal for the typology's body slab.
func _face_proud(body_size: Vector3) -> float:
	if typology == Typology.BLADE:
		return body_size.x * 0.5 + FACE_PROUD
	return body_size.z * 0.5 + FACE_PROUD


## One body slab: a named box-mesh part in the body material.
func _box_part(part_name: String, size: Vector3, pos: Vector3,
		mat: StandardMaterial3D) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	part.name = part_name
	part.mesh = mesh
	part.position = pos
	add_child(part)


## Honest-budget warning: lettering wider than its face reads as a broken
## sign — warn (don't clamp; a sign ticket retunes the letter height instead).
## Vertical (blade) faces stack one letter per line, so the widest SINGLE
## character is the width that matters, not the whole string's.
func _warn_overflow(content: String, letter: float, body_size: Vector3) -> void:
	var px := letter / (float(FONT_SIZE_PX) * CAP_HEIGHT_EM)
	var face_width: float = body_size.z if typology == Typology.BLADE \
			else body_size.x
	var widest := content
	if SPEC[typology]["vertical"]:
		widest = ""
		for c: String in content:
			if FONT.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1,
					FONT_SIZE_PX).x > FONT.get_string_size(widest,
					HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_PX).x:
				widest = c
	var width: float = FONT.get_string_size(
			widest, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_PX).x * px
	if width > face_width - 0.2:
		push_warning("SignText: text '%s' measures %.2f m on a %.2f m face — "
				% [widest, width, face_width]
				+ "lower letter_height or shorten the text")
