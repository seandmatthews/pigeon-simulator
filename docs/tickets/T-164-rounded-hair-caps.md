# T-164 — Hair that is not a plank: one fitted dome cap on every head (café sitter, elder, tourist)

- **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 ·
  **Risk (1-5):** 2
- **Depends on:** T-145 (the mesh-pinned head mount and `HEAD_PROP_LIFT`
  law this dome hangs under — the mount stays, the mesh swaps) · T-142
  (the café sit-bake harvest and MultiMesh key machinery this re-keys)
- **Refs:** owner idea + screenshots (2026-11-03: the café sitter wears a
  brown rectangular box on his skull — `sit_hair`, and the elder's white
  hair reads as a loaf slab despite T-145's band mount) ·
  `scripts/cafe_spawner.gd:196-204` (`_hair_offset`), `cafe_spawner.gd:312-317`
  (the `sit_hair` box), `cafe_spawner.gd:172` (the queue line),
  `cafe_spawner.gd:60` (`HAIR`) · `scenes/elder.tscn:18-20,51-52` (the
  white hair box), `scenes/tourist.tscn:19-21,49-50` (the gold cap box) ·
  `scripts/people_rig.gd:92` (`HEAD_PROP_LIFT`), `people_rig.gd:131-148`
  (the frame-1 AABB pin), `people_rig.gd:240-253` (`mount_prop`) ·
  `scripts/tourist.gd:112`, `scripts/elder.gd:154` (the two mount calls) ·
  `tests/sim_test.gd:8842-8889` (the bench scenario), `sim_test.gd:8890-8952`,
  `8899` (the café scenario and its key list) · `VERIFICATION.md:127,131,132`
  (the three Gate 1b rows this touches) · render evidence opened this
  session: `.captures/t144_hair/head_zoom_band.png` (the white slab's flat
  top and vertical sides on a visibly rounded skull) and
  `.captures/t142_cafe/cafe_sitters_closeup.png` (the sitters' dark box
  blocks perched on their heads) · a throwaway head-geometry probe run this
  session in the `tools/probe_sit_geometry.gd` family (numbers below;
  deleted after recording, the T-162 precedent) · a round-2 probe verifying
  the ArrayMesh realization after the round-1 review (numbers below; also
  deleted after recording)

## What

All three hair props are BoxMesh slabs of one family — the elder's
0.3 × 0.1 × 0.28 white (`elder.tscn:18-20`), the tourist cap 0.3 × 0.1 ×
0.3 gold (`tourist.tscn:19-21`), the café `sit_hair` 0.28 × 0.1 × 0.3 fixed
brown `HAIR` (`cafe_spawner.gd:312-317`, `:60`). The pack mannequin is bald
and the pack has no hair mesh to harvest, so the slabs were stand-ins. The
pack HAS a rounded skull, and that is the defect: a flat-sided solid on a
rounded head reads as a plank even where T-145's mount already seats it —
the owner's 2026-11-03 screenshots re-flag the family (café box, elder
loaf), and "tourist cap, same mount family" extends the fix there.

**Measured this session** (throwaway probe
`tools/probe_hair_cap_geometry.gd`, run
`~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script …`
against the shipped rig, deleted after recording). The HeadRigid bind-frame
AABB is pos (−0.1376, −0.0798, −0.1475) end (0.1376, 0.2603, 0.1102) —
byte-consistent with T-145's record. Binning the mesh faces per 0.02 y
band (max horizontal radius about the AABB center xz, crown down), the
UPPER skull is a genuine dome: y 0.240..0.260 r 0.076 → 0.220..0.240
r 0.081 → 0.200..0.220 r 0.107 → 0.180..0.200 r 0.119 → 0.160..0.180
r 0.104 (face bands below carry the wider nose/ear maxima, ≤ 0.129). The
slabs fight that curvature: the elder box's corner radius about the head
center is √(0.15² + 0.14²) = 0.205 (arithmetic from the scene literals +
probe AABB), so its four corners hang ~0.09 off a skull that only reaches
0.119 up there, over flat vertical sides — the loaf. The café fit input,
the harvested `sit_head` bake, measures pos (−0.1417, 1.0515, 0.0439) end
(0.1299, 1.3981, 0.3273) (the nodded bake; plan half-extents 0.136/0.142),
its crown bands the same family (1.378..1.398 r 0.092 → 1.318..1.338
r 0.137 → 1.278..1.298 r 0.142). Engine facts the probes pinned:
`SphereMesh.is_hemisphere` on this build emits the dome base circle at
LOCAL y = 0, apex at +height, elliptical taper (r 0.15/h 0.09 → 4224 tris
at default segments; base band r 0.150, top band r 0.093) — and the type
exposes no offset channel (radius, height, is_hemisphere, radial_segments,
rings only; every probe hemisphere measured AABB pos.y exactly 0.0), so a
drop cannot live on the primitive itself. The realization that CAN carry
one is verified by the round-2 probe: build the SphereMesh, take its
`get_mesh_arrays()`, translate the vertex arrays by the drop, return a
one-surface ArrayMesh — measured: source sphere (r 0.138, h 0.10, 24×12)
AABB y 0.0..0.10 → translated ArrayMesh AABB y −0.03..+0.07, x/z unchanged
(±0.137), 624 tris preserved, taper profile identical (base band 0.1370 →
apex band 0.0641, ratio 0.47), material readable back off surface 0
(`surface_get_material(0)`; unset it is null).

