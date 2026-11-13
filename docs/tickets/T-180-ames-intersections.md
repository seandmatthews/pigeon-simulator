# T-180 — Ames R2 · intersections: crosswalks, stops, signals on real corners

- **Status:** done · **Category:** worldbuilding · **Ring:** R2 The Life ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-178 (the graph), T-179 (etiquette reads it)
- **Refs:** `census/BUILD-CENSUS.md` §4 (20 downtown / 13 Campustown
  4-way; 78 signals) · T-069 (zebra crosswalks), T-134 (stop signs +
  the near-coplanar relief lesson), T-143 (sign thickness) · MUTCD
  consts in `scripts/city.gd` (the geometry being re-positioned)

## What

The crossing/stop/sign machine leaves the synthetic grid node list and
lands on real corners:

1. **Start set** (pinned, expandable): the downtown 20 + Campustown 13
   four-way anchors, plus arterial stops on Lincoln Way / Duff / Grand
   at the crosswalk census points. Real corner geometry — setbacks and
   band widths adapt the T-134 consts to measured street widths.
2. **Signals**: a selected subset of the 78 (arterial × collector
   corners; the count comes from the data and is pinned) — mast-arm
   geometry reads at real intersection widths; all-way-stop corners
   get the T-134 treatment.
3. **Crosswalk paint**: zebra bars at the pin set, worn-white palette
   (T-069's read) — pedestrian demand comes with T-181.
4. **No new behavior classes**: cars obey stops/signals via T-179's
   states; pigeons ignore everything as always.

## Why

Intersections are where the town's governance is visible — the four-way
stops were a landed owner complaint fix (T-134 batch); they must exist
where Ames actually has them or the town reads wrong at eye level.

## Acceptance criteria

- [x] Crosswalk/stop/sign set placed at the pinned start-set corners
      (count + list recorded from the census)
- [x] *(Gate 1b)* `ames_intersections_present`: per-district corner
      counts pinned; geometry within tolerance of the T-134 consts at
      measured widths; near-coplanar layering discipline preserved
      (the T-143 lesson — relief offsets survive the port)
- [x] Traffic obeys the start set (T-179 states fire at real corners —
      pilot probe)
- [x] Screenshot set: Lincoln Way × Welch, downtown 4-way, one signal —
      vs T-134 research refs
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3 folded into T-184.

## Landed record (T-180)

**The pin-set derivation** (all pure data over the committed pack, built once
in `AmesTrafficGraph._classify_intersections`; the derivation instrument is
`tools/probe_intersections.gd`):

1. **Anchors** — the graph's 361 junction nodes (T-178's ≥ 3-arm welds)
   merge within `INTERSECTION_MERGE_RADIUS` 20 m: a divided arterial's
   carriageway junctions sit ~12 m apart and street jogs ~17 m, and both are
   ONE real corner (a transitive merge — Grand × Lincoln Way's far carriageway
   corner sits 20.5 m from the head but 12-16 m from a member). 325 anchors.
2. **District pins** — the census §4 windows (the census script's own bboxes,
   `ames_census.py:820-821`, through the pack transform) over the census
   §7.1/§7.2 street sets: an anchor touching ≥ 1 band street AND ≥ 1 cross
   street pins. **Downtown: exactly 20** (Main/5th/6th × Northwestern, Grand,
   Pearle, Clark, Burnett, Kellogg, Douglas, Duff — the census's recorded
   stock, list in the Gate 1b record). **Campustown: 11 of the census's 13**
   (LW/Hunt/Chamberlain × Hyland, Sheldon, Hayward, Welch, Stanton): the pack
   welds no junction at L/W × State and one Hunt-grade T — the recorded
   delta, honest and expandable.
3. **Arterial stops** — anchors (≥ 2 distinct street names) touching
   Lincoln Way / Duff / Grand inside the pack's core bbox, beyond the district
   pins: **43**.
4. **Signals** — the ticket's "arterial × collector corners; the count comes
   from the data and is pinned": an anchor signals when an ARTERIAL-grade
   street (primary/secondary class, or the Lincoln Way/Duff/Grand/Main Street
   names) meets a COLLECTOR-grade street (tertiary class, or the census §4
   Campustown signal-set avenues — State/Hyland/Sheldon/Hayward/Welch/Stanton,
   which the pack classes residential but the census records as the
   signalized strip), or two distinct arterials cross. **25** — including the
   census-named L/W × Hayward/Sheldon/Hyland/Welch/Stanton set, downtown's
   6th×{Grand, Kellogg, Clark, Duff} + Main×{Duff, Clark, Kellogg}, and the
   Duff/Grand corridor's 13th/S-Duff/S-Grand crossings. The remaining **49**
   pinned corners get the T-134 all-way treatment.

