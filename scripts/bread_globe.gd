class_name BreadGlobe
extends Control
## The bread globe (T-111): the HUD's pigeon-frame bread finder — a drawn
## 40 px instrument that replaces the T-037/T-057/T-098/T-058 chevron lineage
## in the pointer slot. A dark ball disc carries a segment protruding from its
## center: the target's direction RELATIVE TO THE PIGEON'S OWN ORIENTATION,
## projected through a fixed vantage tilted `vantage_tilt_deg` down from the
## widget's level plane (a camera hovering behind and above the pigeon). The
## owner's steering contract: steer the pigeon along the segment's direction
## and you intersect the bread — level dead ahead draws straight up (its tip
## landing exactly on the fly-to pip), a crumb above/below/left/right swings
## the segment to match, and a stern crumb draws DOWN (short, foreshortened)
## so "behind you" reads at a glance with zero text. The tilt is load-bearing:
## straight-on, a dead-ahead crumb projects to a zero-length dot and the
## contract is undrawable. Widget's upper half = in front of the pigeon,
## lower half = behind it; projected LENGTH separates ahead from above and
## stern from below. Deliberately a drawn Control (the repo's HUD idiom, no
## second render target, fully machine-checkable headless) and deliberately
## camera-blind: an attitude instrument moves when the PIGEON moves.
## Main owns ALL the math — this widget only draws what it is handed:
## `aim(dir_local)` with +X starboard, +Y up, −Z the nose. The flash (T-111)
## mixes the ink toward the score gold and back over `flash_seconds` of GAME
## time — deterministic under --fixed-fps, frozen while paused or over, like
## every HUD pulse. Redraws are guarded (the T-035/T-055/T-077 idle-frame
## concern, the PoopReticle's same-shaped changed-value guard): idle frames
## queue nothing.

## The projected ink at rest — the pointer label's font color
## (scenes/main.tscn), shared by segment, tip marker and pip.
const INK_ALPHA_SEGMENT := 0.75
## Under-stroke widths: the T-019 outline convention (a dark stroke under the
## ink) at draw-list scale.
const UNDER_STROKE_PX := 3.0
const INK_STROKE_PX := 1.5
## Ring/tip geometry.
const RING_SEGMENTS := 48 ## Polyline samples of the level-ring ellipse.
const PIP_RADIUS_PX := 2.0 ## The fly-to pip's dot radius.
const TIP_RADIUS_PX := 2.5 ## The tip marker's dot/ring radius.
## The redraw guard's resolution: the flash mix is quantized to 1/16 steps, so
## a 0.4 s flash redraws ~16 times, not every frame.
const FLASH_MIX_STEPS := 16.0

@export_group("Globe")
@export var ball_radius_px: float = 13.0 ## The ball disc's radius (px) — the dark puck.
@export var segment_px: float = 21.0 ## Full segment length (px) — the Gate 3 trim knob.
@export var vantage_tilt_deg: float = 25.0 ## The fixed vantage's downward pitch (deg) — lengthens ahead/stern projections to a readable 0.42x.
@export var flash_seconds: float = 0.4 ## Game-time seconds the target-change flash takes to mix out and back.

@export_group("Colors")
@export var ball_fill: Color = Color(0, 0, 0, 0.35) ## The puck's translucent fill (the T-080 hunger-track pair).
@export var ball_rim: Color = Color(0, 0, 0, 0.85) ## The puck's dark rim — never flashes.
@export var ring_color: Color = Color(1, 1, 1, 0.25) ## The level ring — the pigeon's local level plane, projected.
@export var segment_color: Color = Color(1, 1, 1, 0.75) ## The ink: segment, tip marker and pip at rest.
@export var outline_color: Color = Color(0, 0, 0, 0.85) ## The under-stroke color (the T-019 outline convention).
@export var flash_color: Color = Color(1.0, 0.85, 0.3) ## The score gold the ink mixes toward (scripts/main.gd's pulse gold).

## The pigeon-local direction the widget currently shows: +X starboard, +Y up,
## −Z the nose. ZERO when cleared — the machine-readable state the harness
## reads, never pixels.
var dir_local: Vector3 = Vector3.ZERO
## The drawn tip in px from the widget's center — the projected `dir_local`
## scaled by `segment_px`.
var screen_offset: Vector2 = Vector2.ZERO
## True while the target-change flash is running (game time).
var flash_active: bool = false

var _flash_left: float = 0.0 ## Game-time seconds left in the flash; 0 = at rest.
var _last_mix_step: int = -1 ## The quantized flash mix last drawn — redraw only when it steps.
var _drawn_tip: Vector2 = Vector2.ZERO ## The tip px last drawn — redraw only when the new one moves >= 0.5 px.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE ## Never eats HUD clicks.
	visible = false ## Hidden until Main aims it, like the pointer label.


## Aim at a pigeon-local direction (+X starboard, +Y up, −Z the nose): store
## it, publish its projected tip, and queue a redraw ONLY when the drawn tip
## actually moves (>= 0.5 px — the changed-value guard; a hovering pigeon
## re-aims every frame and redraws none of them).
func aim(p_dir_local: Vector3) -> void:
	dir_local = p_dir_local
	var tip := _project(dir_local) * segment_px
	screen_offset = tip
	if (tip - _drawn_tip).length() >= 0.5:
		_drawn_tip = tip
		queue_redraw()