**The cap.** One generated squashed hemisphere, fitted per head AABB (the
T-145 measurement family), used on all three mounts:

1. **Generator** — `static func hair_cap_mesh(head_aabb: AABB, base_drop:
   float, material: Material = null) -> ArrayMesh` on `PeopleRig` (it owns
   the head measurement law). The dome SHAPE is a SphereMesh (its
   `is_hemisphere` is the taper above), but the SphereMesh cannot carry the
   drop — base circle at local y = 0, no offset property — so the builder
   realizes the cap as the round-2 probe verified: build the SphereMesh
   with the derivation below, take `get_mesh_arrays()`, translate the
   vertex arrays by `base_drop` (normals untouched), and return the result
   as a ONE-SURFACE ArrayMesh (`add_surface_from_arrays` +
   `surface_set_material(0, material)`) — the drop lives in the vertices,
   `get_aabb()`/`get_faces()` read the offset dome directly, and the node
   origins stay pinned (the elder/tourist mounts need no geometry-offset
   channel and no extra node). Derivation: radius = the AABB's max
   horizontal half-extent (rig head 0.1376, café bake 0.1417 — the ≤ 6%
   plan oblateness stays inside the sunk rim; a uniform dome is claimed,
   NOT an ellipsoid fit); height = `HAIR_CAP_HEIGHT := 0.10` (base circle
   at y = `base_drop`, apex at `base_drop + HAIR_CAP_HEIGHT` in mesh-local
   terms — exactly the translated probe AABBs);
   `radial_segments 24` / `rings 12` (624 tris measured, preserved through
   the translation — the default 64×32 dome is 4224, 7× the budget a
   0.14 m cap needs at gameplay distances, the T-018 spirit); `material`
   stamped on surface 0 so the key keeps its color law (elder white,
   tourist gold, café `HAIR` — the scenes harvest the placeholder box's own
   material before swapping; the café builds its flat `HAIR` material as
   the match arm does today).
2. **Rig mounts (elder, tourist)** — unchanged mount lines, new mesh:
   `elder.gd:154` / `tourist.gd:112` keep `mount_prop(…, Mount.HEAD)`, then
   swap the node's mesh via the generator with
   `base_drop = HAIR_CAP_BASE_DROP := −0.03` (slot-local, bind units: the
   slot rides mesh-top − 0.05 at `people_rig.gd:141`, so the dome's rim
   lands at mesh-top − 0.08 and its apex at mesh-top + 0.02 — the T-145
   crown-pokes-past read kept). The node ORIGIN never moves, so
   `elder_seats_on_the_bench`'s `hair_lift` (which reads
   `hair.global_position.y` and bands it exclusive −0.05/+0.10,
   `sim_test.gd:8866-8874`) stays −0.049 world — inside its pinned band
   with the band UNTOUCHED.
