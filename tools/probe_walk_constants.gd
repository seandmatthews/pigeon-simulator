extends SceneTree
## The people-locomotion constants census (T-165): re-measures the T-138 rig's
## clip/stride numbers live — the persistent form of the 2026-11-04 throwaway
## probe whose numbers are recorded in the ticket ledger. Run headless:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/probe_walk_constants.gd
##
## Five printed sections:
##   1. the pinned constants echoed from `PeopleRig`;
##   2. live lengths of all six whitelisted clips (vs the SECONDS constants);
##   3. the stride census — `Rig|Walk` then `Rig|Sprint` at rate 1.0 from
##      frame 0, one full loop stepped at SAMPLES_PER_CYCLE samples
##      (dt = length / STEPS, `anim.advance` + `force_update_all_bone_transforms`
##      — the proven headless pattern from `people_on_one_rig`,
##      tests/sim_test.gd), tracking world-space DEF-foot.L/R origins; reports
##      per-foot x/y/z ranges and stride = fore-aft(L) + fore-aft(R) against
##      the pinned constants with delta and percent;
##   4. the hips in-place check — per-axis DEF-hips world range must read
##      ~0.0000 in both locomotion clips (a future clip edit that adds root
##      motion reds this census; the script bob layers are the ONLY vertical
##      motion on a walking figure);
##   5. the played-rate table — what the rate law does at the shipped driver
##      speeds, plus the elder sit pacing.
##
## Sampling tolerance ±0.5%: the fore-aft extremes of a stepped sample train
## can miss the true extremes by up to half a step (the ticket's 48 vs 144
## sample passes agreed within 0.4%). The census-green verdict therefore
## gates each MEASURED stride against its LEDGER-RECORDED value (±0.5%) —
## clip drift reds, agreement greens — while the comparison against the
## PINNED `PeopleRig` constants is printed as findings only (the sprint's
## recorded −2.2% is the ledger's known defect candidate, shipped as-is —
## see the ticket). Bone names are the import contract
## (`DEF-foot.L`/`DEF-foot.R`/`DEF-hips`, tools/import_people_rig.gd);
## "fore-aft" is the bone-origin range along the rig's local Z (the pack's
## forward is −Z, scripts/people_rig.gd); stride = per-foot fore-aft L + R
## (two feet, half a cycle apart — the T-138 derivation).

const SAMPLES_PER_CYCLE := 144
const CLIPS_CENSUSED: Array[String] = ["Rig|Walk", "Rig|Sprint"]
const FEET: Array[String] = ["DEF-foot.L", "DEF-foot.R"]
## The ledger's MEASURED strides (the ticket's recorded 2026-11-04 census,
## re-confirmed by this probe on the landed tree): the census-green band is
## against THESE — a future clip edit that moves the live foot travel moves
## the measured stride past ±0.5% of the recorded value and reds the census.
## The pinned-constant comparison below stays a printed finding: the sprint's
## recorded −2.2% vs SPRINT_STRIDE is the ledger's known defect candidate,
## shipped as-is by T-165 (its follow-up fix is a separate owner decision).
const LEDGER_WALK_STRIDE_MEASURED := 1.3337
const LEDGER_SPRINT_STRIDE_MEASURED := 2.0859
## A standalone `--script` SceneTree run does not resolve the project's global
## class names — the rig script comes in as an explicit preload.
const RigScript := preload("res://scripts/people_rig.gd")

var _rig: RigScript


func _initialize() -> void:
	## Add the rig here, run the census from _process: a SceneTree script's
	## `_initialize` runs BEFORE the tree iterates, so _ready/@onready resolve
	## only after the first frame (the probe_sizes.gd convention).
	_rig = (load("res://scenes/people_rig.tscn") as PackedScene).instantiate()
	root.add_child(_rig)


func _process(_delta: float) -> bool:
	_census(_rig)
	return true


