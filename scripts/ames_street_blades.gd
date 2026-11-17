class_name AmesStreetBlades
extends RefCounted
## The Ames street-name blades (T-200, R4 · the names): the MUTCD green
## wayfinding blades at the pinned corners — one blade per SPINE street name
## at every T-180 pinned intersection anchor the spine set touches, with the
## blade TEXT byte-exact against the data pack's own street names (the
## exact-match law: the text IS the run's `sname`, never retyped, never
## invented — so the Lincoln Way → East Lincoln Way seam at Duff and the
## Grand/Duff southern renames land exactly as the data spells them).
##
## The mount derives entirely from the traffic graph's T-180 classification
## (`AmesTrafficGraph`): a corner is in the blade set when its pinned anchor
## carries ≥ 1 spine name; each spine name takes ONE blade on its
## first approach carrying the name (the members' edges in order,
## deterministic) — the post stands at the T-134 sign outset clamped into
## its run (never past the run's far end minus the margin), so even the
## tightest downtown corner signs its spine name.
## The form follows the corner type, the MUTCD read:
## - **signal corners** — the blades stack under the T-180 mast arm (the
##   overhead street-name mount): same pole/arm derivation as the world's
##   `_queue_signal_mast`, hung at a pinned arm station, stacked downward
##   (the real stacked-overhead read). The world's mast consts ride as
##   documented TWINS here (the one-way dependency law — the venue module's
##   `CHUNKS_DIR` twin precedent); the gate pins the twins EQUAL to the
##   world's, so a mast retune that forgets the twins fails the same night.
## - **all-way stops** — the blade tops its own post on the approach's right,
##   the T-134 sign-assembly law at blade size (same post section/color,
##   same stop-outset position, one pinned lateral separation off the stop
##   sign's own post; the plate center rides above the octagon band).
##
## Orientation law (the MUTCD blade read): the plate's LONG axis runs along
## the street it names and its two faces read ACROSS the street — a driver
## on the cross street reads the name face-on, both directions (the STREET
## typology is double-faced ±z; each side's label reads left-to-right
## correctly). Yaw = atan2(−a.z, a.x) for the street axis a, so the plate's
## local +x carries the axis and local +x = up × face-normal keeps the text
## order right on the +z face.
##
## The plate fits its name by construction: the module measures the string
## at the pinned letter height through the component's own font metrics and
## widens the plate to width + 2×pad (real blades fit their text; the
## overflow guard then never fires on a spine name).
##
## Visual-only throughout (the T-197 scope guard): zero colliders, zero RNG
## of any stream — a rebuild reproduces every mount byte-identically.

## The blade scene (T-197's component at the STREET typology).
const SCENE_STREET: PackedScene = preload("res://scenes/sign_street.tscn")

## --- the spine set (the ticket's pinned list, as the data spells them) ------
## Exact data names only — a family and its directional renames are separate
## keys because the data names them separately (Lincoln Way/East Lincoln Way,
## Duff/South Duff, Grand/South Grand; 16th carries both the South and
## Southeast spellings the survey records). A name on this list that no
## pinned corner touches (Mortensen, Stange, the 16ths in v1) simply places
## no blades — the R5 bake extensions will light them up when their corners
## join the pinned set.
const SPINE_NAMES: Array[String] = [
	"Lincoln Way", "East Lincoln Way",
	"Welch Avenue", "Hayward Avenue", "Sheldon Avenue", "Stanton Avenue",
	"Main Street", "Duff Avenue", "South Duff Avenue",
	"Grand Avenue", "South Grand Avenue",
	"University Boulevard", "Mortensen Road",
	"South 16th Street", "Southeast 16th Street",
	"Stange Road", "Clark Avenue", "Burnett Avenue", "Douglas Avenue",
]

## --- blade plate consts (the STREET typology at blade size) -----------------

## The pinned letter height (m of capital) — the MUTCD 200 mm+ overhead
## blade range; every blade letters at it (the component's export default
## would also land here; the module pins it explicitly so the records carry
## the value the gate re-locks).
const BLADE_LETTER := 0.22

## The plate body (m) — the STREET typology's default plate: the y/z pair
## every blade rides (the module widens ONLY x per name).
const BLADE_BODY := Vector3(2.6, 0.44, 0.06)

## Plate margins (m): the MUTCD margin around the name, per side, and the
## shortest plate a blade may carry.
const PLATE_PAD := 0.15
const PLATE_MIN_LEN := 1.2