3. **Café mount** — NEW MultiMesh key `sit_hair_cap` (node `SitHairCap`),
   replacing the `sit_hair` box key: `_harvest_sit_meshes` builds the dome
   once per populate from the harvested `sit_head` AABB with `base_drop 0.0`
   (the instance transform is the positioner), and the queue line
   (`cafe_spawner.gd:172`) becomes
   `sit_root.translated_local(center.x, end.y − HAIR_CAP_SINK, center.z)`
   with `HAIR_CAP_SINK := 0.08` — `_hair_offset`'s current end.y − 0.03
   rides 5 cm deeper so the rim sinks onto the skull instead of the
   box-center convention. The café passes `base_drop 0.0` — the translation
   is the identity there (the round-1 review's note: the café mount was
   already consistent), the instance transform carries the full 0.08 sink.
   One mesh for the whole crowd (every sitter bakes
   the same head), per-instance transforms as today; the key is NOT in
   `SHIRT_KEYS` (fixed color, as now). The retired `sit_hair` key joins the
   swap tripwire (`cafe_spawner.gd` keeps no box arm in `_visual_mesh`).

**The fit read** (probe-derived): the rim plane sits at the y where the
skull profile still carries ~85–90 % of its upper-region max — rig head:
rim at 0.180 vs local skull r 0.119 → a 0.019 ledge; café bake: rim at
1.318 vs 0.137 → a 0.0045 ledge. Below the rim the dome is convex: ≤ 0.03
proud everywhere and never a hanging corner — against the box's 0.205
corner floating 0.09. The flat underside annulus hides inside that ledge;
no sky gap at any pose (the prop still pitches with the head on the raw
bone frame — the T-145 mount law, untouched). The rim numbers are the
translated probe AABBs read in head space — base = slot
(end.y + `HEAD_PROP_LIFT`) + `base_drop` = end.y − `HAIR_CAP_SINK`, apex =
end.y + 0.02 — so the scenario's FIT legs measure them directly off
`get_aabb()`; nothing here depends on a mesh-offset channel the primitive
types don't have.

**No reference photos:** no research phase ran — stylized hair on a pack
mannequin is a game-invented affordance with no very clear real-world
counterpart, so reference photos do not apply; the criteria are concrete
from the repo's own meshes and the probe lines above.

**Not claimed:** no hair variety (colors, lengths, parting, strands —
IDEAS material; a one-color dome per class is the art style); no pack
re-import and no bake changes (the `sit_head` AABB family is consumed as
-is, so a re-bake re-fits automatically); no mount-law edits
(`HEAD_PROP_LIFT` −0.05, the frame-1 pin, the identity-basis raw-bone-frame
ride all stay); no material/color-law changes (the citizen pairing, the
shirt tints and `SHIRT_PALETTE` untouched); the mitt/foam finger untouched;
no café count/yaw/RNG/fingerprint changes; no new scenes, no input actions;
the elder's cane and tourist flags untouched.

## Why

