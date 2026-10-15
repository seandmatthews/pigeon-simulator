# T-119 — Thumbs on the city: a virtual joystick and touch buttons for the phone

- **Milestone:** Mobile (owner-directed 2026-10-14; M3 candidate) · **Status:** done · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-118 (the Safari build — its device pass is the target hardware)
- **Refs:** owner decision 2026-10-14 (virtual joystick + buttons, chosen over tilt and drag-anywhere); `scripts/player.gd` polling sites (:366 flap, :414 poop, :441/:459 steering axes, :494 the `< 0.01` trim arm); `tests/capture_recorder.gd:219-227` (action-press vs event-flow facts); `scripts/pause_menu.gd:45`

## What

T-118 puts the game on her phone; this ticket makes it *playable* there. A
left-thumb analog joystick steers, the right thumb gets big **Flap** and **Poop**
buttons plus a small **Pause**. New scene + script per convention:
`scenes/touch_controls.tscn` + `scripts/touch_controls.gd` (a CanvasLayer that
main.tscn hosts beside the HUD).

**Zero new InputMap actions.** The joystick feeds the four existing steering
actions with analog strength (`Input.action_press("turn_left"/"turn_right"/
"pitch_up"/"pitch_down", strength)`, released to 0 at rest) — the player already
polls exactly those axes (`player.gd:441/:459`), so the flight model never learns
touch exists. Flap/Poop are `TouchScreenButton`s bound to the existing `flap`/
`poop` actions, which the polled `_flap`/`_try_poop` see directly. The keyboard
path is untouched, and Gate 1b's action-level injection is untouched. No addons —
built-in controls only (AGENTS.md).

**Traps this ticket must respect (each one is a known way this goes wrong):**

- **Pause cannot be a TouchScreenButton.** `Input.action_press` feeds polling
  code only — it never reaches `_unhandled_input`, which is where
  `pause_menu.gd` consumes the action (the same fact `capture_recorder.gd`
  documents for key-vs-action injection). The pause button is an ordinary
  `Button` wired to `PauseMenu.toggle()`.
- **Stick at rest must read exactly 0 on the axes.** The hands-off trim arm keys
  on `absf(pitch_input) < 0.01` (`player.gd:494`); a stick that leaks strength
  would silently disable hands-off trim. Release = `action_release` all four
  actions, deadzone handled inside the stick.
- **Action deadzones are 0.5** (`project.godot`) and polled strength is
  deadzone-remapped, so gentle stick deflections can read zero. Decide
  deliberately — scale output past the deadzone vs. a touch-specific lower
  deadzone — and record the choice in Tuned values.
- **Menus need nothing:** Fly/Again/Menu/Pause buttons are real `Button`s and
  taps drive them (touch→mouse emulation is on by default).

**Visibility & verification:** the layer shows only when touch is real
(`DisplayServer.is_touchscreen_available()`); desktop stays keyboard-first. For
desktop work: a force-show debug flag plus
`input_devices/pointing/emulate_touch_from_mouse`, and the sim drives the stick
with synthetic `InputEventScreenTouch`/`InputEventScreenDrag`.

**Safe area:** the HUD and the touch layer respect
`DisplayServer.get_display_safe_area()` so nothing sits under the notch or home
indicator in landscape; on desktop the safe area is the whole window — no
change. Multi-touch is an acceptance criterion: steer and flap simultaneously
(`TouchScreenButton` supports it natively; the sim asserts it with overlapping
synthetic contacts).

**Docs:** the controls tables in README.md and VERIFICATION.md gain a touch row
(no new actions — the row documents where the buttons live). The title screen's
keycap line stays byte-identical on desktop (pinned by
`title_screen_teaches_controls`); a touch-device variant of that line is
optional.

**Route note:** input-feel adjacent — goes through pigeon-ticket-pipeline per
the routing rule. Feel tuning AFTER she plays (stick sensitivity, button sizes)
is a likely follow-up and goes through the pipeline too.

## Acceptance criteria

- [x] `touch_controls.tscn`/`.gd` exist per convention; hidden on desktop; no
      new input actions; no keyboard-path changes
- [x] *(Gate 1b)* new scenario(s): a synthetic screen-drag on the joystick
      yaws/pitches the pigeon through the same action axes the player polls;
      stick-at-rest reads exactly 0 on all four actions (the trim arm survives);
      the flap/poop buttons fire the real actions (a drop actually falls); the
      pause button pauses through the real PauseMenu; overlapping contacts
      steer + flap at once. Full existing suite green untouched.
- [x] *(Gate 2)* autoplay green (touch layer inert on the desktop path)
- [x] HUD + touch layer respect the safe area; desktop layout byte-unchanged
      (default-window HUD reads intact) — the desktop arm is machine-proven
      (`touch_layer_desktop_inert`: zero safe-area offsets, HUD reads intact,
      fade un-expanded); the notched-device half rides the Gate 3 line below,
      covered by the reviewer sign-off (2026-10-15)
- [x] controls tables updated in README.md and VERIFICATION.md
- [ ] *(Gate 3)* **on the iPhone:** she starts a run from the hosted build, flies
      a loop, eats bread, lands, poops on a tourist, and pauses — her judgement
      on stick comfort and button reach recorded in VERIFICATION.md (tuning
      follow-ups ticketed, not smuggled in) — stays OPEN by design (the T-118
      precedent: a done ticket with its device-pass line pending until her
      hands-on run; no such evidence exists yet, and none may be invented).
      Reviewer sign-off on this ticket: 2026-10-15.

## Landed (2026-10-15)

