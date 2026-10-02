# Plaza bench ring — research note (spawn-plaza bin/bench clipping fix)

Companion note to `../plaza-litter-bin/research.md` (the bin/bench *pair* and its
gap convention, written minutes earlier from the same ticket-forge pass). This
note covers the *arrangement* the fix is about: a ring of benches around a plaza
landmark, with bins placed outside the seating line.

## What it is

A **plaza bench ring**: discrete benches arranged in a circle (or arc) around a
central feature — fountain, bandstand, statue — with the seats **facing the
landmark** (backs to the outside). It is one of the most common formal seating
layouts in the world; every kept reference shows it:

- Bench ring around a bandstand, with walk-in entry gaps in the ring and a
  litter bin standing just behind the bench line on the paving
  (`benches-around-bandstand-pontypridd.jpg` — the anchor image).
- Bench ring around a circular fountain/planter, seen from above the planting
  (`benches-around-fountain-geograph.jpg`).
- A named landscape-architecture archetype: Jens Jensen's **council ring** —
  "low circular benches with a small opening at one end", built "to encourage
  neighbors to come together as equals" (GC America, fetched 2026-10-02;
  see Sources). Examples: `council-ring-glacial-lakes.jpg` (backless curved
  stone benches facing a center), `henry-cool-park-benches.jpg` (discrete
  benches ringing a planting, large gaps).
- Variant: one continuous **circular bench** instead of discrete straight ones
  (`circular-bench-port-glasgow.jpg`).
- The landmark-centered furniture zone from directly above — café tables, not
  benches, but it shows the layout convention from the air
  (`dulmen-marktplatz-jubilaeumsbrunnen.jpg`).

## Real dimensions and proportions (with units)

Fetched directly from Wabash Valley's bench-dimensions guide (2026-10-02):

- Seat height: 18–19 in ≈ **0.46–0.48 m**; seat depth 15–20 in ≈ **0.38–0.51 m**.
- Length: a **6 ft (1.8 m)** bench seats 3–4 adults; 8 ft seats 4–5. The game's
  1.8 m bench (`scripts/city.gd:1159`) is the standard real length.
- Spacing: benches **6–8 ft (1.8–2.4 m) apart** in parks.
- **36–48 in (0.9–1.2 m) of clear space around each bench**; ADA wants at least
  48 in (1.2 m) clear beside a bench.
- Council rings have **no standardized diameter** — neither the fetched GC
  America article nor my searches produced one; Jensen's rings varied by site.

## Orientation of the parts (explicit)

- **Benches face the landmark**: seats on the outer ring, backs to the plaza
  edge, facing the center in every ring photo. The game matches this — bench
  yaw = `ang + PI/2` (tangent), `scripts/city.gd:1081` — though its benches
  carry no backrest geometry, so facing is cosmetic there.
- **People enter the ring through gaps between benches**: the Pontypridd path
  passes through a gap in the ring; Henry Cool Park leaves very large gaps.
  Real rings are never a solid wall of bench.
- **Bins stand on the paving, offset from the bench line — never on it**:
  Pontypridd's bin sits just behind the ring near the entry gap; the Moscow
  photo shows bins slotted between bench runs at the path edge. The
  bin-beside-bench gap (≈0.3–1 m) and the "adjacent to seating" placement rule
  are documented in `../plaza-litter-bin/research.md` (its photo set and its
  fetched sources; not re-fetched here).

## The game's current clipping, in these terms

All code values read directly this session:

- 8 benches on an 8.0 m ring at all 8 azimuths; footprint 1.8 × 0.5 m, so the
  bench band is radially 7.75–8.25 m (`scripts/city.gd:1078-1081`,
  `scripts/city.gd:1159-1162`).
- Bins at (±5.5, ±5.5) → center radius √(5.5²+5.5²) ≈ 7.78 m — the four
  diagonal azimuths, shared with four of the benches
  (`scripts/city.gd:1089-1091`). The bin box is axis-aligned 0.5 m (collider
  0.55 m, no yaw, `scripts/city.gd:1177-1180`), so on a 45° azimuth its
  **diagonal** faces the center: radial half-extent 0.25·√2 ≈ 0.354 m visual,
  0.275·√2 ≈ 0.389 m collider (computed with python this session).
