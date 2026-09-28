class_name Player
extends CharacterBody3D
## Placeholder arcade flight controller (scaffold).
## T-001 replaces this with the real flap / glide / dive model.

const GRAVITY := 18.0
const MAX_SPEED := 18.0
const DRAG := 0.35

@export var flap_impulse: float = 7.0
@export var flap_cooldown: float = 0.3
@export var turn_speed: float = 2.2
@export var pitch_speed: float = 1.8
@export var glide_speed: float = 10.0 ## Forward speed at which lift cancels gravity.

var _flap_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_steer(delta)
	_flap(delta)
	_apply_flight_forces(delta)
	move_and_slide()

func _steer(delta: float) -> void:
	var turn_input := Input.get_axis("turn_right", "turn_left")
	rotate_y(turn_input * turn_speed * delta)
	var pitch_input := Input.get_axis("pitch_down", "pitch_up")
	rotate_object_local(Vector3.RIGHT, pitch_input * pitch_speed * delta)

func _flap(delta: float) -> void:
	_flap_timer = maxf(_flap_timer - delta, 0.0)
	if not Input.is_action_just_pressed("flap") or _flap_timer > 0.0:
		return
	var flap_direction := (transform.basis.y - transform.basis.z).normalized()
	velocity += flap_direction * flap_impulse
	_flap_timer = flap_cooldown

func _apply_flight_forces(delta: float) -> void:
	var forward_speed := velocity.dot(-transform.basis.z)
	var lift := clampf(forward_speed / glide_speed, 0.0, 1.0)
	velocity.y -= GRAVITY * (1.0 - lift) * delta
	velocity *= 1.0 - DRAG * delta
	velocity = velocity.limit_length(MAX_SPEED)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
