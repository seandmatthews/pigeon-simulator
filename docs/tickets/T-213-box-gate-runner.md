# T-213 — Box gate runner · the machine gates run on the Ubuntu box

- **Status:** doing · **Category:** dev-tooling · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-211 (the POSIX pilot port + the box's gate recipes) ·
  T-212 (the testing deploy target)
- **Refs:** T-170 (the hidden-launch contract this makes moot) · T-014
  (pilot harness) · the deploy leg stays Windows-side until its own ticket

## Why

Windows gate runs steal input even when their windows are off-screen: the
T-170 sub-second activation blip rides every pilot session, and the Gate 2
autoplay opens a real window for its whole ~103 s mission — both land in the
owner's games mid-play. The box has nothing to steal (`focuscheck`
self-skips there; a server has no desktop), so the machine gates move there
wholesale. Owner directive 2026-11-17: "I just want to offload all the
testing to this box" — and the box's checkout layout follows what gets
deployed: `main` at `~/pigeon-simulator` (the prod deploy source), the
integration branch in a worktree (the testing deploy source).

## What

1. **Hardware-GL display (landed 2026-11-17, box-side):**
   `pigeon-xorg.service` — a real `Xorg :98` on the HD 530 at vt8 with
   `-novtswitch` (a background VT: the two real downstairs monitors keep
   their foreground, and GL rendering + viewport-texture screenshots don't
   care about scanout). Autoplay went fps=1 (llvmpipe ≈ 1 hr/run) →
   **fps=56 ≈ 2 min/run**, `DONE ok=true` proven same day.
2. **Box checkout layout** — `~/pigeon-simulator` tracks `origin/main`; a
   git worktree `~/pigeon-simulator-testing` carries the integration branch
   (`ames/campaign` while the Ames campaign rides it, `develop` after the
   T-210 cutover) for gate runs and the testing deploy. The per-machine
   `addons/godot_mcp` copy joins the worktree.
3. **`tools/gate-box.sh <ref>`** — the box-side runner: fetch a pushed ref
   from origin, stage a disposable worktree under `~/gate-runs/`, run
   Gate 1 + Gate 1b headless and Gate 2 on `:98`, print one
   machine-greppable PASS/FAIL line per gate, exit non-zero on any failure.
   `nice`d so Caddy and the web roots stay snappy.
4. **Pipeline + sweep repoint** — the saved workflow defs' machine-gate legs
   (baseline, pre-merge, post-merge integration gates) call the runner over
   ssh against the pushed branch ref instead of launching Windows Godot.
   Reviewer play sessions stay on Windows this ticket (hidden pilot
   sessions — the visible window was autoplay; the sub-second blip remains
   until its own move).
5. **VERIFICATION.md** — the Linux gate box section documents the display
   service, the runner, and the checkout layout; the box Gate 2 recipe
   becomes the `:98` hardware-GL command (xvfb-run stays as the fallback).

## Acceptance criteria

- [ ] `~/pigeon-simulator` is at origin/main;
      `~/pigeon-simulator-testing` is at the pushed integration tip with
      warmed imports and the addon copy.
- [ ] `gate-box.sh ames/campaign` runs all three gates green on the box
      against the campaign tip (the prove-out recorded in this ticket).
- [ ] A runner failure (bad ref, red gate) exits non-zero with the failing
      gate named on stdout.
- [ ] The saved pipeline + sweep defs' machine-gate legs invoke the box
      runner over ssh; a gate leg spawns no Windows Godot window.
- [ ] VERIFICATION.md's Linux gate box section matches the landed reality.

## Verification

The tree change-set is docs + a bash tool (no GDScript touched), so the
Windows gates re-run as normal sanity (Gate 1b green before commit). The
box prove-out run IS the runner's verification; the saved-def repoint is
proven by the next pipeline/sweep execution's gate legs (recorded here
when one next runs).