- Overlap into the bench band: **0.38 m visual / 0.42 m collider**. The idea's
  "~0.28 m" understates it — it used the straight half-side and missed the
  diagonal factor. Same conclusion, worse magnitude.
- The fix's stated intent — bins on the diagonals, radially outside the ring,
  on the slab — matches the real convention (bins behind/beside the seating
  line). Real clear-space numbers put the bin center radius at:
  - 8.94 m for a minimal 0.3 m gap (what the photos show) → per-axis (6.3, 6.3),
  - 9.54–9.84 m for the 0.9–1.2 m ADA-ish clear space → per-axis
    (6.7, 6.7)–(7.0, 7.0).
  All of these sit well inside the plaza slab (edge 11.0 m from center per
  axis; `scripts/city.gd:209`, `scripts/city.gd:484`) and far clear of the
  corner lamps at (±9.8, ±9.8) (`scripts/city.gd:1090`), which are radially
  ≈13.9 m out. Exact radius is the ticket's call.

## What the game should copy vs simplify

Copy: the ring facing the landmark; walk-in gaps (the game's eight 1.8 m
benches on a 50.3 m circumference leave ~4.5 m average gaps — real rings are
gap-ier than solid, so this reads true); bins offset from the seating line with
a visible gap, standing on the paving. Simplify: straight tangent boxes instead
of curved benches (Pontypridd proves straight benches ring a circle fine); skip
backrests and the continuous-ring variant; the game's gaps are larger than the
1.8–2.4 m real spacing — acceptable for a readable game plaza, not a defect.

## Reviewed by

researcher (ticket-forge research pass, 2026-10-02). Opened and read all 8 kept
images: benches-around-bandstand-pontypridd, dulmen-marktplatz-jubilaeumsbrunnen,
benches-around-fountain-geograph, four-benches-bandstand-battersea,
henry-cool-park-benches, council-ring-glacial-lakes, circular-bench-port-glasgow,
moscow-vdnkh-fountain-benches. Also downloaded and viewed 2 candidates that were
then deleted as redundant/weak (seats-around-bandstand-battersea — same park and
bench type as the kept Battersea shot; ring-of-benches-sele — underexposed,
benches hidden by foliage). Honesty note on the aerial requirement: the only
true top-down found (Dülmen) shows café furniture around a fountain, not a bench
ring — after ~15 Commons searches (quoted phrases, category probes under
"Council rings", `filemime:image/jpeg` filters, English and German terms) no
top-down photo of a bench ring itself surfaced; the ring-layout facts above rest
on the elevated Pontypridd and fountain-geograph views plus the eye-level shots.
A first Port Glasgow download was 1.9 KB (broken); re-fetched via its thumburl
and verified as a 261 KB JPEG before use.

## Sources

Fetched and read directly (2026-10-02):

- Wabash Valley, "Standard Bench Dimensions Explained" — seat height/depth,
  6 ft bench capacity, 6–8 ft spacing, 36–48 in clear space, ADA 48 in —
  <https://wabashvalley.com/blogs/blog/standard-bench-dimensions>
- Garden Conservancy / GC America, "Benches: Sometimes More than Just a Place
  to Sit" — Jensen council rings: "low circular benches with a small opening at
  one end", egalitarian purpose; no diameter given —
  <https://www.gcamerica.org/news/get/id/2640>

Surfaced by web search but NOT fetched directly (not relied on): Landscape
Forms space-planning tips (≥0.6 m between same-facing benches, 1.5 m beyond
bench ends); Skokie IL design guidelines (1 seat per 100 ft² of plaza).

Repo material read: `../plaza-litter-bin/research.md` and `credits.md` (sibling
research note from the same pass — its metroSTOR/Broxap/Recycling-Bins-Direct
figures are cited on its own fetched authority, not re-verified here);
`scripts/city.gd` plaza/prop builders (lines as cited above).
