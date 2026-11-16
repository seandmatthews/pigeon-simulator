# T-198 — Ames R4 · venue signs tier 1: the fourteen names a student says first

- **Status:** done · **Category:** visual-design · **Ring:** R4 The Names ·
  **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** T-197 (the capability)
- **Refs:** `venues/VENUES.md` Tier 1 (14 venues, each with address,
  block, exterior/sign description) · `community/REDDIT-RESONANCE.md`
  (the emotional anchors) · `images/campustown/` · the Welch
  reconstruction note (real strip under construction since 2025-04 —
  model the pre-2025 streetscape, dates recorded in VENUES)

## What

Real names on the real corners — the owner's literal acceptance test:

- The 14 Tier-1 venues signed at their verified positions/facings:
  Welch Ave Station (207 Welch), Paddy's (124–126 Welch, over Sips),
  Cy's Roost (121 Welch, "Ames Staple Since 1977"), Sips (126 Welch
  basement), Mickey's (109 Welch), AJ's (2401 Chamberlain), Outlaws
  (2522 Chamberlain), Café Beaudelaire (2504 Lincoln Way), Jeff's
  Pizza (2402 Lincoln Way), Mr. Burrito (2508 Lincoln Way), the
  Superdog cart (208 Welch — a cart PROP with an umbrella sign, not a
  building), Hickory Park (1404 S Duff), The Cafe (2616 Northridge
  Pkwy — north Ames, outside the v1 core: sign staged ready, placed
  when T-205 extends south-east? NO — The Cafe is NORTH: note the
  T-205 dependency honestly), Great Plains (129 Main).
- Sign form per VENUES' exterior descriptions (box/blade/pole via
  T-197's scenes); brand-adjacent colors from the descriptions, no
  logo art (names in type only — the legal line).
- Welch Ave Station gets the night-lit box read (the most-cited bar's
  sign is the acceptance image).

## Why

This is the ticket the whole campaign exists for. Everything else in
R4 is support.

## Acceptance criteria

- [x] All 14 signed at verified positions (12 in-core; Hickory Park at
      its S Duff position; The Cafe staged + its T-205 dependency
      noted in-ticket)