**The adapted corner geometry** (the ticket's "setbacks and band widths adapt
the T-134 consts to measured street widths"): for an approach of half-width W
and lane offset L — band inner edge L + 3.5 (the T-134 corner-sweep margin),
band center L + 4.7, band outer L + 5.9, **stop line L + 7.3** (the MUTCD
1.2 m gap + half the bar), sign at W/2 + 0.2 lateral, stop_outset + 0.5 out,
face center y 2.5, plaque below. The retired Windrow street (W 5.0, L 1.5)
reproduces the landed T-134/T-069 constants exactly (band 5.0-7.4, stop 8.8)
through the same law — the constants are the PORT, not a retune. Paint rides
its own stack level: 0.02-thick boxes centered y 0.11, tops 0.12 — above the
arterial dash top (0.11) the bands overlap, below the rail tie top (0.13),
equal to no baked layer top (the T-143 near-coplanar lesson, pinned by the
scenario against the baked tops list). The T-143 relief ports verbatim: red
core 0.086 over the 0.03 border. Zebra bars tile ACROSS the road at 0.5 pitch
(T-102's longitudinal read), one bar count per width. Signal corners carry NO
stop furniture (control exclusivity, pinned at L/W × Welch).

**The signal model**: one city-wide synchronized two-phase cycle on the fixed
physics clock (`TrafficControl.signal_phase`, green 10 s per group) — group 0
is the arterial's two directions, group 1 the cross street, derived per
corner from the widest arterial arm. A car obeys through T-179's existing
states only (ticket item 4): it brakes to its line, registers, and the phase
gate fronts the same ladder; a red hold parks it WITHOUT feeding the patience
clock (the light guarantees progress — a force-commit break would run the
red), pedestrian priority and the ladder still apply on green. The mast-arm
furniture reads the same clock: pole 5.8 m on the arterial approach's right
corner, the arm spanning the asphalt at 5.6, two three-lamp heads over the
arterial's two lane lines, the lamps repainted per phase flip (amber never
lights — a two-state green/red cycle; the cross street's heads are the
expandable note). All furniture is visual-only (T-017), zero RNG, and a
forced rebuild reproduces every transform.

**Gate results (this ticket's own runs)**: Gate 1 — `--import` exits 0 with
only the documented addon-teardown ERROR line; the 120-frame boot exits 0
with zero error lines. Gate 1b — **135 scenarios, 0 failures** (exit 0;
`/tmp/sim_t180_run6.log`): the new `ames_intersections_present` row green
with counts 20/11/43/25/49, 9,812 paint bars / 200 stop lines / 200 posts /
800+800 octagon bars / 200 plaques / 50 mast boxes / 50 heads / 150 lamps,
the obey arms measured below, determinism byte-identical; `density_cpu_budget`
median 95.0 ms per 100 physics frames (budget 750). `ames_traffic_routes`
0/19 dead windows, `ames_traffic_calm` byte-identical arms (the staged probes
stop ~19+ m before their lines — unregistered, so the red gate never binds;
live arm 0/10 dead windows, blinker 40/40, 0 honks). Gate 2 — `AUTOPLAY DONE
ok=true world=ames crumb_target=40 loop_ok=true restart=true` (exit 0,
141 fps). Gate 3 folds into T-184 (the owner watches calm traffic at a real
signal corner).

**Two re-pins the port forced, both recorded in the rows**: `ames_traffic_
density` (T-178) — the per-seed arterial bar 10 → 9 and the residential bar
restated per-anchor (bounded minority, never leading primary): the arterial
stop lines moved out to the adapted setback (17.0 m on Lincoln Way, was the
flat 8.8) and the staging window follows its own line (the T-178 round-2
corridor lock at the measured width), so the near-junction arterial
candidates that tree wrongly allowed are refused and a few cars rebase onto
later legs — the density LAW, the fleet contract and the arterial majority
all hold (cruise [11, 9, 12], low_hover [13, 14, 11]); `ames_traffic_calm`
(T-179) — no arm moved, the re-verification note appended.

**`ames_intersections_present` obey values** (the `SIM DATA`/detail line):
a staged mover timed into a red window at L/W × Welch — **483 red frames**
held at its line with the patience clock byte-frozen (delta 0.000: a red
never force-commits), the commit landing **+8.1 s** after registration (the
green flip, inside 13 s); the crosswalk arm parks the pigeon in the corner's
REAL oriented band and a green-registered mover holds **622 frames** (10.4 s
of green) without committing — pedestrian priority reads the painted bands.

**Pilot probe record (2026-11-13, session `t180int`, hidden window, muted,
no persistence — criterion 3)**: the live game on the resident world, the
shipped 14+12 fleet, hunger locked (`hunger_lock`) for the soak. The
state-stream soak at the L/W × Welch corner: **16 of 26 cars within 80 m of
the corner standing through a 9 s sample** (the red-phase queue across the
Lincoln Way strip and the Welch approaches; the T-179 liveness pins hold —
the queue drains each green). The call-verb entry reads on live queue cars:
`@654`/`@655` at nodes **1691/1674 (L/W × Welch, SIGNAL)** —
`signal_group 0`, `bands 1` (the real oriented record), cruise 9.0 (the
primary class); `@656`/`@657` at node 1681 (L/W × Stanton, SIGNAL) — same
stamps; `@653` at node 839 (Welch × Chamberlain, ALL-WAY) — `bands 1`,
NO `signal_group`, cruise 4.5. An unpinned single-street junction (node 1665,
L/W × Lynn) reads `bands []` — the furniture and the entries agree on where
the dress lives. Screenshots (`.captures/`): `t180_lw_welch_signal.png`
(L/W × Welch from the north-above — the zebra bands, the mast arm and its
head, the center dashes), `t180_downtown_4way.png` (Main × Duff from down
Duff — queued cars at the line, red stop signs on the right, zebras across,
the rail corridor adjacent), `t180_stop_sign_close.png` (the Main Street
storefront canyon at glide height), `t180_lw_welch_signal_aerial.png` (the
Welch strip aerial) — against the T-134 research refs' read: bars behind the
zebras, signs on the approach's right, nothing z-fighting.

**Acceptance record:** reviewer sign-off 2026-11-13 — ticket accepted against
this branch (the five criteria ticked on the recorded runs: the pin-set counts
+ list in the landed record and the Gate 1b row; `ames_intersections_present`
green with the geometry/relief/sync/determinism arms quoted; the obey arms +
the `t180int` pilot probe (signal_group/bands entry reads, the 16-car red-phase
soak at L/W × Welch); the screenshot set in `.captures/`; Gate 1 import+boot
clean and Gate 2 `AUTOPLAY DONE ok=true world=ames … restart=true`). The
tuned values are the shipped derivation constants quoted above — none is a
hand-set number outside the recorded laws.

**Tuned values (as landed):** `INTERSECTION_MERGE_RADIUS` 20.0 ·
`CROSSWALK_BAND_DEPTH` 2.4 · `CROSSWALK_BAR_WIDTH` 0.4 ·
`CROSSWALK_BAR_PITCH` 0.5 · `BAND_INNER_MARGIN` 3.5 · `BAND_STOP_GAP` 1.2 ·
`STOP_LINE_WIDTH` 0.4 · `STOP_LINE_SPAN` 2.8 · `SIGN_EDGE_OFFSET` 0.2 ·
`SIGN_OUTSET_GAP` 0.5 · `PAINT_CENTER_Y` 0.11 (tops 0.12) ·
`PAINT_THICKNESS` 0.02 · `STOP_SIGN_THICKNESS` 0.086 (the T-143 port) ·
`STOP_SIGN_BORDER_THICKNESS` 0.03 · `SIGN_FACE_Y` 2.5 · `SIGN_PLAQUE_Y` 2.0 ·
`SIGNAL_GREEN_SECONDS` 10.0 · mast: `MAST_HEIGHT` 5.8, `MAST_ARM_Y` 5.6,
`MAST_HEAD_Y` 4.9, `MAST_POLE_CLEAR` 0.6, `MAST_POLE_SIDE` 0.7,
`MAST_ARM_END_CLEAR` 1.2, `MAST_HEAD_DEPTH` 0.30, `MAST_LAMP_PITCH` 0.33,
`MAST_LAMP_OUT` 0.18. Derived per approach (not constants): band inner
L+3.5 / center L+4.7 / outer L+5.9, stop_outset L+7.3 — the Windrow street
reproduces the landed T-134/T-069 numbers exactly through the same law.
