extends Node
## Sound service (T-012): every gameplay sound effect and the looping city
## ambience bed live here, mixed onto the two dedicated buses from
## `default_bus_layout.tres` (SFX, Ambience — both under Master). Gameplay
## scripts stay presentation-light: they call `play()` for the pigeon's own
## sounds (non-positional) or `play_at()` for events out in the city
## (3D-positional, attenuates with distance) with a sound name — this service
## owns the streams, the pool of players, the per-sound mix and a little pitch
## jitter so repeats don't sound sampled. `played_counts` records every play
## per sound name — the sim harness (Gate 1b) and the autoplay DONE line report
## it as machine evidence that game events actually fired their sounds.
## Sources + licenses: assets/CREDITS.md (CC0 only).

## The SFX palette: stream, per-sound trim (dB, on the SFX bus) and pitch
## jitter (± fraction). Non-positional unless noted.
const SOUNDS: Dictionary = {
	"flap": {
		"stream": preload("res://assets/third-party/opengameart/flap_whoosh.ogg"),
		"volume_db": -6.0,
		"pitch_jitter": 0.12,
	},
	"effort": {
		"stream": preload("res://assets/third-party/opengameart/wing_effort.ogg"),
		"volume_db": -8.0,
		"pitch_jitter": 0.1,
	},
	"splat": {
		"stream": preload("res://assets/third-party/opengameart/splat.ogg"),
		"volume_db": -2.0,
		"pitch_jitter": 0.08,
	},
	"yelp": {
		"stream": preload("res://assets/third-party/opengameart/tourist_yelp.ogg"),
		"volume_db": -3.0,
		"pitch_jitter": 0.15,
	},
	"panic": {
		"stream": preload("res://assets/third-party/opengameart/tourist_panic.ogg"),
		"volume_db": -4.0,
		"pitch_jitter": 0.1,
	},
	"honk": {
		"stream": preload("res://assets/third-party/opengameart/car_horn.ogg"),
		"volume_db": -3.0,
		"pitch_jitter": 0.06,
	},
	"peck": {
		"stream": preload("res://assets/third-party/kenney/bread_peck.ogg"),
		"volume_db": -4.0,
		"pitch_jitter": 0.2,
	},
}

## The city bed (T-012): traffic murmur + distant chatter, looping forever on
## the Ambience bus — quieter than any gameplay sound by bus and trim. Sources
## were made into seamless loops (head-tail crossfade, see CREDITS.md).
const AMBIENCE: Dictionary = {
	"traffic": {
		"stream": preload("res://assets/third-party/opengameart/traffic_murmur_loop.ogg"),
		"volume_db": 0.0,
	},
	"chatter": {
		"stream": preload("res://assets/third-party/opengameart/distant_chatter_loop.ogg"),
		"volume_db": -8.0, ## The chatter bed is peakier than the murmur — sit it back.
	},
}

@export_group("Voices")
@export var pool_size_2d: int = 6 ## Non-positional voices (the pigeon's own sounds).
@export var pool_size_3d: int = 12 ## Positional voices (city events overlap in bursts).
@export var pos_unit_size: float = 10.0 ## 3D attenuation reference (m): ~half volume at this distance.

## Plays per sound name since boot — sim scenarios reset it; the autoplay DONE
## line reports it. Both play() and play_at() count.
var played_counts: Dictionary = {}

## True while the ambience beds are playing (Main starts/stops them; a run
## restart keeps them — the city never falls silent).
var ambience_playing: bool = false

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _ambience_players: Array[AudioStreamPlayer] = []
var _next_2d: int = 0
var _next_3d: int = 0


func _ready() -> void:
	for bed_name in AMBIENCE:
		var stream: AudioStream = AMBIENCE[bed_name].stream
		var ogg := stream as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true ## The bed never falls silent.
	for _i in pool_size_2d:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool_2d.append(p)
	for _i in pool_size_3d:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = &"SFX"
		p3.unit_size = pos_unit_size
		add_child(p3)
		_pool_3d.append(p3)
	for bed_name in AMBIENCE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Ambience"
		player.stream = AMBIENCE[bed_name].stream
		player.volume_db = AMBIENCE[bed_name].volume_db
		add_child(player)
		_ambience_players.append(player)


## Plays a sound everywhere-equal (the pigeon's own flap/effort/peck).
func play(sound_name: String) -> void:
	var sound: Dictionary = SOUNDS.get(sound_name, {})
	if sound.is_empty():
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	var p := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	_play_on(p, sound)
	_count(sound_name)


## Plays a sound at a world position (splats, yelps, honks — attenuates with
## distance and pans with the chase camera).
func play_at(sound_name: String, pos: Vector3) -> void:
	var sound: Dictionary = SOUNDS.get(sound_name, {})
	if sound.is_empty():
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	p.global_position = pos
	_play_on(p, sound)
	_count(sound_name)


## Starts the ambience beds — idempotent; a paused tree pauses them with it.
func start_ambience() -> void:
	if ambience_playing:
		return
	ambience_playing = true
	for player in _ambience_players:
		player.play()


## Stops the ambience beds (leaving the city for the title screen).
func stop_ambience() -> void:
	ambience_playing = false
	for player in _ambience_players:
		player.stop()


## The live ambience players — the sim harness asserts bus and playing state.
func ambience_players() -> Array[AudioStreamPlayer]:
	return _ambience_players


## Zeroes the play counters (sim scenarios measure their own events only).
func reset_counts() -> void:
	played_counts = {}


## Whether a stream repeats forever — the ambience beds must.
func stream_is_looping(stream: AudioStream) -> bool:
	var ogg := stream as AudioStreamOggVorbis
	return ogg != null and ogg.loop


## `player` is untyped on purpose: AudioStreamPlayer and AudioStreamPlayer3D
## share no closer base than Node in Godot 4, and the stream/volume/pitch API
## is identical on both.
func _play_on(player, sound: Dictionary) -> void:
	player.stream = sound.stream
	player.volume_db = sound.volume_db
	var jitter: float = sound.get("pitch_jitter", 0.0)
	player.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	player.play()


func _count(sound_name: String) -> void:
	played_counts[sound_name] = int(played_counts.get(sound_name, 0)) + 1