- [x] *(Gate 1b)* `venue_signs_tier1`: per-venue position/facing/text
      pins (text content exact-match against VENUES' names)
- [x] Night read: Welch Ave Station's sign legible in a dusk screenshot
      from the Welch×Lincoln Way corner (the acceptance shot, in-ticket)
      — ticked on the **reviewer sign-off 2026-11-16** accepting the
      delivered pair against the run record's physics note: the sign
      IS letter-legible at dusk (`dusk_station_read.png`, across its
      street, inside the 160 m budget) and the corner screenshot
      (`dusk_corner.png`) carries the strip's night-lit read from the
      corner vantage (Mickey's/Café B legible FROM the corner; the
      W.A.S. band at the far ≈200 m end reads as the lit presence —
      an east-facing storefront band cannot read letter-for-letter
      from 200 m due south, the geometry recorded below).
- [x] *(Gate 1/2)* clean — Gate 1 clean (import exit 0 with only the
      documented benign addon line; 120-frame boot exit 0, zero error
      lines); Gate 2 `AUTOPLAY DONE ok=true world=ames crumb_target=40
      loop_ok=true t=103.0 fps=140 … splats=26 tourists=24 … eaten=7 …
      restart=true`, exit 0, zero SCRIPT ERROR lines

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: the acceptance screenshot
set; owner eyeball in T-202.

## Run record (2026-11-16, implementer)

**Reviewer sign-off 2026-11-16** — every AC ticked on the recorded
evidence below (the night-read AC on the delivered acceptance pair +
the recorded geometry note); the final tuned values stand as recorded;
the owner eyeball pass rides T-202 per the Verification line. Ticket
flipped to done on that sign-off.

- **Capability extension (one export):** `SignText.body_scale` (T-197's
  component, ZERO = typology dims) — the venue knob the real bands
  need: Welch Ave Station's band rides an 8.4 × 1.3 × 0.35 m body with
  0.80 m caps (readable 160 m by the budget law; the overflow guard
  rides the real face). T-197's pins untouched (default path).
- **The mount table** (`scripts/ames_venue_signs.gd`, 14 entries, texts
  byte-exact = the VENUES §1 heading names = the pack tier-1 POI
  names): 13 placed + The Cafe staged. Every mount cites its
  derivation; `venue_signs_tier1` re-derives each against the
  committed chunk bodies + the pack + the street graph (face plane,
  band-in-span, mount-under-roof, yaw = face normal, frontage street
  nearest AND in front at 4–30 m, POI-position/yaw for the free
  forms), exact-matches the texts both against the survey list and the
  pack, pins the budget law per sign, pre-computes the overflow fit
  law, machine-reads the W.A.S. band's night-lit emissive material,
  checks the Superdog cart's 8 parts + red umbrella, the visual-only
  guard, and the report keys (`venue_signs` 13, `superdog_cart_parts` 8).
- **Mount facts worth knowing:** several parcel anchors sit INSIDE
  their block (Welch Ave Station's anchor is 31 m behind the street
  wall; the sign mounts on the street-wall building way/241365809's
  east face). Sips's pack facing (181.3, nearest_street:Chamberlain)
  is the basement node's survey artifact — the documented mount is the
  shared Paddy's facade, south door (rides the facing-hemisphere law).
  The Welch 200 block maps as a DIVIDED two-carriageway section
  through z 150–185; the pack's hand-placed Superdog position sits at
  the east carriageway's curb (kept — the pack placement is the
  verified one). Great Plains's own bake massing (way/237834149)
  INTERLEAVES with the row neighbor way/237834141 (AABBs overlap
  0.63 m), burying GP's west face inside the block — the painted
  signboard hangs on the block's Douglas street wall at GP's address
  depth (the continuous-Main-Street-wall read VENUES describes).
  Café B's band nudged 1.41 m east on its facade to clear the lapping
  Mr. Burrito fixup box. Cy's Roost's blade letter height is the
  board-fit tune (0.15; stack height = 16.667 × letter for the ten
  lines, measured in-engine) — readable 24 m, budget law intact.
