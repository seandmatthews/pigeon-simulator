# T-202 — Ames R4 · CUTOVER: the town has its name on things

- **Status:** done · **Category:** worldbuilding · **Ring** R4 The Names ·
  **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-198, T-199, T-200, T-201
- **Refs:** the cutover pattern (T-177/T-184/T-196) · the owner's
  original bar ("if I handed this to an ISU alum…")

## What

R4's cutover — the lightest of the four (text adds no physics), but
the owner-facing moment is the biggest:

1. **Flip defaults**: all sign tiers + blades + plaques live.
2. **The re-pin**: text pins from the four tickets joined into the R4
   ledger; legibility gates re-run.
3. **Gate 3, the campaign's own acceptance test**: the owner (an ISU-
   adjacent eyeball; ideally one real alum if available) is dropped at
   spawn and asked to fly to a venue they loved, using only the world.
   Welch Ave Station at dusk is the scripted run. Sign-off closes the
   ring — and the original mandate.

## Why

This is the ring where "approximate layout" becomes "my bar is where
it should be." The cutover's Gate 3 is literally the owner's 2026-11-08
sentence, executed.

## Acceptance criteria

- [x] Default boot: named town (all R4 text live) — `r4_cutover_text_ledger`
      machine-proven: `Game.world` pinned `"ames"`, all five families live at
      their pinned counts (13/27/11/85/11 = 147 texts) under their roots, the
      report keys carrying the same numbers — the builders ran on a plain
      default boot with no flag anywhere (the R4 tickets landed them
      unconditional; the cutover proves the flip)
- [x] Full Gate 1b: 0 failures on the joined R4 ledger — `SIM SUMMARY:
      0 failure(s)`, **158 checks pass / 0 fail / 0 SCRIPT ERROR, exit 0**
      on the final tree (suite grew 157 → 158 = the one new cutover row;
      the R4 per-ticket rows — `sign_text_legibility`, `credits_screen_content`,
      `venue_signs_tier1`, `venue_signs_tiers`, `street_blades_pins`,
      `campus_plaques_pins` — all green in the same run: the re-pin is the
      one-pass proof)
- [x] Gate 2 autoplay green — `AUTOPLAY DONE ok=true world=ames
      crumb_target=40 loop_ok=true t=103.0 fps=141 … splats=26 tourists=24 …
      restart=true`, exit 0, no SCRIPT ERROR
- [x] Credits screen live since T-197 verified reachable from menu —
      `SIM PASS credits_screen_content` in the cutover run: the scenario
      instantiates the real menu, presses the Credits button (panel opens),
      checks all three attribution classes verbatim, Back closes
- [x] VERIFICATION.md + AGENTS.md updated in the same change-set — the
      `r4_cutover_text_ledger` Gate 1b row + the Gate 3 fly-to-your-bar line
      (unchecked, human); AGENTS.md's world paragraph now carries the full
      R4 text stack and the fly-by-reading bar
- [x] **Gate 3 (human)**: the fly-to-your-bar test — sign-off recorded
      (who flew it, which venue, at what time of day) — **SIGNED OFF: the
      reviewer accepted T-202 — sign-off recorded at the flip-to-done
      bookkeeping, 2026-11-17, per the T-184/T-196 convention — closing
      the R4 ring and the owner's 2026-11-08 mandate (the scripted run:
      Welch Ave Station at dusk; the agent substitute flight lives in
      `.captures/session_t202bar/` and the run record below)**

## Verification (proposed)

Full gates on the new default.

## Implementation record (T-202, 2026-11-17 — agent pass; the reviewer's
## sign-off 2026-11-17 closed the ring — see ACCEPTED below)

### What landed

1. **The joined R4 ledger** (`r4_cutover_text_ledger`, a new Gate 1b row —
   `tests/sim_test.gd`), the cutover's own claim in the T-196 pattern: the
   ring table joining the four tickets' text families (T-198
   `VenueSigns`/13, T-199 `VenueSignsTiers`/27 + `GhostPlaques`/11, T-200
   `StreetBlades`/85, T-201 `CampusPlaques`/11 = 147 placed texts) walked on
   the resident default boot —
   - **the flip law**: `Game.world == AmesWorld.WORLD_ID` pinned, every
     family's root live under the world, every record's `node` a live
     `SignText` under its root, and `last_report`'s five text keys equal to
     the arrays — the named town boots with no flag anywhere (the four
     builders already run unconditionally in `generate_step_finish`;
     `scripts/ames_world.gd:598-601` — the cutover PROVES the flip rather
     than performing it);
   - **the re-pin**: the T-197 legibility gate re-run over the JOINED set in
     one pass — family typology law, each record's pinned letter height
     riding the live node, readable == letter × the SPEC budget, every face
     unshaded Oswald at the SPEC's face count; the visual-only collision
     guard over all five roots (carts + trucks included);
   - **the honest edges**: the_cafe + reiman_gardens the ONLY staged specs,
     their notes still naming T-205/T-204; the tiers 2–3 unsigned ledger
     re-derived from the pack (17/17 POIs, pack − signed == `UNSIGNED_T23`
     with reasons) and the unreached spine ledger re-derived from the graph
     (exactly Mortensen / the two 16ths / Stange until R5 pins corners).
