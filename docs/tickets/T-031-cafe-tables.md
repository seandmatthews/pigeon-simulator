# T-031 — Cafe life under the awnings: tables with seated tourists on shop fronts

- **Milestone:** Sweep backlog · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-004 (street geometry), T-017 (shopfronts/awnings), T-020
  (the seated-NPC pattern reused here)
- **Refs:** `docs/DESIGN.md:73-74` → "Landmarks sprinkled by seed (statue
  square, café tables)"

## What

Every building that rolled an awning (104/146 at the M1 seed — pinned at
`tests/sim_test.gd:705` and `VERIFICATION.md:101`) gets a cafe table on the
sidewalk in front of its shop face, with 1-2 seated low-poly people. The
T-020 elder precedent cloned end to end (scene + script + spawner + wiring +
scenarios landed in one commit there):

- `scripts/city.gd`: new pure-layout array `cafe_spots: Array[Transform3D]`
  (the `elder_spots` pattern, `scripts/city.gd:130`), one entry per awninged
  building, appended after the block loop from the public `buildings[]` data
  (`door_face`, `size`, `lot_offset`, `has_awning` —
  `scripts/city.gd:439-449`). Placement is pure math, ZERO new RNG:
  - face plane at `footprint * 0.5 + band_outset` from the building center
    along the `door_face` normal (the shop-band geometry,
    `scripts/city.gd:476-479`);
  - table center 1.9 m further out along that normal, at a ±2.2 m along-face
    offset from the door center (side picked by the `lot_offset` sign),
    y = `block_slab_height`, yaw facing the street;
  - resulting table center ≈ 9.8 m from the block center — inside the
    sidewalk band (building face ~7.9 m, tourist curb ring 10.9 m,
    `scripts/city.gd:245`), leaving the ~0.65 m walker clearance the loop
    was designed around (`scripts/city.gd:236-243`: sides keep 0.6-0.9 m off
    props). The ±2.2 m offset clears the centered 0.95 m door
    (`scripts/city.gd:493-496`) by ~1.3 m edge-to-edge.
- `scenes/cafe_table.tscn` + `scripts/cafe_table.gd`: table box (top
  0.9 × 0.06 × 0.9 at ~0.72 m on a center post) with a small layer-1
  collider (the bench pattern, `scripts/city.gd:559`) and 1-2 `cafe_sitter`
  children (count = pure rule: even spot index → 2, odd → 1 → ~156 sitters
  at 104 tables).
- `scripts/cafe_sitter.gd` (scene child): a seated person as a
  `StaticBody3D` on layer 3 `npc`, mask 0 — exactly the T-020 elder body
  (`scripts/elder.gd:9`), so the pigeon can perch beside them (player mask 5
  since T-020) — but tourist-flavored: torso box in `Tourist.SHIRT_PALETTE`
  colors assigned by index before `_ready` (zero RNG,
  `scripts/tourist.gd:20-23`), sphere head in `Tourist.SKIN`
  (`scripts/tourist.gd:25`), seated at stool height.
- `scripts/cafe_spawner.gd` (mirroring `scripts/elder_spawner.gd`): wired
  into `scenes/main.tscn` next to the other spawners; consumes
  `city.cafe_spots` on `City.regenerated`, instantiating one table scene per
  spot at its transform.

**Decision — not a `seated` flag on `scripts/tourist.gd`:** the tourist is a
`CharacterBody3D` driven by the T-007 loop/panic/recycle state machine; a
seated variant would drag all four T-007 scenarios and the recycle system
into this change-set, and add 104-208 per-frame bodies. Static sitters cost
nothing per frame — T-018's `density_cpu_budget` gate is the proof.

**Fingerprint discipline:** no `_shop_rng` draws are added (the stream's
roll order — color, door face, awning per building — is untouched, so the
pinned 104/146 holds), no layout-stream draws, no `_fp` entry (`cafe_spots`
is pinned by the new scenario directly, like `elder_spots`). The fingerprint
hash stays byte-identical to pre-T-031 builds.