The owner flagged this family twice: T-145 (2026-11-02) fixed WHERE the
hair sits and the owner confirmed the attachment; the 2026-11-03
screenshots flag WHAT the hair is — a flat-sided solid still reads as a
loaf on a rounded skull, and the café sitter still wears the raw brown box.
Tourists, elders and café sitters are the city's only close-range humans —
the player lands beside them and walks through their tables — and
head-wear is the class tell (the superfan's gold cap is how a visitor reads
at lob distance, `VERIFICATION.md:127`). A prop with floating corners and
vertical sides reads as rigging the city wears, not as a person — the
Pillar 2 family (`docs/DESIGN.md:46-53`, per T-163's citation). One
generator also settles the family for good: the dome derivation becomes
the reusable fit for any future head-worn prop (a helmet, a hood) the way
T-163's probe lines made any future seat a measurement.

## Acceptance criteria

- [ ] *(Gate 1b)* new `hair_caps_round_the_skull` (the bare-rig
      instantiation family of `citizen_classes_readable`,
      `sim_test.gd:8420`; the elder/tourist legs read the live `Hair`/`Cap`
      nodes post-`_ready` — each node's mesh IS the offset dome (the
      vertex-baked ArrayMesh, no child node, no re-homing: the round-1
      alternative was rejected because it breaks exactly this read path),
      so `mesh.get_aabb()`/`get_faces()` see the drop directly; the café
      leg reads `visual("sit_hair_cap").multimesh.mesh` plus
      `visual("sit_head").multimesh.mesh.get_aabb()`):
      - SHAPE, all three cap meshes: tri count ≥ 96 (the retired boxes
        carry 12), and the y-binned radial-profile taper — the top-20 %-
        band max horizontal radius ≤ 0.75 × the base-20 %-band max radius
        (probe: dome 0.54 at 64×32 / 0.47 at 24×12, box 1.00 — the dome
        tapers, the box's top-face corners keep full radius);
      - FIT, against the live head AABB (the rigs' HeadRigid bind AABB via
        a `PeopleRig.head_aabb()` accessor; the café's harvested `sit_head`
        bake AABB): cap plan within head plan + 0.01 per axis; cap base at
        head end.y − `HAIR_CAP_SINK` ± 0.01 (rim sunk onto the skull, not
        perched); cap apex ≥ head end.y − 0.03 (the crown read survives);
        rig legs additionally pin the drop equation the bands lean on —
        `HAIR_CAP_BASE_DROP == −0.03`, `HEAD_PROP_LIFT == −0.05`, and
        `HAIR_CAP_SINK == −HEAD_PROP_LIFT − HAIR_CAP_BASE_DROP`
        (0.08 = 0.05 + 0.03), so a silent const edit fails the band;
      - VALUE LOCKS: `HAIR_CAP_SINK` 0.08, `HAIR_CAP_HEIGHT` 0.10,
        `HAIR_CAP_BASE_DROP` −0.03, segments 24/12 (the T-110 precedent);
        the realization pinned too — each cap mesh is a ONE-surface
        ArrayMesh with a non-null surface-0 material (a bare SphereMesh
        return would land its base circle 0.03 high and fail the FIT leg
        by construction — the round-1 contradiction, kept impossible).
- [ ] *(Gate 1b)* `cafe_sitters_on_the_rig` amended in the same change-set:
      the key list (`sim_test.gd:8899`) `sit_hair` → `sit_hair_cap` (still
      one instance per sitter) and `sit_hair` joins the swap tripwire; the
      stamped/shirt/human legs untouched (`sit_hair` was never metadata-
      stamped — the box was generated too). `elder_seats_on_the_bench` green
      UNCHANGED (the mesh swap is invisible to a node-origin band).
      `citizen_classes_readable` green UNCHANGED (its cap leg pins
      visibility + color, not geometry — `VERIFICATION.md:127`). FULL suite
      0 failures: `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`.
- [ ] *(Gate 1)* `--import` and the 120-frame boot exit clean, zero ERROR
      lines.
- [ ] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`).
- [ ] *(Gate 3, screenshots)* pilot-harness captures into
      `.captures/t164_hair_caps/`, eyes-on: (a) an elder head zoom reads
      hair-ON-skull — a rounded white cap, no flat top plane, no vertical
      sides, no corner floating off the dome; (b) a café sitter closeup
      reads the brown hair as a rounded cap on the seated head; (c) a
      superfan's gold cap reads as a rounded cap, not a gold slab; (d) the
      T-145 read survives at the 7 m zoom — no sky gap under the rim in
      idle AND seated poses (the mount law untouched).

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with the new
`hair_caps_round_the_skull` registered in `_run_scenarios` (the
`sim_test.gd:240` neighbors), its row added to the Gate 1b table in
`VERIFICATION.md`, the `cafe_sitters_on_the_rig` row (`VERIFICATION.md:132`)
re-worded for the re-key, the `elder_seats_on_the_bench` row
(`VERIFICATION.md:131`) gaining a parenthetical that the hair MESH is the
T-164 dome under the unchanged origin law — all in the same change-set ·
Gate 2 autoplay · Gate 3 the four screenshot lines above.

**Red-before probe to record when landed:** the shipped boxes fail the new
scenario's SHAPE leg on every mount — measured this session against the
literal elder box (0.3 × 0.1 × 0.28): 12 tris (< 96) and a taper ratio of
1.00 (> 0.75), both from the probe's face bins. The elder/tourist boxes
also fail the FIT plan leg (0.30-wide box vs the 0.276 bind plan → 0.012
poke > 0.01, arithmetic from the probe AABB + scene literals); the café
box passes the fit bands (T-145 sized it so) and fails ONLY the shape leg —
which is the ticket's law: a cap must BE round, not merely sit right.

**Tuning latitude:** `HAIR_CAP_SINK` ±0.02 and `HAIR_CAP_HEIGHT` ±0.02 on
the Gate 3 read (`HAIR_CAP_BASE_DROP` follows as sink − 0.05); the radius
law is fixed (max half-extent) with an allowed ±0.005 hand-trim if the rim
ledge reads wrong on the zoom; segments may rise, never drop below
16 radial. Record the landed values here (the T-134 "Tuned values"
pattern).
