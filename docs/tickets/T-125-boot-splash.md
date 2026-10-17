# T-125 — Ditch the Godot boot splash

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-18) · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** owner 2026-10-17: *"get rid of the default godot logos and
  stuff."* No `application/boot_splash` section exists in `project.godot`, so
  the stock Godot logo splash shows on desktop AND on the web build's load.
  `icon.svg` is already a custom pigeon. The MIT license requires no logo —
  a credit line in `assets/CREDITS.md` is plenty.

## What

Set `application/boot_splash` in `project.godot`: background = the menu's
sunny sky color, `show_image=false`. Acceptable upgrade in the same change:
use the `icon.svg` pigeon art as the splash image on the same sky color —
pick one and record the choice here. Keep `config/icon` as-is.

Out of scope: the web export's loading shell (template HTML) — a branded
loading page is its own follow-up if the owner wants it.

**Route note:** presentation-only → direct-loop eligible.

## Acceptance criteria

- [ ] *(Gate 1b)* a scenario pins the boot_splash project settings
      (background color, show_image) so a silent revert fails
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 2)* desktop + web builds launched: no Godot logo — screenshot
      recorded here
- [ ] *(Gate 3)* owner confirms the boot reads as Pigeon Simulator
