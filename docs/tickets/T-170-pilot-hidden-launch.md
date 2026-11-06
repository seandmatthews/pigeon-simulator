# T-170 — Pilot sessions never steal the desktop: hidden-from-focus launch by default, a `--shown` opt-out

- **Status:** proposed · **Category:** code-optimization ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-014 (the pilot harness this modifies; the T-167/T-168
  dev-verb family is untouched)
- **Refs:** `tests/tools/pilot.py:192-202` (`cmd_start` — the cascade
  position and the plain `subprocess.Popen`, no `startupinfo=` argument),
  `pilot.py:153-156` (`cascade_pos` — 40,40 + 48·n, on-screen by design),
  `pilot.py:53` (`CREATE_NO_WINDOW` — the only process-creation flag set
  today) · `tests/capture_recorder.gd:96-121` (`_start_session` — where
  the per-session env knobs are consumed and the hide leg lands),
  `capture_recorder.gd:152-158` (the re-title loop — the window handle
  the OS checks must find) · `tests/tools/window-shot.ps1:26-31,45,62`
  (PrintWindow `PW_RENDERFULLCONTENT` — captures without focus; its
  `SetForegroundWindow` at line 45 becomes a harmless no-op on a
  no-activate window — measured) · `project.godot:30-31` (the 1280×720
  default window the hide math sizes from) · engine 4.7.2-stable sources
  (the shipped binary's tag, fetched 2026-11-06): `platform/windows/
  console_wrapper_windows.cpp` (the wrapper's `STARTUPINFOW` carries only
  `STARTF_USESTDHANDLES` — no `GetStartupInfoW`, so a launcher's
  show-state cannot cross the wrapper), `platform/windows/
  display_server_windows.cpp` (`show_window`: the no-focus branch is
  `ShowWindow(SW_SHOWNA)` with **no** `SetForegroundWindow`/`SetFocus`;
  `window_set_flag(WINDOW_FLAG_NO_FOCUS)` → `wd.no_focus` +
  `WS_EX_NOACTIVATE` via `_update_window_style`; `window_set_position` =
  raw `MoveWindow`, no clamp; `window_move_to_foreground` skips
  no-focus windows), `main/main.cpp:3459` (`show_window(MAIN_WINDOW_ID)`
  in `Main::setup2` — before autoloads register at `main.cpp:4501-4572`
  in `Main::start`), `main/main.cpp:1496` (`--position` parse) and
  `display_server_windows.cpp` `_create_window` (an off-screen rect is
  CLAMPED back into the primary screen's usable rect) · owner complaint
  2026-11-06, verbatim: game windows keep popping up and taking window
  priority while he is working or playing games — it is "so distracting"

## What

Every pipeline gate and reviewer session boots one or more pilot windows
(T-162's reviewer ran 8); each one lands on-screen at the cascade corner
and can take the foreground. This ticket makes the pilot launch
hidden-from-focus **by default**, with `--shown` restoring today's
visible behavior for human eyes-on sessions.

**Probes on the landed tree (2026-11-06, recorded here as the red-before
baseline — both sessions booted via `pilot.py`, muted, then stopped):**

- Default launch, session `t170a`: the window's `GetWindowRect` reads
  **(32, 9, 1328, 768)** — the 40,40 cascade request becomes a window
  square across the primary desktop's top-left (frame offsets and
  engine-side adjustment); `GetForegroundWindow` kept returning the
  owner's app across 12 s of samples — in this background-launch context
  the boot-time activation attempt was **denied** by Windows, so today's
  guaranteed harm is the window appearing over the owner's work, with
  the foreground steal a context-dependent extra (a launch from the
  owner's own foreground terminal can succeed).
- `--pos=-1600,-900` (fully off-screen request), session `t170b`: the
  resulting rect is **(−8, −31, 1288, 728)** — ~86 % ON-screen. The
  engine clamps an off-screen creation rect back into the primary
  screen's usable rect (`_create_window`: `get_screen_from_rect < 0 →
  get_primary_screen()`, then `wpos.clamp(srect.position, …)`). **So an
  off-screen `--position` cannot work, and this ticket deliberately does
  not use one** — the off-screen placement happens post-boot through the
  unclamped `DisplayServer.window_set_position` (raw `MoveWindow`,
  verified against the 4.7.2 source) instead.
- Same `t170b` window (unfocused its whole life): `shot` via
  `window-shot.ps1` wrote a complete 1296×759 PNG of the title screen
  (PrintWindow `PW_RENDERFULLCONTENT` needs no focus), the in-process
  frame PNG stream counted 31 frames, and a `{"action":"flap","frames":7}`
  queued through the channel landed as `pilot_press` — none of the
  capture/drive machinery needs a focused or visible window.

The change, three parts:

1. **`pilot.py` launch default (`cmd_start`)** — unless `--shown` is
   passed: (a) build a `subprocess.STARTUPINFO`, set
   `STARTF_USESHOWWINDOW` with `wShowWindow = SW_SHOWNOACTIVATE (4)`,
   pass it as `startupinfo=` — the belt-and-suspenders leg the ask
   prescribes ("apps honoring the show state get it"); stated plainly,
   grounded in the fetched 4.7.2 wrapper source: the console wrapper's
   own `CreateProcessW` STARTUPINFO carries only `STARTF_USESTDHANDLES`
   (no `GetStartupInfoW`), and Godot never uses `SW_SHOWDEFAULT`, so
   this leg is **not load-bearing** — it costs four lines and matches
   the intent, nothing more; (b) set `PIGEON_WINDOW_HIDDEN=1` in the
   child env (the `PIGEON_MUTE`/`PIGEON_NO_PERSIST` pattern,
   `pilot.py:185-190`) — this is the lever the recorder acts on;
   (c) `--shown` skips both and reproduces today's path byte-for-byte
   (visible cascade window, focusable, no new env). Explicit `--pos`
   keeps reaching the engine, but with the default launch the window
   ends off-screen regardless — staging a *visible* window at a specific
   spot is `--shown --pos X,Y` (also note argparse needs the
   `--pos=X,Y` form for negative coordinates).
2. **`CaptureRecorder._start_session()` (session mode only)** — when
   `PIGEON_WINDOW_HIDDEN == "1"` and `DisplayServer.get_name() !=
   "headless"`, right where the mute/env knobs are consumed:
   (a) `DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,
   true, DisplayServer.MAIN_WINDOW_ID)` — the style update applies
   `WS_EX_NOACTIVATE` and every later `show_window`/
   `window_move_to_foreground` path takes the SW_SHOWNA/no-activate
   branch (source-verified); (b)
   `DisplayServer.window_set_position(hide_pos, MAIN_WINDOW_ID)` with
   `hide_pos` from a small pure helper
   `CaptureRecorder._hide_position(screen_positions: Array[Vector2i],
   window_size: Vector2i) -> Vector2i`: `min-corner over all screens
   minus window size minus 80 px` — for this desktop (screens at (0,0)
   and (2560,0), 1280×720 client) that is **(−1360, −800)**, fully
   outside every monitor with huge margin (measured frame slop on this
   machine: ≤ 8 px x, ≤ 31 px y); the 80 px margin absorbs it;
   (c) `_log_event("pilot_window_hidden", {pos, no_focus: true, size})`
   — the machine-checkable ack, the T-095/T-167 "new mechanics get a
   pilot event" precedent. Headless and legacy flag-file modes are
   untouched (the guard skips both). Timing, stated honestly: the window
   is shown by the engine in `Main::setup2` before autoloads run
   (`main.cpp:3459` vs `main.cpp:4501`), so a sub-second blip at the
   cascade corner before the hide is unavoidable, and the boot-instant
   `SetForegroundWindow` happens before any game code can flag the
   window no-activate — measured denied in background launches (the
   agent-batch context this ticket targets); the flag then kills every
   later activation (clicks, taskbar, `window_move_to_foreground`).
3. **`pilot.py focuscheck` (new subcommand — the tooling scenario)** —
   self-contained: boots two short sessions itself (muted, menu scene),
   checks, stops both, prints measurements and `FOCUSCHECK PASS`/`FAIL`,
   exit 0/1 (non-Windows: prints SKIP, exit 0). Hidden leg (default
   launch): (a) the hwnd titled `Pigeon pilot <id>` is found;
   (b) `GetWindowRect` intersects NO monitor rect (EnumDisplayMonitors)
   with ≥ 32 px margin; (c) `GetForegroundWindow() != pilot hwnd` at 3
   samples ≥ 1 s apart after the claim settles; (d) `pilot_window_hidden`
   is in `events.jsonl` with `no_focus: true`; (e) `shot` writes a
   non-empty PNG and the frame-PNG count grows — the render pipeline is
   alive off-screen; (f) one `{"action":"flap","frames":7}` lands as
   `pilot_press` — input flows without focus. Shown leg (`--shown`): the
   rect DOES intersect the desktop and no `pilot_window_hidden` ack
   appears — today's behavior restored. Ownership rules apply as
   everywhere (`start` refuses a live id — pick fresh ids per run).

**Docs in the same change-set:** AGENTS.md's pilot section gains the
default-hidden + `--shown` lines (the T-167 discoverability pattern);
VERIFICATION.md gains the `pilot_window_hide_math` Gate 1b row and a
line describing `focuscheck` in the pilot tooling section. No controls
table changes (README.md untouched).

**No reference photos:** OS launch mechanics with no real-world visual
counterpart — no research phase ran, no image opened; the criteria are
derived from the repo's own code and the probes recorded above.

**Not claimed:** no change to Gate 2 autoplay's own direct `godot` boot
(it still shows a window for ~40 s — a later adopter could route it
through the same recorder leg, since autoplay runs session-mode-able
env, but that is out of scope here); no focus *restoration* of a
displaced owner window (if a foreground-context launch wins the boot
instant, the recorder cannot demote it — engine ordering fact above;
that context is `--shown` territory in practice); no minimize-based
hiding (DWM stops rendering minimized windows — PrintWindow and the
swapchain would degrade; rejected); no change to window size, the
`Pigeon pilot <id>` title, `--time-scale`, the dev-verb family, legacy
flag-file mode, or the godot-mcp editor-bridge path; no fighting of a
later explicit position set by game code (none exists today); no new
in-game UI.

## Why

The owner runs agent batches and review sessions while working or
playing; every pilot boot pops a window over his desktop at the cascade
corner and may fight him for the foreground — his 2026-11-06 verbatim
complaint mid-batch. The pilot's own contract already says sessions
should never wreck the owner's environment (muted by default, high-score
persistence off — T-014); the desktop itself is the one part of that
contract still missing. The fix is one env var, one window flag, one
`window_set_position`, and a checker — and because the in-process frame
stream, PrintWindow capture and channel input are all placement- and
focus-insensitive (measured in the probes above), an agent loses
nothing: every pipeline gate, reviewer session and screenshot workflow
keeps working with windows the owner never sees.

## Acceptance criteria

- [ ] `pilot.py start` defaults to the hidden launch: `STARTUPINFO`
      (STARTF_USESHOWWINDOW / SW_SHOWNOACTIVATE) + `PIGEON_WINDOW_HIDDEN=1`
      unless `--shown`; `--shown` reproduces today's path exactly (no
      startupinfo, no env, visible cascade window)
- [ ] CaptureRecorder session mode sets `WINDOW_FLAG_NO_FOCUS`, moves the
      window to `_hide_position`'s result and acks `pilot_window_hidden`
      with the resolved pos; headless and legacy modes skip the leg via
      the guard (no event, no error)
- [ ] *(Gate 1b)* new `pilot_window_hide_math` scenario (registered in
      the `sim_test.gd` `_run_scenarios` block, the T-167 neighbors)
      pins the PURE helper against three monitor layouts — this
      machine's (0,0)+(2560,0), a negative-left-monitor layout
      (−1920,0)+(0,0), and a single screen — each returned position's
      window rect outside the union of the given rects with ≥ 80 px
      margin; the full suite stays 0 failures:
      `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
      (no NEW OS-level Gate 1b scenario is added — the headless
      DisplayServer has no window and `GetForegroundWindow` is not
      reachable from a sim; the OS-level proof is `focuscheck` below,
      and the suite's existing pilot self-checks — `pilot_time_scale_flag`,
      `pilot_frame_step`, `dev_hunger_lock`, `dev_verb_pack`,
      `audio_boots_muted` — must all re-run green over the recorder
      change)
