#!/usr/bin/env node
// sim_gate.mjs — the climb's absolute behavior gate (Goodhart guard): the
// repo's own Gate 1b sim harness boxed as an exit-code command for the
// engine's gate mechanism (T-084 climbs need `--gate name=command`; the
// harness already exits nonzero on any failed scenario — sim_test.gd's
// quit(1 if failures)). A candidate that "improves" the storm by breaking
// the game fails here: traffic disabled, citizens deleted, systems gutted —
// the 163-check behavior suite decides. Mirrors gate-box.sh Gate 1b's scan
// (rc + SIM PASS/FAIL lines) and adds the Gate-1 hard-error scan
// (SCRIPT ERROR lines fail; Godot's benign "resources still in use at exit"
// line is stripped exactly as the gate scans strip it).
// GODOT_BIN overrides the binary. List-form spawns only.
import { spawnSync } from 'node:child_process'


// The T-210/T-102 lesson (VERIFICATION.md Known issues #1): a fresh git
// worktree carries NO addons/godot_mcp (untracked by policy) and the boot
// then fails its MCPRuntimeProbe autoload — SCRIPT ERROR noise that fails
// any honest hard-error scan while the project code is fine. Restore the
// addon from the canonical checkout before anything boots; the copy must be
// WRITABLE (the first import rewrites icon.png.import; a read-only copy
// turns that into `Safe save failed`).
import { cpSync, existsSync } from 'node:fs'
const ADDON_SRC = process.env.PIGEON_ADDON_SRC
  || 'C:\\Users\\matth\\Documents\\pigeon-simulator\\addons\\godot_mcp'
function ensureAddon() {
  if (existsSync('addons/godot_mcp')) return
  if (!existsSync(ADDON_SRC)) {
    console.log(`gate-addon: REFUSING: no addons/godot_mcp here and none at PIGEON_ADDON_SRC (${ADDON_SRC}) — restore the per-machine addon first (VERIFICATION.md Known issues #1)`)
    process.exit(2)
  }
  cpSync(ADDON_SRC, 'addons/godot_mcp', { recursive: true })
}

const GODOT = process.env.GODOT_BIN
  || 'C:\\Users\\matth\\Desktop\\Godot_v4.7.2-stable_win64_console.exe'
const TIMEOUT_MS = 30 * 60_000

ensureAddon()

// The import pass first (the gate-box Gate-1 shape): a fresh worktree has no
// .godot cache and an unimported project cannot run the harness.
const imp = spawnSync(GODOT, ['--headless', '--path', '.', '--import'], {
  encoding: 'utf8', windowsHide: true, timeout: 20 * 60_000,
})
if (imp.status !== 0) {
  console.log(`sim_gate: FAIL import pass rc=${imp.status}`)
  process.exit(1)
}

const r = spawnSync(GODOT, ['--headless', '--fixed-fps', '60', '--path', '.', 'res://tests/sim_test.tscn'], {
  encoding: 'utf8', windowsHide: true, timeout: TIMEOUT_MS,
})
const out = (r.stdout || '') + '\n' + (r.stderr || '')
const passes = (out.match(/^SIM PASS/gm) || []).length
const fails = (out.match(/^SIM FAIL/gm) || []).length
const scriptErrors = (out.split('\n').filter((l) => /^SCRIPT ERROR:/.test(l)
  && !/still in use at exit/.test(l))).length
if (r.status === 0 && fails === 0 && scriptErrors === 0 && passes > 0) {
  console.log(`sim_gate: PASS checks=${passes}`)
  process.exit(0)
}
console.log(`sim_gate: FAIL rc=${r.status} (timedOut=${r.signal === 'SIGTERM'}) passes=${passes} fails=${fails} scriptErrors=${scriptErrors}`)
console.log(out.split('\n').filter((l) => /^(SIM FAIL|SCRIPT ERROR:)/.test(l)).slice(0, 10).join('\n'))
process.exit(1)
