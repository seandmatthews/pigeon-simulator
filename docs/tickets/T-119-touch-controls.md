# T-119 — Thumbs on the city: a virtual joystick and touch buttons for the phone

- **Milestone:** Mobile (owner-directed 2026-10-14; M3 candidate) · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
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

- [ ] `touch_controls.tscn`/`.gd` exist per convention; hidden on desktop; no
      new input actions; no keyboard-path changes
- [ ] *(Gate 1b)* new scenario(s): a synthetic screen-drag on the joystick
      yaws/pitches the pigeon through the same action axes the player polls;
      stick-at-rest reads exactly 0 on all four actions (the trim arm survives);
      the flap/poop buttons fire the real actions (a drop actually falls); the
      pause button pauses through the real PauseMenu; overlapping contacts
      steer + flap at once. Full existing suite green untouched.
- [ ] *(Gate 2)* autoplay green (touch layer inert on the desktop path)
- [ ] HUD + touch layer respect the safe area; desktop layout byte-unchanged
      (default-window HUD reads intact)
- [ ] controls tables updated in README.md and VERIFICATION.md
- [ ] *(Gate 3)* **on the iPhone:** she starts a run from the hosted build, flies
      a loop, eats bread, lands, poops on a tourist, and pauses — her judgement
      on stick comfort and button reach recorded in VERIFICATION.md (tuning
      follow-ups ticketed, not smuggled in)
