# T-211 — Linux gate box · the pilot harness runs on POSIX

- **Status:** done (box Gate 3 landed same day; the autoplay DONE-pass
  still running on the box's slow llvmpipe wall-clock) · **Category:**
  dev-tooling · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** nothing (pure tooling)
- **Refs:** T-014 (pilot harness) · T-167..T-169 (dev verbs) · T-170
  (hidden launch — the Windows contract this box makes moot)

## What

The NixOS games box died; its replacement (a Dell OptiPlex) runs
**Ubuntu Server** and takes over BOTH web hosting and testing. This
ticket is the testing half: the pilot harness's four Windows-only seams
gain POSIX paths so every gate and agent session can run on the box,
and VERIFICATION.md gains the box recipe.

1. **`godot_alive` on POSIX** — the real defect: `pid_info`'s non-Windows
   branch returns image name `"?"`, so the image-name check in
   `godot_alive` can never pass and every session reads dead. POSIX
   reads `/proc/<pid>/comm` (the same liveness-by-name contract as the
   Windows kernel32 path, pid-reuse absorb included).
2. **`shot` on POSIX** — xdotool (find the window by title, same
   pattern contract as window-shot.ps1) + ImageMagick `import` (the
   pixels). Windows keeps PowerShell/PrintWindow untouched.
3. **`stop`/`stop_force` on POSIX** — no taskkill; POSIX kills via
   `os.kill`, and `stop_session`'s fallback routes through
   `stop_force` instead of calling taskkill directly.
4. **Launch flags** — `--gl` (forces the GL compatibility renderer;
   the desktop default is forward_plus/Vulkan and software Vulkan is
   the fragile path under llvmpipe) and `--headless` (no window at
   all — the CI door; the session-mode recorder already works
   headless, proven by the dev_call_verb Gate 1b scenario). POSIX
   launches without `--sound` also pass `--audio-driver Dummy`
   automatically (a server has no audio device).

`focuscheck` stays Windows-only by design (it self-skips today); the
whole T-170 hide dance is unnecessary on a server with no desktop to
steal.

## Why

The owner's complaint driving this: even the T-170 hidden launch
briefly touches the desktop (the boot blip, the taskbar button) and
disrupts whatever game he's playing. Windows cannot do better — proven
twice. A headless server has nothing to fight: sessions run under Xvfb
(or fully headless), and the entire focus-defect class disappears. The
same recipe also runs unchanged on GitHub Actions ubuntu runners if CI
gates ever come.

## Acceptance criteria

- [x] `pilot.py list/state/events` report TRUE liveness on POSIX (the
      `/proc` fix — a live session reads yes, a dead one no)
- [x] graceful `stop` and `--force` kill work on POSIX (no taskkill)
- [x] `--gl` and `--headless` flags land on `start` (and `--headless`
      sessions boot, claim, take input, and quit cleanly)
- [x] POSIX non-sound launches pass `--audio-driver Dummy`
- [x] Windows behavior byte-unchanged: PowerShell shot, taskkill,
      focuscheck legs (CLI smoke + identical Gate 1b output)
- [x] VERIFICATION.md carries the Ubuntu-box recipe (one-time setup +
      per-gate commands)
- [x] **Verified on POSIX**: a real headless session smoke (WSL2 Ubuntu
      stands in for the box) — start → claim → liveness yes → input →
      run reaches Main → graceful stop; PLUS bonus fix: a reused id's
      stale `started.json` poisoned the next boot's claim-wait (the
      run-2 lesson) — boot now sweeps it like the T-018 command sweep
- [ ] **Gate 3 (box)**: an Xvfb-rendered session with a `shot`, then
      the full Gate 1/1b/2 on the box itself — **laned 2026-11-13 on
      sean@192.168.1.247 (the Ubuntu Server OptiPlex)**: Gate 1 boot
      clean + Gate 1b **0 failures** (density_cpu_budget median
      **120.8 ms** vs 750 — 6× headroom on the i7-6700); the rendered
      session + `shot` proven through the CLI (`--shown` session; the
      title screen AND a mid-flight Ames frame pulled back and
      eyeballed — llvmpipe handles the world: streets, fleet cars with
      blinkers lit, HUD, the reticle). The box run FORCED two follow-up
      fixes (13dd6bd): the `shot` backend is `xwd -id | convert` (the
      box's IM 7.1.2 `import -window <id|name>` grabs only root) and
      sessions needing `shot` run `--shown` (X11 X_GetImage cannot read
      a window outside the root — the T-170 hide position is
      ungrabbable; under Xvfb `--shown` disturbs nothing). Gate 2
      autoplay left RUNNING on the box (llvmpipe ≈ 0.04× wall — its
      ~180 game-s done condition needs ~80 wall-min; hunger holding
      ~80, it eats) — when `/tmp/autoplay.log` shows `AUTOPLAY DONE
      ok=true`, tick this box. The hosting half of the box move landed
      the same day (main 26c50bd): see the deploy-verify SIGPIPE fix +
      the compose-caddy facts in [[web-hosting-cloudflare-plan]].

## Verification (landed 2026-11-13)

- py_compile; Windows CLI smoke (`list`, `start --help`) — no desktop
  sessions were launched on the owner's machine
- **POSIX lifecycle (WSL2 Ubuntu 22.04, python 3.10, Godot
  4.7.2-stable Linux):** start → claim → `list` live=yes (pid 207781)
  → Space starts a run → flap → `scene: Main` with the Ames fleet
  live (26 moving cars, hunger 98.35 ticking) → `grounded` event →
  `stop` = `pilot_quit`, "stopped (graceful)", live=no. `stop
  --force` = SIGTERM kill path, "stopped (killed)". `clean` swept 9
  dead sessions.
- **Gate 1b on POSIX: 0 failures** — first Linux run of the suite;
  `density_cpu_budget` median 121.1 ms per 100 physics frames vs the
  750 budget (6× headroom; WSL on the dev machine's CPU — the box
  re-derives per the recipe's watch-item)
- **Gate 1b on Windows (same tree): 0 failures**, exit noise
  identical to POSIX (16-instance ObjectDB leak warning both sides —
  baseline, not a Linux regression)
- WSL2 DrvFs notes (not box-relevant, recorded for the next person):
  another process's writes to an OPEN file (state.jsonl, godot.log)
  are invisible through the 9P cache until the writer closes — read
  state/events AFTER stop there; and a WSLg window moved fully
  off-screen can be killed by the RAIL compositor.
