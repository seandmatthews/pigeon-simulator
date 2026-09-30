# T-074 — Fix the broken failure diagnostics in two Gate 1b scenarios (string-precedence bug)

- **Milestone:** Sweep backlog · **Status:** done · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** sweep 1 planning lane (code quality & performance) · line numbers on commit f77da93, this tree

## What

Two parenthesized expressions in `tests/sim_test.gd` — nothing else. GDScript's
`%` binds tighter than `+`, so in both `_check` detail arguments the format
args are applied to the tail literal alone and never reach the head literal:

1. `_scenario_city_cafe_tables` (`sim_test.gd:1439-1447`): the head literal
   carries 7 placeholders (`spots %d vs awnings %d, recompute=%s band=%s
   bread=%s door=%s det=%s`) that the `%` never sees; all 13 args hit the
   6-placeholder tail → `String formatting error: not all arguments converted`
   (backtraced to `sim_test.gd:1439`). Fix: wrap the concatenation before the
   `%` — `("head…" + "tail…") % [ …13 args… ]`.
2. `_scenario_pigeon_silhouette_contrast` (`sim_test.gd:2530-2535`): same
   idiom — head has 4 placeholders, tail 2, args 6, and the tail's `%.3f`s
   receive strings → `String formatting error: a number is required`
   (backtraced to `sim_test.gd:2530`). Same 2-line parenthesize.
3. *(added 2026-09-30, this tree)* `_scenario_city_roofs_inhabited`
   (`tests/sim_test.gd:1864-1871`): the same idiom — head has 7 placeholders,
   tail 4, args 11 → `String formatting error: not all arguments converted`
   (backtraced to `sim_test.gd:1864`). This site did not exist at the
   f77da93 snapshot the sweep below describes; it was added post-snapshot and
   was caught by AC #1's own zero-errors criterion when the baseline was
   re-reproduced (three ERROR lines, not two). Owner approved extending the
   identical one-line parenthesize to it.

`_check` prints `detail` only on FAIL (`sim_test.gd:157-162`), but the `%`
expression is evaluated eagerly at EVERY call — so the ERROR lines appear even
while the scenarios pass, and if any of them ever regresses, the FAIL
line loses exactly the numbers it exists to report. A static sweep of the
whole file (`grep -n '+ ".*% \[' tests/sim_test.gd`) finds exactly these two
continuation lines (`sim_test.gd:1444`, `sim_test.gd:2533`) among the 87
`_check` sites on the f77da93 tree — *(update, this tree: the sweep now also
finds `city_roofs_inhabited` at `tests/sim_test.gd:1868`, item 3 above; no
fourth site).*

What this does NOT claim: any change to scenario logic, gate expressions,
thresholds or pass behavior — the diff is the two detail expressions only.

## Why

The one output you need when a gate goes red is exactly the path that is
broken today. Reproduced on this tree this session — the documented Gate 1b
command (`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`)
exits 0 with `SIM SUMMARY: 0 failure(s)` and 77 PASS lines, and still prints
exactly two `ERROR: String formatting error` lines, backtraced to
`_scenario_city_cafe_tables` (`sim_test.gd:1439`, "not all arguments
converted") and `_scenario_pigeon_silhouette_contrast` (`sim_test.gd:2530`, "a
number is required"). Both scenarios PASS, so the damage is currently noise —
but the first real regression in either rides a failure path that cannot print
its own diagnosis.

## Acceptance criteria

- [x] Full Gate 1b suite green with ZERO `String formatting error` lines in
      the output (baseline before the fix, reproduced this session on the
      current tree: exactly three — exit 0, 85 PASS, `SIM SUMMARY: 0
      failure(s)`, backtraces at `tests/sim_test.gd:1663`
      (`city_cafe_tables_present`), `tests/sim_test.gd:1864`
      (`city_roofs_inhabited`, post-snapshot site, item 3 above) and
      `tests/sim_test.gd:3226` (`pigeon_silhouette_contrast`); after the fix
      the same command exits 0 with 85 PASS and
      `grep -c "String formatting error"` = 0)
- [x] One-time forced-failure proof recorded in this ticket, then reverted:
      with the three combined gates temporarily forced false, the headless
      run prints the complete `SIM FAIL …` lines with every value filled
      (13, 11 and 6 respectively) and ZERO formatting errors — see the
      proof section below
- [x] The diff touches only the three same-class detail-literal expressions
      in `tests/sim_test.gd` — no gate expressions, no thresholds, no
      scenario logic, no other files (the third, `city_roofs_inhabited`, was
      approved by the owner as recorded under item 3 in What)
- [x] Both original scenarios' PASS output is unchanged (`SIM PASS
      city_cafe_tables_present`, `SIM PASS pigeon_silhouette_contrast`;
      `SIM PASS city_roofs_inhabited` likewise)

## Result (2026-09-30, reviewer-accepted)

No values were tuned — the diff is the three detail-literal parenthesizes
only. Final measured state on this tree: documented sim command exits 0 with
85 PASS, `SIM SUMMARY: 0 failure(s)`, `grep -c "String formatting error"` = 0;
forced-failure runs print complete FAIL diagnostics (see proof below).

## Forced-failure proof (2026-09-30, one-time, then reverted)

With each of the three gates prefixed `false and ` (scratch edit, reverted
after the run — the committed diff contains no gate change), the documented
command printed complete FAIL lines and no formatting errors:

```
SIM FAIL city_cafe_tables_present: spots 104 vs awnings 104, recompute=true band=true bread=true door=true det=true, seated=104 tables, sitters=156 (rule=true shirts=true layers=true), perch=true
SIM FAIL city_roofs_inhabited: props_ok=true spots=146/146 total_ok=true one_per_building=true colliders=true (259 high) det=true physical=true eat=true prop=true
SIM FAIL pigeon_silhouette_contrast: sidewalk+cream=[0.23, 0.67, 0.54, 0.74] worst luminance margin 0.057 tip_step=true head_step=true ground sidewalk-asphalt=0.435 sidewalk-body=0.230
SIM SUMMARY: 3 failure(s)   # run exit 1; grep -c "String formatting error" = 0
```

## Verification

Gate 1 + Gate 1b: the documented headless command must exit 0 with
`SIM SUMMARY: 0 failure(s)` and `grep -c "String formatting error"` on the log
returning 0. No VERIFICATION.md row changes — the existing
`city_cafe_tables_present` and `pigeon_silhouette_contrast` rows are
untouched; the fix makes their failure output usable, which is the point.
Gate 3: n/a — headless diagnostics, nothing human-judgeable changes.
