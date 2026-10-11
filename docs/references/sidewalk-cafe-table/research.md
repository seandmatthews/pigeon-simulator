# Sidewalk café table — reference research

Concept slug: `sidewalk-cafe-table`. Context: the game's bread crumbs should mostly
spawn on the café tables T-031 already places in front of awninged buildings
(`scripts/city.gd`, `_build_cafe_spots`), because that is where humans actually
have food within reach. This note records what real sidewalk café furniture looks
like so the ticket writer and implementer place table bread plausibly.

## What it is

A sidewalk café (pavement café, café terrace, terrasse) is café seating placed on
the public sidewalk/street directly outside the café's street frontage, almost
always under the shop's awning or freestanding parasols. The furniture is small,
light, and weather-rated: pedestal-based tables with 1–4 stacking chairs each,
laid out in rows parallel to the facade. Food and drink (bread, croissants,
plates, cups) sits **on the tabletop**, at the height of a standing adult's
mid-thigh to waist — nowhere near the ground. This is precisely the "bread where
humans could reasonably be eating" placement the game owner wants: a crumb on a
café tabletop is the natural, everyday sight; a crumb on a rooftop is not.

## Real dimensions and proportions

Standard furniture figures (common café-furniture dimensions), cross-checked
against proportions visible in the photos:

- **Tabletop height:** 0.73–0.76 m above the pavement (0.75 m is the common
  standard). Corroborated in `terrasse-cafe-paris-munhoven.jpg` (tabletop rims at
  roughly the standing waiter's upper-thigh/hip level) and `terras-halle-2023.jpg`
  (top at the seated woman's waist/rib level). For a 1.75 m adult that is ~42% of
  body height.
- **Round bistro tops:** Ø 0.50–0.70 m. The Paris row shows very small tops
  (Ø ≈ 0.5–0.6 m, one or two chairs each); `st-gallen-sidewalk-cafe.jpg` shows
  larger round tops (Ø ≈ 0.7 m) with 2–4 chairs.
- **Square tops:** 0.60 × 0.60 m (2 seats) up to 0.80 × 0.80 m (4 seats)
  (`terras-halle-2023.jpg`, `wiki-takes-porto-pausa-cafe.jpg`).
- **Tabletop thickness:** stone/marble 0.02–0.03 m; wood 0.02–0.04 m.
- **Pedestal:** single central column Ø 0.06–0.09 m on a cast foot ~0.40–0.55 m
  across (visible under every table in `st-gallen-sidewalk-cafe.jpg` and
  `terras-halle-2023.jpg`). Four-leg frames exist but the pedestal type dominates
  street café furniture.
- **Chairs:** seat top ~0.45 m (i.e. ~0.28–0.30 m below the tabletop), seat
  0.40–0.45 m wide, armless and stackable; in `where-is-my-seat-topdown.jpg`
  most chairs are tucked under the tabletop, 2–4 per table.
- **Spacing:** rows run parallel to the facade at a pitch of roughly 1.5–2.0 m
  between table centers (`where-is-my-seat-topdown.jpg`, the Paris row), leaving
  ~0.45–0.60 m of clear walkway between a chair back and passing pedestrians.
- **Food scale:** a bread roll/croissant plate is Ø 0.20–0.25 m
  (`cafe-breakfast-croissant-table.jpg`) — crumbs occupy a few centimetres of a
  0.6–0.9 m top, usually near the edge where the eater sits.

## Orientation of parts (explicit)

- The **tabletop is horizontal**, carried on a **central vertical pedestal**
  (column down to a ground foot); it is not tilted or wall-mounted.
- Tables repeat **ALONG the facade line** and stand **OUT from it** on the
  sidewalk — a standoff of ~0.5–2 m from the shopfront/awning plane, never
  inside the doorway itself.
- **Chairs face the table across it**, one per side on small tops (the Paris row
  literally alternates chair–table–chair along the facade), so a 2-top has its
  two sitters on opposite sides, facing each other.
- **Food lies flat on the top surface**, within an arm's reach of a seated
  person's edge of the tabletop.
- Parasols either pass through a **center hole in the tabletop** (Halle) or stand
  free beside the table group (Herengracht); awnings over the terrace belong to
  the building, not the furniture.

## Common variants

1. **Paris bistro row** (`terrasse-cafe-paris-munhoven.jpg`): single-file row of
   tiny round marble tops hard against the facade, rattan bistro chairs, one
   waiter standing.
2. **Parasol square-tops** (`terras-halle-2023.jpg`): 0.7–0.8 m wood square tops
   on pedestals under branded parasols, wicker-look chairs, street and parked
   cars directly behind.
3. **Awning-door plastic sets** (`wiki-takes-porto-pausa-cafe.jpg`): red plastic
   tables and chairs clustered right at the café door under the awning.
4. **Waterfront/square terraces** (`herengracht-sidewalk-cafe.jpg`): mixed tables
   with free parasols, diners seated and a waiter standing.
5. **From the air** (`where-is-my-seat-topdown.jpg`): what a pigeon actually sees
   — bright round tabletop dots with 2–4 tucked chairs each on a ~1.5–2.0 m
   pitch; table tops read as the dominant light-colored discs of the scene.

## What the game should copy vs simplify

The game's tables already match reality where it matters: the tabletop's walkable
top face is at 0.72 m (`scripts/cafe_spawner.gd:124` places the 0.06 m-thick top
mesh at +0.69; the collider `scripts/cafe_spawner.gd:24-25` spans 0→0.72), against
the real 0.73–0.76 m standard; the table stands 1.9 m out from the shop-band face
plane (`scripts/city.gd:69`, `CAFE_STANDOFF`), like the real standoff; and the
two sitters sit at ±0.72 m on opposite sides facing inward
(`scripts/cafe_spawner.gd:17-19`), exactly a real 2-top. So table-top bread spots
should sit **on the 0.72 m top surface, offset toward a sitter's edge** — never at
spot-origin ground level — and the awninged-building count (pinned 104 of 146
buildings, `scripts/city.gd:464`) is plenty for ~36 simultaneous table crumbs
against `target_count = 40` (`scripts/bread_spawner.gd:15`). Simplify freely:
skip parasols and tableware (the game's awnings are deliberately visual-only,
`scripts/city.gd:195`), and the 0.9 m square top is at the large end of real
2-tops but reads correctly at low-poly scale.

## Reviewed by

researcher agent, 2026-10-10 — opened and visually reviewed **all 7** images in
this folder (each verified >20 KB after download). An 8th candidate (Coimbra
courtyard terrace, chairs stacked, no diners) was downloaded, viewed, judged
weaker than the set, and deleted before writing this note.