- [ ] *(tooling scenario)* `pilot.py focuscheck` passes on Windows with
      the six hidden-leg assertions and the two shown-leg assertions
      listed in What, both sessions stopped cleanly, exit 0 — the run's
      measured values (rect, foreground samples, frame counts) recorded
      in this ticket at landing
- [ ] *(Gate 1)* `godot --headless --path . --import` and the 120-frame
      boot exit clean, zero ERROR lines
- [ ] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`) —
      the direct-boot path is untouched by the pilot/recorder change
- [ ] Landing re-probe recorded here: `shot` + the frame PNG stream
      re-proven from a FULLY off-screen window (today's probe ran on the
      clamped mostly-on-screen window; the off-screen capture behavior is
      the one datum not yet measured)
- [ ] AGENTS.md pilot section + VERIFICATION.md (Gate 1b row +
      focuscheck line) updated in the same change-set
- [ ] *(Gate 3, human)* an agent batch of ≥ 4 concurrent/serial sessions
      (the T-162 reviewer pattern) runs while the owner works or plays a
      game: he sees no game windows appear and loses no foreground — his
      complaint's own bar, his sign-off; and a `--shown` session still
      visibly boots, takes keyboard focus and plays normally for eyes-on
      sessions

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with
`pilot_window_hide_math` registered and its row added to the Gate 1b
table · Gate 2 autoplay · **the tooling scenario**: `python
tests/tools/pilot.py focuscheck` (Windows-only; boots, checks, stops,
exit-code gated — the ask's named verification, kept light per the
T-167 tooling pattern) · Gate 3: the owner's batch-while-working pass
plus a `--shown` sanity run, recorded in this ticket when they pass.

**Pending human playtest (Gate 3):** the batch-while-working session
above, and one `--shown` eyes-on session confirming nothing about human
play changed.
