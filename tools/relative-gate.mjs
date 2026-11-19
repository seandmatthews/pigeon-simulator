#!/usr/bin/env node
// relative-gate.mjs — the T-082 relative-gate TEMPLATE: a beat-the-baseline
// gate an operator points at their own benchmark command. Copy this file into
// the target repo (or call it from anywhere) — it is SELF-CONTAINED on purpose:
// node: builtins only, no repo imports, so it survives being lifted out of this
// checkout. It is NOT engine code: the CommandGate mechanism (src/gate/command.ts)
// is untouched — a gate is any exit-code command, and this is the disciplined
// script pattern for "pass iff the candidate's measured value beats a recorded
// baseline by more than a noise tolerance" (T-082).
//
//   node relative-gate.mjs --baseline <path> --metric <name>
//        [--tolerance-pct 2] [--runs 5] [--lower-is-better]
//        [--refuse-if-writable] -- <benchmark command...>
//
// Everything after `--` is the benchmark argv, spawned LIST-FORM (never through
// a shell — Windows paths with spaces and `&` shred string-joined commands),
// `--runs` times, sequentially, in the CURRENT directory: the candidate worktree
// during a run, the integration worktree at accept. Each run must print one
// JSON document on stdout whose top-level object carries the named metric as a
// number (the T-018 benchmark-probe measurement shape — durationsMs/medianMs/p95
// — is the reference vocabulary; point --metric at medianMs or p95Ms, one number
// per gate invocation). The values' MEDIAN (nearest-rank order statistic — the
// T-018 rule sorted[ceil(q*n)-1], no interpolation) is compared against the
// baseline file's recorded value for that metric.
//
// Baseline file (JSON, committed in the TARGET repo at an operator-chosen path
// — convention: .refinery/baseline/<gate-name>.json — so every candidate
// worktree can read it; visibility to workers is fine and intended for the
// climbing signal):
//
//   { "<metric>": { "value": <number>, "capturedAt": "<iso>", "capturedBy": "<who>" } }
//
// Exit semantics, pinned exactly (any refusal exits 1 — an unevaluable gate
// proves nothing and must say so, never a silent pass):
//   improved beyond tolerance          → exit 0 (prints the old/new values)
//   improved within tolerance or equal → exit 1  "within tolerance (<tol>%): not good enough"
//                                        (noise-chasing is the failure this refusal exists for)
//   regressed                          → exit 1  "regressed (...)"
//   missing/unreadable/unparseable baseline or metric,
//   a benchmark run that fails or yields no numeric metric,
//   a --refuse-if-writable preflight hit,
//   or any bad/missing option          → exit 1  "REFUSING: ..." naming the file/metric
//
// The template is READ-ONLY over the baseline: it never writes it. Baseline
// updates happen only at accept-time, as part of the accepting commit (the
// T-084 climb driver owns that). `--refuse-if-writable` (off by default; the
// driver passes it) is a preflight leg that refuses a writable baseline file
// before any benchmark dispatch, so a misconfigured climb is caught early.
//
// All output goes to stdout on one channel (a gate's whole output is its
// evidence tail — CommandGate merges stdout and stderr anyway). The benchmark
// carries no per-run timeout here: the harness gate budget bounds the whole
// gate; this template adds no second timeout mechanism.
//
// Documented honestly as a HEURISTIC bar, not a confidence test: median-of-N
// with a fixed tolerance, no statistical rigor beyond that.
import { accessSync, constants as fsConstants, readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

const PREFIX = 'relative-gate:'

const refuse = (msg) => {
  console.log(`${PREFIX} REFUSING: ${msg}`)
  process.exit(1)
}

const isPlainObject = (v) =>
  typeof v === 'object' && v !== null && !Array.isArray(v)

// argv split: everything before the first `--` is template flags, everything
// after it is the benchmark argv verbatim (a benchmark may carry its own `--`).
const argv = process.argv.slice(2)
const dash = argv.indexOf('--')
const flagArgs = dash === -1 ? argv : argv.slice(0, dash)
const benchArgv = dash === -1 ? [] : argv.slice(dash + 1)

let baselinePath = null
let metric = null
let toleranceRaw = null
let runsRaw = null
let lowerIsBetter = false
let refuseIfWritable = false

for (let i = 0; i < flagArgs.length; i++) {
  const a = flagArgs[i]
  const value = () => {
    const v = flagArgs[i + 1]
    if (v === undefined || v.startsWith('--')) refuse(`option ${a} requires a value`)
    i++
    return v
  }
  switch (a) {
    case '--baseline': baselinePath = value(); break
    case '--metric': metric = value(); break
    case '--tolerance-pct': toleranceRaw = value(); break
    case '--runs': runsRaw = value(); break
    case '--lower-is-better': lowerIsBetter = true; break
    case '--refuse-if-writable': refuseIfWritable = true; break
    default: refuse(`unknown option ${a} (expected --baseline/--metric/--tolerance-pct/--runs/--lower-is-better/--refuse-if-writable)`)
  }
}

if (baselinePath === null) refuse('--baseline is required')
if (metric === null) refuse('--metric is required')

const tolerancePct = toleranceRaw === null ? 2 : Number(toleranceRaw)
if (!Number.isFinite(tolerancePct) || tolerancePct < 0) {
  refuse(`--tolerance-pct must be a number >= 0 (got ${toleranceRaw})`)
}

const runs = runsRaw === null ? 5 : Number(runsRaw)
if (!Number.isInteger(runs) || runs < 1) {
  refuse(`--runs must be a positive integer (got ${runsRaw})`)
}

if (benchArgv.length === 0) {
  refuse(`no benchmark command after '--' (everything after -- is the benchmark argv)`)
}

// Preflight (off by default; the climb driver passes it): a writable baseline
// under --refuse-if-writable refuses BEFORE any benchmark dispatch. An absent
// file falls through — the not-found refusal below is the honest one there.
if (refuseIfWritable) {
  try {
    accessSync(baselinePath, fsConstants.W_OK)
    refuse(`--refuse-if-writable: baseline file is writable: ${baselinePath}`)
  } catch {
    // not writable (or absent) — preflight passes
  }
}

let raw
try {
  raw = readFileSync(baselinePath, 'utf8')
} catch (e) {
  if (e && e.code === 'ENOENT') refuse(`baseline file not found: ${baselinePath}`)
  refuse(`baseline file unreadable: ${baselinePath} (${e?.message ?? e})`)
}

let baselineDoc
try {
  baselineDoc = JSON.parse(raw)
} catch (e) {
  refuse(`baseline file unparseable as JSON: ${baselinePath} (${e?.message ?? e})`)
}
if (!isPlainObject(baselineDoc)) {
  refuse(`baseline file is not a JSON object: ${baselinePath}`)
}

const entry = baselineDoc[metric]
if (entry === undefined) {
  refuse(`metric '${metric}' not found in baseline file ${baselinePath}`)
}
if (!isPlainObject(entry)) {
  refuse(`metric '${metric}' in baseline file ${baselinePath} is malformed (expected { value: <number>, capturedAt, capturedBy })`)
}
if (!Number.isFinite(entry.value)) {
  refuse(`metric '${metric}' in baseline file ${baselinePath} is not a number`)
}
const baselineValue = entry.value

// The benchmark runs: every requested run must produce the metric — a run
// that crashes, prints something unparseable, or carries no numeric metric is
// a loud refusal, never a silent partial average (one number per gate).
const values = []
for (let i = 1; i <= runs; i++) {
  const r = spawnSync(benchArgv[0], benchArgv.slice(1), {
    cwd: process.cwd(), // the current directory: candidate worktree / integration worktree
    encoding: 'utf8',
    windowsHide: true,
  })
  const tail = () => {
    const s = `${r.stdout ?? ''}${r.stderr ?? ''}`.trim()
    return s.length > 200 ? `...${s.slice(-200)}` : s
  }
  if (r.error !== undefined) {
    refuse(`benchmark run ${i}/${runs} could not be spawned (${r.error.message})`)
  }
  if (r.status !== 0) {
    refuse(`benchmark run ${i}/${runs} exited ${r.status ?? 'no exit code'} (no measurement recorded); output tail: ${tail()}`)
  }
  let doc
  try {
    doc = JSON.parse((r.stdout ?? '').trim())
  } catch {
    refuse(`benchmark run ${i}/${runs} printed unparseable JSON output; output tail: ${tail()}`)
  }
  const v = isPlainObject(doc) ? doc[metric] : undefined
  if (typeof v !== 'number' || !Number.isFinite(v)) {
    refuse(`benchmark run ${i}/${runs} output JSON carries no numeric metric '${metric}'; output tail: ${tail()}`)
  }
  values.push(v)
}

// The median: nearest-rank order statistic over the ascending-sorted values —
// sorted[ceil(q*n)-1], no interpolation — exactly the T-018 benchmark probe's
// rule (src/probe.ts nearestRank).
const sorted = [...values].sort((a, b) => a - b)
const median = sorted[Math.ceil(0.5 * sorted.length) - 1]

const tolFrac = tolerancePct / 100
const runsTxt = `median of ${runs} runs`
const verdictTail = `(${metric} ${baselineValue} -> ${median}, ${runsTxt}; baseline unchanged: ${baselinePath})`

if (lowerIsBetter) {
  if (median < baselineValue * (1 - tolFrac)) {
    console.log(`${PREFIX} PASS improved beyond tolerance (${tolerancePct}%): ${metric} ${baselineValue} -> ${median} (${runsTxt})`)
    process.exit(0)
  }
  if (median > baselineValue) {
    console.log(`${PREFIX} FAIL regressed ${verdictTail}`)
    process.exit(1)
  }
  console.log(`${PREFIX} FAIL within tolerance (${tolerancePct}%): not good enough ${verdictTail}`)
  process.exit(1)
}

if (median > baselineValue * (1 + tolFrac)) {
  console.log(`${PREFIX} PASS improved beyond tolerance (${tolerancePct}%): ${metric} ${baselineValue} -> ${median} (${runsTxt})`)
  process.exit(0)
}
if (median < baselineValue) {
  console.log(`${PREFIX} FAIL regressed ${verdictTail}`)
  process.exit(1)
}
console.log(`${PREFIX} FAIL within tolerance (${tolerancePct}%): not good enough ${verdictTail}`)
process.exit(1)
