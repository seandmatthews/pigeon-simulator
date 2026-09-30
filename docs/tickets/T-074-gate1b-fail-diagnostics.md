# T-074 — Fix the broken failure diagnostics in two Gate 1b scenarios (string-precedence bug)

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 1
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

`_check` prints `detail` only on FAIL (`sim_test.gd:157-162`), but the `%`
expression is evaluated eagerly at EVERY call — so the ERROR lines appear even
while both scenarios pass, and if either scenario ever regresses, the FAIL
line loses exactly the numbers it exists to report. A static sweep of the
whole file (`grep -n '+ ".*% \[' tests/sim_test.gd`) finds exactly these two
continuation lines (`sim_test.gd:1444`, `sim_test.gd:2533`) among the 87
`_check` sites on this tree — no other site uses the broken idiom.

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

- [ ] Full Gate 1b suite green with ZERO `String formatting error` lines in
      the output (baseline before the fix, reproduced this session: exactly
      two — exit 0, 77 PASS, `SIM SUMMARY: 0 failure(s)`, backtraces at
      `sim_test.gd:1439` and `sim_test.gd:2530`)
- [ ] One-time forced-failure proof recorded in this ticket, then reverted:
      with `city_cafe_tables_present`'s combined gate temporarily forced
      false, the headless run prints the complete
      `SIM FAIL city_cafe_tables_present: …` line with all 13 values filled;
      likewise `pigeon_silhouette_contrast` with all 6; neither prints a
      formatting error
- [ ] The diff touches only the two detail-literal expressions in
      `tests/sim_test.gd` — no gate expressions, no thresholds, no scenario
      logic, no other files
- [ ] Both scenarios' PASS output is unchanged (`SIM PASS
      city_cafe_tables_present`, `SIM PASS pigeon_silhouette_contrast`)

## Verification

Gate 1 + Gate 1b: the documented headless command must exit 0 with
`SIM SUMMARY: 0 failure(s)` and `grep -c "String formatting error"` on the log
returning 0. No VERIFICATION.md row changes — the existing
`city_cafe_tables_present` and `pigeon_silhouette_contrast` rows are
untouched; the fix makes their failure output usable, which is the point.
Gate 3: n/a — headless diagnostics, nothing human-judgeable changes.
