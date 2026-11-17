class_name AmesVenueSigns
extends RefCounted
## The Ames venue signs (T-198 + T-199, R4 · the names): the VENUES.md names
## mounted as real SignText signs at their verified positions/facings on the
## resident Ames world. T-198's §1 table (`SIGNS`) carries the fourteen Tier-1
## names a student says first — twelve in-core venues on the street wall of
## the bake body their parcel anchor sits in (the Welch 100/200 blocks, the
## Chamberlain row, the Lincoln Way corner cluster, downtown Main's east end),
## the Superdog cart as the one PROP (cart + umbrella + its topper sign, not
## a building), Hickory Park's big-box pylon out on the S Duff apron flat,
## and The Cafe's spec STAGED (north Ames is outside the v1 bake core, so it
## places when T-205 extends the bake; the dependency is recorded here and in
## the ticket, not worked around).
##
## T-199 adds the depth: `SIGNS_T2`/`SIGNS_T3` sign the Tier-2/3 survey names
## (27 of the 34 POIs — the unsigned remainder rides `UNSIGNED_T23` with its
## honest reason, never a silent gap), and `PLAQUES` gives the mourned CLOSED
## venues of §6 their memorial plaques — a modest ground-floor bronze, never
## a glowing sign ("Es Tas — 2024" reads as love, not kitsch; the styling
## constants + the tone law are pinned for the gate).
##
## Every mount is a literal derived ON its ticket from the committed bake and
## survey (the derivation cited per entry), and the `venue_signs_tier1` /
## `venue_signs_tiers` scenarios re-derive each one independently from the
## committed chunk files + the pack — a bake drift, a moved sign or a retyped
## name fails the gate the same night. The sign TEXTS are the VENUES.md
## heading names byte-exact (the exact-match law); the forms follow the
## survey's exterior descriptions via T-197's three typology scenes plus the
## lettered plaque, colors are brand-adjacent ONLY where the description
## names a scheme, and no logo art ships anywhere (names in type only — the
## legal line).
##
## Mount convention: `face` selects the street wall of the pinned bake body
## (an axis-aligned AABB face — E/W faces run along z, N/S along x), the sign
## root sits one GAP off that plane proud of the wall with its text facing the
## street (`+z` on the yaw), `wall_u` is the sign center's coordinate along the
## wall, `mount_y` the center height. Free-standing forms (`pole`, `cart`,
## `truck`) stand on the ground at the pack POI position, yawed onto the POI's
## verified facing (`facing_to_yaw`'s convention: the facing vector n, yaw =
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
		## (T-204 re-pin) The building LANDED with the bbox south — the way
		## rides the bake as an authored massing slot — so the pylon moved
		## OFF the POI (it would stand inside the building's own mass now)
		## onto the lot's frontage edge: a wall-face mount on the building's
		## own north face, text facing the lot-frontage street.
		"body": "massing:way/196541966",
		"face": "N", ## Meadow Lane Court — the lot's frontage street.
		"wall_u": 3382.0, ## The lot's NE station: Meadow Lane's bend keeps
			## the face-north aim inside the facing cone there (the center
			## station's nearest street point sits 47° off the face normal).
		"mount_y": 0.0,
		"letter": 0.40, ## 5.697 × 0.40 = 2.28 ≤ 2.4 cabinet face.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.12 (1404 S Duff): freestanding big-box restaurant in "
			+ "a sea of parking — the big roadside pylon signs the position. "
			+ "Was the apron staging (the v1 bake's SE corner had no building, "
			+ "tile (13,5) unbaked); the bbox SOUTH landed the way with T-204 "
			+ "(the T-203 note's R5 east landing was one ring early), so the "
			+ "pylon stands the building's own north face — the pack's S Duff "
			+ "polyline ends at Meadow Lane (the naming splits south of it), "
			+ "making that the lot's frontage street; the survey address "
			+ "stays 1404 S Duff.",
	},
	{
		"id": "the_cafe",
		"venue": "The Cafe",
		"form": "plaque",
		## (T-205 placement — the staged pin un-staged) The v4 north bake
		## landed the venue's own building: way/114039922, the unnamed
		## 32.7 × 18.5 m procedural massing at 2616 Northridge Pkwy (the
		## census addr node sits inside it, 2 m off its centroid). The
		## signboard hangs on the building's own NORTH wall — Northridge
		## Parkway fronts it there (the street's nearest point (513.2,
		## −2904.7) lies 21 m north of the face; the pack facing 359.9°
		## points the same way), wall_u the POI's own x along the wall.
		"body": "massing:way/114039922",
		"face": "N",
		"wall_u": 536.49,
		"mount_y": 5.4, ## The tier-1 plaque band on the 11 m massing.
		"letter": 0.16, ## 3.858 × 0.16 = 0.62 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 1.13 (2616 Northridge Pkwy): NORTH Ames — the last "
			+ "staged tier-1 spec PLACED by T-205 (the v4 bbox north landed "
			+ "the whole Northridge corridor + Ada Hayden). The building "
			+ "way (unnamed in OSM — the census §6 north strip keeps it "
			+ "procedural, the authored set stays closed) rides the bake as "
			+ "the venue's own massing; the T-175 venue fixup box also "
			+ "lands at the POI now it is in-core and authored-uncovered — "
			+ "fully swallowed by the massing box, the same buried-box "
			+ "grain the eleven named fixups carry.",
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

## --- T-199 the ghost-plaque styling (the mourned closed venues) -------------
##
## Master plan §11.4's fork, owner-decided 2026-11-09: yes, memorial styling.
## The tone law the ticket pins: a modest GROUND-FLOOR plaque — never a
## glowing sign — in a quiet bronze/parchment pair, so "Es Tas — 2024" reads
## as love, not haunted-house kitsch. The PLAQUE typology is unlit by
## construction; the constants below re-state that in machine-checkable form
## (the `venue_signs_tiers` scenario reads them off the live nodes).
const PLAQUE_MEMORIAL_BODY := Color(0.30, 0.26, 0.20) ## Deep bronze slab.
const PLAQUE_MEMORIAL_TEXT := Color(0.86, 0.80, 0.63) ## Warm parchment lettering.
const PLAQUE_MEMORIAL_MAX_Y := 2.0 ## Center height cap — the ground-floor band.
const PLAQUE_MEMORIAL_LETTER := 0.16 ## Cap-height cap — a close sidewalk read.

## --- the Carlos Quesadilla truck prop (VENUES 3.12: truck, not a building) --

const TRUCK_BOX := Vector3(2.2, 1.9, 4.4)
const TRUCK_BOX_Y := 1.55
const TRUCK_CAB := Vector3(2.1, 1.1, 1.3)
const TRUCK_CAB_Y := 1.15
const TRUCK_CAB_Z := 2.55 ## The cab rides the local +z (the facing end).
const TRUCK_WHEEL_R := 0.38
const TRUCK_WHEEL_H := 0.22
const TRUCK_WHEELS: Array[Vector3] = [
	Vector3(0.95, TRUCK_WHEEL_R, 1.5), Vector3(-0.95, TRUCK_WHEEL_R, 1.5),
	Vector3(0.95, TRUCK_WHEEL_R, -1.5), Vector3(-0.95, TRUCK_WHEEL_R, -1.5),
]
const TRUCK_SIGN_Y := 2.85 ## Topper plaque over the box roof (top 2.5).
const TRUCK_SIGN_Z := -0.6
const TRUCK_STEEL := Color(0.82, 0.24, 0.14) ## The gameday truck's warm red.

## --- the tiers 2–3 mount table (T-199; texts are the VENUES §2/§3 names) ----
##
## The same component and rules as the tier-1 table: every mount is a literal
## derived ON this ticket from the committed bake + the census/OSM anchors
## (the derivation cited per entry), wall mounts hang on the pinned bake
## body's street wall at a pinned wall_u/mount_y, free-standing forms stand
## at the pack POI yawed onto its verified facing, letters pass the face-fit
## law (string width at the cap ≤ face − 0.2; widths measured in-engine),
## colors only where VENUES names a scheme, no logo art anywhere.
##
## Signed: 15 of the 17 Tier-2 POIs + 12 of the 17 Tier-3 POIs (27). The
## unsigned remainder rides `UNSIGNED_T23` with its reason — no silent gaps.
const SIGNS_T2: Array[Dictionary] = [
	{
		"id": "mothers_pub_coffee",
		"venue": "Mother's Pub & Coffee",
		"form": "box",
		"body": "massing:way/251728629",
		"face": "N", ## The row fronts north onto West Street's E-W run.
		"wall_u": -588.03, ## The POI's own x along the wall (way anchor exact).
		"mount_y": 3.4, ## The house-scale pub band on the 8 m block.
		"letter": 0.26, ## 9.915 × 0.26 = 2.58 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.1 (2900 West St): house-scale corner pub, small "
			+ "sign. The census way anchor (exact) sits inside its bake "
			+ "massing; West Street maps as an E-W street here (centerline "
			+ "z ≈ −283) with the row on its south side — the north wall is "
			+ "the street wall (frontage 9.6 m).",
	},
	{
		"id": "thumbs",
		"venue": "Thumbs",
		"form": "box",
		"body": "massing:way/251728624",
		"face": "N", ## Same West Street row, north wall.
		"wall_u": -526.9, ## The POI's own x along the wall (way anchor exact).
		"mount_y": 2.6, ## The slot is 4 m tall — a low painted band.
		"letter": 0.30, ## 3.459 × 0.30 = 1.04 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.10, 0.09, 0.08),
		"text_color": Color(0.91, 0.87, 0.78),
		"lit": 1, ## Painted, not lit — the hand-painted sign.
		"staged": false,
		"note": "VENUES 2.2 (2816 West St): a 6 m slot of a bar, "
			+ "hand-painted sign — painted means the lit box OFF (the "
			+ "Outlaws rule). Census way anchor exact; frontage 9.5 m.",
	},
	{
		"id": "west_street_deli",
		"venue": "West Street Deli",
		"form": "box",
		"body": "massing:way/251728626",
		"face": "N",
		"wall_u": -504.06, ## The POI's own x along the wall (way anchor exact).
		"mount_y": 2.6,
		"letter": 0.26, ## 7.305 × 0.26 = 1.90 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 1, ## The noon counterpoint — a daytime deli box, not a glow.
		"staged": false,
		"note": "VENUES 2.3 (2810 West St): small storefront deli in the "
			+ "Thumbs row; chalk boards are the daytime cue. Census way "
			+ "anchor exact; frontage 9.5 m.",
	},
	{
		"id": "bnc_field_house",
		"venue": "BNC Field House",
		"form": "box",
		"body": "massing:way/241365816",
		"face": "W", ## East side of the 200 block, across Welch.
		"wall_u": 175.99,
		"mount_y": 2.6, ## The low sports-bar band on the 4 m box.
		"letter": 0.30, ## 7.356 × 0.30 = 2.21 ≤ 4.0.
		"band": Vector3(4.2, 1.0, 0.28), ## The wide flat sign band.
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0, ## The TV-glow sports bar read.
		"staged": false,
		"note": "VENUES 2.4 (206 Welch, east side): widest ground-floor "
			+ "frontage in the 200 block's east row — the band rides the "
			+ "Census-named bake massing (32×14 m), frontage 20.7 m. The "
			+ "pack facing (1.3) is a nearest_street artifact; the wall "
			+ "choice is the survey's own block side.",
	},
	{
		"id": "blue_owl_bar",
		"venue": "Blue Owl Bar",
		"form": "box",
		"body": "placeholder:blue_owl_bar",
		"face": "E", ## West side of the 200 block (the Welch Crown Center row).
		"wall_u": 264.06,
		"mount_y": 5.4,
		"letter": 0.28, ## 5.787 × 0.28 = 1.62 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.5 (223 Welch Ste 3): suite-level storefront in "
			+ "the Crown Center row — its fixup box pokes 0.2 past the row "
			+ "massing way/236800161 and IS the street wall (the Paddy's "
			+ "rule). Welch frontage 14.2 m past the Hunt kink.",
	},
	{
		"id": "cornbred_barbecue",
		"venue": "Cornbred Barbecue",
		"form": "box",
		"body": "massing:way/260524827",
		"face": "N", ## The depot fronts Main across its set-back.
		"wall_u": 2635.76,
		"mount_y": 2.6, ## The low depot band (massing 4 m).
		"letter": 0.26, ## 8.591 × 0.26 = 2.23 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.6 (526 Main Ste 106, the restored depot): the "
			+ "depot massing (Main Street Station, 93×20 m) fronts NORTH "
			+ "onto Main — set back 56 m at Main's west end (the honest "
			+ "depot read; the frontage leg pins the set-back band, the "
			+ "pack facing 358.8 agrees).",
	},
	{
		"id": "whiskey_river",
		"venue": "Whiskey River",
		"form": "box",
		"body": "massing:way/269752175",
		"face": "N", ## South side of the 100 block.
		"wall_u": 3168.41,
		"mount_y": 5.2,
		"letter": 0.30, ## 6.327 × 0.30 = 1.90 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.7 (132-134 Main): saloon-style signboard on the "
			+ "south sidewalk row. Census-named bake massing; Main "
			+ "frontage 11.4 m.",
	},
	{
		"id": "london_underground",
		"venue": "London Underground",
		"form": "box",
		"body": "massing:way/269752154",
		"face": "N",
		"wall_u": 3116.26,
		"mount_y": 5.2,
		"letter": 0.26, ## 9.221 × 0.26 = 2.40 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.07, 0.07, 0.08), ## VENUES 2.8: dark paint.
		"text_color": Color(0.82, 0.78, 0.68),
		"lit": 1, ## "the no-lights conversation pub" — the lit box OFF.
		"staged": false,
		"note": "VENUES 2.8 (212 Main): below-street-level English pub, "
			+ "dark paint — the darkest doorway on Main signs dim, unlit. "
			+ "Census-named bake massing; frontage 11.7 m.",
	},
	{
		"id": "time_out",
		"venue": "Time Out",
		"form": "box",
		"body": "massing:way/236565187",
		"face": "W", ## The building fronts Kellogg on its west wall.
		"wall_u": -113.76,
		"mount_y": 3.4, ## The marquee band at the top of the 4 m box.
		"letter": 0.30, ## 4.025 × 0.30 = 1.21 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0, ## The marquee glow.
		"staged": false,
		"note": "VENUES 2.9 (120 Kellogg): set back off Main on Kellogg — "
			+ "the west wall is the Kellogg street wall (frontage 17.3 m; "
			+ "the pack facing 89.3 is a nearest_street artifact, recorded). "
			+ "Census-named bake massing (36×19 m).",
	},
	{
		"id": "torrent_brewing",
		"venue": "Torrent Brewing Company",
		"form": "box",
		"body": "massing:way/931902030",
		"face": "W", ## Burnett runs north-south west of the taproom.
		"wall_u": -401.38,
		"mount_y": 2.8, ## The 4 m warehouse box.
		"letter": 0.22, ## 11.497 × 0.22 = 2.53 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.11 (504 Burnett): warehouse-y taproom corner. "
			+ "Census-named bake massing; Burnett frontage 12.1 m.",
	},
	{
		"id": "aunt_maudes",
		"venue": "Aunt Maude's",
		"form": "plaque",
		"body": "massing:way/519341364",
		"face": "S", ## North side of Main — fronts south.
		"wall_u": 2570.01,
		"mount_y": 5.4, ## The 11 m block; the modest front at mid-height.
		"letter": 0.18, ## 5.890 × 0.18 = 1.06 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.12 (547 Main): white-tablecloth storefront — "
			+ "awning, modest brass-and-glass front: the lettered plaque IS "
			+ "the front's sign (the Great Plains rule). The fixup box is "
			+ "fully buried in the block massing, so the mount rides the "
			+ "massing's Main wall; frontage 11.9 m.",
	},
	{
		"id": "grove_cafe",
		"venue": "The Grove Cafe",
		"form": "box",
		"body": "massing:way/269752153",
		"face": "N", ## South side of the 100 block.
		"wall_u": 3193.27,
		"mount_y": 5.2,
		"letter": 0.28, ## 6.713 × 0.28 = 1.88 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0, ## The counter window glow at dawn.
		"staged": false,
		"note": "VENUES 2.13 (124 Main): narrow diner storefront, "
			+ "striped-awning feel. Census-named bake massing; frontage "
			+ "11.4 m.",
	},
	{
		"id": "provisions_lot_f",
		"venue": "Provisions Lot F",
		"form": "pole",
		"body": "", ## No baked body — the S research-park POI is out of core.
		"face": "poi",
		"wall_u": 0.0,
		"mount_y": 0.0,
		"letter": 0.32, ## 6.983 × 0.32 = 2.23 ≤ 2.4 cabinet face.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.14 (2400 N Loop Dr): the pack POI is placed but "
			+ "OUT of the v1 bake core (in_core false) — the big-box pylon "
			+ "stands the apron flat at the verified position, yawed onto "
			+ "its verified facing (9.8), exactly the Hickory Park rule; "
			+ "the building lands with the R5 extensions.",
	},
	{
		"id": "the_stan_tap",
		"venue": "The Stan Tap",
		"form": "box",
		"body": "massing:way/273536249",
		"face": "W", ## Stanton runs north-south west of the building.
		"wall_u": 212.64,
		"mount_y": 5.4, ## The 11 m corner bar block.
		"letter": 0.28, ## 5.646 × 0.28 = 1.58 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 2.15 (216 Stanton, the ex-Es Tas room): reuse the "
			+ "building, new sign paint. The addr-way anchor (census: "
			+ "unnamed ex-Es Tas building) — the fixup box is buried in "
			+ "the massing, so the mount rides the massing's Stanton wall; "
			+ "frontage 9.2 m.",
	},
	{
		"id": "sams_place",
		"venue": "Sam's Place",
		"form": "box",
		"body": "massing:way/237834143",
		"face": "S", ## North side of the 100 block.
		"wall_u": 3179.49,
		"mount_y": 5.2,
		"letter": 0.30, ## 5.183 × 0.30 = 1.55 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.08, 0.09, 0.11), ## VENUES 2.16: dark glass.
		"text_color": Color(0.93, 0.90, 0.82),
		"lit": 0, ## The widest game-room glow on the block.
		"staged": false,
		"note": "VENUES 2.16 (125 Main): classic downtown pool-hall front, "
			+ "dark glass. Census-named bake massing (the ex-Corner "
			+ "Pocket/DG's building); Main frontage 12.4 m.",
	},
]

const SIGNS_T3: Array[Dictionary] = [
	{
		"id": "stomping_grounds",
		"venue": "Stomping Grounds Cafe",
		"form": "box",
		"body": "massing:way/301106601",
		"face": "E", ## West side of the 300 block.
		"wall_u": 302.44,
		"mount_y": 5.4, ## The 11 m block at the quiet south end.
		"letter": 0.24, ## 10.481 × 0.24 = 2.52 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.1 (303 Welch, Ste 101/105): the last lit "
			+ "storefront at the south end. Status re-checked 2026-11-16 "
			+ "(Aug 2025 feature; Oct 2025 Green Drinks on the 303 patio) "
			+ "— the UNVERIFIED flag is cleared, recorded in-ticket. The "
			+ "fixup box is buried in the row massing; frontage 16.4 m.",
	},
	{
		"id": "clouds",
		"venue": "Clouds",
		"form": "box",
		"body": "massing:way/236800162",
		"face": "E", ## The tower fronts Stanton on its east wall.
		"wall_u": 92.72,
		"mount_y": 27.0, ## The 7th-floor band on the 40 m tower (~100 ft up).
		"letter": 0.50, ## 2.996 × 0.50 = 1.50 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0, ## The rooftop restaurant glass band.
		"staged": false,
		"note": "VENUES 3.2 (Legacy Tower 7th floor): model the tower's "
			+ "rooftop restaurant glass band — the sign rides the "
			+ "census-named Legacy Tower massing high on its Stanton wall "
			+ "(frontage 11.3 m); the Legends ghost plaque holds the "
			+ "ground floor.",
	},
	{
		"id": "ichiban",
		"venue": "Ichiban Japanese Restaurant",
		"form": "box",
		"body": "massing:way/231767126",
		"face": "E", ## West side of the 100 block.
		"wall_u": 80.5,
		"mount_y": 2.6, ## The narrow 4 m slot.
		"letter": 0.20, ## 12.641 × 0.20 = 2.53 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.11, 0.09, 0.08),
		"text_color": Color(0.86, 0.13, 0.10), ## The red lantern cue.
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.4 (117 Welch): narrow glowing Japanese-facade "
			+ "slot between bars, red lantern cue. Census-named bake "
			+ "massing (the ex-Fighting Burrito room — its ghost plaque "
			+ "shares the wall below); frontage 10.0 m.",
	},
	{
		"id": "blue_fish_poke",
		"venue": "Blue Fish Poke Bowl",
		"form": "box",
		"body": "placeholder:blue_fish_poke",
		"face": "E",
		"wall_u": 112.62,
		"mount_y": 4.6,
		"letter": 0.26, ## 8.938 × 0.26 = 2.32 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0, ## The bright minimal storefront.
		"staged": false,
		"note": "VENUES 3.5 (127 Welch): bright minimal storefront among "
			+ "the old brick — its fixup box pokes 2.5 past the row massing "
			+ "way/241365815 and IS the street wall. Frontage 7.7 m.",
	},
	{
		"id": "macubana",
		"venue": "Macubana",
		"form": "box",
		"body": "massing:way/241365821",
		"face": "W", ## East side of the 100 block.
		"wall_u": 78.47,
		"mount_y": 5.2,
		"letter": 0.30, ## 4.475 × 0.30 = 1.34 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.6 (116 Welch): signed as of the dated snapshot — "
			+ "the Sept 2026 report has the Welch brick-and-mortar closing "
			+ "(truck-only), recorded in-ticket as the end-of-era note per "
			+ "the survey's own instruction. Census-named massing; "
			+ "frontage 10.7 m.",
	},
	{
		"id": "dogtown_university",
		"venue": "Dogtown University",
		"form": "box",
		"body": "massing:way/259249457",
		"face": "E", ## West side of the 200 block (the Crown Center row).
		"wall_u": 233.23, ## The 217-Welch block's own depth.
		"mount_y": 4.2, ## The ground-floor suite band (Ste 101).
		"letter": 0.26, ## 8.681 × 0.26 = 2.26 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0.61, 0.09, 0.12), ## VENUES 3.7: cardinal-and-gold.
		"text_color": Color(0.87, 0.66, 0.11),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.7 (217 Welch Ste 101, Welch Crown Center): the "
			+ "name is the Campustown lore. HONEST DATA NOTE: the pack POI "
			+ "sits misplaced (inside the Kingland/23-Twenty massing) "
			+ "while its own src line names the census's Welch Crown "
			+ "Center way — the mount derives from THAT committed way "
			+ "(way/259249457, addr 217 Welch, 4 levels), the verified "
			+ "building; the POI data fix rides a later pack ticket. "
			+ "Frontage 11.1 m.",
	},
	{
		"id": "thai_kitchen",
		"venue": "Thai Kitchen",
		"form": "box",
		"body": "massing:way/1101564268",
		"face": "N", ## The Chamberlain row's south side.
		"wall_u": 75.56,
		"mount_y": 5.6, ## Mid-band on the 14 m Clock Tower Place block.
		"letter": 0.28, ## 5.530 × 0.28 = 1.55 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.8 (2410 Chamberlain): modest storefront on "
			+ "Chamberlain's student row. The named addr node sits inside "
			+ "the census-named Clock Tower Place massing, whose NORTH "
			+ "wall is the Chamberlain street wall here (frontage 10.9 m).",
	},
	{
		"id": "szechuan_house",
		"venue": "Szechuan House",
		"form": "pole",
		"body": "", ## No baked body — the west Lincoln Way POI is out of core.
		"face": "poi",
		"wall_u": 0.0,
		"mount_y": 0.0,
		"letter": 0.32, ## 7.202 × 0.32 = 2.30 ≤ 2.4 cabinet face.
		"band": Vector3.ZERO,
		"body_color": Color(0.72, 0.10, 0.09), ## VENUES 3.9: red-and-gold.
		"text_color": Color(0.90, 0.72, 0.15),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.9 (3605 Lincoln Way, ~1.4 km west): suburban "
			+ "strip storefront with the big red-and-gold roadside sign — "
			+ "the pylon stands the apron flat at the pack's doc-"
			+ "interpolated POI (in_core false, nearest street 710 m), "
			+ "yawed onto its verified facing (96.3): the Hickory rule.",
	},
	{
		"id": "carlos_quesadilla",
		"venue": "Carlos Quesadilla",
		"form": "truck",
		"body": "", ## A PROP at the pack POI (the gameday truck).
		"face": "poi", ## Yaw carries the POI's verified facing (359.4).
		"wall_u": 0.0,
		"mount_y": 0.0,
		"letter": 0.16, ## 7.690 × 0.16 = 1.23 ≤ 2.0 topper face.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.12: a truck prop with a game-day position — the "
			+ "pack POI sits inside the Jack Trice footprint (the gameday "
			+ "spot the survey names), so the truck stands there: box van "
			+ "+ cab + wheels + the topper plaque, the Superdog-cart rule.",
	},
	{
		"id": "isu_creamery",
		"venue": "Iowa State Creamery",
		"form": "plaque",
		"body": "massing:relation/2507887",
		"face": "E", ## Best match to the POI's committed facing (132.2).
		"wall_u": -452.53, ## The POI's own depth along the east wall.
		"mount_y": 3.0, ## The service window's ground-floor band.
		"letter": 0.16, ## 9.285 × 0.16 = 1.49 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.13 (Food Sciences 536 Farm House Lane): a small "
			+ "service window on a big brick lab building — treasure, not "
			+ "landmark: the lettered plaque. Campus interior: Farm House "
			+ "Lane is not in the pack street graph, so the frontage leg "
			+ "yields to the POI's committed facing law (recorded in the "
			+ "scenario).",
	},
	{
		"id": "morning_bell",
		"venue": "Morning Bell Coffee Roasters",
		"form": "box",
		"body": "massing:way/237834136",
		"face": "S", ## North side of Main.
		"wall_u": 3230.16,
		"mount_y": 5.0,
		"letter": 0.19, ## 12.950 × 0.19 = 2.46 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.16 (111 Main): clean modern sign in an old brick "
			+ "wall. Census-named bake massing; Main frontage 12.6 m.",
	},
	{
		"id": "cafe_diem",
		"venue": "Cafe Diem",
		"form": "box",
		"body": "massing:way/237834126",
		"face": "S",
		"wall_u": 3041.24,
		"mount_y": 5.0,
		"letter": 0.28, ## 4.565 × 0.28 = 1.28 ≤ 2.8.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES 3.17 (229 Main): the semester-schedule coffeehouse. "
			+ "Status re-checked 2026-11-16 (active May 2025 Main Street "
			+ "promotions; directory-listed) — the summer-closure flag is "
			+ "the seasonal rhythm the survey itself cites, cleared, "
			+ "recorded in-ticket. Census-named massing; frontage 12.8 m.",
	},
]

## The tier-2/3 venues that carry NO sign, with the honest reason each — the
## gate pins the set (pack tier-2/3 POIs minus the signed tables == these keys),
## so an unsigned venue can never silently appear or vanish.
const UNSIGNED_T23: Dictionary = {
	"mucky_duck_pub": "no OSM anchor anywhere in the extract — unplaced",
	"lost_and_found_lounge": "status re-check 2026-11-16 found "
		+ "permanent-closure reports (listing + past-tense community "
		+ "references) — the survey's UNVERIFIED flag stands, unsigned",
	"labyrinth_coffee": "unplaced (UNVERIFIED exact suite at 159 Sheldon)",
	"restaurant_888": "north Ames — no committed position (unplaced)",
	"el_azteca": "two locations, no committed position (unplaced)",
	"perfect_games": "north Ames — no committed position (unplaced)",
	"whatcha_smokin": "out of Ames entirely (Luther) — unplaced",
}

## --- the ghost plaques (T-199; the mourned CLOSED venues) -------------------
##
## The ticket's pinned mourned list is VENUES §6's 17 entries. Plaques go to
## the closed venues whose room the committed bake actually pins (11); the
## rest are recorded, not invented: People's + Charlie Yoke's share the
## unbuilt 2430 Lincoln Way room, One Night Stand's room is ambiguous
## (121/124 Welch — both candidate rooms trade as live signed venues),
## Hickory Park is SOLD-not-closed (a memorial would mourn a living business
## — the tone law), West Towne Pub's Westown Pkwy room is outside the bake,
## and Cocost has no address at all (UNVERIFIED details). The year rides the
## text only where the survey pins a closure year; unpinned rooms carry the
## name alone. All plaque texts are the §6 names byte-exact.
const PLAQUES: Array[Dictionary] = [
	{
		"id": "es_tas_bar_grill",
		"venue": "Es Tas Bar & Grill — 2024",
		"form": "plaque",
		"body": "massing:way/241365813",
		"face": "W", ## The 120 Welch vacant room's street wall.
		"wall_u": 92.0,
		"mount_y": 1.5, ## The ground-floor band.
		"letter": 0.16, ## 11.934 × 0.16 = 1.91 ≤ 2.2.
		"band": Vector3(2.4, 0.5, 0.08),
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 1: evicted Dec 2, 2024. The fly-through "
			+ "marks '[120 vacant — ex-Es Tas]' — the bake body between "
			+ "Macubana (116) and Portobello Road (122) IS that room; the "
			+ "original slot carries the memorial. The 216 Stanton "
			+ "flagship room trades as The Stan Tap (signed above) and "
			+ "tells that half of the story live.",
	},
	{
		"id": "wise_guys",
		"venue": "Wise Guys",
		"form": "plaque",
		"body": "massing:way/241365813",
		"face": "W", ## The same vacant 120 Welch room.
		"wall_u": 88.6, ## Offset along the wall from the Es Tas plaque.
		"mount_y": 1.5,
		"letter": 0.16, ## 4.604 × 0.16 = 0.74 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 12: closed before Es Tas took the SAME "
			+ "room — the two plaques share the wall at separate depths, "
			+ "the room's timeline in bronze. No closure year is pinned "
			+ "by the survey, so the text carries the name alone.",
	},
	{
		"id": "little_taipei",
		"venue": "Little Taipei — 2024",
		"form": "plaque",
		"body": "massing:way/241365808",
		"face": "N", ## The Chamberlain row's south side.
		"wall_u": -51.16,
		"mount_y": 1.5,
		"letter": 0.16, ## 9.439 × 0.16 = 1.51 ≤ 2.2.
		"band": Vector3(2.4, 0.5, 0.08),
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 2: closed permanently Oct 5, 2024. The "
			+ "building is NAMED in the committed bake (way/241365808 "
			+ "'Little Taipei', amenity=restaurant) — the room pins "
			+ "itself. Set back 23.9 m from Chamberlain, the honest "
			+ "set-back read.",
	},
	{
		"id": "fighting_burrito",
		"venue": "Fighting Burrito — 2019",
		"form": "plaque",
		"body": "massing:way/231767126",
		"face": "E",
		"wall_u": 78.0, ## Offset south of the Ichiban band above it.
		"mount_y": 1.2,
		"letter": 0.16, ## 11.214 × 0.16 = 1.79 ≤ 2.2.
		"band": Vector3(2.4, 0.5, 0.08),
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 10: closed May 2019 after 14 years. The "
			+ "later room (117 Welch) is Ichiban's building — the survey "
			+ "itself says Ichiban 'occupies the old Fighting Burrito "
			+ "slot' — so the plaque rides that wall under the live sign "
			+ "(heights separated). The 2712 L/W original room is "
			+ "outside the bake core.",
	},
	{
		"id": "the_scene",
		"venue": "The Scene",
		"form": "plaque",
		"body": "placeholder:paddys_irish_pub",
		"face": "W", ## The shared 124-126 facade.
		"wall_u": 116.6, ## Between the two doors.
		"mount_y": 1.4,
		"letter": 0.16, ## 4.540 × 0.16 = 0.73 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 15: closed; its LLC became Paddy's/Sips — "
			+ "the license literally reads THE SCENE, LLC DBA Sips and "
			+ "Paddy's. The plaque sits between the two doors on the "
			+ "shared facade, the room's first name in bronze. No "
			+ "closure year pinned by the survey.",
	},
	{
		"id": "cafe_mood",
		"venue": "Café Mood",
		"form": "plaque",
		"body": "massing:way/241365821",
		"face": "W", ## Macubana's room (the old Café Mood).
		"wall_u": 76.2, ## Offset from the Macubana band above.
		"mount_y": 1.4,
		"letter": 0.16, ## 4.694 × 0.16 = 0.75 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 14: closed; the room is Macubana's now — "
			+ "the plaque rides the same wall at ground floor, the "
			+ "room's earlier era under the live sign. No closure year "
			+ "pinned by the survey.",
	},
	{
		"id": "dgs_tap_house",
		"venue": "DG's Tap House + Corner Pocket — 2019",
		"form": "plaque",
		"body": "massing:way/237834143",
		"face": "S", ## The Sam's Place building's Main wall.
		"wall_u": 3183.4, ## Offset east of the Sam's Place band above.
		"mount_y": 1.5,
		"letter": 0.13, ## 18.248 × 0.13 = 2.37 ≤ 2.6.
		"band": Vector3(2.8, 0.5, 0.08), ## The long name's widened slab.
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 4: licenses suspended Apr 30 2019, "
			+ "permanent May 2019. The room IS Sam's Place's building "
			+ "(census: Sam's Place at the former Corner Pocket/DG's) — "
			+ "the plaque rides the same Main wall at ground floor.",
	},
	{
		"id": "olde_main_brewing",
		"venue": "Olde Main Brewing — 2019",
		"form": "plaque",
		"body": "massing:way/254335401",
		"face": "N", ## 316 Main: even address, SOUTH side — fronts north.
		"wall_u": 2932.4,
		"mount_y": 1.5,
		"letter": 0.16, ## 12.539 × 0.16 = 2.01 ≤ 2.2.
		"band": Vector3(2.4, 0.5, 0.08),
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 5: closed May 2019 (same owner as DG's). "
			+ "The census addr-way (316 Main — even number, the south "
			+ "side) resolves to the committed massing the OSM tags name "
			+ "Sweet Carolines; its NORTH wall is the Main street wall "
			+ "(frontage 12.2 m) and carries the plaque.",
	},
	{
		"id": "legends",
		"venue": "Legends — 2012",
		"form": "plaque",
		"body": "massing:way/236800162",
		"face": "E", ## Legacy Tower's Stanton wall.
		"wall_u": 96.5, ## Offset north of the Clouds band far above.
		"mount_y": 1.5,
		"letter": 0.16, ## 7.742 × 0.16 = 1.24 ≤ 2.0.
		"band": Vector3.ZERO,
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 6: the rooftop closed end of March 2012 — "
			+ "VENUES 3.2: 'the ghost of Legends haunts the top floors'. "
			+ "The memorial holds the tower's ground floor while the "
			+ "Clouds band rides the 7th floor of the same census-named "
			+ "massing.",
	},
	{
		"id": "battles_bar_b_q",
		"venue": "Battle's Bar-B-Q — 2009",
		"form": "plaque",
		"body": "massing:way/231767135",
		"face": "W", ## The original 112 Hayward room fronts Hayward.
		"wall_u": 56.81,
		"mount_y": 1.5,
		"letter": 0.16, ## 11.535 × 0.16 = 1.85 ≤ 2.2.
		"band": Vector3(2.4, 0.5, 0.08),
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 7: closed 2009 after George Battle died. "
			+ "The census addr-way (112 Hayward) resolves to this "
			+ "committed massing — the ORIGINAL room carries the memorial "
			+ "(the later 218 Welch slot is way/241365819, recorded "
			+ "here); Hayward frontage 11.6 m.",
	},
	{
		"id": "angry_irishmen",
		"venue": "The Angry Irishmen — 2025",
		"form": "plaque",
		"body": "massing:way/237834131",
		"face": "S", ## North side of Main.
		"wall_u": 3206.22,
		"mount_y": 1.5,
		"letter": 0.16, ## 12.860 × 0.16 = 2.06 ≤ 2.2.
		"band": Vector3(2.4, 0.5, 0.08),
		"body_color": Color(0, 0, 0, 0),
		"text_color": Color(0, 0, 0, 0),
		"lit": 0,
		"staged": false,
		"note": "VENUES §6 row 11: closed ~2025-26 — Mary Jane's (the "
			+ "census-named bake massing, way/237834131) replaced it by "
			+ "March 2026, so 2025 is the last full year the survey's "
			+ "own dates pin; the derivation is recorded in-ticket. Main "
			+ "frontage 12.5 m.",
	},
]


## Builds the PLACED signs under `root` (a plain Node3D — the world supplies
## it) and returns one record per placed sign for the gate + the world report:
## {id, venue, form, pos, yaw, node, cart} — pack-frame coordinates (the world
## node IS the pack frame). Staged entries (The Cafe) build nothing.
static func build(root: Node3D) -> Array[Dictionary]:
	return _build_table(root, SIGNS)


## (T-199) The tiers 2–3 signs under their own world root — same record
## shape, no staged entries (the out-of-core venues ride the apron as
## free-standing forms, the Hickory rule).
static func build_tiers(root: Node3D) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	table.append_array(SIGNS_T2)
	table.append_array(SIGNS_T3)
	return _build_table(root, table)


## (T-199) The ghost plaques under their own world root — memorial-styled
## lettered slabs at the pinned mourned-list positions. The bronze/parchment
## pair is stamped onto every entry here (the table entries stay alpha-0 so
## the styling lives in ONE place — these constants).
static func build_plaques(root: Node3D) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	for e: Dictionary in PLAQUES:
		var entry: Dictionary = e.duplicate()
		entry["body_color"] = PLAQUE_MEMORIAL_BODY
		entry["text_color"] = PLAQUE_MEMORIAL_TEXT
		table.append(entry)
	return _build_table(root, table)


## One mount-table walk: instantiate + dress + mount every PLACED entry.
## Shared by the tier-1 build and the T-199 tiers/plaques builds.
static func _build_table(root: Node3D, table: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for entry: Dictionary in table:
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
			"truck":
				var truck := _build_truck(root, entry)
				sign = truck["sign"]
				pos = truck["pos"]
				yaw = float(truck["yaw"])
				var rec := _record(entry, sign, pos, yaw)
				rec["truck"] = true
				rec["truck_parts"] = int(truck["parts"])
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


## The Carlos Quesadilla truck prop (VENUES 3.12): a box-van food truck —
## body, cab, four wheels — with the name topper over the box roof, standing
## at the pack POI's gameday position yawed onto its verified facing.
## Visual-only like every sign (no colliders). Returns {sign, pos, yaw, parts}.
static func _build_truck(root: Node3D, entry: Dictionary) -> Dictionary:
	var poi := _poi(entry["id"])
	var n := _facing_normal(float(poi["facing_deg"]))
	var yaw := atan2(n.x, n.z)
	var truck := Node3D.new()
	truck.name = "Truck_%s" % entry["id"]
	truck.position = Vector3(float(poi["position"][0]), 0.0,
			float(poi["position"][1]))
	truck.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(truck)
	var parts := 0
	parts += _cart_box(truck, "Body", TRUCK_BOX,
			Vector3(0.0, TRUCK_BOX_Y, 0.0), TRUCK_STEEL)
	parts += _cart_box(truck, "Cab", TRUCK_CAB,
			Vector3(0.0, TRUCK_CAB_Y, TRUCK_CAB_Z),
			TRUCK_STEEL.lerp(Color(0.95, 0.90, 0.80), 0.35))
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.22, 0.24)
	for i: int in TRUCK_WHEELS.size():
		var wheel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = TRUCK_WHEEL_R
		mesh.bottom_radius = TRUCK_WHEEL_R
		mesh.height = TRUCK_WHEEL_H
		mesh.material = steel
		wheel.name = "Wheel%d" % (i + 1)
		wheel.mesh = mesh
		wheel.position = TRUCK_WHEELS[i]
		wheel.rotation = Vector3(0.0, 0.0, PI * 0.5) ## Axis along x.
		truck.add_child(wheel)
		parts += 1
	var sign: SignText = SignText.new()
	sign.typology = SignText.Typology.PLAQUE
	_dress(sign, entry)
	sign.name = "Sign_%s" % entry["id"]
	sign.position = Vector3(0.0, TRUCK_SIGN_Y, TRUCK_SIGN_Z)
	truck.add_child(sign)
	return {"sign": sign, "pos": truck.position, "yaw": yaw, "parts": parts}
