# Four-way stop (US all-way stop intersection) — research note (T-134)

## The thing

A four-way (all-way) stop: a 4-leg intersection where EVERY approach has a red
octagonal STOP sign plus a painted stop line, and the right-of-way protocol is
"everyone stops, negotiated order" — the US default for low-speed city streets.
This is the real-world counterpart of the T-134 traffic system: right-hand
lanes, stop-line-first behavior, first-arrived-goes, simultaneous arrivals
yield to the right, crosswalk yield, stop-sign/speed-limit props.

## The facts that matter for the game

- **Right-of-way protocol** (Wikipedia "All-way stop", fetched 2026-10-23):
  come to a FULL stop behind the stop line / crosswalk; pedestrians have
  priority. First vehicle to stop is first to go; vehicles already at the
  intersection have priority over new arrivals. If two arrive simultaneously,
  **the vehicle on the right goes first**. Two opposite vehicles may proceed
  together if both go straight; otherwise **straight beats left turn**, and
  right-turn beats left-turn (both enter the same road; the right-turner is
  nearer its lane). This maps 1:1 onto the ticket's rules — and its
  "no strict-FIFO court" clause is realistic: real 4-way stops run on
  arrival-order convention plus yielding, not a queue.
- **ORIENTATION (the T-069 lesson, stated explicitly):**
  - The **stop line is a solid white BAR ACROSS the road** (perpendicular to
    travel), spanning the incoming approach lanes ONLY — one bar per approach,
    on the approach side, never mid-road, never on the outgoing side.
    (Plan diagram: one horizontal bar per vertical road leg; every photo.)
  - The stop line sits **BEHIND (before) the crosswalk**: MUTCD 2009 §3B.16
    (fetched from mutcd.fhwa.dot.gov): stop lines 12–24 in (0.30–0.61 m)
    wide, "a minimum of 4 feet [1.2 m] in advance of the nearest crosswalk
    line"; with no crosswalk, 4–30 ft (1.2–9.1 m) from the near edge of the
    intersecting traveled way.
  - Crosswalk bars run ALONG the road (parallel to traffic), repeating ACROSS
    it; crosswalk boundary lines 6–24 in (0.15–0.61 m) wide (MUTCD §3B.18).
    Consistent with docs/references/zebra-crossing/research.md.
  - The car nose stops AT the line; crosswalk between car and intersection box.
- **Stop sign (MUTCD R1-1)** (Wikipedia "Stop sign", fetched): red octagon,
  white border and legend, all retroreflective. Standard size **30 in (76 cm)
  across opposite flats** with 10 in (25 cm) legend and 0.75 in (1.9 cm)
  border; larger (35 in / 89 cm) on expressways/multi-lane, smallest general
  use 24 in (61 cm). Bottom of sign ~**7 ft (2.13 m)** above the roadway
  (current MUTCD height, since 1971). Mounted on the RIGHT side of the
  approach at/just beyond the stop line (every photo). Post: galvanized
  perforated/U-channel steel strap post (closeup + Perry photos).
  - Two all-way variants in photos: separate white "ALL-WAY" plaque below the
    octagon (San Francisco, Silver Springs) vs "ALL WAY" printed on the sign
    face itself (Perry FL). Either reads correctly at game scale.
- **Lane geometry** (Wikipedia "Lane", fetched): US standard lane 12 ft
  (3.7 m); urban streets commonly narrower, 9–15 ft (2.7–4.6 m) overall range.
  Right-hand traffic: cars drive right of the double-yellow centerline
  (Silver Springs photo); a ~1.8 m car sits centered in its ~3.0–3.7 m lane.
  Grid streets one lane each direction → right-hand lane = right half of the
  roadway; left turns are made from just right of the centerline (rare, per
  ticket — matches real behavior where straight-through dominates).
- **Speed-limit prop**: white portrait rectangle, black legend ("SPEED LIMIT
  20/30/35" seen in photos), same ~7 ft mounting band and post style as the
  stop sign, standing on the right side of the roadway.
- **Turn signals**: US/intl regulation flash rate 60–120 pulses/min (1–2 Hz)
  (Wikipedia "Automotive lighting", fetched). Amber rear/front lamps. The
  ticket's "~2 s blink before each turn" = 2–4 flashes at the legal rate — a
  compressed version of real signaling, which is continuous from well before
  the maneuver (no fixed legal lead time in the fetched source).

## Common variants

Stop-line-only 2-way stops (sign on one street only) vs all-way (sign on every
approach — this ticket). ALL-WAY as plaque vs on-face legend. Continental
(striped) vs transverse (two-line) crosswalks. Rural flare vs urban grid
corner radii (~4.5–7.5 m curb radius on city streets, visible in the plan
diagram and SF photos). Solar flashers atop stop signs exist (dashcam photo)
but are extras, not the norm.

## What the game should copy vs simplify

Copy: one white stop bar per incoming approach (~0.4 m paint, one lane wide,
perpendicular to travel, ≥1.2 m before the crosswalk); octagonal red R1-1 sign
(30 in ≈ 0.76 m; at low-poly scale ~0.75 m octagon, ~2.1 m to sign bottom) on
a thin post at the right edge of each approach; ALL-WAY plaque below; optional
white/black speed-limit prop; the exact protocol ladder — full stop →
first-stopped-goes → simultaneous yields right → straight beats left →
yield to crosswalk occupants. Simplify: single lane per approach (no turn
pockets, no lane markings beyond centerline + stop bars), uniform bar offsets,
honk-then-pass replaces real indefinite queuing, blinker tell compressed to
~2 s at 1–2 Hz, no pavement STOP legends, no pedestrian chrome. Do NOT put
stop lines mid-road or rotate crosswalk bars across the road — that was the
T-069 inversion.

## Reviewed by

researcher (T-134 reference session, 2026-10-23): all eight files opened and
read in this session — all-way-stop-intersection-san-francisco.jpg,
four-way-stop-4waystop.jpg, silver-springs-all-way-stop.jpg,
all-way-stop-plaque-perry-florida.jpg, us-stop-sign-closeup.jpg,
dashcam-stop-sign-intersection.jpg, speed-limit-20-sign-southbridge-ma.jpg,
four-way-intersection-plan-diagram.png. Stop-bar orientation cross-checked
between the plan diagram and the street photos.

Honest notes: (1) No true AERIAL photograph of an all-way stop exists on
Wikimedia Commons — 13 searches (four-way stop / all-way stop aerial, drone,
from-above, stop-controlled aerial…) returned only signalized intersections in
other countries; the top-down slot is filled by Minh Nguyen's CC BY-SA plan
diagram, which shows the stop-bar/crosswalk geometry explicitly. (2) That
diagram file is 14.5 KB, under the >20 KB size heuristic: it is NOT broken —
verified by PNG magic-byte signature, IHDR dimensions 1280×1280, and visual
read; a 2048px render was attempted first and WAS broken (2009 bytes, bad
signature) and was deleted. (3) Discarded as off-target after viewing:
four-way-stop-seattle.jpg (traffic signal + crow, not a stop control),
four-way-stop-signal-outage-odot.jpg (near-black night shot of a signal
head), stop-line-before-crosswalk-eric-fischer.jpg (Bilbao, Spain — not a US
stop line), patterson-three-chopt-intersection.png (dusk shot of a signalized
intersection), speed-limit-30-sign-vermont.jpg (right subject but
foliage-obscured; replaced by the clean Southbridge CC0 photo).
