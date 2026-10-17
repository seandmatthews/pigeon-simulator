# T-126 — Hide Quit on the web (a browser tab can't close itself)

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-19) · **Status:** proposed · **Category:** platform · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** — (T-118 landed; this is a hosted-build defect report)
- **Refs:** owner 2026-10-17, playing the hosted build: *"on the web the quit
  button doesn't do very much."* Three quit paths all funnel into
  `get_tree().quit()` — the pause menu Q key + button
  (`scripts/pause_menu.gd:38,74` → `scripts/main.gd:655`) and the title
  screen Q (`scripts/menu.gd:24-25`, hint text included). Web pages cannot
  close their own tab, so all three are silent no-ops on the web build.

## What

Gate every quit affordance behind `OS.has_feature("web")`:

1. Route the check through ONE testable seam (e.g. `Game.is_web()`) so Gate
   1b can pin both branches.
2. On web: no Quit button in the pause menu, the `quit` action is ignored,
   and the title screen drops the "Q quits" hint.
3. Desktop: everything exactly as today.
4. Do NOT attempt `JavaScriptBridge` `window.close()` — browsers only honor
   it for script-opened windows; unreliable by design.

Annotate Q as **desktop only** in the controls tables in `README.md` and
`VERIFICATION.md` in the same change (house rule).

**Route note:** direct-loop eligible.

## Acceptance criteria

- [ ] *(Gate 1b)* with the web seam forced on: no visible quit control in
      the pause menu, the quit action ignored, no Q hint on the title; with
      it off (default desktop): existing scenarios green untouched
- [ ] *(Gate 1b)* controls tables updated — Q marked desktop-only
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 3)* owner on the hosted build: no dead button anywhere —
      recorded here
