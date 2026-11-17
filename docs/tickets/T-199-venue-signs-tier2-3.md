# T-199 — Ames R4 · venue signs tiers 2–3 + the ghost plaques

- **Status:** done · **Category:** visual-design · **Ring:** R4 The Names ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-198 (tier-1 pattern proven)
- **Refs:** `venues/VENUES.md` Tiers 2–3 (34 venues) + the 17-entry
  closed/mourned list · `community/REDDIT-RESONANCE.md` trends section
  (Es Tas eviction 12/2024, Little Taipei closing, Hickory Park sale
  8/2019) · master plan §11.4 (ghost-plaque fork, default yes,
  tone-checked)

## What

1. **Tiers 2–3 signed** at verified positions (the same component and
   rules as T-198; UNVERIFIED-status venues from the 8-flag list get
   signs ONLY after a status re-check recorded in-ticket).
2. **Ghost plaques** (owner-decided 2026-11-09: yes, memorial
   styling): the mourned closed venues get a small memorial plaque
   styling — a modest ground-floor plaque, never a glowing sign: "Es
   Tas — 2024" reads as love, not haunted-house kitsch. The list is
   dated and sourced; the styling is reviewed against the tone
   guardrail in this ticket's review round.
3. Naming discipline: all names exactly as VENUES records them; no
   slogan/tagline text (legal line: names in type, no trade dress).

## Why

Tiers 2–3 + the ghosts are the depth that turns "a college town" into
"Ames" for the people who knew it — and the mourned list is itself the
dated snapshot the owner asked the survey to be.

## Acceptance criteria

- [x] Tier-2/3 signs placed at verified positions (count pinned);
      every UNVERIFIED venue either re-verified or unsigned (recorded)
- [x] Ghost plaques at the pinned mourned list positions, memorial
      styling, tone-checked in review *(ticked on the reviewer
      sign-off 2026-11-16 accepting the delivered set against the run
      record: the plaques placed and machine-pinned at the pinned §6
      rooms, the memorial styling constants enforced by the gate, and
      the tone read carried by the recorded shots — "Es Tas Bar &
      Grill — 2024" bronze at ground floor, love not kitsch)*
- [x] *(Gate 1b)* `venue_signs_tiers`: text/position pins; plaque
      styling constants
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-202.

## Run record (2026-11-16, implementer)

**Reviewer sign-off 2026-11-16** — every AC ticked on the recorded
evidence below (the plaque tone check on the delivered shots +
machine-pinned styling); the final tuned values stand as recorded; the
owner eyeball pass rides T-202 per the Verification line. Ticket
flipped to done on that sign-off.

- **The mount tables** (`scripts/ames_venue_signs.gd`): `SIGNS_T2`
  (15 entries) + `SIGNS_T3` (12) — 27 of the 34 Tier-2/3 POIs signed,
  texts byte-exact = the VENUES §2/§3 heading names = the pack POI
  names; `PLAQUES` (11 entries) — the §6 mourned CLOSED venues whose
  rooms the committed bake pins. Same component and rules as T-198:
  wall mounts on the pinned bake body's street wall (face plane ± the
  stand, band inside the face span, mount under the body top, yaw =
  the face normal), free-standing forms at the pack POI yawed onto its
  verified facing, letters measured in-engine against the face-fit law
  (widths quoted in the table comments are the real Oswald
  measurements at cap height 1.0), colors only where VENUES names a
  scheme, no logo art. The world builds them under separate roots
  (`VenueSignsTiers`, `GhostPlaques`) so the T-198 subtree and its
  gate pins stay byte-identical; report keys `venue_signs_t23` 27,
  `ghost_plaques` 11, `cq_truck_parts` 6.
- **The unsigned set, recorded** (`UNSIGNED_T23`, machine-pinned by
  the gate as POI ids − signed tables == these keys): mucky_duck_pub
  (no OSM anchor anywhere in the extract — unplaced);
  lost_and_found_lounge (UNVERIFIED flag, re-checked — see below);
  labyrinth_coffee (unplaced; UNVERIFIED exact suite at 159 Sheldon);
  restaurant_888 / perfect_games (north Ames, no committed position);
  el_azteca (two locations, no committed position); whatcha_smokin
  (out of Ames entirely — Luther).
