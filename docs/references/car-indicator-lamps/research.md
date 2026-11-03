# Car indicator lamps (turn signals / blinkers)

Reference for re-seating the four floating blinker boxes in `scenes/car.tscn`
(`BlinkFL/FR/RL/RR`, car.tscn:111-129) onto the T-124 Kenney-stretched sedan body.
All 8 images in this folder were downloaded and **viewed** this session (see
`Reviewed by` below).

## What it is

Direction indicators — "turn signals" (US), "blinkers", German *Blinkleuchte /
Fahrtrichtungsanzeiger* — are the **amber lamps at each corner of a car** that
flash to announce an intended turn or lane change. A conventional sedan has one
per corner (two front, two rear; up to four rear are legal), plus an optional
side repeater per side. The game's four corner boxes depict exactly these corner
lamps; the flash tell itself (T-134) is load-bearing splat-planning information.

## Real dimensions and placement

From the installation regulation (UN ECE R48) and equipment regulation (ECE R6,
now consolidated into R148), as summarized in the sources below:

- **Color:** amber (front and rear in Europe).
- **Height above ground:** 350–1500 mm. The game's y = 0.82 m station is inside the band.
- **Lateral:** no more than **400 mm from the outermost edge of the body**; the
  left/right pair at least 600 mm apart. Indicators hug the corners.
- **Flash rate:** 60–120 pulses per minute, all indicators on one side synchronous.
  The game's `blinker_hz = 2.0` (= 120/min, scripts/car.gd:79) sits at the top of
  the legal band — legal, and deliberately snappy for readability.
- **Size:** ECE R6-era direction indicators require a minimum illuminated/apparent
  surface of roughly **20 cm²** — so the smallest legal lens face is ~45 × 45 mm.
  Typical sedan corner lenses run **~100–200 mm long × 50–80 mm tall**, protruding
  **centimeters, not decimeters**. (The 20 cm² and the typical lens range: the
  minimum is from regulation; the typical range is estimated from the reviewed
  photos, not measured in person.)

## Orientation (explicit)

- The lens **face looks outward from the car**: front lamps face forward-and-outward,
  rear lamps rearward-and-outward, so a quartering viewer sees them — that is the
  entire purpose of the lamp.
- The lens sits **in or on the body surface**: either flush-set into the panel with
  a thin gasket line (modern: Aventador fender lamp, Charger rear lens) or mounted
  on a small bezel base that follows the panel curve (classic: Beetle, Isetta, Nash).
- Mounting always follows the body surface — the Beetle's fender-top pod shows the
  extreme case: the bezel conforms to the curved fender top and the amber lens angles
  forward/outward. **A real indicator never hovers off the fender line.**
- Variants: amber outer section of the headlight/taillight cluster (Cortina,
  Gordon-Keeble); separate small lens on fender/quarter panel (Aventador, Charger);
  round bezel lamp (Nash); fender-top pod (Beetle); side repeater as a strip in the
  mirror housing (Passat B5) or on the wing edge; historical mechanical semaphore
  arms ("trafficators") — wrong tech for this game, not pictured in the final set.

## What the game should copy vs simplify

**Copy:** small amber lenses **seated on the paint** at the four corner stations —
a lens roughly 0.15–0.18 m long × 0.05–0.06 m tall × ≤0.04 m proud (versus today's
0.14 × 0.12 × 0.30 m slabs). At the |z| ≈ 1.7–2.2 m stations the stretched Kenney
sedan's paint mesh only reaches |x| ≈ 0.70 and tops out at y ≈ 0.72 (owner's
measurement against `assets/generated/models/cars/car_paint.res`), so the lamps
must pull in to that surface line rather than the old box-car corner (±0.85, 0.82).
y = 0.82 m itself is fine per R48. Keep the 2 Hz square-wave flash, dark at rest
(`Car._apply_blinker_meshes`, car.gd:584-587 — T-134 logic untouched).

**Simplify:** no housing, gasket, bulb or chrome bezel geometry — one flat emissive
amber box per corner reads correctly at game scale. Amber only (no red rear lamps).
No side repeaters needed — four corners are enough to read the tell.

**Robustness (the actual fix):** derive each mount from the paint mesh at `_ready()`
(the café hair-box AABB precedent in `cafe_spawner.gd` `_hair_offset`) so a future
re-bake of `car_paint.res` can never strand the lamps off the body again. The Gate 1b
"no float" assert (each blinker AABB intersects the body surface at its station)
matches what every reviewed photo shows: the lens always touches the panel.

## Reviewed by

researcher (this session, 2026-11-03). **Every image in this folder was opened and
viewed with the Read tool** — none is described from its filename or metadata alone.
Also viewed and **rejected** (then deleted) six candidates, honestly recorded here:
`isuzu-dmax-indicator-lens.jpg` (off-vehicle spare part, not a mounted lamp),
`man-truck-indicator-detail.jpg` (concept-truck camera pod, not a car corner lamp),
`caterham-side-repeater.jpg` (lamp illegible in frame), `turn-signal-09.jpg`
(mechanical semaphore arms — wrong tech), `saab-99-full-car.jpg` (indicators too
subtle to read), `citroen-2cv-rear-indicator.jpg` (too low-res).

**No true top-down/aerial photo of a corner indicator exists in this set** — at
10–20 cm scale a lamp is invisible from aerial imagery. The closest usable
equivalent is `vw-beetle-fender-indicator.jpg`, shot from above fender height
looking down at the fender-top lamp seated in its bezel; the Isetta and Aventador
shots cover the flush-set angles. Stated plainly rather than padded with a photo
that does not show the subject.

## Sources

- Hella Tech World, "Signal lights in cars" — fetched this session; amber,
  350–1500 mm height, ≤400 mm from outermost body edge, ≥600 mm pair spacing,
  60–120 flashes/min synchronous, 2 front / 2–4 rear / 0–1 side per side:
  <https://www.hella.com/techworld/us/technical/automotive-lighting/signal-lights-in-cars>
- UNECE R48 (installation) and R148 = consolidated R6/R7/R38 (equipment) — located
  via web search this session: <https://unece.org/sites/default/files/2021-05/R148e.pdf>,
  <https://unece.org/sites/default/files/2025-04/R048r13e_0.pdf> (PDFs not fully
  read; regulatory numbers above are as summarized by the Hella page and search results).
- Web search this session: ECE R6 minimum illuminated surface 20 cm² for direction
  indicators (historical requirement, folded into R148).
- Game side: `scenes/car.tscn:109-129` (blinker nodes + transforms), `scripts/car.gd:78-79`
  (`blinker_lead`, `blinker_hz` and the legal-band comment), `scripts/car.gd:584-587`
  (`_apply_blinker_meshes`).
