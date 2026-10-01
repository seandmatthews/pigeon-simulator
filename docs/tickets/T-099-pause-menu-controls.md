# T-099 — Put the controls inside the pause menu — the one screen a stuck player opens

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** sweep 2, ui-ux lane (2026-09-30) · T-019 (outline treatment + hint
  styling) · T-010 (pause flow, done) · T-039 (copy-duplication precedent) ·
  pause-panel source `scenes/main.tscn:138-184`

## What

Two static Labels appended to `PauseMenu/Center/PausePanel/Box` in
`scenes/main.tscn` — the Box currently holds exactly Title plus the
Resume/Restart/Menu/Quit buttons and nothing else
(`scenes/main.tscn:160-184`) — below the buttons:

- `%AirControls` (unique_name_in_owner):
  `Air: W/S pitch · A/D turn · Space flap · F poop`
- `%GroundControls` (unique_name_in_owner):
  `Ground: W/S waddle · A/D turn · Space flap off · walk into crumbs to eat`

(The proposal's sketch omitted A/D from the ground line; it is included here
so the recap carries the same verb set as `MainGame.HINT_GROUND` — the
divergence guard below checks it.)

Styling mirrors the hint line's T-019 treatment exactly
(`scenes/main.tscn:99-102`): `font_size 14`,
`font_outline_color Color(0, 0, 0, 0.85)`, `outline_size 4`,
`font_color Color(1, 1, 1, 0.75)` — on the panel they read over the Dim
(`Color(0, 0, 0, 0.55)`, `scenes/main.tscn:148`).

The copy duplicates `MainGame.HINT_AIR` / `HINT_GROUND`
(`scripts/main.gd:12-13`) by design: scene files cannot reference script
constants (T-039's precedent), so the Gate 1b scenario is the divergence
guard. No script change at all: `pause_menu.gd` and `main.gd` are untouched;
the labels ride the CanvasLayer's visibility (`pause_menu.gd:45-54`).

Does **not** claim: no hint-line change, no new input action, no flow change,
and no claim that the recap teaches more than the key families (tone is
Gate 3).

## Why

A player who forgets what W/S or F do mid-run has exactly one in-game
reference: the 14 px hint line that shows only the CURRENT mode's verbs — the
airborne half (`HINT_AIR`) is never shown while grounded and vice versa (the
swap is `scripts/main.gd:294-295`) — and when the pause panel is up, that hint
sits dimmed under the overlay's 0.55 dim. The pause panel itself — the one
screen a stuck player reliably opens — offers four buttons and zero controls.
Recorded from the lane's `session_uiuxs4b` trace (panel moments in the trace;
the hint line above it dimmed, grounded copy only). Honest note: the lane's
window grab of that session caught unpaused gameplay, so the panel's bareness
rests on the scene source (`scenes/main.tscn:160-184`) plus the trace rather
than a framed screenshot of the open panel — the Gate 3 pass below closes
that gap.

## Acceptance criteria

- [x] While paused through the real Main, the pause panel shows both control
      lines and they are visible; during normal play and after unpausing they
      are hidden with the panel — Gate 1b only (new scenario
      `pause_menu_shows_controls`)
- [x] Each line carries its constant's key families — air: W/S, A/D, Space,
      F; ground: W/S, A/D, Space — checked against `MainGame.HINT_AIR` /
      `HINT_GROUND` so a future constant edit that drops a family fails the
      gate — Gate 1b only
- [x] Both labels carry the T-019 treatment (14 px, outline 4, black-0.85
      outline, white-0.75 fill) — Gate 1b theme check
- [x] The panel with its control lines reads at a glance over the dimmed
      world — [screenshot] (open pause panel, mid-run; agent grab
      `.captures/t099_pause_controls.png`, unpause confirm
      `.captures/t099_pause_unpaused.png`; reviewer sign-off 2026-10-01)
- [x] `scripts/pause_menu.gd`, `scripts/main.gd` and `project.godot` are
      untouched by the diff; only `scenes/main.tscn` gains the two labels

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b — new scenario
`pause_menu_shows_controls` through the REAL main scene, on the
`_scenario_hud_hunger_tiers` pattern (`tests/sim_test.gd:2659-2662`:
own-space `MAIN_SCENE.instantiate()`, the unpaused-tree window after the
restart scenarios, same cleanup tail). Pausing a live Main mid-scenario is
proven harness practice (`tests/sim_test.gd:1175-1186`). Steps:
`main_game.pause_menu.toggle()` → assert `get_tree().paused` and both labels
exist and are visible; assert the key families above; `toggle()` again →
assert both hidden and the tree unpaused; free the instance and restore the
window (`Game.hunger.player = null`, `Game.reset_run()`) — and never leak a
pause into later scenarios (the `_scenario_pause_freezes` tail,
`tests/sim_test.gd:2337-2339`). Full suite green. Gate 2 unaffected (the
autoplay never opens the pause menu; run it anyway). Gate 3: [screenshot]
pass — the recap reads at a glance beside the button labels, and the
"one controls block per screen" tone holds.

## Recorded verification (agent, 2026-10-01 — accepted by reviewer sign-off)

**Tuned values:** the two recap lines, as landed in `scenes/main.tscn:223-238`
— `%AirControls` `Air: W/S pitch · A/D turn · Space flap · F poop` and
`%GroundControls` `Ground: W/S waddle · A/D turn · Space flap off · walk into
crumbs to eat`, both with the T-019 treatment (`font_size 14`,
`outline_size 4`, `font_outline_color Color(0, 0, 0, 0.85)`,
`font_color Color(1, 1, 1, 0.75)`, `horizontal_alignment` centered to match the
Title), appended below the four buttons; the ground line drives the panel's
width. Copy intentionally duplicates `MainGame.HINT_AIR` / `HINT_GROUND`
(only the key families — the constants' "land by bread to eat" tail is
recap-specific and stays hint-only); the Gate 1b bi-directional family match
is the drift guard. No script or input changes.

- **Gate 1:** `--import` exit 0 with the one documented benign line
  (`ERROR: 33 resources still in use at exit` — see VERIFICATION.md known
  issues); `--quit-after 120` exit 0, zero ERROR lines.
- **Gate 1b:** full suite `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` → exit 0, `SIM SUMMARY: 0 failure(s)`, 95 PASS
  including the new `pause_menu_shows_controls` (re-run on the final tree).
- **Gate 2:** `godot --path . res://tests/autoplay.tscn` → exit 0,
  `AUTOPLAY DONE ok=true … restart=true` (fps 135) — the autoplay never opens
  the pause menu, run anyway per the ticket.
- **Gate 3, agent-side via the pilot harness** (session `t099pause`, muted,
  persistence off): Space started a run (`wait --scene Main`), four flap
  commands drove mid-run, `send {"key":"Escape"}` opened the panel —
  screenshot `.captures/t099_pause_controls.png` shows PAUSED with both recap
  lines legible below the four buttons over the dimmed world (the HUD hint
  above shows only the grounded copy, the gap this ticket closes); a second
  Escape resumed play — `.captures/t099_pause_unpaused.png` shows the panel
  and recap gone with hunger still ticking (90% → 89%). Raw session kept at
  `.captures/session_t099pause/`. Reviewer sign-off 2026-10-01.
