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

const GODOT = process.env.GODOT_BIN
  || 'C:\\Users\\matth\\Desktop\\Godot_v4.7.2-stable_win64_console.exe'
const TIMEOUT_MS = 30 * 60_000

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