## --- post mounts (the T-134 family at blade size) ---------------------------

## Plate center height on its post (m): above the T-134 octagon band
## (face 2.5, border top ≈ 2.92) so a blade never plates over a stop sign.
const POST_MOUNT_Y := 3.1
## Lateral separation off the T-134 stop-sign post (m) — the blade post
## stands its own hole, one separation past the sign assembly's edge offset.
const POST_SEP := 0.6
## The T-134 post section (m) and its color (the world's corner-post gray).
const POST_THICK := 0.08
const POST_COLOR := Color(0.25, 0.25, 0.28)

## --- mast-arm mounts (the world's T-180 mast consts, twinned) ---------------
## The gate pins these EQUAL to `AmesWorld`'s — a mast retune must walk the
## twins (or the twins' gate line fails, whichever lands first).

## The arm height the blades hang under (m).
const MAST_ARM_Y := 5.6
## The pole's stop-line clearance and lateral offset (m) — the world's law.
const MAST_POLE_CLEAR := 0.6
const MAST_POLE_SIDE := 0.7
## The arm's short-side end clearance (m) — the world's law.
const MAST_ARM_END_CLEAR := 1.2

## The hang: blades sit at this fraction of the arm from the pole, this far
## under the arm, stacked downward one plate height + gap per extra blade.
const ARM_BLADE_STATION := 0.30
const ARM_BLADE_CLEAR := 0.12
const ARM_BLADE_STACK_GAP := 0.10

## The blade's own run-fit margin (m): the post never stands past its run's
## own far end minus this much. Deliberately NOT the crosswalk paint's
## `fits` gate (stop_outset + 2.0): a plate on a post needs far less runway
## than a zebra band + stop bar, and the tightest downtown corner (Main ×
## Kellogg — Main's runs there run ~10 m between the junction and the
## street's own kink) must still sign its spine name — its post clamps
## into the run instead of skipping.
const BLADE_RUN_MARGIN := 0.5


