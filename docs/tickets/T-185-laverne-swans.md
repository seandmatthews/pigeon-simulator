# T-185 — Ames R3 · Lake LaVerne + the swans: Lancelot and Elaine, restored

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-177 (placeholder slot), T-174 (water v1)
- **Refs:** `MODELING-SPECS.md` §1 lake-laverne cluster ·
  `community/TRADITIONS.md` §2 (swan tradition; both birds gone 2022 —
  the game restores them by owner premise) · `images/laverne/` (6+1
  refs incl. real swans) · `verification` ground truth (236×122 m,
  2.8 ac)

## What

1. **Lake polish**: shoreline band → proper shore read (pale edge,
   reed hint), the MU lawn adjacency kept honest (the postcard
   composition: lake foreground, campanile behind).
2. **The swans**: two mute-swan NPCs — Lancelot & Elaine — ambient
   swimmers on a slow lake circuit; bob on wake; wing-tuck idle; the
   three-laps folklore honored as a sign easter egg in R4 (NOT
   gameplay here). **Scope guard (owner-decided 2026-11-09, master
   plan §11.3):** ambient only — not perchable, not splat-able, not
   bread-able; they are the town's beloveds (REDDIT-RESONANCE: "They
   were so iconic").
3. **Swap discipline**: replaces the T-175 placeholder at the same
   id/slot; dims probe re-pins (the water body was T-174's — this
   ticket owns the shore + birds).

## Why

The lake+swans shape is the #3 from-the-air read and the survey's most
longed-for place-pair; restoring the (real-world extinct) pair is the
campaign's heart note.

## Acceptance criteria

- [x] Shore read verified at 60 m and 200 m; composition shot (lake →
      MU → campanile) matches the reference photo angle — agent pass
      recorded (see the round notes: `.captures/session_t185shore{,2}/`),
      ACCEPTED by reviewer sign-off on the landed tree 2026-11-14 (the
      owner still sees the swans in T-196's postcard flight per the
      ticket's Verification line — that ride is booked, not owed here)
- [x] Swans: exactly 2, circuiting ≤ 122 m span, T-165-independent
      (bird rig, not the people rig); never leave the water; collide
      with nothing (they yield) — `laverne_swans_present` (Gate 1b,
      run 2026-11-14: count 2 named Lancelot/Elaine; circuit span
      54.0×54.0 ≤ 122; 600/600 live frames in-polygon; no physics
      body/area/AnimationPlayer anywhere in either bird)
- [x] *(Gate 1b)* `laverne_swans_present`: count=2, position-in-polygon
      always, dims re-pin — SIM PASS (139 scenarios, 0 failures,
      exit 0 on the committed tree)
- [x] *(Gate 1/2)* clean; the T-163 sit law untouched (no bench sit
      here) — Gate 1 import+boot clean; Gate 2 `AUTOPLAY DONE ok=true
      world=ames … restart=true`, exit 0; the sit rows
      (`elder_seats_on_the_bench` / `sitters_clear_their_seats`) ran
      unchanged in the same green suite

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots vs
`images/laverne/` refs; owner sees the swans in T-196's postcard flight.

## Decisions & forks

Swan scope DECIDED (owner, 2026-11-09): ambient-only swimmers. More
character would be a new owner-picked ticket.

## Rounds & tuned values

- **Swap discipline, read:** the water body is untouched (T-174's bake
  families byte-identical — `ames_bake_census` / `ames_bake_determinism`
  green on the same tree); the "placeholder slot" the ticket replaces is
  the bare mown-band shore read AT the pack's own lake ring — no id
  moves, no new bake, no dims drift (`ames_placeholder_dims` re-measured
  the same 235.8×122.4 water + 13.7 m MU gap + 264.1 m campanile on this
  tree). The dims re-pin rides the new row (pack lake 236×122 ±2,
  circuit span, shore-read recounts).
- **Runtime dressing (the T-180 corner-dress pattern), not a re-bake:**
  pure pack-derived geometry, zero colliders, zero RNG of any stream, a
  rebuild reproduces every transform; the transform queues are retained
  for the gate.
- **Pale edge:** #C7C1B3, one quad per non-degenerate ring-split edge
  (117, basin + Swan Island), extruded 1.2 m outward, box top at 0.03
  (12 mm over the shore band's 0.018, 10 mm over the water's 0.02 — the
  road-paint clearance discipline; corner overlaps read as the
  waterline fringe, never interior paint).
- **Reed hint:** clumps of three #546B2E slivers (0.05 m section,
  0.6–1.1 m tall, hash-spread yaw/offset, per-sliver ±5 % shade) standing
  IN the water 1.0 m off the ring edge on hash-picked edges (`hash %
  3 == 0`, edge ≥ 6 m) — 63 slivers at landing. Round 1 defect caught by
  the in-water arm: centroid-facing normals stood clumps on land in the
  crescent's north bay; the fix rides the ring WINDING (the baker's
  `_signed_area` shore rule) and the arm pins it.
- **The swans:** `scenes/swan.tscn` + `scripts/swan.gd`, primitive mute-
  swan rig (§1.2 white #F4F2EC body, S-neck, black knob, orange bill),
  1:1 scale (~1.2 m hull). Circuit PROBE-PINNED (the T-181 insets way):
  a 27 m round at (230, −118) pack-local — the widest inscribed circle
  in the south basin, dense-sample verified 2.67 m minimum shore
  clearance, clear of Swan Island; span 54 m ≤ the AC's 122. Paddle
  0.8 m/s; wake bob 0.9 Hz ± 0.025 m + 0.6 Hz roll; wing-tuck idle
  9.0 s period, 0.14 rad lift + 0.18 chord squeeze, phases desynced
  (Lancelot 0.0 / Elaine 0.45 loop phase). Ambient only by
  construction: no PhysicsBody3D, no Area3D, no splat/eat hooks.
- **Gate record (2026-11-14, on the committed tree):** Gate 1 import +
  120-frame boot clean (the one accepted godot_mcp teardown line);
  Gate 1b 139 scenarios, 0 failures, exit 0 (incl. `laverne_swans_present`
  and the untouched `ames_*`/sit rows); Gate 2 `AUTOPLAY DONE ok=true
  world=ames … restart=true`, exit 0. Gate 3 agent pass: shore 60 m +
  200 m, the postcard angles, and a swan mid-circuit — recorded under
  `.captures/session_t185shore{,2}/`, pixel-A/B'd against a parent-commit
  capture (`.captures/session_t185ab/laverne_200m_ab.png`) to prove the
  polish ADDED the shore read and moved nothing else.
- **DONE on reviewer sign-off, 2026-11-14** — the ticket flipped done on
  the signed-off landed tree; the owner's T-196 postcard flight remains
  the booked owner-eye ride for the swans.
