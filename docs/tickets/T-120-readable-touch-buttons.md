# T-120 — Readable thumbs: the touch buttons need an at-a-glance treatment

- **Milestone:** Mobile follow-up (owner feedback 2026-10-15) · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** — (T-119 landed; this tunes it)
- **Refs:** owner hands-on pass 2026-10-15, live on the hosted mobile build:
  *"the buttons need to be a little easier to read"*; `scenes/touch_controls.tscn`
  + `scripts/touch_controls.gd` (T-119); the T-019 HUD outline treatment
  (dark outline behind bright fills) as the house pattern for at-a-glance
  legibility; T-113's Euclidean-RGB contrast legs as the machine-check pattern.

## What

The touch controls work — the owner flew the hosted build on a phone and the
auto-layout detection did its job — but the on-screen buttons read poorly.
He asked for them to be "a little easier to read"; that's a legibility pass,
not a redesign:

1. **Judge what "read" means here first** (Gate 3 before/after grabs on a
   phone or `PIGEON_TOUCH=1` desktop preview): label glyphs too small? fill
   too close to the sky/road behind it? no outline separating button from
   world? Likely the T-019 answer — a dark outline (≥ 4 px) + bright label
   fill on each TouchScreenButton's label, and/or a translucent dark panel
   behind each button — but the pass should be driven by what the grabs show,
   not by guesswork. Record the chosen treatment here.
2. **Scope discipline:** labels/contrast/outline only. Button positions,
   sizes and reach stay as landed unless the grabs show an outright problem —
   stick comfort and layout are T-119's landed design and any move there is
   its own owner-directed change.
3. **Desktop stays byte-identical:** the layer is hidden on desktop; the
   desktop-first rule (keyboard path untouched) and `touch_layer_desktop_inert`
   must not move.

**Route note:** ui-ux tuning of a landed input feature — goes through
pigeon-ticket-pipeline per T-119's route note and the routing rule.

## Acceptance criteria

- [ ] *(Gate 3)* Before/after grabs of the mobile buttons over bright pavement
      and over dark road/shadow; the after reads at a glance — labels legible,
      buttons findable without hunting (owner or agent grabs recorded here)
      [screenshot]
- [ ] *(Gate 1b)* the chosen treatment is pinned the T-019 way — the scenario
      asserts the scene-owned constants (label fill, outline size/color or
      panel stylebox per button) so a silent revert fails; extend the existing
      touch scenario family, don't fork a new one
- [ ] *(Gate 1b)* full sim suite green untouched otherwise — desktop path
      byte-unchanged (`touch_layer_desktop_inert` still passes unmodified)
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 3)* owner re-check on the phone: "easier to read" — recorded here