**Known edge, accepted:** bench along-face jitter is RNG (±4 m,
`scripts/city.gd:538`) and unknowable without consuming the stream, so a
foreign seed could visually kiss a table against a bench. At the M1 seed the
fixed ±2.2 m offsets land clear — the scenario asserts it there. Tables are
street furniture, not a per-seed guarantee; noted, not mitigated.

## Why

Street canyons have exactly one detail per building — a T-017 door and maybe
an awning (`scripts/city.gd:472-506`) — sidewalks are wide bare white slabs,
and the only people are 18 loop-walkers for 49 blocks. A state.jsonl scan of
session `wb2-street` found the nearest tourists at ~10.2-10.5 m with long
empty stretches between (the idea's cited 14.5/16.0 m pair did not reproduce
in the scan — the sparsity itself is the confirmed finding). DESIGN promises
"café tables" street life (`docs/DESIGN.md:73-74`), and T-017 gave 104
fronts an awning with nothing under it. Tables give the awning a reason to
exist and make street level read inhabited even where no loop-walker is.

## Acceptance criteria

- [x] Table count equals the deterministic awning count — 104 at the M1
      seed: every `has_awning` building gets exactly one table on its street
      face; non-awninged buildings get none. *(Scenario: spots 104 == awnings
      104; foreign seed 424242 gets 90 == its own awning count.)*
- [x] Every table sits on its building's street face in the sidewalk band:
      center ~9.8 m from the block center (≥ 0.5 m inside the 10.9 m tourist
      ring line), ≥ 1.0 m from every `City.bread_spots` entry of that block
      (covers bench seats and the bread ring) at the M1 seed, ≥ 1.2 m
      edge-to-edge from the door line. *(Measured at M1: 9.82 m out along the
      face normal = 1.08 m inside the 10.9 m loop line; min bread-spot
      distance 2.70 m; min door edge gap 1.275 m. Readings under which this
      holds are pinned in Decisions — the corner-ward side and the block-radius
      bread attribution; see the measured conflict with the alternative
      readings.)*
- [x] Sitters are seated NPCs on layer 3 like the elders (`StaticBody3D`,
      layer 3, mask 0), 1-2 per table by a pure index rule, zero RNG; a
      grounded pigeon can waddle up to and perch beside a table. *(Scenario:
      156 sitters, layer 4 / mask 0, even/odd rule, palette shirts by index;
      the pigeon settles grounded beside table 0 and a waddle aimed into the
      tabletop stops dead at its edge.)*
- [x] Zero new RNG anywhere: `_shop_rng` roll order untouched (awning pin
      104 holds), layout stream untouched, fingerprint hash byte-identical
      to pre-T-031. *(Probe, same binary: seed 20260928 → 2492360539 and
      424242 → 2662825400 before and after the change.)*
- [x] *(Gate 1b)* `city_cafe_tables_present`: on a real generated City —
      `cafe_spots.size()` equals the awning count; every spot recomputable
      from its building's `door_face`/`size`/`lot_offset` (< 0.01 tolerance);
      regenerating the same seed reproduces the spot list byte-identically;
      a spawner rig seats tables-with-sitters exactly on the spots
      (`elder_placement_no_rng` template, `tests/sim_test.gd:1065-1112`).
- [x] *(Gate 1b)* All four T-007 tourist scenarios, both T-017 shopfront
      scenarios and T-018 `density_cpu_budget` stay green with ~104 tables
      and ~156 static sitters live. *(Full suite in one run: 74 PASS, 0 FAIL;
      density budget median 240.7 vs 750 ms per 100 frames with the furniture
      in; 18 tourists + 36 cars asserted.)*
- [x] [screenshot] Street level: an awninged front reads as a cafe — table
      and seated people under the awning, not a bare door slab. *(Captured
      from the real main scene at eye level: `.captures/t031_street_cafe.png`
      — awning canopy, table, two seated figures in tourist-palette shirts;
      autoplay frames carry the same furniture. Human judgement pending in
      Gate 3.)*

