# T-097 — Stop the title screen's Esc key from hard-quitting the app

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** sweep 2, ui-ux lane (2026-09-30) · T-010 (menu flow, done) · T-039
  (title-screen precedent; coordinates on the footer line) · pilot traces
  `session_uiuxs4a` / `session_uiuxs4a2` (2026-09-29)

## What

Delete one branch in `scripts/menu.gd` `_unhandled_input`
(`scripts/menu.gd:20-24`): `elif event.is_action_pressed("pause") or
event.is_action_pressed("quit"): get_tree().quit()` becomes a quit-only branch
— `elif event.is_action_pressed("quit"): get_tree().quit()`. Space keeps
starting a run via the `flap` arm above it, exactly as both control tables
already document. Update `menu.gd`'s docstring in the same hunk — line 5 still
says "Q quits and Esc is an alias from the menu", which stops being true.

Two doc touches in the same change-set. No InputMap change — `pause` keeps Esc
and `quit` keeps Q (`project.godot:72-76` and `:87-91`); nothing is added or
rebound, the tables just stop implying Esc is live at the title:

- `README.md:34` and `VERIFICATION.md:210` (the Esc rows): they already
  describe only the in-run pause; append the title fact, e.g.
  "· does nothing on the title screen".
- `README.md:37` and `VERIFICATION.md:213` (the Q rows) already say quit works
  from the title — unchanged.

One discoverability edit: `scenes/menu.tscn`'s Footer
(`scenes/menu.tscn:67-78`, currently "eat bread to survive · splat tourists
(100) and cars (30) · don't starve") gains "· Q quit", so the title's only
exit stays discoverable once Esc stops doing anything there. If T-039 has
already landed its controls line, fold "Q quit" into that line instead so the
title carries one controls block, not two.

Does **not** claim: no flow change (menu.tscn ↔ main.tscn untouched), no new
action, no PauseMenu change, and no headless test of Q-quit (see Verification).

## Why

Esc is the game's back-out key on every other screen — in-run it is the
reversible pause toggle (`scripts/pause_menu.gd:28-31`) — but on the title
screen the same reflex instantly kills the whole application, with no
confirmation and no hint that Esc is wired there at all. A player who pauses
out of a run, returns to the title with M, and presses Esc again by reflex
quits the game. Executed proof from the sweep-2 lane sessions: pilot session
`uiuxs4a` died immediately after its first injected Escape at the menu
(`pilot.py list` → live no, state frozen at frame 1856); control session
`uiuxs4a2` was alive after 14 s idle (state t_ms=15301), then the same
injected Escape killed it within ~4 s (last state t_ms=20136, live no). The
README table documents Q as the title's quit key (`README.md:37`) — that is
what the code should do, and nothing else.

## Acceptance criteria

- [x] Feeding a synthetic `pause` (Esc) action event to `menu.gd`'s
      `_unhandled_input` neither quits the process nor pauses the tree —
      Gate 1b only (new scenario `title_escape_does_not_quit`)
- [x] Space still starts a run from the title: the `flap` arm and
      `_start_run()` are untouched and the T-010 flow line
      (`VERIFICATION.md:259`) keeps passing
- [x] Q remains the title's quit key: the `quit` arm survives verbatim (not
      asserted headlessly — a harness cannot survive testing its own quit; the
      Gate 3 pass covers it)
- [x] `project.godot` `[input]` is untouched: `pause`/`quit` keep their keys
      and no action is added or removed
- [x] README.md and VERIFICATION.md control tables state, in the same
      change-set, that Esc does nothing on the title screen and Q quits from
      it
- [x] `menu.gd`'s docstring no longer describes Esc as a quit alias
- [x] The title screen shows a Q quit hint (Footer or the T-039 controls
      line), legible at a glance — [screenshot]

## Verification

Gate 1 (import + 120-frame boot, both exit 0, zero ERROR lines) + Gate 1b —
new scenario `title_escape_does_not_quit`: instance `scenes/menu.tscn`
headless (`menu.gd`'s `_ready` is headless-safe — it only sets the high-score
label text and grabs button focus, `scripts/menu.gd:12-17`; the same precedent
T-039's proposed scenario relies on), fabricate an `InputEventAction` for
`pause` and feed it directly to the instance's `_unhandled_input`, advance a
few frames, then assert `is_instance_valid(menu)` and
`get_tree().paused == false` before issuing the scenario's normal `_check`.
A regression re-adding the quit branch kills the whole Gate 1b process at that
line, so the missing check IS the loud failure. Do not feed `flap` (it would
change the harness's scene) or `quit` (it would quit it). Registration is
unconstrained — the menu instance touches no Main state and frees itself; any
unpaused point works. Full suite green. Gate 2 unaffected: the autoplay boots
`main.tscn` directly and never visits the menu (verified: `tests/autoplay.gd`
has no menu or Esc reference), run it anyway. Gate 3: [screenshot] of the
title showing the Q quit hint; while there, one manual Esc press at the title
(app stays up) and one Q press (app exits).

## Recorded verification (agent, 2026-09-30 — accepted by reviewer sign-off)

T-039 was still `proposed` when this landed, so per the ticket's fallback the
"Q quit" hint went on the existing Footer line.

**Tuned values:** none — this change deletes a branch and adds a footer hint;
no constants were tuned and no code values need recording.

- **Gate 1:** `--import` exit 0 with the one documented benign line
  (`ERROR: 33 resources still in use at exit` — see VERIFICATION.md known
  issues); `--quit-after 120` exit 0, zero ERROR lines.
- **Gate 1b:** full suite `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` → exit 0, `SIM SUMMARY: 0 failure(s)`, 86 PASS
  including the new `title_escape_does_not_quit`. The regression guard was
  executed, not assumed: with the quit branch temporarily re-added the run's
  output stops exactly after `SIM PASS pause_freezes_world` — the quit fires
  inside the new scenario and kills the process with no `SIM SUMMARY` (exit
  code is Godot's default 0, so the missing summary/check IS the loud signal,
  as this ticket predicted).
- **Gate 2:** `godot --path . res://tests/autoplay.tscn` → exit 0,
  `AUTOPLAY DONE ok=true … restart=true` (fps 137).
- **Gate 3, agent-side via the pilot harness** (sessions `t097a` / `t097b`,
  muted, persistence off):
  - Space still starts a run: session `t097a` `send {"key":"Space"}` at the
    title → `wait --scene Main` reached Main.
  - Esc no longer quits: session `t097b` `send {"key":"Escape"}` at the title;
    6 s later `state` reports alive at scene Menu (`t_ms=29327`, frame 1710).
  - Q still quits: same session `send {"key":"Q"}` → `pilot.py list` shows
    `t097b live no` (last state frozen at `t_ms=40481`); the godot log ends
    clean — a graceful quit, not a crash.
  - Q quit hint: title screenshot at
    `.captures/t097_title_q_hint.png` (raw session kept at
    `.captures/session_t097b/`) — the footer reads "eat bread to survive ·
    splat tourists (100) and cars (30) · don't starve · Q quit" and is legible
    at a glance.