## Start the target-change flash: the ink (segment, tip, ring, pip) mixes
## toward `flash_color` and back over `flash_seconds` of game time. Called by
## Main when the named bread target is a DIFFERENT crumb than the one last
## drawn — never on first acquisition, never in city mode.
func flash() -> void:
	_flash_left = flash_seconds
	if not flash_active:
		flash_active = true
	queue_redraw() ## The ink leaves rest the moment the flash starts.


## Back to the empty state: direction zeroed, hidden, any running flash
## cancelled — the null-target and fresh-run state (Main's reset block calls
## this, so a new run's first acquisition is flash-less).
func clear() -> void:
	dir_local = Vector3.ZERO
	screen_offset = Vector2.ZERO
	_drawn_tip = Vector2.ZERO
	_flash_left = 0.0
	flash_active = false
	visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return ## At rest — idle frames touch nothing.
	_flash_left -= delta
	var step := _flash_step()
	if step != _last_mix_step:
		_last_mix_step = step
		queue_redraw() ## The ink is visibly moving — redraw at mix resolution.
	## End-of-flash check AFTER the decrement, with a microsecond-class
	## tolerance: the 0.4 s countdown at the fixed 60 Hz step lands within a
	## float hair of zero on exactly the 24th frame, and the flash must be
	## BACK AT REST by then (the sim harness's flash arm samples that frame).
	if _flash_left <= 0.000001:
		_flash_left = 0.0
		flash_active = false
		queue_redraw() ## Back to rest ink.


## The flash's mix amount, 0..1: a sine arc over the flash's lifetime — the
## ink leaves rest, peaks at gold, and settles back (the hunger-pulse shape,
## one-shot).
func _flash_mix() -> float:
	if _flash_left <= 0.0 or flash_seconds <= 0.0:
		return 0.0
	var progress: float = 1.0 - _flash_left / flash_seconds
	return sin(clampf(progress, 0.0, 1.0) * PI)


func _flash_step() -> int:
	return roundi(_flash_mix() * FLASH_MIX_STEPS)


## The fixed-vantage projection: pigeon-local direction -> px offset from the
## widget's center. A vantage hovering behind and above the pigeon, pitched
## down by `vantage_tilt_deg` (s): canvas y is DOWN, so the y term negates.
## Dead ahead (0,0,-1) projects to (0, -sin s) — straight up, 0.42x full;
## straight above (0,1,0) to (0, -cos s) — straight up, 0.91x full; stern
## (0,0,1) mirrors dead ahead straight DOWN. This is the widget's whole math.
func _project(p_dir_local: Vector3) -> Vector2:
	var s := deg_to_rad(vantage_tilt_deg)
	return Vector2(p_dir_local.x,
			-(p_dir_local.y * cos(s) - p_dir_local.z * sin(s)))


## The ink color for the flashable strokes: rest ink mixed toward the score
## gold by the current flash amount.
func _ink() -> Color:
	return segment_color.lerp(flash_color, _flash_mix())


func _draw() -> void:
	var center := size * 0.5
	var s := deg_to_rad(vantage_tilt_deg)
	## 1. The ball disc — the HUD's dark puck grammar (fill + rim), under
	##    everything, never flashing.
	draw_circle(center, ball_radius_px, ball_fill)
	draw_arc(center, ball_radius_px, 0.0, TAU, RING_SEGMENTS, ball_rim,
			INK_STROKE_PX, true)
	## 2. The level ring — the pigeon's local level plane, projected: a
	##    stroked ellipse, semi-axes (segment_px, segment_px * sin s). Tip on
	##    the ring = level with you; above = up-component; below = down.
	var ring: PackedVector2Array = PackedVector2Array()
	ring.resize(RING_SEGMENTS + 1)
	for i in RING_SEGMENTS + 1:
		var a := TAU * float(i) / float(RING_SEGMENTS)
		ring[i] = center + Vector2(segment_px * cos(a),
				segment_px * sin(s) * sin(a))
	draw_polyline(ring, outline_color, UNDER_STROKE_PX, true) ## Under-stroke first.
	draw_polyline(ring, ring_color.lerp(flash_color, _flash_mix()),
			INK_STROKE_PX, true)
	## 3. The fly-to pip — where the tip lands when the crumb is level dead
	##    ahead. "Fly at the pip" is the whole instruction.
	var pip := center + Vector2(0.0, -segment_px * sin(s))
	draw_circle(pip, PIP_RADIUS_PX, outline_color)
	draw_circle(pip, PIP_RADIUS_PX * 0.5, _ink())
	## 4. The segment — center to tip, dark under-stroke then ink (the label
	##    outline convention).
	var tip := center + screen_offset
	draw_line(center, tip, outline_color, UNDER_STROKE_PX, true)
	draw_line(center, tip, _ink(), INK_STROKE_PX, true)
	## 5. The tip marker — filled dot bow (dir_local.z < 0), hollow ring stern
	##    (dir_local.z > 0). Redundant with the geometry by design — a symbol
	##    may reinforce a convention but never be its sole carrier (T-058's
	##    lesson). The under-stroke already ran the segment to the tip.
	if dir_local.z < -0.0001:
		draw_circle(tip, TIP_RADIUS_PX, outline_color)
		draw_circle(tip, TIP_RADIUS_PX - INK_STROKE_PX * 0.5, _ink())
	elif dir_local.z > 0.0001:
		draw_arc(tip, TIP_RADIUS_PX, 0.0, TAU, RING_SEGMENTS, outline_color,
				INK_STROKE_PX * 0.5, true)
		draw_arc(tip, TIP_RADIUS_PX, 0.0, TAU, RING_SEGMENTS, _ink(),
				INK_STROKE_PX * 0.5, true)