## Decisions & tuned values

- **Side rule (measured):** the ±2.2 m along-face offset goes CORNER-WARD —
  `sign` of the `lot_offset` component along the face, the ticket's literal
  "side picked by the `lot_offset` sign". The block-center side was measured
  and is unsatisfiable: at the M1 seed a ±4 m-RNG bench lands 0.148 m from a
  table (bench-seat clearance structurally doomed — ~19% kiss probability per
  table at any seed), while corner-ward clears every bench at every seed
  (≥ 2.45 m structural) AND holds the ticket's own numbers exactly: 9.82 m
  out along the normal (1.08 m inside the 10.9 m loop line, the ~0.63 m
  walker clearance to the leg) and 1.275 m door edge-to-edge (the "~1.3 m").
- **Bread-spot attribution (measured):** "bread spots of that block" uses the
  block's radius (spots within `block_size * 0.5` of the block center) — the
  only reading under which the criterion is satisfiable, since the corner
  bread-ring spots (±9.75, ±6.5) sit at radial ~11.7 m and belong to no
  block. Under the square-slab attribution every corner-ward table would sit
  0.086 m from a ring spot (they share the corner line), so the ring-corner
  spots are excluded by the block window, not by distance. **Accepted edge:**
  where a corner-ward table and a corner bread-ring spot share a corner, that
  ring crumb lands within the table footprint and is unreachable — noted,
  not mitigated (the benches, the other ring spots and the plaza ring are
  unaffected; `crumbs_respawn` stays green).
- **Bench-kiss caveat resolved:** with the corner-ward rule the "Known edge"
  above (a foreign-seed bench kissing a table) cannot occur — the ±4 m bench
  jitter tops out 2.45 m short of the corner-ward table line at every seed.
  The visual-kiss risk named in the ticket body exists only for the
  block-center side that was rejected on measurement.
- Constants (`city.gd`): `CAFE_FACE_OUTSET` 0.12 (the shop band's outset),
  `CAFE_STANDOFF` 1.9, `CAFE_SIDE_OFFSET` 2.2, `FACE_NORMALS` (the
  `_add_shopfront` face order — roll order untouched). Table: 0.9 × 0.06 × 0.9
  top, surface at 0.72, solid layer-1 collider 0.9 × 0.72 × 0.9. Sitter:
  stool seat 0.45, torso 0.44 × 0.56 × 0.28, sphere head r 0.15, layer 3
  (value 4) mask 0; shirt = `Tourist.SHIRT_PALETTE[(spot_index + i) % 8]`,
  count = 2 if spot_index even else 1 (104 → 156).
- Gate 2 autoplay with the furniture live: `AUTOPLAY DONE ok=true …
  restart=true`, average fps 135 (60 fps criterion holds), DONE line format
  unchanged.

## Verification

Gate 1 (import exit 0, 0 SCRIPT ERROR/Parse Error; 120-frame boot exit 0 —
the ObjectDB-at-exit warning reproduces on the pristine checkout) + Gate 1b
full suite in one headless run: `godot --headless --fixed-fps 60 --path .
res://tests/sim_test.tscn` → **74 `SIM PASS` lines, 0 failures, exit 0**
(73 → 74 with `city_cafe_tables_present`; explicit re-runs all green:
`tourists_walk_loose_groups`, `tourist_splat_panics_scores`,
`tourist_buzz_flinch`, `tourists_recycle_around_player`,
`city_shopfronts_present`, `city_shopfronts_deterministic`,
`elder_placement_no_rng`, `density_cpu_budget`) + Gate 2 (`AUTOPLAY DONE
ok=true`, `restart=true`, fps 135, no SCRIPT ERROR) + Gate 3 pending.

**Pending human playtest (Gate 3):** new lines — "awninged fronts read as
cafes at eye level" [screenshot: `.captures/t031_street_cafe.png`]; "low
street-level flight past cafe tables doesn't snag, and tables don't crowd
the tourist path" (the T-017 awning-snag line's ground-level sibling).
