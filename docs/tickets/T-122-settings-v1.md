# T-122 — Settings v1: invert pitch + volume on the pause menu

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-10; carries B-3's invert-pitch ask) · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** owner in 2026-10-17 (*"I feel like we will probably need one
  eventually"*). The pause menu already exists — `PauseMenu` in `main.tscn`
  (`scripts/pause_menu.gd`, restart/menu/quit signal pattern); title screen
  `scripts/menu.gd`; pitch is read via `Input.get_axis("pitch_down",
  "pitch_up")` at `scripts/player.gd:302/459/564`; buses in
  `default_bus_layout.tres` (SFX −2 dB, Ambience −10 dB); the boot-muted
  policy (`scripts/game.gd:60-70`) stays; T-119's touch joystick feeds the
  same actions.

## What

One **Settings** entry on the pause menu and one on the title screen, opening
a small panel — nothing else until something demands it:

1. **Invert pitch** — a persisted toggle that flips the sign of the pitch
   axis. Implement as ONE helper (e.g. `Game.pitch_axis()`) used by all
   three call sites, so keyboard and the T-119 touch joystick invert
   together. With the toggle off, the code path must be identical to today —
   no feel-math changes ride along.
2. **Volume** — Master / SFX / Ambience sliders plus a mute toggle, applied
   to the existing buses.
3. **Persistence** — `user://settings.cfg`, loaded at boot before Main reads
   anything. Settings only ever opt IN to changes on top of the boot-muted
   default (the T-101 policy stays).

**Route note:** direct-loop eligible — with invert off the flight path is
byte-identical and no sim bar moves. Any excursion into actual feel math
beyond the sign helper re-routes to the pipeline (2026-10-13 rule).

## Acceptance criteria

- [ ] *(Gate 1b)* scenario: boot with a pre-seeded `user://settings.cfg`
      (invert on) → pitch input drives the nose inverted; the config
      round-trips (save → load → same values) and volumes land on the buses
      at boot
- [ ] *(Gate 1b)* default path untouched: with no config file, every
      existing scenario passes unmodified (invert off = today's controls
      exactly)
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 3)* owner toggles invert and volume, plays a run, confirms the
      feel flipped the way they asked and the setting survives a restart —
      recorded here
