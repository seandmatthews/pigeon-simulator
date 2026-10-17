# T-125 — Ditch the Godot boot splash

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-18) · **Status:** done 2026-10-17 · **Category:** visual-design · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** owner 2026-10-17: *"get rid of the default godot logos and
  stuff."* No `application/boot_splash` section exists in `project.godot`, so
  the stock Godot logo splash shows on desktop AND on the web build's load.
  `icon.svg` is already a custom pigeon. The MIT license requires no logo —
  a credit line in `assets/CREDITS.md` is plenty.

## What

Set `application/boot_splash` in `project.godot`: background = the menu's
navy (`Color(0.16, 0.22, 0.33)` — the title screen's own Background color,
so the splash dissolves into the menu seamlessly), `show_image=false`.
**Choice recorded: plain color (option a)** — the icon-art upgrade can ride
a later pass if the owner wants it. Keep `config/icon` as-is.

Out of scope: the web export's loading shell (template HTML) — a branded
loading page is its own follow-up if the owner wants it.

**Route note:** presentation-only → direct-loop eligible.

## Acceptance criteria

- [x] *(Gate 1b)* a scenario pins the boot_splash project settings
      (background color, show_image) so a silent revert fails —
      `boot_splash_pinned` (reads the menu's navy live off the scene so the
      two can never drift)
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true` — the desktop
      launch itself runs the new splash)
- [ ] *(Gate 2)* desktop + web builds launched: no Godot logo — screenshot
      recorded here *(desktop covered by the autoplay launch; the WEB
      screenshot needs a re-export + the hosted URL — rides the owner's next
      deploy)*
- [ ] *(Gate 3)* owner confirms the boot reads as Pigeon Simulator
      *(PENDING owner pass — the machine legs are green.)*
