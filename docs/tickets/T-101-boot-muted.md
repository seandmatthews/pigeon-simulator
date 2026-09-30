# T-101 — Boot muted: the game starts silent unless a sound-design session opts in

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-012 (the audio buses this mutes, landed)
- **Refs:** owner request (2026-09-30): "the GAME STARTS MUTED unless we are actively working on
  sound design" · the pilot-fleet precedent (`tests/tools/pilot.py` already defaults its sessions
  to muted via `PIGEON_MUTE=1`, consumed in `tests/capture_recorder.gd`)

## What

Invert the audio default for every launch path — normal double-click, `F5` editor run, CLI — so
the game boots with the Master bus muted, and only an explicit sound-design opt-in unmutes.
`scripts/game.gd` (the Game autoload, present in every scene):

- A `boot_muted(user_args: PackedStringArray) -> bool` policy method, applied once in `_ready`:
  `AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), boot_muted(OS.get_cmdline_user_args()))`.
- The contract, in priority order: `PIGEON_MUTE=1` (pilot fleet sessions) always mutes;
  `PIGEON_SOUND=1` or a `--sound` user arg (after `--` on the CLI, or the editor's Main Run Args)
  opts in; anything else mutes.
- `tests/tools/pilot.py --sound` additionally sets `PIGEON_SOUND=1`, so the pilot's existing
  sound-on path keeps working through the new default (its `PIGEON_MUTE=""` alone no longer
  unmutes — the opt-in flag does).

What this does NOT claim: no new input action or in-game mute toggle (no controls-table change);
no per-bus volume work; the sim harness's logical sound checks (`played_counts`, `playing`,
loop flags) are mute-insensitive by construction and stay untouched.

## Why

Agents and fleet runs launch the game constantly; today only pilot sessions are muted, so a
normal launch or editor playtest blasts audio unprompted. The owner wants silence as the
default with sound design as the deliberate exception. Muting the Master bus leaves the whole
mix graph (SFX/Ambience, trims, positional attenuation) untouched — one bit flips, and every
existing machine check stays valid because they assert logical playback, not audible output.

## Acceptance criteria

- [x] The game boots muted: through the real autoload path, Master reports muted at first
      (Gate 1b: `audio_boots_muted`, asserted in the harness process whose own `Game._ready`
      ran under no opt-in)
- [x] The opt-in contract holds (Gate 1b: same scenario, env-switched truth table):
      `PIGEON_SOUND=1` opts in; the pilot's `PIGEON_MUTE=1` wins over `--sound`;
      the `--sound` user arg opts in; no opt-in stays muted
- [x] `pilot.py --sound` sessions are still audible (the env flag lands in the same change-set)
- [x] The full Gate 1b suite stays green — no audio scenario depends on Master being unmuted
- [ ] [screenshot/ear] Gate 3: a normal launch is silent; `godot --path . -- --sound` plays
      the ambience bed and flap whooshes as before

## Verification

Gate 1 (`--import` + 120-frame boot) + Gate 1b full suite with the new `audio_boots_muted`
scenario (row added to the Gate 1b table in the same change-set) + Gate 2 (autoplay runs with
`--audio-driver Dummy`; its DONE-line sfx counts are logical and mute-insensitive) + Gate 3
(the ear check above; README and VERIFICATION gain the opt-in flag documentation).

**Pending human playtest (Gate 3):** a normal launch is silent; a `--sound` launch sounds
exactly like pre-T-101 (nothing else in the mix changed).

**Recorded (2026-09-30):** Gate 1 clean (0 script/parse errors on import; 120-frame boot
silent); Gate 1b `SIM SUMMARY: 0 failure(s)` — 82 scenarios including the new
`audio_boots_muted` (muted_at_boot=true, all four truth-table legs true); Gate 2
`AUTOPLAY DONE ok=true restart=true` with logical sfx counts intact (flap:18, splat:10,
ambience=true) under `--audio-driver Dummy`.