func _census(rig: RigScript) -> void:
	var skel: Skeleton3D = rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var anim: AnimationPlayer = rig.anim
	var walk_len := anim.get_animation(RigScript.CLIP_WALK).length
	var sprint_len := anim.get_animation(RigScript.CLIP_SPRINT).length

	## --- 1. the pinned constants ------------------------------------------------
	print("=== 1. pinned constants (RigScript) ===")
	print("WALK_STRIDE            %.4f" % RigScript.WALK_STRIDE)
	print("WALK_SECONDS           %.4f" % RigScript.WALK_SECONDS)
	print("SPRINT_STRIDE          %.4f" % RigScript.SPRINT_STRIDE)
	print("SPRINT_SECONDS         %.4f" % RigScript.SPRINT_SECONDS)
	print("SITTING_ENTER_SECONDS  %.4f" % RigScript.SITTING_ENTER_SECONDS)
	print("SITTING_EXIT_SECONDS   %.4f" % RigScript.SITTING_EXIT_SECONDS)

	## --- 2. live clip lengths ----------------------------------------------------
	print("=== 2. live clip lengths (whitelisted six) ===")
	var lengths_ok := true
	for clip_name: String in RigScript.CLIPS_WHITELIST:
		var live := anim.get_animation(clip_name).length
		var expected := 0.0
		match clip_name:
			RigScript.CLIP_IDLE: expected = 2.5
			RigScript.CLIP_WALK: expected = RigScript.WALK_SECONDS
			RigScript.CLIP_SPRINT: expected = RigScript.SPRINT_SECONDS
			RigScript.CLIP_SITTING_IDLE: expected = 1.6667
			RigScript.CLIP_SITTING_ENTER: expected = RigScript.SITTING_ENTER_SECONDS
			RigScript.CLIP_SITTING_EXIT: expected = RigScript.SITTING_EXIT_SECONDS
		var agree := absf(live - expected) < 0.0005
		lengths_ok = lengths_ok and agree
		print("%-18s %.4f  (expected %.4f  %s)" % [clip_name, live, expected,
				"OK" if agree else "MISMATCH"])

	## --- 3. the stride census ----------------------------------------------------
	var census: Dictionary = {}
	for clip_name: String in CLIPS_CENSUSED:
		census[clip_name] = _stride_census(skel, anim, clip_name)

	print("=== 3. stride census (world-space foot origins, %d samples/cycle, ±0.5%% sampling tolerance) ==="
			% SAMPLES_PER_CYCLE)
	var strides_ok := true
	for clip_name: String in CLIPS_CENSUSED:
		var c: Dictionary = census[clip_name]
		var pinned: float = RigScript.WALK_STRIDE if clip_name == RigScript.CLIP_WALK \
				else RigScript.SPRINT_STRIDE
		var ledgered: float = LEDGER_WALK_STRIDE_MEASURED \
				if clip_name == RigScript.CLIP_WALK \
				else LEDGER_SPRINT_STRIDE_MEASURED
		var stride: float = c["fore_aft_l"] + c["fore_aft_r"]
		var delta := stride - pinned
		var pct := 100.0 * delta / pinned
		var ledger_pct := 100.0 * (stride - ledgered) / ledgered
		print("%s  len %.4f s" % [clip_name,
				walk_len if clip_name == RigScript.CLIP_WALK else sprint_len])
		for foot: String in FEET:
			var r: Dictionary = c["ranges_" + foot]
			print("  %s  x %.4f..%.4f  y %.4f..%.4f  z %.4f..%.4f" % [foot,
					r["x"].x, r["x"].y, r["y"].x, r["y"].y, r["z"].x, r["z"].y])
		print("  fore-aft L %.4f + R %.4f = stride %.4f  vs pinned %.4f  delta %+.4f (%+.1f%%)"
				% [c["fore_aft_l"], c["fore_aft_r"], stride, pinned, delta, pct])
		print("  vs ledger measured %.4f: %+.2f%%  %s" % [ledgered, ledger_pct,
				"agrees with the recorded census" if absf(ledger_pct) <= 0.5
				else "  <- MOVED PAST THE LEDGER — clip drift, census RED"])
		strides_ok = strides_ok and absf(ledger_pct) <= 0.5

	## --- 4. the hips in-place check ----------------------------------------------
	print("=== 4. hips in-place check (world ranges must be ~0.0000) ===")
	var inplace_ok := true
	for clip_name: String in CLIPS_CENSUSED:
		var h: Dictionary = census[clip_name]["hips_range"]
		var flat: bool = h["x"].y - h["x"].x < 0.0001 \
				and h["y"].y - h["y"].x < 0.0001 \
				and h["z"].y - h["z"].x < 0.0001
		inplace_ok = inplace_ok and flat
		print("%s  DEF-hips  x %.4f  y %.4f  z %.4f  %s" % [clip_name,
				h["x"].y - h["x"].x, h["y"].y - h["y"].x, h["z"].y - h["z"].x,
				"in-place" if flat else "ROOT MOTION — census RED"])

	## --- 5. the played-rate table -------------------------------------------------
	print("=== 5. played-rate table (the rate law at the shipped driver speeds) ===")
	print("law: rate = speed × clip_seconds / clip_stride")
	print("tourist stroll (walk_speed 1.3):")
	for pace: float in [0.85, 1.0, 1.2]:
		var speed := 1.3 * pace
		print("  pace %.2f  speed %.3f m/s  -> walk_rate %.4f" % [pace, speed,
				RigScript.walk_rate(speed)])
	var authored := RigScript.WALK_STRIDE / RigScript.WALK_SECONDS
	print("  authored walk pace %.3f m/s (stride/seconds)" % authored)
	print("elder shuffle (walk_speed 0.8): walk_rate %.4f" % RigScript.walk_rate(0.8))
	print("tourist panic (panic_speed 4.2): sprint_rate %.4f" % RigScript.sprint_rate(4.2))
	print("elder sit pacing at rise_seconds 0.6: enter %.4f  exit %.4f"
			% [RigScript.SITTING_ENTER_SECONDS / 0.6,
			RigScript.SITTING_EXIT_SECONDS / 0.6])

	var verdict_ok := lengths_ok and strides_ok and inplace_ok
	print("=== census %s ===" % ("GREEN — every printed number inside tolerance"
			if verdict_ok else "RED — see the flagged sections above"))
	quit(0 if verdict_ok else 1)


