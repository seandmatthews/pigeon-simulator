# T-127 — Xbox controller: sticks and pads drive the existing actions

- **Milestone:** M3 wave 2 (owner picks, from IDEAS.md B-17) · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
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

- [ ] *(Gate 1b)* `gamepad_actions_bound`: every gameplay action carries the
      mapping's joypad events (read live from the InputMap — device type and
      axis/button indices pinned), the four stick actions sit at deadzone
      0.25, and the action set still reads EXACTLY the shipped eleven (the
      T-119 no-new-actions pin holds); a synthetic `InputEventJoypadMotion`
      through `Input.parse_input_event` drives the real pitch axis
- [ ] *(Gate 1b)* full suite green untouched — keyboard and touch paths
      byte-unchanged
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 3)* owner plays a run ON THE CONTROLLER: steering feels right,
      menus navigate, no double-fires — recorded here. iPhone-Safari pad
      check rides the next hosted deploy if the hardware is at hand
