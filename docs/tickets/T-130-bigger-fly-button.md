# T-130 — Thumbs first: a bigger Fly button and real distance from Poop

- **Milestone:** Mobile follow-up (owner feedback 2026-10-19) · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** — (T-119 landed; this tunes it — sibling of T-120's legibility pass)
- **Refs:** owner hands-on pass 2026-10-19, live on the hosted mobile build:
  *"the fly button is too small, and the poop button is too close to it"*;
  `scenes/touch_controls.tscn` + `scripts/touch_controls.gd` (T-119); T-120
  (the legibility treatment — labels/contrast — whose scope note keeps
  size/position moves out as "its own owner-directed change", which this
  ticket is).

## What

A second hands-on pass on the phone named two ergonomic problems with the
T-119 button cluster, verbatim: the Flap ("fly") button is **too small**, and
Poop sits **too close** to it. The owner dictated the spec, so no forge pass
runs here — the values below are the whole design:

1. **Flap grows:** the Flap `CircleShape2D` radius goes 52 → 68 canvas px
   (diameter 136). On an iPhone-landscape screen (the 720-tall canvas
   stretched to it) that is roughly a 74 pt target — Apple-HIG-large, a full
   thumb-pad hit — up from ~56 pt. The drawn circle follows for free:
   `_build_visuals` reads the radius back from the shape.
2. **Poop gets distance:** `button_gap` 18 → 30 canvas px. The gap drives
   BOTH axes of the Poop offset (`_layout`: one `gap` of ring separation to
   the left, one up), so ring-to-ring breathing room roughly doubles on each
   axis (~8 mm physical on the phone) and the two hit-circles stop reading
   as one blob under the thumb.
3. **Nothing else moves:** Poop keeps radius 52; stick geometry, Pause,
   edge margins, the labels (font 18 — T-120 owns their treatment) and every
   action binding stay byte-identical. `_layout()` already derives the whole
   cluster from the radii + gap, so the change is two constants — which is
   exactly why the tuned values get pinned (below).

## Acceptance criteria

- [ ] `scenes/touch_controls.tscn`: `CircleShape2D_flap.radius = 68.0`;
      `scripts/touch_controls.gd`: `button_gap = 30.0`; Poop's shape stays
      52.0. No other touch-layout constant moves.
- [ ] *(Gate 1b)* the tuned values are pinned the T-019 way — extend the
      existing touch scenario family (no new file/fork): a scenario asserts
      Flap radius 68 / Poop radius 52 read back from the live shapes,
      `button_gap == 30.0`, and the Poop center sits exactly
      `flap_center + (-(68 + 30 + 52), -30)` from the layout math — so a
      silent revert of either constant fails.
- [ ] *(Gate 1b)* the existing touch scenarios stay green unmodified —
      `touch_buttons_fire_real_actions`, `touch_multitouch_steer_and_flap`,
      `touch_stick_rest_reads_exactly_zero`, `touch_layer_desktop_inert`
      (they read centers back from the live layout, so bigger circles must
      not break the synthetic touches).
- [ ] *(Gate 2)* autoplay green.
- [ ] *(Gate 3)* before/after grabs of the bottom-right cluster
      (`PIGEON_TOUCH=1` desktop preview at a phone-ish aspect) recorded
      here; the after reads as: Flap is the dominant target, and a thumb
      fits between the rings.
- [ ] *(Gate 3)* owner re-check on the phone: fly button comfortable, poop
      no longer crowded — recorded here (needs a hosted re-deploy after
      merge).

**Tuned values:** Flap radius 52 → 68; `button_gap` 18 → 30; Poop radius 52
(unchanged).

**Route note:** owner-directed feel tuning of a landed input feature —
T-119's route note names exactly this ("feel tuning AFTER she plays (stick
sensitivity, button sizes) … goes through the pipeline too"). Forge skipped:
the owner dictated the spec verbatim. Goes through pigeon-ticket-pipeline.