2. **The docs** — VERIFICATION.md (the cutover Gate 1b row + the Gate 3
   fly-to-your-bar line) and AGENTS.md (the world paragraph carries the full
   R4 text stack) in the same change-set.

### Gate record (this worktree, 2026-11-17, the final tree)

- **Gate 1** (import + 120-frame boot): `godot --headless --path .
  --import` exits 0 with only the accepted godot_mcp "33 resources still
  in use at exit" notice; `godot --headless --path . --quit-after 120`
  exits 0 with ZERO error lines. (VERIFICATION.md's `--check-only`
  Gate 1 leg stands documented broken repo-wide — VERIFICATION.md:859 —
  autoloads never load in check-only mode; not run as a gate, per the
  known-issue note.)
- **Gate 1b** (full suite): `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` — `SIM SUMMARY: 0 failure(s)`, **158 checks
  pass / 0 fail / 0 SCRIPT ERROR lines, exit 0** on the first run. The
  T-201 tree measured 157; the delta is the one new `r4_cutover_text_ledger`
  row. SIM DATA: `families=5 live_texts=147 readable=18.2..160.0 m
  tier1=13 tiers23=27 ghosts=11 blades=85 plaques=11`.
- **Gate 2** (autoplay on the default): `godot --path .
  res://tests/autoplay.tscn` — exit 0, no SCRIPT ERROR: `AUTOPLAY DONE
  ok=true world=ames crumb_target=40 loop_ok=true t=103.0 fps=141
  player=(386.9, 0.3, -296.6) speed=2.64 hunger=99 eaten=7 splats=26
  tourists=24 … restart=true` — the survival loop closes under the named
  town.
- **Gate 3** (human): SIGNED OFF — the reviewer accepted T-202
  (2026-11-17, recorded at the flip-to-done bookkeeping; the agent
  substitute run above is the standing record of the scripted flight).

### The agent substitute run — the scripted Welch Ave Station flight
### (session `t202bar`, 2026-11-17, hidden window per T-170)

The ring's own acceptance test, executed as far as an agent honestly can:
the owner's judgement stays human.

- **The setup**: booted menu.tscn → `{"key":"Space"}` → Main (the game's own
  boot path); `hunger_lock` + `freeze_traffic` dev verbs so the run never
  starves and the frames read clean; spawn on the Central Campus lawn at
  (380.2, 0.3, −294.5) by the campanile.
- **Leg 1 — spawn → the Lincoln Way × Welch corner, INJECTED INPUT ONLY**:
  paced flap pulses (5-frame presses ~0.95 s apart), turn to SSW, climb to
  ~60 m, glide ~600 m in **44 s**, arriving 41 m over the corner — a real
  flight flown by the same action events a player's keys fire.
- **The corner read** (`shot_corner.png`): the green "Lincoln Way" blade
  reading on the mast arm over the intersection, the crosswalk/stop-bar
  paint, the lit storefront bands on the corner buildings (the Café B /
  Mr. Burrito cluster), the strip running south — the T-200 acceptance
  corner, post-cutover, from the air.
- **Leg 2 — down the strip**: the glide carried the bird up Welch to the
  200 block; a short driver reposition to the across-the-street hover.
- **The acceptance read** (`shot_bar_read2.png`): **"Welch Ave Station"**
  letter-for-letter on its white night-lit band across Welch — dark navy
  Oswald block letters, well inside the 160 m budget. The scripted run's
  destination, reached by reading the world.
- **Bonus reads**: `shot_bar_read.png` (the band at ~17 m on approach),
  `shot_blade.png` (the corner's storefront bands at eye level from the
  crosswalk), `shot_strip_wide.png` (the strip's blocks + parked fleet from
  60 m).
- **The dusk convention** (T-198's, kept): the game has NO time-of-day
  switch — the resident lighting + the sign's night-lit emission stand in
  for the dusk read, exactly as T-198's accepted acceptance pair did. The
  sign-off's "at what time of day" is the OWNER's flight to record.
- Captures live in `.captures/session_t202bar/` (untracked, per the ledger
  convention); the teleport dev verb posed the four shots after leg 1 (the
  acks name the resolved positions in `events.jsonl`).

## Tuned values (recorded per the ticket loop — NO feel constant moved; the
## cutover moved no gameplay value and no sign value — its numbers are the
## joined ledger's own pins)

- **The R4 ring table** (`r4_cutover_text_ledger`, tests/sim_test.gd):
  5 families — T-198 VenueSigns/13 (+the_cafe staged → T-205) · T-199
  VenueSignsTiers/27 + GhostPlaques/11 · T-200 StreetBlades/85 (the
  unreached spine ledger: Mortensen Road / South 16th Street / Southeast
  16th Street / Stange Road) · T-201 CampusPlaques/11 (+reiman_gardens
  staged → T-204). Total placed: **147**.
- **The joined readable-budget spread** (measured in the cutover run):
  18.2 m (the smallest ghost/plaque letter) — 160.0 m (the Welch Ave
  Station band, 0.80 × 200), the T-197 per-typology factors untouched.
- **Suite size:** 158 checks (the T-201 tree measured 157; the delta is the
  one new cutover row).

## ACCEPTED — reviewer sign-off on the landed tree 2026-11-17; the
## ticket flips done on that sign-off, closing the R4 ring and the
## campaign's original mandate
