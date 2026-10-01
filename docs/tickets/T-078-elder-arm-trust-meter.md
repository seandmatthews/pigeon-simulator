# T-078 — Make the elder's arm the trust meter — make the hangout learnable

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** — (T-020 landed; this retunes only its presentation)
- **Refs:** sweep 1 session `uiuxs3c` (`.captures/session_uiuxs3c/`, readings below)

## What

Standing next to a bench elder for ~4 s is the game's hidden bread faucet, but nothing shows
trust building or marks the 25 s of dead time after a share. `scripts/elder.gd` already has
every part: `_trust` fills at 1.0/s while a grounded pigeon is present
(`scripts/elder.gd:86-94`), and the near arm already animates — it just only ever moves for
the 0.5 s post-share beat (`_arm_left`, `scripts/elder.gd:112`; `_animate`,
`scripts/elder.gd:134-139`).

Drive the existing arm from trust, in `scripts/elder.gd` only. In `_physics_process`, compute
the arm's target raise before `_animate` runs:

- `_cooldown_left > 0` → target **0** ("not now" — `share_cooldown` 25.0, `scripts/elder.gd:44`);
- else pigeon present → target `_trust / trust_needed` (0…1 as trust banks);
- else (absent) → target **0**;
- the post-share beat layers on top exactly as today: while `_arm_left > 0` the target is 1.0
  (`arm_raise_seconds`, `scripts/elder.gd:47,112`).

`_animate` keeps easing toward the target with `move_toward` at `arm_raise_rate` (8.0/s,
`scripts/elder.gd:48`) — the mechanism is unchanged; only the target stops being binary. The
player reads it diegetically: the arm rises as the elder warms up, drops while they ignore
you. Zero HUD cost.

One transient worth knowing: if the pigeon is still present when the cooldown expires, trust
is already pinned at `trust_needed`, so the elder shares on that same frame
(`scripts/elder.gd:90-91`) — the "risen arm awaiting expiry" state lasts one physics tick,
and the visible full-up moment stays the share beat.

What this does NOT claim: no change to trust rates, `trust_needed`, share timing, crumb
tosses or the cooldown; no new signal; no HUD element.

## Why

The design paid for a learnable behavior the player cannot see happening. Session `uiuxs3c`
(re-read this run): waddling into the PresenceZone (elder at (8, 0.72, 0)),
`elder_bread_shared` fired at t_ms 113407 with 2 crumbs and a `crumb_eaten` 20 ms later
(events.jsonl lines 14-15) — but no frame or HUD element changes until the crumbs pop in:
`f00006792.png` (viewed this run) shows the payoff — a crumb on the pavement, pointer
"bread 2 m", the elder's arm at rest — with zero build-up. After the share, the 25 s cooldown
(`scripts/elder.gd:44`) is invisible, so "hang out ~4 s, then a long wait" is unteachable.

## Acceptance criteria

- [x] Mid-hangout (present, no cooldown) the near arm sits visibly part-raised and keeps
      rising as trust grows toward `trust_needed`
- [x] After a share, with the pigeon still present, the arm eases back down and stays down
      through the whole cooldown — even though trust refills and pins at `trust_needed`
      during it
- [x] With no pigeon present the arm never rises
- [x] `_scenario_elder_shares_bread_after_hangout` (`tests/sim_test.gd:1169`) extended with
      three arm assertions in its existing windows (below) passes
- [x] `elder_no_bread_airborne` and `elder_cooldown_blocks_second_share` pass untouched
- [x] [screenshot] pass: the arm is visibly part-raised mid-hangout at ground level (a
      chase-cam frame from inside the zone) — agent grabs
      `.captures/t078_arm_midhangout.png` / `.captures/t078_arm_after_leave.png`;
      reviewer sign-off 2026-10-01

## Tuned values

None changed — the ticket explicitly retunes only the presentation. Landed pins:
`arm_raise_seconds` 0.5, `arm_raise_rate` 8.0/s, `share_cooldown` 25.0,
`trust_needed` 4.0. Measured presentation on the landed build: mid-hangout
`_arm_raise` ≈ 0.58 at trust ≈ 2.3 (window screenshot), arm back to exactly 0 from
0.63 s after the share (0.5 s beat + 0.125 s sweep at 8.0/s).

## Runs (agent, 2026-10-01 — feature/t-078 worktree)

- Gate 1: `--import` exit 0 (only the VERIFICATION.md-documented benign
  `33 resources still in use at exit` addon line); `--quit-after 120` exit 0, zero
  error lines; `--check-only --script res://scripts/elder.gd` exit 0 with no
  `elder.gd` diagnostics (the transitive `Sfx` autoload noise from
  `player.gd`/`poop.gd` reproduces byte-identically on the untouched base tree —
  pre-existing `--check-only`-without-autoloads behavior, not this change).
- Gate 1b: full suite `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
  → exit 0, all 95 `SIM PASS` lines including `elder_shares_bread_after_hangout`
  (with the three new arm assertions), `elder_no_bread_airborne`,
  `elder_cooldown_blocks_second_share`.
- Gate 2: `AUTOPLAY DONE ok=true … restart=true`, exit 0.
- Gate 3 agent grabs (reviewer sign-off 2026-10-01):
  `.captures/t078_arm_midhangout.png` (chase cam inside the zone, `arm_raise=0.579`
  at trust 2.32/4.0 — the elder's near arm reads clearly raised over the bench;
  compare the arms-down elders elsewhere in frame) and
  `.captures/t078_arm_after_leave.png` (pigeon stepped out of the zone,
  `arm_raise=0.000` — arm back at rest).

## Verification

Gate 1 + Gate 1b — extend `_scenario_elder_shares_bread_after_hangout` (it already reads
`elder._trust` directly, `tests/sim_test.gd:1189`; its windows map 1:1 onto the checks):

- bank checkpoint (~2.2 s of company, `tests/sim_test.gd:1188`): `elder._arm_raise` is
  part-raised (assert > 0.2 and < 0.9) and still increasing across a few sampled frames;
- away window (`tests/sim_test.gd:1190-1194`): `elder._arm_raise` stays 0 the whole time the
  pigeon is absent;
- after the share is detected inside the 280-frame wait (`tests/sim_test.gd:1197`), still
  parked: once the 0.5 s beat has passed, `_arm_raise` eases low (< 0.1) while
  `elder._trust` stays pinned at `trust_needed` — the cooldown-overrides-trust proof.

No existing elder scenario reads `_arm_raise`, so the blast radius is nil. Gate 2 runs
normally. Gate 3: the [screenshot] line above; VERIFICATION.md gains a Gate 1b row and a
Gate 3 line in the same change-set.
