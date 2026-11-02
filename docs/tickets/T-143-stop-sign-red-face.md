# T-143 — The stop signs read red: give the red face real relief over the border

- **Milestone:** Stop-sign follow-up (owner ask 2026-11-02, right after the
  T-141/T-142 playtest: "Fix the stop signs") · **Status:** done 2026-11-02 ·
  **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-134 (the stop-control furniture whose sign face this
  fixes, landed)
- **Refs:** `scripts/city.gd` (`_queue_stop_sign`, `STOP_SIGN_THICKNESS`),
  `tests/sim_test.gd` `_scenario_intersection_furniture` (the geometry pin
  that carries the thickness literal), the committed transform probe
  (this ticket's Implementation record).

## What

Every stop sign in the city reads **white with thin red hairline seams** —
inverted from the R1-1 red-face-with-white-border it's built to be. The
symptom is consistent at every distance the pilot could reach (4 m, 10 m,
25 m, 40 m, face-on and oblique; before-shots in
`.captures/t143_signs/`).

**Root cause.** The sign is the union of four white border bars (0.03 m
thick along the approach) with the four red core bars inside them — proud
by only **0.003 m per face** (red 0.036 vs border 0.03). The two layers
are near-coplanar over ~95 % of the sign's face, and that separation does
not survive the render pipeline at gameplay distances: the white face
draws over the red, and the red survives only as hairline seams along the
bar boundaries (the pilot zoom shows the ±45° bars' edges crossing the
face as an X). The queued transforms are CORRECT — a headless probe of the
city's visual queues shows red z-extent 0.036 vs border 0.03 at identical
origins, red mesh/material registered red — so this is a render-order/
depth-resolution phenomenon on near-coplanar MultiMesh layers, not a
layout bug. (The road paint's 5 mm float never fights because it does not
coplanar-overlap the slab.)

**Fix.** Real relief: `STOP_SIGN_THICKNESS` 0.036 → **0.086** — the red
core sits ~0.028 m proud of the border on both faces, a raised red plate
on a white plate, unambiguous at every distance from every angle under
any depth configuration (desktop Forward+ and the web's
`gl_compatibility` alike). The sign stays double-sided red (the back face
reads red to the opposite lane — unchanged T-134 behavior).

## Known pin breaks, amended in the same change-set

- `_scenario_intersection_furniture`'s geometry pair literal
  `["stop_sign", 0.75, 0.31, 0.036]` → `0.086` (the pin that holds the
  thickness; the row's layout claims are untouched — positions, counts,
  angles, fingerprint).

## Not claimed

- Gray sign backs (real R1-1s are gray on the back; the opposite-lane read
  is unchanged T-134 scope).
- "STOP" lettering on the face (the city's blank-signboard convention,
  T-090).
- Sign placement/height/right-side rules (pinned by
  `intersection_furniture_oriented`, untouched).

## Acceptance criteria

- [x] `STOP_SIGN_THICKNESS` 0.086 with the probe-verified margin (red
      0.043 half vs border 0.015 half = ~0.028 proud per face); the
      amended `intersection_furniture` pin green; FULL suite 0 failures
      (the layout fingerprint leg included — geometry consts draw no RNG).
- [x] (Gate 3, screenshot) A stop sign reads RED face + white rim at close
      and distance framings — after-shots in `.captures/t143_signs/`
      (`after_closeup.png`: face-on at ~10 m, sampled red 71,4,8;
      `after_distance_zoom.png`: the ~25 m read; the before hairline zoom
      is `sign_zoom.png` from the pre-fix session).
      *(Owner feel-pass pending as the human judgement.)*
- [x] VERIFICATION.md notes the fix on the furniture row's ticket list.

## Implementation record (2026-11-02)

**The diagnosis path** (for the next near-coplanar prop): eyes-on at 4–40 m
showed white fill + hairline red seams (the ±45° bars' edges crossing the
face as an X); a headless probe of the city's `_visuals` queues proved the
transforms CORRECT (896 red bars, origins identical to the border bars, z
extents 0.036 vs 0.03 — red 0.003 proud per face) and the mesh/material
registered red. With layout, materials and transforms exonerated, the
defect lives in the render: two MultiMesh layers near-coplanar over ~95 %
of the sign's face interleave at gameplay distances (the road paint's 5 mm
float never fights because it does not coplanar-overlap the slab). The
engineer's answer is relief the pipeline cannot confuse: **0.086** — the
red core stands ~0.028 proud per face, a raised red plate on a white
plate.

**Gates.** Full suite green with the amended pin: `SIM PASS
intersection_furniture_oriented` + `SIM SUMMARY: 0 failure(s)` (log
`/tmp/sim_t143.log`, 2026-11-02). Pilot re-read: the same intersections
that read white pre-fix read red face + white rim at ~10 m and ~25–30 m;
a cross-road sign seen ~70° off-face shows its profile (border side +
relief) — correct for the angle; a heavily shadowed face was not
pixel-sampled before the run starved — the owner's feel-pass should
glance at a shadowed sign.

**Human playtest (pending):** owner confirms the red face reads right in
play, including shadowed and grazing framings.
