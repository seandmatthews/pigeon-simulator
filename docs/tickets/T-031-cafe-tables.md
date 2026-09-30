# T-031 — Cafe life under the awnings: tables with seated tourists on shop fronts

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
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

- [ ] Table count equals the deterministic awning count — 104 at the M1
      seed: every `has_awning` building gets exactly one table on its street
      face; non-awninged buildings get none.
- [ ] Every table sits on its building's street face in the sidewalk band:
      center ~9.8 m from the block center (≥ 0.5 m inside the 10.9 m tourist
      ring line), ≥ 1.0 m from every `City.bread_spots` entry of that block
      (covers bench seats and the bread ring) at the M1 seed, ≥ 1.2 m
      edge-to-edge from the door line.
- [ ] Sitters are seated NPCs on layer 3 like the elders (`StaticBody3D`,
      layer 3, mask 0), 1-2 per table by a pure index rule, zero RNG; a
      grounded pigeon can waddle up to and perch beside a table.
- [ ] Zero new RNG anywhere: `_shop_rng` roll order untouched (awning pin
      104 holds), layout stream untouched, fingerprint hash byte-identical
      to pre-T-031.
- [ ] *(Gate 1b)* `city_cafe_tables_present`: on a real generated City —
      `cafe_spots.size()` equals the awning count; every spot recomputable
      from its building's `door_face`/`size`/`lot_offset` (< 0.01 tolerance);
      regenerating the same seed reproduces the spot list byte-identically;
      a spawner rig seats tables-with-sitters exactly on the spots
      (`elder_placement_no_rng` template, `tests/sim_test.gd:1065-1112`).
- [ ] *(Gate 1b)* All four T-007 tourist scenarios, both T-017 shopfront
      scenarios and T-018 `density_cpu_budget` stay green with ~104 tables
      and ~156 static sitters live.
- [ ] [screenshot] Street level: an awninged front reads as a cafe — table
      and seated people under the awning, not a bare door slab.

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b full suite (73 → 74 with
`city_cafe_tables_present`; explicit re-runs: `tourists_walk_loose_groups`,
`tourist_splat_panics_scores`, `tourist_buzz_flinch`,
`tourists_recycle_around_player`, `city_shopfronts_present`,
`city_shopfronts_deterministic`, `elder_placement_no_rng`,
`density_cpu_budget`) + Gate 2 (tables visible in the autoplay screenshots;
DONE line unchanged) + Gate 3.

**Pending human playtest (Gate 3):** new lines — "awninged fronts read as
cafes at eye level" [screenshot]; "low street-level flight past cafe tables
doesn't snag, and tables don't crowd the tourist path" (the T-017
awning-snag line's ground-level sibling).