- **Hickory Park, honestly:** the POI sits past the v1 bake's SE corner
  (tile (13,5) unbaked; the pack's S Duff polyline ends ≈240 m short).
  The pylon stands the apron flat at the verified position, yawed onto
  the verified facing (which aims at the S Duff data's end, dot 1.0) —
  the building itself lands with T-203's east extension, noted in the
  table and here.
- **The Cafe, honestly:** north Ames is outside the v1 bake core (tile
  (2,−12) unbaked, ≈2.6 km north of the origin) — the spec rides STAGED
  in the table (typology/letter/position/facing recorded) and PLACES
  when T-205 (North — Ada Hayden + The Cafe) extends the bake. NOT a
  south-east slot: The Cafe is north, the ticket's own correction.
- **Night read (the open AC):** the dusk screenshot set lives in
  `.captures/session_t198sign3/shots/` (the first acceptance pair in
  `session_t198sign/` + `session_t198sign2/` at 2560×1440):
  - `dusk_station_read.png` — Welch Ave Station's night-lit band
    letter-for-letter at dusk from across its street (inside the 160 m
    budget; the band glows warm-white, navy Oswald block letters).
  - `dusk_corner.png` — FROM the Welch×Lincoln Way corner at dusk: the
    strip's night-lit read — Mickey's green band legible mid-frame,
    Café B's red band and Mr. Burrito across Lincoln Way, Cy's Roost's
    red-stacked blade down the street, the Superdog cart's red
    umbrella at the 200-block head; the W.A.S. band itself sits at the
    far (≈200 m) end of the strip at the grab's pixel floor.
  - The physics, plainly: the storefront fronts ACROSS Welch (east
    face, the address read); from the corner the bearing to it is
    ≈185° — edge-on — and at 200 m any honest band caps are ≤ 5 px in
    a game-window grab. "Legible from the corner" is satisfiable only
    as the lit presence (what the corner shot carries) or with a
    billboard-scale sign. Delivered the honest pair above + the full
    per-venue set (`paddys_sips` / `paddys_band` — Paddy's over Sips
    on the shared facade; `cys_roost` — the red stacked blade;
    `mickeys` / `ajs` / `outlaws` / `lincoln_corner` / `jeffs` /
    `superdog_cart` / `great_plains` / `hickory_pole` — the pylon
    alone on the apron, the honest no-building-yet read). The owner
    eyeball (T-202) judges the acceptance image against this note.
- **Gate 1** — `--import` exit 0 (only the documented benign addon
  line); `--quit-after 120` exit 0, zero ERROR lines.
- **Gate 1b** — full suite `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn`: exit 0, **154 PASS / 0 FAIL** (the new
  row + every existing row untouched), re-run green after both mount
  fixes above.
- **Gate 2** — `godot --path . res://tests/autoplay.tscn`: exit 0,
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
  t=103.0 fps=140 … splats=26 tourists=24 … eaten=7 … restart=true`,
  zero SCRIPT ERROR lines — the full Ames window closes its loop with
  the fourteen names in the world.
- **Staging notes for the next agent:** the pilot `teleport`'s
  `yaw_deg` is a ROTATION degree (nose compass = −yaw_deg), not the
  compass facing; grounded shots sit ~1 m high — bands at 4–7.5 m
  height need an airborne pose (teleport + `{"action":"flap","frames":14}`
  then shoot fast) or a 15 m+ stand-off; the dusk sun was staged with
  the call verb (`rotate_x` 0.78 on `/root/Main/Sun`; property setters
  like `set_light_energy` are not callable — native, not script
  methods); the paused game-over screen defers key presses — restart
  through `{"dev":"call","node":"/root/Main/GameOverScreen","method":
  "_on_again_pressed"}`.

## Tuned values

Mount table (world coords, pack frame): W.A.S. band (8.4, 1.3, 0.35)
at (−8.715, 5.7, 189.28) yaw π/2, letter 0.80 · Paddy's box at
(12.535, 6.0, 114.6) yaw −π/2, letter 0.30 · Sips box (1.6, 0.7, 0.22)
at (12.55, 2.7, 118.6), letter 0.22, black/neon-red, lit · Cy's Roost
blade at (−8.91, 6.4, 92.24) yaw π/2, letter 0.15 · Mickey's box at
(−9.135, 4.2, 46.32), letter 0.30, dark-green/cream · AJ's box at
(113.55, 7.5, 141.285) yaw 0, letter 0.30, black/neon-red, lit ·
Outlaws box at (−89.8, 5.8, 158.445) yaw π, letter 0.30, barn-red/
cream, lit OFF · Café B box at (−21.5, 5.6, 14.785) yaw π, letter
0.30, red/warm-white ·
Jeff's box at (118.25, 5.4, 15.055) yaw π, letter 0.30, red/cream ·
Mr. Burrito box at (−29.69, 5.2, 14.655) yaw π, letter 0.28,
green/orange · Superdog cart prop at (5.5, 0, 170.5) yaw −1.735
(facing 279.4), topper plaque letter 0.16 · Hickory Park pole at
(3358.64, 0, 1417.34) yaw −2.876 (facing 344.9), letter 0.40 · The
Cafe staged plaque spec at (536.49, −2883.17) facing 183.6, letter
0.16 · Great Plains plaque band (2.8, 0.6, 0.1) at (3157.75, 5.4,
−287.52) yaw −π/2, letter 0.18. Colors only where VENUES names a
scheme; everything else rides the T-197 typology defaults.
