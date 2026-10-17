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

	## --- T-123 additions -----------------------------------------------------
	## The pigeon's voice (in-house synthesis — assets/generated/, see
	## CREDITS.md): soft coos while grounded, a smug one after every other
	## splat, and the two ending stingers through `play_ending()`.
	"coo_idle": {
		"stream": preload("res://assets/generated/coo_idle.wav"),
		"volume_db": -6.0,
		"pitch_jitter": 0.06,
	},
	"coo_waddle": {
		"stream": preload("res://assets/generated/coo_waddle.wav"),
		"volume_db": -7.0,
		"pitch_jitter": 0.06,
	},
	"coo_smug": {
		"stream": preload("res://assets/generated/coo_smug.wav"),
		"volume_db": -5.0,
		"pitch_jitter": 0.05,
	},
	"splat_2": {
		"stream": preload("res://assets/generated/splat_2.wav"),
		"volume_db": -3.0,
		"pitch_jitter": 0.08,
	},
	"splat_3": {
		"stream": preload("res://assets/generated/splat_3.wav"),
		"volume_db": -4.0,
		"pitch_jitter": 0.08,
	},
	## The yelp/honk variants ride the SAME CC0 recordings at a shifted base
	## pitch — the group cycler (VARIANT_GROUPS) is what kills the
	## same-sample read, not new files.
	"yelp_2": {
		"stream": preload("res://assets/third-party/opengameart/tourist_yelp.ogg"),
		"volume_db": -3.0,
		"pitch_jitter": 0.15,
		"pitch": 0.88,
	},
	"honk_2": {
		"stream": preload("res://assets/third-party/opengameart/car_horn.ogg"),
		"volume_db": -3.0,
		"pitch_jitter": 0.06,
		"pitch": 0.9,
	},
	"stinger_win": {
		"stream": preload("res://assets/generated/stinger_win.wav"),
		"volume_db": -5.0,
		"pitch_jitter": 0.0,
	},
	"stinger_lose": {
		"stream": preload("res://assets/generated/stinger_lose.wav"),
		"volume_db": -5.0,
		"pitch_jitter": 0.0,
	},
}

## Variant groups (T-123): playing a group name cycles its members round-robin
## so repeated hits stop reading as one sample. The cycler is a plain counter —
## deterministic, no RNG — and `played_counts` records the REQUESTED name, so
## the sim's per-event counts (and the autoplay DONE line) stay exact.
const VARIANT_GROUPS: Dictionary = {
	"splat": ["splat", "splat_2", "splat_3"],
	"yelp": ["yelp", "yelp_2"],
	"honk": ["honk", "honk_2"],
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
var _variant_next: Dictionary = {} ## (T-123) Per-group round-robin counters.


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


## Plays a sound everywhere-equal (the pigeon's own flap/effort/peck). A
## variant-group name cycles its members (T-123).
func play(sound_name: String) -> void:
	var sound: Dictionary = SOUNDS.get(_resolve_variant(sound_name), {})
	if sound.is_empty():
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	var p := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	_play_on(p, sound)
	_count(sound_name)


## Plays a sound at a world position (splats, yelps, honks — attenuates with
## distance and pans with the chase camera). A variant-group name cycles its
## members (T-123).
func play_at(sound_name: String, pos: Vector3) -> void:
	var sound: Dictionary = SOUNDS.get(_resolve_variant(sound_name), {})
	if sound.is_empty():
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	p.global_position = pos
	_play_on(p, sound)
	_count(sound_name)


## (T-123) Plays an ending stinger through a transient always-on voice: the
## score screen pauses the tree the same frame it opens, and the bed contract
## (ambience pauses with the tree) must not swallow the sting. Frees itself.
func play_ending(sound_name: String) -> void:
	var sound: Dictionary = SOUNDS.get(sound_name, {})
	if sound.is_empty():
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.stream = sound.stream
	p.volume_db = sound.volume_db
	p.finished.connect(p.queue_free)
	p.play()
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
	player.pitch_scale = sound.get("pitch", 1.0) * (1.0 + randf_range(-jitter, jitter))
	player.play()


## (T-123) The variant-group round-robin: group name → member name; plain
## names pass through untouched.
func _resolve_variant(sound_name: String) -> String:
	var group: Array = VARIANT_GROUPS.get(sound_name, [])
	if group.is_empty():
		return sound_name
	var idx := int(_variant_next.get(sound_name, 0))
	_variant_next[sound_name] = (idx + 1) % group.size()
	return group[idx]


func _count(sound_name: String) -> void:
	played_counts[sound_name] = int(played_counts.get(sound_name, 0)) + 1