- **The §7 UNVERIFIED re-checks (web, 2026-11-16), recorded per the
  ticket law:**
  - *Stomping Grounds Cafe* — RE-VERIFIED open: an Aug 31 2025
    feature calls it a living campus staple, and Oct 2025 Ames Green
    Drinks events were planned on its 303 Welch patio. SIGNED.
  - *Cafe Diem* — RE-VERIFIED active: May 2025 Main Street
    promotions, the downtown directory listing, Sunday hours; the
    summer-closure flag is the seasonal rhythm the survey itself
    cites. SIGNED.
  - *Thumbs* — re-check found a neighboring West Street business
    (Billy Jack's Shack) cross-promoting Thumbs for patio season
    around graduation week ("#ThumbsUpAmes #weststreetwasted") — a
    second, independent local source, but soft-dated. SIGNED WITH THE
    STRENGTH RECORDED here and in the table note; the survey graded
    the flag low-risk.
  - *Lost and Found Lounge* — REFUTED: listing reported
    permanently closed, community references past-tense, no 2025-26
    operation evidence. UNSIGNED (and NOT added to the plaque set —
    it is not in the ticket's pinned mourned list, and the source
    strength is below the survey's own bar).
- **The ghost plaques** — 11, the §6 rows whose rooms the committed
  bake pins: Es Tas Bar & Grill — 2024 (the vacant 120 Welch room,
  way/241365813 — the fly-through's own "[120 vacant — ex-Es Tas]";
  the 216 Stanton flagship half of the story trades live as The Stan
  Tap, noted) · Wise Guys (the SAME room, offset along the wall — the
  room's timeline; no survey-pinned year, so name alone) · Little
  Taipei — 2024 (the building is NAMED in the bake:
  way/241365808) · Fighting Burrito — 2019 (the 117 Welch room —
  VENUES 3.4 itself says Ichiban occupies the old Fighting Burrito
  slot; the plaque rides that wall under the live sign) · The Scene
  (between Paddy's two doors on the shared facade — the license
  literally reads THE SCENE, LLC DBA Sips and Paddy's; no pinned
  year) · Café Mood (under Macubana on the 116 Welch wall; no pinned
  year) · DG's Tap House + Corner Pocket — 2019 (Sam's Place's
  building, the census's own note) · Olde Main Brewing — 2019
  (way/254335401 — 316 Main, even address, SOUTH side: the north wall
  is the Main street wall) · Legends — 2012 (Legacy Tower's ground
  floor under the Clouds band) · Battle's Bar-B-Q — 2009 (the
  original 112 Hayward room, way/231767135; the later 218 Welch slot
  is way/241365819, recorded here) · The Angry Irishmen — 2025
  (Mary Jane's building; Mary Jane's replaced it by March 2026, so
  2025 is the last full year the survey's own dates pin).
  **Recorded unsigned from §6:** People's + Charlie Yoke's (the
  unbuilt 2430 Lincoln Way room), One Night Stand (ambiguous room —
  listed 121/124 Welch; both candidate rooms trade as live signed
  venues), Hickory Park (SOLD-not-closed — a memorial would mourn a
  living business; the tone law), West Towne Pub (Westown Pkwy,
  outside the bake), Cocost (no address at all). The year rides a
  plaque's text only where the survey pins a closure year.
- **Memorial styling (the tone law in machine form):** every plaque is
  the PLAQUE typology at a ground-floor mount (y ≤ 2.0), letter
  ≤ 0.16, the bronze/parchment pair (`PLAQUE_MEMORIAL_BODY`
  0.30/0.26/0.20, `PLAQUE_MEMORIAL_TEXT` 0.86/0.80/0.63), unlit —
  the gate reads the constants off the live materials and REFUSES a
  lit plaque. "Es Tas — 2024" reads as love, not kitsch; the owner
  judges it in this ticket's review round (T-202 fold-in).
- **Mount facts worth knowing:** the pack POI for dogtown_university
  sits MISPLACED (inside the Kingland/23-Twenty massing) while its
  own src line names the census's Welch Crown Center way — the mount
  derives from THAT committed way (way/259249457, addr 217 Welch);
  the POI data fix rides a later pack ticket, recorded in the table
  note. West Street maps as an E-W street through the row (centerline
  z ≈ −283): Mother's/Thumbs/the Deli front NORTH onto it — the
  "two doors north of" addresses are postal, the buildings face the
  street they're on. BNC's and Time Out's pack facings (1.3 / 89.3)
  are nearest_street artifacts — the frontage law pins the wall (the
  law-shape change vs the tier-1 row is recorded in the scenario
  header). Cornbred's depot fronts Main across a 56 m set-back (the
  pinned 30–70 band); Provisions Lot F and Szechuan House stand
  apron pylons at their out-of-core POIs (the Hickory rule); Carlos
  Quesadilla rides a box-van truck prop at the Jack Trice gameday
  POI (the Superdog-cart rule). Iowa State Creamery's Farm House Lane
  is not in the street graph — the campus-interior read rides the
  POI's committed facing.
- **Screenshot ledger** (`.captures/session_t199signs/`, pilot
  hidden window per T-170, muted, traffic frozen for the pose):
  - `ghost_plaques_120_welch.png` — the two bronze plaques ("Wise
    Guys", "Es Tas Bar & Grill — 2024") on the vacant room's street
    wall, ground-floor, unlit — the memorial read, live.
  - `dogtown_welch_crown.png` — the cardinal-and-gold Dogtown
    University band on the Crown Center wall, live.
  - **Honest limitation, recorded:** street-level close poses in the
    FAR districts (West Street ≈600 m out, downtown Main ≈3.2 km
    east) render void under the chase camera — the ground/roads
    render but the massing boxes of those chunks do not draw at
    close range (the same districts read fine from the air; the
    near-origin Welch strip renders at all ranges, both T-198's and
    this ticket's shots prove it). The gate re-derives every
    far-district mount from the committed chunks independently, so
    the machine pin does not depend on the camera; the owner/agent
    visual pass for the far districts rides T-202's aerial pass.
- **Gate 1** — `--import` exit 0 (the single documented benign addon
  line, "resources still in use at exit"); `--quit-after 120` exit 0,
  zero ERROR lines.
- **Gate 1b** — full suite `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn`: exit 0, **SIM SUMMARY: 0 failure(s)** —
  the new `venue_signs_tiers` row green (tables 15/12/11, unsigned
  set closed, every mount re-derived from the committed chunks +
  pack, frontage by the survey street name, memorial styling
  machine-read, report keys) and every existing row untouched
  (`venue_signs_tier1` still PASS).
- **Gate 2** — `godot --path . res://tests/autoplay.tscn`: exit 0,
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
  t=103.0 fps=138 … splats=26 tourists=24 … eaten=7 … restart=true`,
  zero SCRIPT ERROR lines.

## Tuned values

Mount tables (world coords, pack frame; the full derivation per entry
lives in the table notes): Mother's Pub & Coffee box at (−579.62,
3.4, −273.07) yaw π letter 0.26 · Thumbs box at (−524.01, 2.6,
−273.96) yaw π letter 0.30, dark/cream, lit OFF (painted) · West
Street Deli box at (−498.88, 2.6, −274.34) yaw π letter 0.26, lit OFF
· BNC Field House band (4.2, 1.0, 0.28) at (24.18, 2.6, 175.99)
yaw −π/2 letter 0.30 · Blue Owl Bar box at (−11.56, 5.4, 264.06)
yaw π/2 letter 0.28 · Cornbred Barbecue box at (2635.76, 2.6,
−195.07) yaw π letter 0.26 (the 56 m set-back) · Whiskey River box at
(3168.41, 5.2, −250.21) yaw π letter 0.30 · London Underground box at
(3116.26, 5.2, −248.77) yaw π letter 0.26, near-black/dim, lit OFF
(the no-lights pub) · Time Out box at (3033.63, 3.4, −113.76)
yaw −π/2 letter 0.30 · Torrent Brewing box at (2885.94, 2.8, −401.38)
yaw −π/2 letter 0.22 · Aunt Maude's plaque at (2570.01, 5.4, −261.68)
yaw 0 letter 0.18 · The Grove Cafe box at (3193.27, 5.2, −250.69)
yaw π letter 0.28 · Provisions Lot F pole at its POI (1196.24,
2472.29) facing 9.8 letter 0.32 · The Stan Tap box at (146.53, 5.4,
212.64) yaw −π/2 letter 0.28 · Sam's Place box at (3179.49, 5.2,
−274.31) yaw 0 letter 0.30, dark glass/cream · Stomping Grounds box
at (−13.20, 5.4, 302.44) yaw π/2 letter 0.24 · Clouds box at
(125.28, 27.0, 92.72) yaw π/2 letter 0.50 (the 7th-floor band) ·
Ichiban box at (−9.67, 2.6, 80.5) yaw π/2 letter 0.20, dark/red
lantern · Blue Fish Poke box at (−7.26, 4.6, 112.62) yaw π/2 letter
0.26 · Macubana box at (10.99, 5.2, 78.47) yaw −π/2 letter 0.30 ·
Dogtown University box at (−9.10, 4.2, 233.23) yaw π/2 letter 0.26,
cardinal/gold · Thai Kitchen box at (75.56, 5.6, 159.69) yaw π letter
0.28 · Szechuan House pole at its POI (−1440, −8) facing 96.3 letter
0.32, red/gold · Carlos Quesadilla truck at its POI (1190.07, 974.12)
facing 359.4, topper letter 0.16 · Iowa State Creamery plaque at
(679.87, 3.0, −452.53) yaw π/2 letter 0.16 · Morning Bell box at
(3230.16, 5.0, −275.48) yaw 0 letter 0.19 · Cafe Diem box at
(3041.24, 5.0, −271.73) yaw 0 letter 0.28. Ghost plaques: Es Tas
(wall_u 92.0), Wise Guys (88.6), Little Taipei (−51.16 N), Fighting
Burrito (78.0 E, y 1.2), The Scene (116.6 W, y 1.4), Café Mood
(76.2 W, y 1.4), DG's (3183.4 S, letter 0.13, band 2.8), Olde Main
(2932.4 N), Legends (96.5 E), Battle's (56.81 W), The Angry Irishmen
(3206.22 S) — all mount_y ≤ 1.5, letter ≤ 0.16, the bronze/parchment
pair, unlit.
