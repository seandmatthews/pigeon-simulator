# T-165 — Ground the gait: the people-locomotion constants probe — a live census instrument, its recorded ledger, and the rate pins the suite never had

- **Status:** done · **Category:** visual-design · **Value (1-5):** 3 ·
  **Risk (1-5):** 2
- **Depends on:** T-138 (the one people rig whose clip/stride constants this
  audits — nothing new is invented here, everything measured already ships)
- **Refs:** `scripts/people_rig.gd:57-62` (the six pinned locomotion
  constants), `people_rig.gd:65` (`CLIP_BLEND`), `people_rig.gd:157-175`
  (the rate law and `play_locomotion`'s 0.2 m/s idle threshold) ·
  `tools/import_people_rig.gd:75-83` (the T-138 provenance comments),
  `import_people_rig.gd:616-627` (`_stamp_meta` writes `walk_stride` /
  `walk_seconds` / `sprint_stride` / `sprint_seconds` metas — read by
  NOTHING today, verified by grep this session) · `scripts/tourist.gd:39-57`
  (the stroll/panic/buzz export groups), `tourist.gd:70` (the per-tourist
  `pace`), `tourist.gd:270-296` (`_animate` — bob, lean, duck, the 0.2 m/s
  gate) · `scripts/tourist_spawner.gd:93` (`pace = randf_range(0.85, 1.2)`) ·
  `scripts/elder.gd:90-100` (the Shuffle group: 0.8 m/s, bob 5 Hz / 0.035 m,
  `rise_seconds` 0.6), `elder.gd:595-613` (`_animate`), `elder.gd:619-632`
  (`_sync_clip` — the sit-enter/exit pacing law) ·
  `tests/sim_test.gd:8725-8729` (the suite's ONLY rate pin today: walk clip
  at stroll + the law literal — sprint, shuffle and sit pacing are unpinned),
  `sim_test.gd:242` (the `_run_scenarios` registration point),
  `sim_test.gd:8632` (`people_on_one_rig`), `sim_test.gd:3243-3276` (the
  T-137 migration harness that yields a live WALKING elder) ·
  `VERIFICATION.md:129` (the `people_on_one_rig` row, walk-rate-only
  wording) · probe evidence recorded this session (2026-11-04): a throwaway
  headless census in the `tools/probe_sizes.gd` family — instantiating
  `scenes/people_rig.tscn`, playing each clip at rate 1.0, stepping
  `AnimationPlayer.advance()` with `force_update_all_bone_transforms()`, and
  reading world-space `DEF-foot.L`/`DEF-foot.R`/`DEF-hips` origins over one
  full loop at 48 and 144 samples per cycle (numbers below; the script was
  deleted after recording, the T-162/T-164 throwaway-probe precedent)

## What

This ticket makes the people-walk animation constants LEGIBLE and LOAD-BEARING
before anyone tunes them. It changes no feel, no visuals, no constant — it
ships (1) a persistent probe that re-measures the locomotion census on demand,
(2) the recorded ledger below, and (3) Gate 1b pins for every played rate the
suite currently trusts but never checks. The T-164/T-163 sweeps proved the
method twice: probe first, record the numbers, then tune against them.

**The inventory.** Six driver states drive every human locomotion read in
the city (eight distinct clip plays counting the idle/seated holds), from
six pinned constants and three scripts:

| Played state | Rate law | Inputs | Pinned today? |
| --- | --- | --- | --- |
| Tourist stroll | `walk_rate(speed)` | `walk_speed` 1.3 × `pace` 0.85–1.2 (`tourist_spawner.gd:93`) | walk leg only (`VERIFICATION.md:129`) |
| Tourist panic | `sprint_rate(speed)` | `panic_speed` 4.2 for `panic_seconds` 2.6 (`tourist.gd:47-48`) | **no** |
| Elder shuffle | `walk_rate(walk_speed)` | `walk_speed` 0.8 (`elder.gd:91`) | **no** |
| Elder RISING | `SITTING_EXIT_SECONDS / rise_seconds` | 1.0 / 0.6 (`elder.gd:623-625`) | **no** |
| Elder ARRIVING | `SITTING_ENTER_SECONDS / rise_seconds` | 1.2917 / 0.6 (`elder.gd:630-632`) | **no** |
| Curb/idle holds | rate 1.0 | `tourist.gd:274` / `people_rig.gd:169` thresholds | no (low stakes) |

The constants themselves: `WALK_STRIDE 1.3239` / `WALK_SECONDS 1.3333` /
`SPRINT_STRIDE 2.1333` / `SPRINT_SECONDS 0.6667` / `SITTING_ENTER_SECONDS
1.2917` / `SITTING_EXIT_SECONDS 1.0` (`people_rig.gd:57-62`), stamped a
second time as import metas (`import_people_rig.gd:621-626`) that nothing
reads. The rate law `speed × seconds / stride` (`people_rig.gd:157-163`) is
the entire anti-skate mechanism — it is only as good as the stride numbers.

**The measured ledger** (throwaway probe, 2026-11-04, headless, rig at
origin, world-space bone origins; 144 samples/cycle, the 48-sample pass
agreed within 0.4% — sampling tolerance ±0.5%):

- **Clip lengths are exact.** All six live lengths byte-match the pinned
  SECONDS constants: Idle 2.5000, Walk 1.3333, Sprint 0.6667,
  Sitting_Idle 1.6667, Sitting_Enter 1.2917, Sitting_Exit 1.0000. (Idle and
  Sitting_Idle lengths are unpinned constants — now recorded here.)
- **Walk stride checks out:** per-foot fore-aft (local Z) ranges 0.6540 /
  0.6797 m → stride 1.3337 vs the pinned 1.3239 (**+0.7%** — inside
  sampling tolerance; feet glide ≤ 0.01 m/s at stroll; invisible).
- **Sprint stride does NOT:** fore-aft 1.0484 / 1.0375 → stride 2.0859 vs
  the pinned 2.1333 (**−2.2%**, sampling-stable across both passes). At
  panic 4.2 m/s the law plays the clip ~2% slow, so ground contact glides
  ≈ 0.09–0.10 m per sprint second — the one candidate DEFECT the probe
  found. This ticket records it and does NOT fix it (see Not claimed); the
  follow-up fix (re-pin `SPRINT_STRIDE` ≈ 2.086 from a denser probe, or
  accept the glide) is the owner's, with this ledger as its evidence.
- **The clips are in-place, entirely.** DEF-hips world position is dead flat
  in both locomotion clips (y range 0.0000, forward z drift 0.0000). The
  script bob layers — tourist 0.045 m @ 9 Hz ×2.2 panic (`tourist.gd:43-44,
  49`), elder 0.035 m @ 5 Hz (`elder.gd:96-97`) — are the ONLY vertical
  motion on a walking figure. No double-motion conflict exists today, and
  any future gait tune that adds clip-side root motion would silently fight
  these two sine layers; the ledger is where that collision gets caught
  first.
- **Authored foot lift** (the pack's exaggeration, baseline for any gait
  work): walk ankle rise 0.2304 / 0.2248 m per swing; sprint 0.4414 / 0.2938
  (asymmetric — the leading foot lifts higher).
- **The played-rate table** (what the law actually does at shipped speeds):
  stroll 1.105 / 1.30 / 1.56 m/s → rates 1.1128 / 1.3092 / 1.5711 (the
  authored walk pace is 0.993 m/s, so every tourist plays the clip 11–57%
  faster than authored — snappier steps than the pack's march); elder
  shuffle 0.8 m/s → 0.8057 (20% slower than authored — the shuffle IS a
  slowed clip, by design); panic 4.2 → 1.3126; sit pacing at
  `rise_seconds` 0.6 → enter 2.1528×, exit 1.6667×.

**The probe instrument.** `tools/probe_walk_constants.gd` lands as a
PERSISTENT script (the `probe_sizes.gd` family — census tools stay), a
SceneTree script run headless:
`~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script
tools/probe_walk_constants.gd`. Five printed sections, exactly the throwaway
census this ticket recorded: (1) the pinned constants echoed from
`PeopleRig`; (2) live lengths of all six whitelisted clips; (3) the stride
census — play `Rig|Walk` then `Rig|Sprint` at rate 1.0 from frame 0, step
one full loop at ≥ 96 samples (`dt = length / STEPS`, `anim.advance` +
`force_update_all_bone_transforms()` — the proven headless pattern from
`people_on_one_rig`, `sim_test.gd:8673-8676`), track world-space
`DEF-foot.L/R` origins, report per-foot x/y/z ranges and
`stride = fore-aft L + R` against the pinned constants with delta and
percent; (4) the hips in-place check (per-axis world range must print
~0.0000 — a future clip edit that adds root motion reds the census);
(5) the rate table for the shipped driver speeds plus the elder sit pacing.
Header comment documents the ±0.5% sampling tolerance.

**The Gate 1b scenario.** New `locomotion_rate_ledger` (registered in the
`sim_test.gd:242` block; the walk-rate leg STAYS in `people_on_one_rig` —
no duplication), four legs, all rate reads ±0.02 `speed_scale` on the LIVE
animation player after stepping the node's own `_physics_process` +
`anim.advance` (the `sim_test.gd:8673-8676` pattern). One design rule the
legs split on: a leg that computes its expected value from the same
`PeopleRig` constant the game plays can never red on a constant edit (both
sides move together — `play_locomotion` calls the same static
`sprint_rate()`, `people_rig.gd:171`, and `_panic` snaps velocity straight
to `panic_speed`, `tourist.gd:236-237`). So constant TRUTH is pinned only
where the expected value comes from the independent copy — the import
stamps — and that is the PANIC and LEDGER legs; the SHUFFLE and SIT PACING
legs pin WIRING in the `people_on_one_rig` convention, by design:

1. PANIC — a strolling tourist takes a real `on_splatted(Vector3(...))`,
   settles into `Mood.PANIC`, then `current_animation == CLIP_SPRINT` and
   `speed_scale == tourist.panic_speed × model.get_meta("sprint_seconds")
   / model.get_meta("sprint_stride")` (the rig's `Visual/Model` node) —
   expected derived from the IMPORT STAMPS, not the script constants (the
   live-Model meta read is the proven `sim_test.gd:8653-8655` pattern), so
   a one-sided edit of either sprint constant separates played from
   expected and reds;
2. SHUFFLE — a walking elder from the T-137 migration harness
   (`sim_test.gd:3243-3276`), rate read mid-WALKING as
   `PeopleRig.walk_rate(elder.walk_speed)` — reading the export live makes
   the pin pace-free (green at the harness's 6 m/s window pace AND the
   0.8 default);
3. SIT PACING — the same harness's RISING and ARRIVING windows record
   `speed_scale == PeopleRig.SITTING_EXIT_SECONDS / elder.rise_seconds` and
   `== PeopleRig.SITTING_ENTER_SECONDS / elder.rise_seconds` respectively
   (the `elder.gd:623-632` wiring, pinned);
4. LEDGER — `PeopleRig.WALK_STRIDE/WALK_SECONDS/SPRINT_STRIDE/
   SPRINT_SECONDS` equal the imported Model's stamped `walk_stride` /
   `walk_seconds` / `sprint_stride` / `sprint_seconds` metas
   (`import_people_rig.gd:621-626`) — the stamps become load-bearing (the
   PANIC leg already derives its expected rate from two of them; this leg
   pins all four against the script copies), and a one-sided edit of
   either copy now reds CI.

**No reference photos:** no research phase ran for this ticket — a code
investigation of the repo's own animation constants has no real-world
counterpart to consult, so reference photos do not apply; every number above
was read from the tree or measured by the probe run recorded in Refs, and
this ticket opened no image. One honesty note about the wider tree: a banked
gait reference set this ticket did NOT create or use already exists —
`docs/references/human-walking-gait/` (untracked; 8 image files banked
2026-11-04 09:35–09:36: `muybridge-human-male-walk-cycle.gif`,
`elderly-man-cane-lisbon.jpg`, `elderly-man-road-profile.jpg`,
`drone-pedestrians-crossing-topdown.jpg`, `manhattan-pedestrians-eyelevel.jpg`,
`pedestrians-pornainen.jpg`, `people-walking-nairobi.jpg`,
`walking-women-bourbon-street.jpg` — subject: human walking gait, including
elderly gait; verified unreferenced by any ticket or doc via grep this
session). It is presumably the research leg of the forthcoming gait-feel
pass the Why section anticipates — no ticket claims it yet — and it stays
parked there: no line of THIS ticket's What, ledger or acceptance reads it,
and its visual judgements belong to that follow-up alongside this ticket's
ledger.

**Not claimed:** no constant changes — the −2.2% sprint stride ships as-is
this ticket and its follow-up fix is a separate owner decision (the ledger
is its evidence); no visual or feel change of any kind (Gate 3 reads only
JUDGE the current motion against the ledger); no pigeon-side animation
(`pigeon_visual.gd`, `player.gd` out of scope — people locomotion only); no
café sitter work (static bakes, T-142's world — the sitters play no clips);
no bob/lean/duck layer edits; no `CLIP_BLEND` change; no new scenes, input
actions or economy surface; no re-import of the pack (the metas are consumed
as stamped; a re-import re-stamps and the LEDGER leg re-checks for free).

## Why

The walk is the last unread layer of the T-138 people rig. The owner's
attention has been on how the city's people present — T-141/T-142/T-145/
T-163/T-164 all reshaped the figure — and the motion is what is left; any
forthcoming walk-feel or gait pass will turn exactly these constants. Today
that pass would start blind: only one of the six played states (the stroll)
is pinned, the stride provenance lives in two copies that agree with each
other but were never both checked against the live clip — which disagrees
by 2.2% on the sprint, silently (the import stamps have no reader) — and
the first person to tune
`SPRINT_STRIDE` would have no way to know the shipped value was never
live-verified. The T-163/T-164 precedent is that a morning of probing turned
seat contact and hair caps from taste arguments into measured laws — this
ticket buys the same ground for motion, cheaply, before the tuning ticket
spends its budget re-deriving it. Player value is indirect but concrete:
the anti-skate rate law only holds while the stride constants are true, so
the pins freeze the one mechanism keeping 18 strolling tourists and 4
shuffling elders believable at gameplay distance, and the ledger gives the
next motion ticket a running start instead of a blind one.

## Acceptance criteria

- [x] *(Gate 1b)* new `locomotion_rate_ledger` scenario registered in the
      `_run_scenarios` block (`sim_test.gd:242` neighbors) with the four
      legs above (PANIC — expected rate derived from the stamped
      `sprint_seconds`/`sprint_stride` metas, the independent copy — /
      SHUFFLE / SIT PACING / LEDGER, ±0.02 reads on the live
      `speed_scale`); the walk-rate leg remains ONLY in
      `people_on_one_rig` (`VERIFICATION.md:129` untouched in its law)
- [x] *(Gate 1b)* the scenario demonstrably bites — recorded when landed:
      with `PeopleRig.SPRINT_STRIDE` hand-edited (e.g. to 2.05) the LEDGER
      leg reds on the meta mismatch (script 2.05 vs stamped 2.1333) AND
      the PANIC leg reds because its expected rate comes from the STAMPS
      while the game plays the edited constant — played
      4.2 × 0.6667 / 2.05 = 1.3659 vs stamp-derived expected
      4.2 × 0.6667 / 2.1333 = 1.3126, delta 0.0533 past the ±0.02
      tolerance; revert and record both red lines in this ticket (the
      red-before evidence this pin-ticket can honestly produce; the
      independence is one-directional by design — a COORDINATED
      constant+stamp re-pin stays green, the correct contract for a
      pins ticket)
- [x] *(Gate 1b)* full suite 0 failures:
      `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
- [x] *(Gate 1)* `godot --headless --path . --import` and the 120-frame
      boot exit clean, zero ERROR lines
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`)
- [x] `tools/probe_walk_constants.gd` lands as the persistent census
      instrument (the five sections above, ≥ 96 samples/cycle, tolerance
      documented in its header), runs clean headless via
      `--script`, and its printed numbers agree with the ledger below
      within the documented tolerance
- [x] the ledger table in this ticket is re-confirmed against the LANDED
      probe's actual output at done-time (the T-134 "Tuned values" pattern —
      record any deltas, don't copy the pre-ticket run)
- [x] *(Gate 3, screenshots)* pilot-harness slow-mo captures into
      `.captures/t165_walk_probe/` (use `--time-scale 0.1` for stride
      readability), eyes-on verdicts recorded here: (a) a strolling
      tourist's feet track the ground — no skating at gameplay distance;
      (b) a panicking tourist's sprint judged against the ledger's
      −2.2% glide prediction (~0.09 m/s — subtle; a "visible/invisible"
      call is the deliverable, and it feeds the follow-up fix decision);
      (c) an elder shuffling beside a strolling tourist — the pace
      separation reads as grandfather-vs-stroll, not glitch

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with
`locomotion_rate_ledger` registered and its row added to the Gate 1b table
in `VERIFICATION.md`, plus a pointer parenthetical on the
`people_on_one_rig` row (`VERIFICATION.md:129`) naming the sibling scenario
for the sprint/shuffle/sit pins — both in the same change-set · Gate 2
autoplay · Gate 3 the three slow-mo lines above.

**Probing notes for the implementer:** the headless `anim.advance()` +
`force_update_all_bone_transforms()` chain is proven by
`sim_test.gd:8673-8676`; bone names are the import contract
(`DEF-foot.L`, `DEF-foot.R`, `DEF-hips` — `tools/import_people_rig.gd:70-73`);
"fore-aft" is the bone-origin range along the rig's local Z (the pack's
forward is −Z, `people_rig.gd:83-87`); stride = per-foot fore-aft L + R (two
feet, half a cycle apart — the T-138 derivation, `import_people_rig.gd:80`).

## Landed evidence (implementer run, 2026-11-06)

Everything below was run on the branch tree (`feature/t-165`, worktree
`t-165`) with `C:/Users/matth/bin/Godot_v4.7.2-stable_win64_console.exe`.
Honesty note on an environment interruption mid-ask: an outside process
hard-reset the worktree's tracked files (and cleaned the untracked probe
script) between the first gate sweep and the commit; every edit was
recreated from the session record and EVERY gate below was re-run against
the recreated tree — the recorded outputs are the recreated tree's runs.
The Gate 3 captures (`.captures/` is gitignored) survived the reset and
document the same shipped game content.

**The landed probe's census vs this ticket's ledger (the done-time
re-confirmation, T-134 pattern):** `godot --headless --path . --script
tools/probe_walk_constants.gd` → exit 0, census GREEN, and every number
byte-matches the pre-ticket ledger — **no deltas recorded**. Walk: fore-aft
L 0.6540 + R 0.6797 = stride 1.3337 vs pinned 1.3239 (+0.7%); sprint:
1.0484 / 1.0375 = 2.0859 vs 2.1333 (−2.2%); hips in-place x/y/z 0.0000 in
both clips; ankle lifts 0.2304/0.2248 (walk) and 0.4414/0.2938 (sprint) via
the per-foot y ranges; rate table 1.1128 / 1.3092 / 1.5711 stroll, authored
0.993 m/s, shuffle 0.8057, panic 1.3126, sit enter 2.1528 / exit 1.6667 —
all identical to the ledger above. The probe pins
`LEDGER_WALK_STRIDE_MEASURED 1.3337` / `LEDGER_SPRINT_STRIDE_MEASURED
2.0859` (the ledger's measured values) as its census-green band (±0.5%),
so a future clip edit that moves the live foot travel reds the census while
the pinned-constant comparison stays a printed finding (the sprint −2.2% is
this ledger's recorded defect candidate, shipped as-is).

**Red-before (the bite, recorded when landed):** with `PeopleRig.SPRINT_STRIDE`
hand-edited to 2.05 and the full suite run
(`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`),
exactly ONE scenario reds, with BOTH independence legs failing and both
wiring legs holding — exit 1, `SIM SUMMARY: 1 failure(s)`:

```
SIM FAIL locomotion_rate_ledger: stamps=true ledger=false strolling=true panic=false (played 1.3659 vs stamps 1.3126) defaults=true seats=true rising=true/true (1.6667 want 1.6667) walking=true/true (6.0426 want 6.0426) arriving=true/true (2.1528 want 2.1528)
```

`ledger=false` is the script-vs-stamp mismatch (2.05 vs stamped 2.1333);
`panic=false (played 1.3659 vs stamps 1.3126)` is the predicted 0.0533
separation past the ±0.02 tolerance — both exactly the ticket's arithmetic.
SHUFFLE (6.0426 == `walk_rate(6.0)`) and SIT PACING (1.6667 / 2.1528) stay
green on the same edited tree, by design — they pin wiring, not constants.
Constant reverted; the identical red line reproduced on a second red run
(after the mid-ask reset rebuilt the scenario), and the suite went back to
green after the revert.

**Gates (recreated tree, final runs):**

- Gate 1b: `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` → exit 0, **176 SIM PASS / 0 SIM FAIL**,
  `SIM SUMMARY: 0 failure(s)`, `SIM PASS locomotion_rate_ledger` (the
  suite prints detail lines on FAIL only; the shipped-tree leg values are
  evidenced by the probe census above and by the red run's detail line,
  whose wiring legs read 6.0426 / 1.6667 / 2.1528 and whose played rate
  moved exactly with the edited constant). `people_on_one_rig` PASSes
  unchanged in the same run (the walk-rate leg stays only there).
- Gate 1: `godot --headless --path . --import` → exit 0 with exactly the
  one VERIFICATION-documented accepted ERROR line ("33 resources still in
  use at exit" — the provisioned-godot_mcp notice); `godot --headless
  --path . --quit-after 120` → exit 0, zero ERROR lines. (The worktree
  needed the untracked `addons/godot_mcp/` copy restored per the
  VERIFICATION.md precondition before the first clean import.)
- Gate 2: `godot --path . res://tests/autoplay.tscn` → exit 0,
  `AUTOPLAY DONE ok=true t=33.0 fps=136 … restart=true …`, zero SCRIPT
  ERROR lines.

**Gate 3 — the three slow-mo reads** (pilot sessions at `--time-scale
0.1`, captures in `.captures/t165_walk_probe/`, untracked; the stroll
frames from session `t165probe`, the panic/elder frames from session
`t165b` after the first session's game process died mid-capture):

- (a) Stroll — `a_stroll_2/4/5.png` (`a_stroll_1/3/6/7.png` are the
  surrounding burst): a red-shirt civilian strolls its sidewalk loop past
  the grounded pigeon at gameplay distance. Across the frames the figure
  advances along the pavement with alternating leg extension → plant;
  against the sidewalk edge and road markings the plant foot holds its
  ground line between frames — **no skating visible. The stroll verdict:
  feet track the ground.**
- (b) Panic — `b_panic_1/2.png` mid-sprint, `b_panic_3.png` the
  arms-down stroll resume, `b_panic_4.png` post-window: the splatted
  civilian sprints across the crosswalk with arms raised, torso lean and
  the flush live (the HUD books `Civilian +100` and the −1 civilian
  favor in the same frames — the scoring chain riding along). Judged
  against the ledger's −2.2% glide prediction (≈0.093 m/s of foot drift,
  ≈4.7 cm per planted step): **INVISIBLE at gameplay distance.** Both
  mid-sprint frames read crisp planted poses against the asphalt
  markings; no smear, no slide. This feeds the follow-up fix decision:
  the shipped −2.2% does not read at gameplay distance — accept-the-glide
  is a live option for the owner.
- (c) Elder — `c_elder_2.png` and `c_elder_4.png`: the white-haired,
  cardigan'd elder mid-shuffle with its cane, having risen off the plaza
  bench via a real `begin_migration(8)` (the call verb, T-169) toward the
  park bench; `c_elder_2.png` holds BOTH figures in one frame — the
  elder's short cane-assisted shuffle step on the right, a strolling
  tourist mid-stride across the plaza on the left. Across the 14 wall-s
  (= 1.4 game-s at 0.1×) between the frames the elder covers ~1 m while
  the tourist crossed several times that — **the pace separation reads as
  grandfather-vs-stroll, not glitch.**

**Accepted by reviewer sign-off 2026-11-06** (the reviewer read the landed
ledger re-confirmation, the red-before line and the three Gate 3 verdicts
and signed off). Final tuned values: none — this ticket changes no constant
by design (Not claimed); the values the next motion ticket tunes against
are the ledger above, re-confirmed byte-identical by the landed probe
(walk stride 1.3337 measured vs 1.3239 pinned, +0.7%; sprint 2.0859
measured vs 2.1333 pinned, −2.2% — the recorded defect candidate, accepted
as shipped per the (b) invisible-at-gameplay-distance call; all six clip
lengths and the played-rate table exact per the census).
