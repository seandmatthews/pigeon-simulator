extends SceneTree
## T-172 — the Ames chunk baker, run headless (the probe_sizes.gd precedent).
## Turns the committed data pack (T-171) into per-chunk JSON resources under
## `data/ames/chunks/` + the SHA-256 determinism manifest. Pure offline tool:
## nothing here runs at boot — the world renderer (T-173) only READS the
## output. Deterministic by construction (see scripts/ames_baker.gd): two
## consecutive runs must leave the manifest hash byte-identical — the
## `ames_bake_determinism` Gate 1b scenario holds that line.
##
## Run:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/bake_ames_chunks.gd

const OUT_DIR := "res://data/ames/chunks"
## The acceptance budget (ticket): the bake must finish comfortably inside
## this wall-clock and the total payload stay under it. Exceeding either
## fails the tool (exit 1) so a regression can't land silently.
const BUDGET_MS := 60000
const BUDGET_BYTES := 40 * 1024 * 1024


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var manifest: Dictionary = AmesBaker.bake_to_dir(OUT_DIR)
	var elapsed := Time.get_ticks_msec() - t0
	if manifest.is_empty():
		push_error("bake_ames_chunks: bake FAILED (no manifest) — see errors above")
		return ## _process quits 1.
	var totals: Dictionary = manifest.get("totals", {})
	print("=== Ames chunk bake (T-172 + T-174 dressing + T-175 placeholders) ===")
	print("chunks written: %d  massing: %d  ribbons: %d  lane_quads: %d  water_tris: %d  shore_quads: %d  creek_quads: %d  lawn_tris: %d  ballast_quads: %d  tie_quads: %d  ground_quads: %d  occluders: %d  placeholders: %d  crossings: %d" % [
		totals.get("chunks", 0), totals.get("massing", 0), totals.get("ribbons", 0),
		totals.get("lane_quads", 0), totals.get("water_tris", 0),
		totals.get("shore_quads", 0), totals.get("creek_quads", 0),
		totals.get("lawn_tris", 0), totals.get("ballast_quads", 0),
		totals.get("tie_quads", 0), totals.get("ground_quads", 0),
		totals.get("occluders", 0), totals.get("placeholders", 0),
		totals.get("crossings", 0)])
	print("districts: %s" % str(totals.get("districts", {})))
	print("payload: %.2f MB (budget 40.00)  wall clock: %d ms (budget %d)" % [
		float(totals.get("bytes", 0)) / (1024.0 * 1024.0), elapsed, BUDGET_MS])
	print("total_sha256: %s" % manifest.get("total_sha256", ""))
	_ok = elapsed <= BUDGET_MS and int(totals.get("bytes", 0)) <= BUDGET_BYTES
	if not _ok:
		push_error("bake_ames_chunks: budget exceeded (%d ms, %d bytes)" % [elapsed, totals.get("bytes", 0)])


var _ok := false


func _process(_delta: float) -> bool:
	quit(0 if _ok else 1)
	return true
