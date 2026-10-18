# T-127 — Xbox controller: sticks and pads drive the existing actions

- **Milestone:** M3 wave 2 (owner picks, from IDEAS.md B-17) · **Status:** done · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** owner ask 2026-10-17 (*"xbox controller support?"*); Godot treats Xbox
  pads as the generic joypad standard; the shipped action set is EXACTLY
  eleven (`flap`/`poop`/`pitch_up`/`pitch_down`/`turn_left`/`turn_right`/`boost`/`pause`/`restart`/`to_menu`/`quit` —
  the `touch_layer_desktop_inert` pin, so this ticket adds NO new actions,
  only joypad events on existing ones); pitch/turn are read via
  `Input.get_axis` (`player.gd:302/459/564`) — a stick feeds ANALOG strength
  where the keyboard gives ±1.0; T-119's touch joystick feeds the same
  actions; iOS Safari exposes the Gamepad API (16.4+) — a paired controller
  may outrank the touch stick on the hosted build (verify opportunistically);
  the settings panel (T-122) is the natural home for a deadzone/invert
  follow-up — not this ticket.

## What

Add joypad events to the EXISTING `project.godot` actions per the IDEAS.md
mapping, and make the menus pad-navigable:

| Input | Action |
| ----- | ------ |
| Left stick | pitch (Y) + turn (X) — analog, 1:1 with WASD |
| A (bottom face) | flap — and menu confirm / title-screen start |
| RT | poop (X as alternate) |
| Start / Menu | pause (B = back/ui_cancel where sensible) |
| D-pad | menu focus traversal |

1. **Deadzones** — the stick-driven actions (`pitch_up/down`, `turn_left/right`)
   drop from Godot's default 0.5 to ~0.25 so gentle stick deflections read.
   Button actions keep the default.
2. **Menus** — the pause menu and title screen take focus from the stick/dpad:
   pad-start on the title (A/Start = the Fly button), pause-menu traversal
   (Godot Control focus; `grab_focus` is already wired).
3. **Analog is a feature, not a bug** — half-deflection genuinely trims
   pitch/turn rates in live play; the sim stays action-injected at full
   strength, so no sim bar moves. The FEEL is the owner's Gate 3.
4. **No rumble in v1** — noted as a follow-up if the owner wants it.
5. **Controls tables** — README + VERIFICATION gain a controller column/rows
   in the same change (house rule).

**Route note:** pipeline — input-path feel (the 2026-10-13 rule), and the
reviewer-plays leg needs an actual pad or a documented stand-in.

## Acceptance criteria

- [x] *(Gate 1b)* `gamepad_actions_bound`: every gameplay action carries the
      mapping's joypad events (read live from the InputMap — device type and
      axis/button indices pinned), the four stick actions sit at deadzone
      0.25, and the action set still reads EXACTLY the shipped eleven (the
      T-119 no-new-actions pin holds); a synthetic `InputEventJoypadMotion`
      through `Input.parse_input_event` drives the real pitch axis
      (SIM PASS 2026-10-18 — the scenario also pins that `restart`/`to_menu`/
      `quit`/`boost` carry NO joypad events, that `ui_accept`/`ui_cancel` carry
      A/B beside their re-declared engine-default keys, that dpad+stick focus
      traversal rides the engine-default `ui_up`/`ui_down`, and that the REAL
      PauseMenu opens on Start, resumes on A, traverses on the dpad and backs
      out on B)
- [x] *(Gate 1b)* full suite green untouched — keyboard and touch paths
      byte-unchanged (140/140 SIM PASS, exit 0, 2026-10-18; no keyboard event
      byte changed — the four stick actions only lost deadzone 0.5 → 0.25 and
      every action only gained joypad events; `touch_controls.gd` and the
      player's input reads untouched, all six T-119 scenarios still green)
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true t=33.0 … restart=true
      ambience=true`, exit 0, 2026-10-18)
- [x] *(Gate 3)* owner plays a run ON THE CONTROLLER: steering feels right,
      menus navigate, no double-fires — recorded here. iPhone-Safari pad
      check rides the next hosted deploy if the hardware is at hand
      (ACCEPTED — reviewer sign-off 2026-10-18. The machine stand-in named in
      the route note is `gamepad_actions_bound`, which drives the real
      pipeline with synthetic joypad events and proves open/resume/traverse/
      back on the real PauseMenu; the FEEL arms — analog trim at half
      deflection, stick up = W non-inverted (the touch stick's own
      convention), no double-fires from A being both `flap` and `ui_accept`
      (the Space precedent) — passed on the pad at sign-off. The iPhone-Safari
      pad check remains conditional on hardware at the next hosted deploy.
      No rumble in v1, per the What block.)

## Landed (2026-10-18)

Mapping as proposed, no vetoes: left stick X = `turn_left/right`, left stick
Y = `pitch_up/down` (stick up = W — the same non-inverted convention the
T-119 touch stick ships), stick four at deadzone 0.25; **A** (b0) on `flap`,
**RT** (axis 5) + **X** (b2) on `poop`, **Start** (b6) on `pause`,
**B** (b1) on `ui_cancel` with a close-when-open branch in `pause_menu.gd`
(keyboard Esc never reaches it — it is consumed by the `pause` branch);
`ui_accept` gains A so the focused button (Fly / Resume / Again) takes the
pad. Title: A confirms the focused Fly button; pad Start starts a run via a
joypad-gated branch in `menu.gd` (keyboard Esc stays inert — T-097). Title
copy teaches the pad family (`title_screen_teaches_controls` extended).
Boost / R / M / Q stay keyboard-side — the mapping assigns them nothing and
`gamepad_actions_bound` pins that absence. Known engine default (probed,
Godot 4.7.2): stock `ui_accept`/`ui_cancel` carry NO joypad events — the
project re-declares both builtins with their measured key lists plus the pad
buttons; the eleven-action pin is unaffected (`ui_*` excluded by design).

