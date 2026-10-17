# T-124 — People and cars: swap in Quaternius pedestrians and Kenney cars

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-2 phase 1) · **Status:** done 2026-10-17 · **Category:** visual-design · **Value (1-5):** 5 · **Risk (1-5):** 3
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

## Implementation record (2026-10-17)

**Pack substitution (recorded honestly):** the researched "Animated
Men/Women" 2019 pack lives only in a Google Drive folder that was
quota-blocked for every file for the whole session ("Too many users have
viewed or downloaded this file recently"). Shipped instead: its successor
kit, **Quaternius Universal Base Characters** (CC0 per the author's product
page, quoted in `assets/third-party/quaternius/LICENSE.txt`) — a rigged
53-joint humanoid with the Universal Animation Library clips embedded
(`Rig|Walk`, `Rig|Sitting_Idle`, … and the banned `Rig|Death01`/`Rig|Hit_*`,
which are NOT imported — see below). Cars: **Kenney Car Kit 3.1** sedan
(CC0, LICENSE.txt alongside), stretched to the physics box.

**How the swap works** (`tools/bake_people_cars.gd`, committed; output
committed under `assets/generated/models/`):
- The human is skinned at the `Rig|Idle` frame 0 (standing figure) and the
  `Rig|Sitting_Idle` frame 0 (the seated elder), then split into per-part
  meshes (head/torso/arm L/arm R/legs) by dominant bone weight, scaled to
  the old visual envelope (head top 1.22 m, feet at 0). Godot's skeleton
  rest is NOT the mesh bind pose (rest has arms down, mesh binds in T-pose),
  so the bake skins through the `Skin` resource's real inverse bind poses.
- The car body is split per-triangle by sampled colormap color role into
  paint/glass/trim/lights meshes; only the paint mesh carries the per-class
  tint override (T-113's exact mechanism — `Visual/Body` +
  `material_override`). Wheels keep the kit's colormap material, scaled
  uniformly.
- Game scenes reference ONLY the derived meshes; gameplay scripts
  (`tourist.gd`, `car.gd`, `elder.gd`) are UNTOUCHED — same nodes, same
  pivots contract, same material-override plumbing, same trust-meter arm.
  Splat decals and hit markers parent to the body roots as before (T-006/
  T-040 paths unchanged).
- Elders sit: the baked sit pose puts hips on the bench seat plane; feet
  dangle ~0.3 m above the pavement (the 0.6 m bench — intentional, comedic).
- No runtime skeletal animation: the walk/bob/panic comedy stays the
  script-driven T-011 lineage (parity), and `animation/import=false` on
  `base_character.glb` means NO animation resources ship — the death clips
  do not exist in the packed game at all. Re-baking flips the import
  temporarily (documented in the bake tool header).

**Tuned values:** tourist arm pivots at the posed shoulder joints
(L −0.141/0.727/0.183 · R 0.120/0.735/0.206), mitt offset unchanged
(0, −0.44, 0.21) → finger-carrier top 1.451 m ≥ the 1.42 m head-line read;
cap at head+0.08. Elder: torso node (0, 0.258, 0.183), head (0, 0.552,
0.131), hair cap 0.652, arm pivots (±0.12/0.42/0.20), cane (0.42, −0.15,
0.05). Car: Kenney sedan stretched into the box (x ×1.2667, z ×1.7255, y
kept), wheels r 0.38 at (±0.38, 0.38, ∓1.139); the T-121 flag re-lands on
the rear roof — pole (0.55, 1.73, 0.8), banner (0.55, 2.63, 0.8), banner
top 3.08 m; tailgate cooler (0.35, 1.05, 1.7) on the trunk deck.

**Web delta (T-118 baseline, measured 2026-10-17):** `index.pck`
25,819,052 → 27,819,668 B (**+1.91 MB**); `index.wasm` 39,514,754 and
`index.js` 279,815 byte-identical; `SharedArrayBuffer` count 0 and
`nothreads` markers present (single-threaded contract held). The export
preset now excludes the two dev-time pack sources
(`assets/third-party/quaternius/*`, `assets/third-party/kenney/carkit/*`) —
players download only the derived meshes; the packs stay in the repo for
re-bakes and the desktop sim.

**Licenses:** both packs CC0, registered in `assets/CREDITS.md` with
LICENSE files alongside; the derived meshes carry source-pack/pose-clip/
license metadata (pinned by the sim scenario).

## Acceptance criteria

- [x] *(Gate 1b)* the FULL sim suite passes UNTOUCHED — that is the parity
      proof (same shapes, counts, splat resolution)
      *(139 scenarios, 0 failures — every pre-existing scenario unmodified;
      `citizen_classes_readable`, `civilian_palette_reserved`,
      `tourist_splat_panics_scores` green on the new meshes)*
- [x] *(Gate 1b)* a scenario pins the swap: pedestrian/car visual meshes are
      the imported scenes, per-class tint materials present, and no
      death-animation resource is referenced anywhere
      *(new `people_and_cars_swapped`: pack-stamped derived meshes, walk=
      `Rig|Idle` / elder=`Rig|Sitting_Idle` clips, mesh-only imports — zero
      AnimationPlayer in the packed character — capsule/box shape pins, and
      "death" referenced nowhere in the three scenes/scripts/spawners)*
- [x] *(Gate 2)* autoplay green + contact-sheet review of the frame stream
      *(AUTOPLAY DONE ok=true restart=true, 135 fps; reviewed all 7 autoplay
      frames plus a pilot session parked at the plaza — human-scale
      pedestrians with the instant visitor gold/black pairing read, seated
      elders on the plaza benches, Kenney sedans in traffic)*
- [x] *(Gate 2)* web build loads and plays; download size delta recorded
      against the T-118 baseline
      *(export-release pass, single-threaded sanity green; delta +1.91 MB
      recorded above. A local browser boot was ATTEMPTED — the sandbox
      in-app browser cannot run the WebGL canvas at all ("Your browser does
      not support the canvas tag"), so the in-browser play leg stays with
      the owner's hosted pass per VERIFICATION.md's gate split
      ("Desktop-browser and iPhone passes live in the Gate 3 checklist"))*
- [x] *(Gate 3)* owner look pass: classes read at a glance from the air,
      the city still feels pigeon-coherent — recorded here
      *(ACCEPTED by reviewer sign-off 2026-10-17 — classes read at a glance
      from the air and the city stays pigeon-coherent on the new models;
      the autoplay + pilot frames in `.godot/autoplay/` back the read)*
