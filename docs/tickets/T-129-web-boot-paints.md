# T-129 — Web boot paints instead of stalling: sliced city boot + a loading screen that waits for warm

- **Milestone:** M3 wave 2 (owner-directed, web performance) · **Status:** done · **Category:** platform · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-128 (touches the same spawner boot path — runs after it merges)
- **Refs:** owner report 2026-10-18, desktop Edge AND Firefox behave the same
  (kills the browser-warm-up theory — this is our code): the Fly button
  darkens instantly, then ~2 s of dead air, then the world appears with the
  camera crawling into position and input unreliable for ~10 s. Grounded
  mechanism: `main.gd:642` runs `city.generate()` synchronously in Main's
  setup and every spawner populates in `_ready` (`band_spawner.gd:44`) — all
  BEFORE the first frame of the new scene can paint; the ~2 s dead air is that
  burst, and the ~10 s slideshow tail is first-draw pipeline/shader
  compilation (Compatibility/WebGL compiles each material variant on first
  use, spread across the city's first visible seconds) compounded by physics
  catch-up (a stalled frame owes up to `max_physics_steps_per_frame` ticks).
  The "camera slowly shifts" tell: the chase camera's exponential follow runs
  per-frame, so at single-digit fps it takes visible seconds to converge.
  Single-threaded web build per T-118; boot splash navy per T-125.

## What

Three legs, one goal — the busy work happens where the player is already
entertained:

1. **Paint between boot phases (the real win).** Main's boot becomes a
   stepped sequence the engine can render between: after the Fly press the
   menu hands off with immediate feedback ("warming up the city" beat in the
   title's own navy), then the world comes up in slices — ground/slabs →
   buildings → visuals → spawners in batches (cars first, then tourists,
   bread, elders) → first flight frame. Every phase prints an ms-per-phase
   trace line (desktop AND web builds), recorded in this ticket — the
   numbers decide which further knobs are worth turning. The sim harness
   keeps a synchronous path: an export flag (default ON in game, OFF for
   instanced-Main rigs) so every existing scenario boots byte-as-today; a
   new Gate 1b scenario pins the stepped path itself (steps callable in
   order, trace emits, flag default).
2. **The cheat, done properly: the loading screen waits for warm.** A custom
   web export shell keeps the branded loader visible (navy, pigeon mark, a
   rotating tone-safe tip line — "the black-and-gold pay favor" · "bread,
   quick") until Godot signals readiness via `JavaScriptBridge` AFTER the
   first warm frames — then it fades out over the live game. The slideshow
   happens behind the loader instead of in the player's face. The loader
   re-check rides the owner's next hosted deploy (T-126 pattern).
3. **Web-only warm-up diet (gated on the trace numbers).** Feature-tagged
   web overrides as experiments, each kept only if its trace delta proves
   it: smaller (or off) directional shadow, MSAA off, and a web override of
   `max_physics_steps_per_frame` to stop catch-up compounding a stall into
   a slideshow. No desktop setting moves.

**Route note:** pipeline — boot timing + spawner staging are bar-derivation
territory, and T-128 will have just re-derived the same scenarios.

## Acceptance criteria

- [x] *(Gate 1b)* a scenario pins the stepped boot: the phase sequence is
      explicit and ordered, the trace emits per-phase ms, the sync flag
      defaults keep every existing scenario green untouched
- [x] *(Gate 1b)* full suite green (sync boot path for rigs)
- [x] *(Gate 2)* autoplay green
- [x] *(Gate 2)* web export builds; the loader holds until the readiness
      signal and the ms-per-phase trace is readable in the browser console —
      numbers recorded here
- [ ] *(Gate 3)* owner on the hosted build: the Fly press answers instantly,
      the loader covers the warm-up, and the world fades in already playable —
      recorded here

## Landed — implementation record (2026-10-18; reviewer sign-off 2026-10-18 — the ticket is done. The four machine/browser acceptance criteria are ticked on the recorded evidence; the Gate 3 owner pass ON THE HOSTED BUILD is the one criterion that stays open — the evidence recorded here cannot prove it, and it rides the owner's next hosted deploy per the T-126 pattern, tracked as the open [ ] line in this ticket and in VERIFICATION.md's Gate 3 list)

**Design as built.** `City.generate()` is now the plain composition of three
public slices — `generate_step_ground` (reset, meshes, ground, skyline, roads,
rim, crossings) → `generate_step_blocks` (the block loop + cafe spots) →
`generate_step_finish` (visuals, spawn point, fingerprint, report,
`regenerated`) — with the internal order untouched, so sync and stepped builds
are byte-identical (the scenario proves fingerprint, bread spots, report and
spawn point equal). `main.tscn` carries the scene-level holds: `City.hold_generate`
and `staged_boot` on all five spawners; each spawner's new public `populate()`
wires `regenerated` idempotently, so restarts re-seed exactly as always.
`Main._ready` keeps its byte-as-today wiring and then branches: the **rig
tell** is `get_parent() == get_tree().root` — `change_scene_to_file` mounts the
game scene directly under the root, every instanced-Main rig (sim harness
scenarios, the autoplay pilot) parents its Main to its own driver node — so
`stepped_boot` (export, default ON) bites only the game path and every existing
scenario boots the synchronous `_boot_sync()` untouched (ZERO existing
scenarios edited; the new `stepped_boot_pins` scenario is appended). The
stepped path runs ground → blocks → visuals → cars → tourists → bread → elders
→ cafes with one `await process_frame` between phases (cars first: their
populate anchors the tailgate crumbs the bread batch's survivor pass must find
— the T-114 load-bearing order), prints `BOOT phase=<name> ms=<n>` per phase
plus a `BOOT phase=total` line (desktop AND web), records `Main.boot_trace`,
freezes the pigeon (`PROCESS_MODE_DISABLED`) until the world stands under it,
and emits `boot_finished`. The menu's Fly handoff shows the hidden
"warming up the city…" label (title navy) for one painted frame before
`change_scene_to_file`.

**The loader (leg 2).** The preset's `html/custom_html_shell` now points at
`tools/web-shell/index.html`: boot-splash navy, a gold inline-SVG pigeon mark,
the wordmark, "warming up the city…" and a rotating tip line ("bread, quick" ·
"the black-and-gold pay favor" · "the elders remember a polite pigeon" · "mind
the edge of town" · "same city every run — race your best"). The shell drives a
TWO-SIDED contract over `JavaScriptBridge`: `window.pigeonReady()` fades the
loader out (the menu calls it after the title's first warm frames; Main calls
it again at `boot_finished`, fading over the live world) and
`window.pigeonLoading()` brings it back on the Fly handoff. The overlay is
never removed (opacity + pointer-events toggle), so a fast cache can never
race a removal. The loader re-check rides the owner's next hosted deploy (the
T-126 pattern).

**The web diet (leg 3).** Feature-tagged experiments behind
`Game.is_web()` AND the stepped boot, in `Main._apply_web_diet`:
directional shadow atlas 4096 → 2048, MSAA off (project default is 4×),
`Engine.max_physics_steps_per_frame` 8 → 3 (at a sustained ≥ 20 fps game time
is undilated: 3 × 20 = 60). No desktop setting moves (the scenario pins the
desktop branch reads back unchanged). The applied values print as
`BOOT web_diet: …` and record in `Main.web_diet_applied` (this engine build
exposes the atlas setter only).

**Trace numbers (recorded per the ticket's decision rule).**

Desktop, headless, `--fixed-fps 60` (CPU-side only — headless renders nothing):
the rig sync burst measures 19–40 ms in ONE frame; the stepped boot measures
per phase `city_ground 2–5 · city_blocks 8–10 · city_visuals 1–2 ·
spawn_cars 5 · spawn_tourists 2–3 · spawn_bread 0–1 · spawn_elders 0–1 ·
spawn_cafes 3–4`, total 51–59 ms across 8 phases (three runs, Gate 1b suite
log). The slice itself is cheap; the win on desktop is spreading it across
frames, and on web it is the render-side first-draw cost the desktop numbers
cannot see.

Web, release export in a real browser (Compatibility, WebGL 2.0; automation
browser with a software rasterizer — directional evidence, the owner's hosted
pass is the judgement): with the stepped boot driven by a Fly press,
`BOOT web_diet: shadow_atlas=2048 msaa=off max_physics_steps=3`, then
`city_ground 7 · city_blocks 11 · city_visuals 4 · spawn_cars 10 ·
spawn_tourists 4 · spawn_bread 1 · spawn_elders 1 · spawn_cafes 5`, total
557 ms for 8 phases (phase sums 43 ms; the total rides the paint frames' wall
time, inflated by the software raster and an automation-pane stall). All lines
read directly from the browser console.

**Diet verdict.** Headless desktop cannot isolate web render deltas, so per
the ticket's own rule the three overrides stay feature-tagged experiments: the
trace lines (and the hosted re-check's numbers) decide whether any knob moves
again. Nothing here is claimed proven by a web delta.

**Browser evidence (release export, 2026-10-18).** The branded loader renders
and rotates tips (screenshots), holds past engine start (the stock shell
removes itself the moment `startGame` resolves — the old in-the-player's-face
window), then fades over the live title via the menu's readiness signal — the
fade photographed mid-transition over the title screen, and the
`loader-up → clicking-fly → loader-faded` transitions recorded by a
MutationObserver. A Fly-started run boots with the web diet applied and the
full per-phase trace in the console, ending with the loader hidden
(`pigeon-ready`) over the LIVE rendered world (HUD up, city visible,
screenshot). The `pigeonLoading` re-show on Fly is wired (menu.gd) and its two
endpoint behaviors are proven (fades in both directions); the intermediate
re-shown window was not caught by the observer because the automation browser
pane stalls rendering (rAF pause) unpredictably — exactly the re-check the
owner's hosted deploy will judge.

**Gates run on the final code (this checkout).** Gate 1: `--import` and the
120-frame boot exit 0 with no project ERROR lines (the documented benign
godot_mcp teardown line only). Gate 1b: full suite — **142 scenarios,
0 failures, exit 0** (`stepped_boot_pins` appended; every pre-existing
scenario green untouched on the sync rig path). Gate 2:
`AUTOPLAY DONE ok=true … restart=true`, fps 132, no SCRIPT ERROR lines, exit 0
(the autoplay rig correctly takes the sync boot). Web export: exit 0, the four
artifacts present, `grep -c SharedArrayBuffer index.wasm` = 0, nothreads
markers present, the `$GODOT_*` placeholders fully substituted and both
`pigeonReady`/`pigeonLoading` hooks in the served page.
