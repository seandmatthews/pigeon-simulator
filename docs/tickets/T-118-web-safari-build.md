# T-118 — A web build Safari can run: Compatibility web override, single-threaded export, Cloudflare Pages

- **Milestone:** Mobile (owner-directed 2026-10-14; M3 candidate) · **Status:** proposed · **Category:** platform · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** —
- **Refs:** owner decision 2026-10-14 (web in Safari · Cloudflare Pages · platform-first split); [Godot docs — Exporting for the Web](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html); [Godot 4.3 progress report — Web export](https://godotengine.org/article/progress-report-web-export-in-4-3); watch-item [godot#107390](https://github.com/godotengine/godot/issues/107390) (iOS web audio crash reports on some 4.5 dev builds)

## What

The owner wants the game playable on his girlfriend's iPhone. Native iOS is ruled
out: Godot's iOS export produces an Xcode project, and signing/installing it
requires macOS plus an Apple developer account — this Windows PC cannot get there.
The chosen path is a **web build she opens in Safari**, which Godot has supported
on iOS since 4.3 via *single-threaded* exports; we are on 4.7.2.

The change-set:

1. **Per-platform renderer override** — `rendering/renderer/rendering_method.web`
   = `gl_compatibility` in `project.godot`. The web platform supports ONLY the
   Compatibility renderer (Forward+/Mobile are not available there). No
   `.desktop` value is added: the desktop game keeps the current default
   (forward_plus) and looks identical. The web build's visual parity should be
   near-exact — the scene carries no glow/SSAO/SDFGI/volumetrics anywhere
   (`scenes/main.tscn`), and Compatibility supports the pieces we do use:
   ProceduralSky ambient, ACES tonemap, directional shadows, MSAA 4×. Gate 3
   confirms it by eye.
2. **Stretch mode** — `display/window/stretch/mode` = `canvas_items`,
   `display/window/stretch/aspect` = `expand`. Today the HUD is fixed-pixel
   offsets against a bare 1280×720 canvas with no stretch (all `main.tscn`
   HUD nodes); a phone viewport needs the canvas to scale. At the desktop's
   default 1280×720 window the stretch is a no-op, so every Gate 1b HUD read
   stays valid.
3. **`export_presets.cfg`** (new file, committed) — a Web preset with
   **Variant → Thread Support OFF**. This is the load-bearing switch:
   single-threaded builds avoid the SharedArrayBuffer requirement that breaks
   iOS Safari, and as a bonus need no COOP/COEP hosting headers. Extension
   support off.
4. **Export command documented** (into VERIFICATION.md in the same change-set):
   `~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html`
   — `build/` is already gitignored.
5. **Hosting on the owner's Cloudflare Pages** (owner-run step: free account,
   direct upload or `wrangler pages deploy build/web`). Pages serves `.wasm`
   with the right MIME type. **Only build artifacts are published** — the
   compiled game and assets, never the source repo.

**Watch-items:** the two autoloads must stay inert in a web build
(`MCPRuntimeProbe` no-ops outside debug sessions per AGENTS.md; `CaptureRecorder`
is pilot-arg-gated) — the browser console in the Gate 3 pass confirms. Audio
needs a user gesture to unlock on iOS — the title screen's Fly button *is* the
gesture (`menu.gd`), and the game boots muted anyway (T-101). If the device pass
shows judder, the first knobs are a `.web` MSAA override
(`msaa_3d.web = 0`) and a web render-scale — record whichever is used.

**Non-goals:** no touch controls here — after this ticket a phone can load the
game and start a run via the Fly button but cannot steer. That is the point:
this ticket is the go/no-go de-risk (renderer, performance, hosting) before
control work is invested. Route note: platform/presentation only, no physics or
bar re-derivations — direct loop is acceptable per the routing rule; T-119 (the
controls) goes through the pipeline.

## Acceptance criteria

- [ ] `project.godot` gains exactly the `.web` renderer override and the two
      stretch settings; no `.desktop` rendering value; keyboard/desktop behavior
      unchanged
- [ ] *(Gate 1b)* full sim suite green unchanged — no scenario edits (desktop
      runs forward_plus at the default window, where the stretch is a no-op)
- [ ] *(Gate 1)* headless web export documented in VERIFICATION.md and exits 0,
      producing `index.html` + `.wasm` in `build/web/`; `export_presets.cfg`
      committed with thread support off
- [ ] *(Gate 2)* autoplay green on the desktop tree
- [ ] *(Gate 3)* desktop browser: the hosted URL loads, the title screen renders,
      a run starts and flies with the keyboard, and the city reads right under
      Compatibility (sky, shadows, edges) — recorded in VERIFICATION.md
- [ ] *(Gate 3)* **iPhone go/no-go:** over the owner's hosting, the page loads in
      Safari, the title renders, the Fly button starts a run, the world renders
      at an acceptable framerate for a few minutes, no crash/reload, autoloads
      silent — the pass that unlocks T-119
- [ ] *(optional)* Progressive Web App manifest + icon so Add-to-Home-Screen
      gives her a fullscreen app icon
