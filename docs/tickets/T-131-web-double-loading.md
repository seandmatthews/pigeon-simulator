# T-131 — One warming screen: the web handoff lets the shell's loader do the talking

- **Milestone:** Web boot follow-up (friend report 2026-10-20) · **Status:** done (Gate 3 pending) · **Category:** platform · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** — (T-129 landed; this fixes its web handoff's double feedback)
- **Refs:** a friend's hosted-web report to the owner, 2026-10-20 — "2
  identical loading screens happening in close proximity to each other, maybe
  just on the web"; code-read confirmed it before any fix;
  `scripts/menu.gd` (`_start_run`, `%WarmupNote`), `tools/web-shell/index.html`
  (`#loader-sub`), T-129's two-sided `pigeonReady`/`pigeonLoading` contract.

## What

T-129's two-sided loader contract works, but on the web the Fly press paints
**the same loading screen twice in a row**:

1. `_start_run` first shows the title's own `%WarmupNote` — navy
   `Color(0.16, 0.22, 0.33)` = `#293854`, gold text, reading exactly
   `"warming up the city…"` — and yields one frame so it paints.
2. One frame later the web branch calls `window.pigeonLoading()`, which brings
   the export shell's loader back — **same navy `#293854`**, **same gold**,
   **the byte-identical words** (`#loader-sub`) — fading in over the note
   (the CSS `transition: opacity 0.8s` applies to the fade-in too, so for
   ~0.8 s both texts are visible at once before the loader covers the title).

The result the friend saw: the message appears mid-screen, then the branded
loader fades in with the same words and the text visually duplicates — on a
fast connection, right after the page-load loader, reading as two identical
loading screens back-to-back. Desktop is unaffected: there is no shell, and
the one-frame note is the whole feedback.

**The fix:** the web branch of the handoff skips the note and the paint frame
— the shell's loader IS the visible answer to the Fly press there
(`pigeonLoading()` is a synchronous JS call, and Godot 4's
`change_scene_to_file` defers the actual swap to the end of the frame, so the
await bought nothing on the web path). Desktop keeps the note + one-frame
paint exactly as T-129 landed it. The branch decision routes through the
T-126 `Game.is_web()` seam (as `_ready`'s footer strip already does) behind a
tiny `_web_loader_covers_handoff()` so the harness can pin both branches.

## Acceptance criteria

- [x] `scripts/menu.gd`: the web handoff (`_web_loader_covers_handoff()` true)
      calls `pigeonLoading()` and changes scene WITHOUT showing
      `%WarmupNote` and without the paint-frame await; the desktop branch is
      byte-as-T-129 (note + one frame).
- [x] *(Gate 1b)* `web_handoff_single_screen` pins the seam both ways through
      `Game.web_override` (forced-web covers the handoff; desktop does not)
      and pins `%WarmupNote` present and hidden at rest on BOTH branches.
      `_start_run` itself is never driven headless — it ends in
      `change_scene_to_file` and would swap the harness's own scene (the
      T-097 never-feed-flap rule) — so the on-screen single-screen judgement
      is deliberately the Gate 3 line below.
- [x] *(Gate 2)* autoplay green.
- [ ] *(Gate 3)* owner on the hosted build: the Fly press shows exactly ONE
      "warming up the city" screen — the branded loader alone, no title-note
      flash before it, no two navy screens back-to-back — while a desktop run
      keeps its one-frame note (rides the next hosted deploy, same pass as
      T-129's pending line).

**Tuned values:** none — presentation routing only, no constants move.

## Verification

- Gate 1: `--import` and `--quit-after 120` both exit 0 — the only ERROR line
  is the accepted godot_mcp headless-teardown one ("33 resources still in
  use"). `--check-only` on `menu.gd` fails with "Identifier not found: Game"
  — proven pre-existing (HEAD's untouched `main.gd` and `menu.gd` fail
  identically: the bare check registers no autoloads); the real compile proof
  is the 120-frame boot, which loads `menu.gd` as the main scene, clean.
- Gate 1b: full suite **144 PASS / 0 FAIL**, exit 0. New scenario
  `web_handoff_single_screen` (registered right after `stepped_boot_pins`;
  VERIFICATION.md table row added) pins the seam both ways and the note's
  at-rest state. Red-before probe: with the seam temporarily re-pointed to
  the old `OS.has_feature("web")` gate (the exact revert shape) the scenario
  FAILs naming the leg — `web: covers=false (want true)` — and the suite
  exits 1. (The pre-fix TREE could not run the scenario at all — the old
  code consulted no seam; the defect's original red-before is the hosted
  report itself, per the What above.)
- Gate 2: `AUTOPLAY DONE ok=true restart=true` (fps 135, poses all six,
  splats 8, ambience true), no SCRIPT ERROR.
- Gate 3: the owner's hosted pass (pending — needs the re-deploy; same pass
  as T-129's open line, so one deploy closes both).

**Route note:** presentation-only (which screen answers the Fly press) — no
feel, no physics, no re-derived bars — so per the T-116 precedent this lands
direct-loop. Forge skipped: the defect and the fix were dictated by the
code-read, one file.