- `scenes/touch_controls.tscn` + `scripts/touch_controls.gd` — a `CanvasLayer`
  (layer 5: above the HUD, under the pause/game-over overlays) hosted in
  `main.tscn` beside the HUD. Left thumb: an analog stick (base ring + knob,
  drawn as script-generated circles — no baked vertex lists in the scene).
  Right thumb: `TouchScreenButton`s bound to the existing `flap`/`poop`
  actions with circle shapes (multitouch native). A small ordinary `Button`
  labelled Pause emits `pause_requested`; the sub-scene wires the button,
  `main.tscn` wires the signal to `PauseMenu.toggle()` — an action press
  would never reach the menu's `_unhandled_input` (the same fact
  `capture_recorder.gd` documents), so a TouchScreenButton pause was never an
  option. Zero new InputMap actions; `project.godot`, `player.gd`, `menu.gd`
  untouched.
- Visibility: `DisplayServer.is_touchscreen_available()`, OR the `force_show`
  export, OR `PIGEON_TOUCH=1` (which also sets
  `Input.emulate_touch_from_mouse` so a real mouse drives the layer — the
  desktop try-it recipe, in the README/VERIFICATION controls tables). Hidden
  = fully inert: no GUI routing, no TouchScreenButton input.
- Safe area: `touch_controls.gd` exposes `canvas_safe_rect()` (window pixels
  → canvas via the viewport's final transform; an empty display-server answer
  means "whole canvas", so desktop/headless get zero insets by construction).
  The touch layer lays its widgets out against the safe rect; a new
  `scripts/hud.gd` (attached to the HUD CanvasLayer) shifts the whole HUD by
  the top-left inset and expands the one full-rect child (`%ReturnFade`) back
  over the insets so the T-087 fade still covers the window. Desktop: all
  insets zero → byte-identical (pinned by `touch_layer_desktop_inert`).
- The title screen's keycap line is untouched (the optional touch variant is
  deliberately NOT taken — `title_screen_teaches_controls` keeps pinning the
  desktop line byte-identical).

## Probed facts this lands on (headless, 2026-10-15; throwaway probes, not committed)

1. **`Input.action_press(a, s)` strength bypasses the InputMap deadzone** —
   probed 0.2 → 0.2, 0.49 → 0.49, 1.0 → 1.0, release → exactly 0.0. The
   0.5 deadzone in `project.godot` governs the *event* path only (the remap
   the trap warned about is real for `InputEvent`-driven strengths, e.g. real
   joypads — not for the API-press call this ticket mandates). What the stick
   feeds IS what `Input.get_axis` hands the player.
2. **The stub headless window is 64×64 and the GUI drops contacts outside
   it** — so the sim's touch block sizes the window to the desktop default
   1280×720 first (and restores it; every other scenario keeps today's exact
   conditions). On a sized window, `Input.parse_input_event` +
   `flush_buffered_events` routes GUI touches to Controls and
   `TouchScreenButton` actions headless.
3. **A synthetic screen touch does NOT emulate mouse headless** — the
   pause-button scenario drives the synthetic *mouse click* a tap produces
   on-device through the default `emulate_mouse_from_touch` (true in
   `project.godot` and on iOS Safari). Windowed, the same synthetic tap does
   click the button (probed both).

## Tuned values

| Value | Choice | Why |
| ----- | ------ | ----- |
| Output scaling past the deadzone | **rescale** — deflection past the touch deadzone maps linearly onto the full 0..1 strength band (the "scale output past the deadzone" option) | A thumb has far less travel than a key's full press; without rescaling the usable band would sit half-dead. With probed fact 1, the fed value reads 1:1 at the player. |
| `stick_touch_deadzone` | 0.18 of `stick_radius` | Comfortably above the trim arm's `< 0.01` key and finger jitter; handled INSIDE the stick (below it the axis pair is *released*, never pressed small — rest reads exactly 0.0). |
| `stick_radius` | 62 px (canvas units) | Full strength at 62 px of drag; base ring r 72, knob r 26 (a 52 px control). |
| `edge_margin` | 28 px | Every widget's distance from its safe-area edge. |
| Button radius | 52 px each (`button_gap` 18) | Big for a thumb; POOP sits up-left of FLAP. |
| Pause button | 104×44 px, top-right | Small + out of the right thumb's rest arc (a bottom-right Pause begs mid-flight fat-fingers). |
| CanvasLayer `layer` | 5 | Above the HUD (1), under PauseMenu (10) and GameOverScreen (20) — when a menu is up it owns the screen; its own buttons are the touch surface. |

## Verification

- Gate 1b: six new scenarios (see the VERIFICATION.md table) — all green; the
  full suite runs 133 PASS / 0 FAIL on the landed tree.
- Gate 2: `AUTOPLAY DONE ok=true restart=true` (fps 136), touch layer inert on
  the desktop path.
- Desktop preview (PIGEON_TOUCH=1) flown via the pilot harness, sessions
  `t119touch`/`t119touch2` in `.captures/` — layer renders: stick bottom-left,
  FLAP/POOP bottom-right, Pause top-right, HUD untouched. (Visual fix between
  the sessions: the ring/knob Polygon2D nodes needed centering on their
  parents — cosmetic only, gates re-run green after.)
- Still open: the Gate 3 iPhone line (needs the hosted build and her thumbs) —
  the ticket is DONE on the reviewer sign-off of 2026-10-15 with that line
  pending, the same shape as T-118; her judgement lands in VERIFICATION.md's
  Gate 3 line when it happens, and any feel retunes go through new tickets.