## Plays `clip` at rate 1.0 from frame 0, steps one full loop at
## SAMPLES_PER_CYCLE and returns the per-foot per-axis world ranges plus the
## fore-aft (local Z) ranges per foot and the hips' per-axis range.
func _stride_census(skel: Skeleton3D, anim: AnimationPlayer,
		clip_name: String) -> Dictionary:
	var length := anim.get_animation(clip_name).length
	anim.speed_scale = 1.0
	anim.play(clip_name, 0.0) ## No crossfade — the census plays from frame 0 cold.
	var dt := length / float(SAMPLES_PER_CYCLE)
	var ranges := {}
	for foot: String in FEET:
		ranges["ranges_" + foot] = {
			"x": Vector2(INF, -INF), "y": Vector2(INF, -INF), "z": Vector2(INF, -INF),
		}
	var hips_range := {
		"x": Vector2(INF, -INF), "y": Vector2(INF, -INF), "z": Vector2(INF, -INF),
	}
	var foot_bones := {}
	for foot: String in FEET:
		foot_bones[foot] = skel.find_bone(foot)
	var hips_bone := skel.find_bone("DEF-hips")
	for _i in SAMPLES_PER_CYCLE:
		## The proven headless order (advance → force update → read). The clip
		## is LOOP_LINEAR, so the stepped positions dt, 2dt, … STEPS·dt wrap
		## onto exactly one full uniform cycle including t ≡ 0.
		anim.advance(dt)
		skel.force_update_all_bone_transforms()
		for foot: String in FEET:
			var origin: Vector3 = (skel.global_transform
					* skel.get_bone_global_pose(foot_bones[foot])).origin
			_grow(ranges["ranges_" + foot], "x", origin.x)
			_grow(ranges["ranges_" + foot], "y", origin.y)
			_grow(ranges["ranges_" + foot], "z", origin.z)
		var hips: Vector3 = (skel.global_transform
				* skel.get_bone_global_pose(hips_bone)).origin
		_grow(hips_range, "x", hips.x)
		_grow(hips_range, "y", hips.y)
		_grow(hips_range, "z", hips.z)
	var out := {"hips_range": hips_range}
	for foot: String in FEET:
		out["ranges_" + foot] = ranges["ranges_" + foot]
		## "Fore-aft" is the bone-origin range along the rig's local Z (the
		## pack's forward is −Z): the z world range under the rig's identity
		## transform IS it.
		var z: Vector2 = ranges["ranges_" + foot]["z"]
		out["fore_aft_" + foot[foot.length() - 1].to_lower()] = z.y - z.x
	return out


## Grows a per-axis min/max pair inside a `ranges` dictionary.
func _grow(store: Dictionary, axis: String, value: float) -> void:
	var pair: Vector2 = store[axis]
	pair.x = minf(pair.x, value)
	pair.y = maxf(pair.y, value)
	store[axis] = pair
