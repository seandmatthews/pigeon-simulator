#!/usr/bin/env node
// storm_gate.mjs — the storm gate's benchmark command (the thing
// relative-gate.mjs spawns --runs times, T-082): an import pass (a candidate
// worktree has no .godot cache — the gate-box.sh Gate-1 lesson, T-210's
// worktree root cause) then the headless storm probe, whose single JSON line
// is passed through as the whole stdout. Exits nonzero when the import or
// the probe fails — a crashed benchmark refuses the gate loudly (the
// template turns any non-numeric face into a REFUSING, never a pass).
// GODOT_BIN overrides the binary; the default is the operator's 4.7.2
// console build. List-form spawns only (the orchestrator's AGENTS #4 — the
// same rule this repo's gate-box.sh follows by passing refs, not strings).
import { spawnSync } from 'node:child_process'

const GODOT = process.env.GODOT_BIN
  || 'C:\\Users\\matth\\Desktop\\Godot_v4.7.2-stable_win64_console.exe'
const IMPORT_TIMEOUT_MS = 20 * 60_000
const PROBE_TIMEOUT_MS = 20 * 60_000

const imp = spawnSync(GODOT, ['--headless', '--path', '.', '--import'], {
  encoding: 'utf8', windowsHide: true, timeout: IMPORT_TIMEOUT_MS,
})
if (imp.status !== 0) {
  console.log(`storm_gate: FAIL import pass rc=${imp.status}`)
  console.log((imp.stderr || imp.stdout || '').split('\n').slice(-10).join('\n'))
  process.exit(1)
}

const r = spawnSync(GODOT, ['--headless', '--path', '.', 'res://tests/tools/storm_probe.tscn'], {
  encoding: 'utf8', windowsHide: true, timeout: PROBE_TIMEOUT_MS,
})
const out = r.stdout || ''
const jsonLines = out.split('\n').filter((l) => l.startsWith('{'))
if (r.status !== 0 || jsonLines.length === 0) {
  console.log(`storm_gate: FAIL probe rc=${r.status} (timedOut=${r.signal === 'SIGTERM'})`)
  console.log(out.split('\n').filter((l) => /FAIL|ERROR/.test(l)).slice(-10).join('\n'))
  process.exit(1)
}
console.log(jsonLines[jsonLines.length - 1])
process.exit(0)