## Builds the blade set under `root` (a plain Node3D — the world supplies it)
## and returns one record per blade for the gate + the world report:
## {id, street, anchor, district, signal, mount, stack, edge, letter, plate,
## pos, yaw, node} — pack-frame coordinates (the world node IS the pack
## frame). Post mounts also stand a `Post_<id>` mesh part under `root`.
static func build(graph: AmesTrafficGraph, root: Node3D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for a in graph.intersection_count():
		if graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		var signalized := graph.intersection_is_signal(a)
		var mast := _mast_pose(graph, a) if signalized else {}
		var stack := 0 ## The mast-arm stack slot, per corner.
		for nm in graph.intersection_streets(a):
			if not SPINE_NAMES.has(nm):
				continue
			var pick := _street_edge(graph, a, nm)
			if int(pick["edge"]) < 0:
				push_warning("AmesStreetBlades: no fitting approach for %s at anchor %d"
						% [nm, a])
				continue
			var street_axis := graph.edge_axis(int(pick["edge"]))
			var yaw := atan2(-street_axis.z, street_axis.x)
			var pos := Vector3.ZERO
			var mount := "post"
			var slot := -1
			if not mast.is_empty():
				mount = "mast"
				slot = stack
				var right: Vector3 = mast["right"]
				var station: Vector3 = mast["station"]
				var y := MAST_ARM_Y - ARM_BLADE_CLEAR - BLADE_BODY.y * 0.5 \
						- float(slot) * (BLADE_BODY.y + ARM_BLADE_STACK_GAP)
				pos = Vector3(station.x, y, station.z)
				stack += 1
			else:
				var geo: Dictionary = pick["geo"]
				var axis: Vector3 = geo["axis"]
				var out := Vector3(-axis.z, 0.0, axis.x)
				var base: Vector3 = pick["node_pos"] - axis * float(pick["outset"]) \
						+ out * (float(geo["half_width"])
						+ AmesTrafficGraph.SIGN_EDGE_OFFSET + POST_SEP)
				pos = Vector3(base.x, POST_MOUNT_Y, base.z)
			var blade_id := "%d/%s" % [a, nm]
			var plate := _plate_size(nm)
			var sign: SignText = SCENE_STREET.instantiate() as SignText
			sign.name = "Blade_%s" % blade_id.replace("/", "_").replace(" ", "_")
			sign.text = nm
			sign.body_scale = plate
			sign.position = pos
			sign.rotation = Vector3(0.0, yaw, 0.0)
			root.add_child(sign)
			if mount == "post":
				_post_mesh(root, blade_id, pos)
			records.append({
				"id": blade_id,
				"street": nm,
				"anchor": a,
				"district": graph.intersection_district(a),
				"signal": not mast.is_empty(),
				"mount": mount,
				"stack": slot,
				"edge": int(pick["edge"]),
				"letter": BLADE_LETTER,
				"plate": plate,
				"pos": pos,
				"yaw": yaw,
				"node": sign,
			})
	return records


## One corner's mast-arm pose for the blade hang — the world's
## `_queue_signal_mast` derivation read off the graph, reduced to what a
## hanging blade needs: the arm station point (at the pinned arm fraction)
## and the arm's across-axis. Empty when the corner carries no derivable
## mast (no arterial arm — the honest skip; the blades fall back to posts).
static func _mast_pose(graph: AmesTrafficGraph, anchor: int) -> Dictionary:
	var axis := graph.intersection_signal_axis(anchor)
	if axis == Vector3.ZERO:
		return {}
	var node := graph.intersection_signal_node(anchor)
	if node < 0:
		return {}
	var half := graph.intersection_signal_half_width(anchor)
	var lane := graph.intersection_signal_lane_off(anchor)
	var node_pos := graph.node_pos(node)
	var stop_outset := lane + AmesTrafficGraph._STOP_OUTSET_TAIL
	var right := Vector3(-axis.z, 0.0, axis.x)
	var along := stop_outset + MAST_POLE_CLEAR
	var pole_pos := node_pos - axis * along + right * (half + MAST_POLE_SIDE)
	var arm_len := (half + MAST_POLE_SIDE) + half - MAST_ARM_END_CLEAR
	return {
		"station": pole_pos - right * (arm_len * ARM_BLADE_STATION),
		"right": right,
	}


## The first graph edge carrying `nm` at the anchor: the members' out-edges
## in order (deterministic), the first whose run can host a post at all
## (longer than the margin — degenerate sub-metre runs never host a blade,
## warned). {edge, geo, node_pos, outset} — edge −1 when nothing fits. The
## `outset` is the post's pull-back off the node: the T-134 sign outset
## (stop line + the MUTCD gap), CLAMPED into the run so the post never
## lands past the run's far end minus the margin (the tight corners sign
## at the clamped position — the law above).
static func _street_edge(graph: AmesTrafficGraph, anchor: int, nm: String) -> Dictionary:
	for member in graph.intersection_members(anchor):
		for e in graph.out_edges(member):
			if graph.edge_name(e) != nm:
				continue
			var geo := graph.approach_geometry(member, graph.edge_reverse(e))
			var run_len := float(geo["run_length"])
			if run_len <= BLADE_RUN_MARGIN:
				continue
			var outset := minf(float(geo["stop_outset"])
					+ AmesTrafficGraph.SIGN_OUTSET_GAP,
					run_len - BLADE_RUN_MARGIN)
			return {"edge": e, "geo": geo, "node_pos": graph.node_pos(member),
					"outset": outset}
	return {"edge": -1, "geo": {}, "node_pos": Vector3.ZERO, "outset": 0.0}


## The plate size for a name: the y/z body pair at the pinned blade dims,
## the length widened to fit the string at the letter height through the
## component's own font metrics (width + 2×pad, at least the minimum) —
## the overflow guard's fit law holds by construction.
static func _plate_size(nm: String) -> Vector3:
	var px := BLADE_LETTER / (float(SignText.FONT_SIZE_PX) * SignText.CAP_HEIGHT_EM)
	var w := SignText.FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1,
			SignText.FONT_SIZE_PX).x * px
	return Vector3(maxf(PLATE_MIN_LEN, w + PLATE_PAD * 2.0), BLADE_BODY.y,
			BLADE_BODY.z)


## One post-mount post under `root`: the T-134 post section from the ground
## to the plate's bottom edge (the plate center rides POST_MOUNT_Y, the
## post reaches it minus half the plate height). Visual-only.
static func _post_mesh(root: Node3D, blade_id: String, plate_pos: Vector3) -> void:
	var height := POST_MOUNT_Y - BLADE_BODY.y * 0.5
	var post := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(POST_THICK, height, POST_THICK)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = POST_COLOR
	mat.roughness = 0.7
	mesh.material = mat
	post.name = "Post_%s" % blade_id.replace("/", "_").replace(" ", "_")
	post.mesh = mesh
	post.position = Vector3(plate_pos.x, height * 0.5, plate_pos.z)
	root.add_child(post)
