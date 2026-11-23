# T-219 — Players hear the game: exports boot audible, runs from source stay silent

- **Status:** done · **Category:** ui-ux · **Ring:** R6 (owner pick) ·
  **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-101 (the boot-mute policy this re-scopes), T-122 (the settings
  file whose mute key moves)
- **Refs:** owner rule 2026-11-23 — "Players should hear the game, but I don't want
  to hear it when you're testing it. If that's not clear, add something to the docs
  such that it is clear." · the 2026-11-23 adversarial review (the shipped game is
  silent and the title screen says nothing about it)

## What

Re-scope T-101's boot audio default from "everybody muted" to the owner's actual
rule, in `scripts/game.gd`:

- **An exported game boots AUDIBLE.** The export is the only thing a player ever
  runs, and the one thing agents never launch.
- **A run from source boots SILENT.** `OS.has_feature("editor")` — a compile-time
  fact of the editor binary — is true for every editor/F5 session, every direct
  `godot --path .`, every pilot session, gate and probe an agent launches. The
  engine tells the two apart; no launch path has to remember a flag.
- The opt-ins keep their order and meaning: `PIGEON_MUTE=1` always mutes;
  `PIGEON_SOUND=1` or `--sound` (after `--` on the CLI, or the editor's Main Run
  Args) opts a source run in — the OWNER's sound-design session.
- The settings file's stored mute moves from `audio/muted` to `audio/mute`. The
  old key stored the T-101 boot DEFAULT (`true`), not a decision; read today it
  would pin every player who ever opened Settings to silence. No key = the boot
  policy stands; an explicit mute saved today survives a reload.
- `Game.source_run_override` (-1 ask the engine; 0/1 force) is the test seam —
  the T-126 `web_override` pattern — so the sim scenarios pin both branches from
  inside the editor binary they run under.

## Why

T-101 was an agent-hygiene request ("the GAME STARTS MUTED unless we are
actively working on sound design") that landed as a player-facing default: a
player at the hosted URL got a silent game, and DESIGN.md's pillar 2 reads "A
silent city is a failed city." The rule was never about players. The engine
already knows which kind of process it is in, so each of the owner's two clauses
is one line, and the agent half holds by construction on every launch path —
including the editor bridge, whose play sessions inherit the editor's Main Run
Args.

## Acceptance criteria

- [x] An exported game boots audible: with the seam forced to "export" and no
      opt-in flags, `boot_muted()` answers false and the real
      `apply_audio_settings()` leaves Master open (Gate 1b:
      `audio_players_hear_the_game`)
- [x] A run from source boots silent: the real autoload path muted Master in the
      harness process (an editor binary, no opt-in) — the T-101 row, re-described
      (Gate 1b: `audio_boots_muted`)
- [x] The opt-in order holds on BOTH branches: `PIGEON_MUTE=1` wins over
      everything, `PIGEON_SOUND=1` and `--sound` opt in (Gate 1b: both scenarios)
- [x] The seam's unforced read equals the engine's own
      (`is_source_run() == OS.has_feature("editor")`) and is true under the
      harness (Gate 1b: `audio_players_hear_the_game`)
- [x] The stored mute is the player's own choice under `audio/mute`: a
      pre-T-219 file's `muted = true` does NOT mute an export boot, an explicit
      mute saved today survives `load_settings()`, and `save_settings()` writes
      no `muted` key (Gate 1b: `audio_mute_setting_key`; the T-122 round-trip
      row re-pinned to the new key)
- [x] The docs state the rule where an agent reads first: AGENTS.md (a dedicated
      sound-rule section), README (Sound), DESIGN.md (the decisions table),
      VERIFICATION.md (rows + the playtest note)
- [x] Full Gate 1b green
- [ ] [ear] Gate 3: the hosted web build plays the ambience bed from the first
      run and the flap whooshes in flight; a source launch without `--sound`
      stays silent *(owner)*

## Verification

Gate 1 (`--import` + 120-frame boot) + Gate 1b with the two new scenarios and
the re-pinned T-101/T-122 rows + Gate 2 (autoplay runs from source, so it is
silent by construction; its DONE-line sfx counts are logical and mute-insensitive)
+ Gate 3 (the ear check above — the one leg a machine cannot hear).

## Run record (2026-11-23, direct loop — the owner dictated the rule)

- **Gate 1:** `--import` rc 0, the 120-frame boot rc 0, no `ERROR:` /
  `SCRIPT ERROR:` line past the benign exit-cleanup filter.
- **Gate 1b:** **169 PASS / 0 FAIL**, exit 0, 227 s. New:
  `audio_players_hear_the_game` (export_audible, export_bus_open, source_silent,
  source_bus_muted, both opt-ins, seam_agrees, harness_is_source — all true) and
  `audio_mute_setting_key` (legacy_ignored, explicit_kept, key_moved,
  export_still_audible, source_still_silent — all true). Re-pinned:
  `audio_boots_muted`, `settings_persist_and_invert`.
- **Red-before (the new checks can fail):** with the old default put back for
  one run — `boot_muted` returning true for an export, `load_settings` reading
  the `muted` key again — exactly those two scenarios fail, **167 PASS / 2
  FAIL**, exit 1: `audio_players_hear_the_game: export_audible=false …
  export_bus_open=false` and `audio_mute_setting_key: legacy_ignored=false …
  export_still_audible=false`. `scripts/game.gd` was restored from a saved copy
  and its SHA-256 confirmed identical before Gate 1 ran on it.
- **Gate 2:** not re-run — no gameplay code moves, and autoplay runs from source
  (silent by construction).
- **Gate 3 (ear):** open for the owner — the hosted build only gets this with
  the next deploy.
