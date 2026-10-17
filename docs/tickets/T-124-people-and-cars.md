# T-124 — People and cars: swap in Quaternius pedestrians and Kenney cars

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-2 phase 1) · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-121 (the readability rules land first; this swap
  implements them on the new models)
- **Refs:** the 2026-10-13 CC0 asset research: Quaternius Animated Men/Women
  + Universal Animation Library (walk/sit clips; death clips exist and are
  BANNED — splatted people flail, wipe off, and grump), Kenney Car Kit /
  City Kits; class uniforms are color-coded (`scripts/citizen_class.gd`);
  the physics shapes are the contract — tourist capsule r 0.25 / h 1.1, car
  box 1.9×1.45×4.4; T-118's web budget (Compatibility, single-threaded
  wasm).

## What

Replace the capsule-people and box-car VISUALS; touch nothing that decides
gameplay:

1. **Pedestrians** — Quaternius human meshes with a per-class tint material;
   the class read must stay instant, and civilian clothing must not collide
   with black-and-gold (T-121's rule). Elders render seated (sit clip).
2. **Cars** — Kenney car meshes; the visitor flag/banner/cooler re-land
   prominent on the new body per T-121.
3. **Parity is the ticket** — physics shapes, layers, masks, spawner counts,
   panic/flinch/buzz behavior: all unchanged. Splat decals and hit markers
   must parent to the new meshes correctly.
4. **Hygiene** — license verified per pack at import; every import updates
   `assets/CREDITS.md`; web build re-exported with the size delta recorded.

**Route note:** presentation-only by the letter of the routing rule, but the
blast radius is every entity in the city — run it through the
pigeon-ticket-pipeline so a reviewer plays it.

## Acceptance criteria

- [ ] *(Gate 1b)* the FULL sim suite passes UNTOUCHED — that is the parity
      proof (same shapes, counts, splat resolution)
- [ ] *(Gate 1b)* a scenario pins the swap: pedestrian/car visual meshes are
      the imported scenes, per-class tint materials present, and no
      death-animation resource is referenced anywhere
- [ ] *(Gate 2)* autoplay green + contact-sheet review of the frame stream
- [ ] *(Gate 2)* web build loads and plays; download size delta recorded
      against the T-118 baseline
- [ ] *(Gate 3)* owner look pass: classes read at a glance from the air,
      the city still feels pigeon-coherent — recorded here
