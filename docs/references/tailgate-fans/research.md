# Tailgate fans in team colors — reference research

Concept slug: `tailgate-fans`. Context: the M2 citizen-class ticket splits the
city's pedestrians and cars into black-and-gold VISITORS (invading tailgaters
with fan props), ordinary CIVILIAN locals, and a rare cardinal-and-gold HOMETOWN
SUPERFAN. Colors only — the locked convention bans real school names, logos and
mascots, so this note records the *visual grammar* of American game-day fan
culture: what tailgaters and superfans actually look like, what their props
measure, and which cues survive being read from the air at flight speed against
the T-026 ground palette.

## What it is

Tailgating is the pre-game ritual of American football (college and NFL): fans
arrive hours early, park in the stadium lots, and picnic around their vehicles —
hatch or tailgate open as a counter (the name), a pop-up canopy for shade, a
folding table, a grill, and coolers on the ground. Fans dress in the team's two
colors: a rank-and-file fan wears *one* team-color garment (jersey or t-shirt)
over ordinary pants; a **superfan** stacks the colors head-to-toe — jersey in the
primary color, long-sleeve under-layer in the secondary color, team hat, lanyard,
sometimes a themed helmet — and carries props: the foam finger raised overhead,
team flags, pennants. The faithful-vehicle variant exists too: fans paint the
*whole car body* in team colors with a monogram/lettering panel
(`husky-tailgate-van.png`). In the stands the crowd reads as a **color mass**:
individual faces vanish and what survives is a solid block of the two team
colors (`alabama-stands.jpg` — a sea of crimson and white). All of this is the
game's joke in physical form: an invasion of one two-color pairing into another
school's town.

## Real dimensions and proportions

Standard figures (common retail/manufactured sizes), cross-checked against
proportions visible in the photos:

- **Adult human:** 1.6–1.9 m tall (game pedestrians already sit in this band —
  the café-table note measured tabletops against a 1.75 m adult). Every prop
  below scales against that body.
- **Foam finger (foam hand):** one-size foam mitt ≈ 0.45–0.60 m long, ≈ 0.25–0.30 m
  across the palm, worn over the whole hand with the index finger extended. In
  `foam-finger-stands.jpg` the mitt runs from the wearer's raised hand to well
  above head height — roughly shoulder-to-half-a-head-over, consistent with
  ~0.5–0.6 m. Screen-printed lettering runs vertically along the index finger.
  Foam is matte, saturated, low-density.
- **Cooler:** the classic wheeled chest cooler (50–70 qt class) is ≈ 0.60–0.65 m
  long × 0.40–0.45 m wide × 0.42–0.45 m tall. `rubbermaid-cooler.jpg` shows the
  type with an American football (0.28 m long) beside it — the cooler is ≈ 2.2
  footballs long, confirming ≈ 0.6 m. Lid hinged on top, swing handles on the
  ends, wheels on one end, so it is *towed rolling* like luggage, or sits on the
  ground beside a table. Waist-to-mid-thigh height of an adult.
- **Jersey:** a torso-length color block with big pale numerals on chest and
  back, striped cuffs. `steeler-superfan.jpg` is the archetypal superfan stack:
  near-black torso with white numerals, **gold** long-sleeve under-layer, gold
  lanyard, themed hat — two colors on one body. A companion fan behind him wears
  the inverse: white jersey with gold/black banded sleeves and a gold/black hat.
  Both directions of the pairing exist; the pairing itself is the read.
- **Canopy + table (the lot-dressing kit):** pop-up canopy ≈ 3 × 3 m, square;
  folding table ≈ 1.8 × 0.75 m, ≈ 0.74 m tall under it; cooler on the ground
  beside the table; grill off to one side (`cascades-tailgate-1.jpg` background,
  `browns-muni-lot.jpg` throughout).
- **Fan car flags** (common retail size — no photo in this set): flag ≈ 0.30 ×
  0.46 m on a ≈ 0.40–0.45 m pole, clipping into the door-window channel, flying
  **up** above roof height. Full-body team-color paint as in
  `husky-tailgate-van.png` (gold body, monogram panel on the side).

## Orientation of the parts (explicit)

- The foam finger's index points **vertically up**; the mitt is worn on the
  raised hand and held **above head height** — it breaks the pedestrian
  silhouette line. It is never carried level or pointing down.
- The cooler lies **horizontal, lid up**, wheels at one end; towed or planted on
  the ground **beside** a table, never on it.
- The canopy is **square over the table**; the table sits **under** the canopy;
  the cooler sits **on the ground beside** the table.
- Car flags fly **up** from the door-window channel; painted vehicles carry the
  monogram/lettering on the **side panels** (largest flat face).
- Jersey numerals face **outward** on chest and back.
- Tailgate groups cluster **around and behind** their vehicle, often using the
  open hatch/tailgate as a counter — groups are vehicle-anchored, not
  free-floating (`war`-lot pattern visible in `browns-muni-lot.jpg` and
  `meadowlands-aerial.jpg` lot geometry: cars in rows, ~2–3 m gaps, groups in
  the gaps).

## Common variants

- Rank-and-file fan (one garment) vs superfan (head-to-toe stack) — the game's
  VISITOR vs SUPERFAN distinction is exactly this real one.
- Jersey weather vs t-shirt weather; wagons and wheeled coolers vs hand-carried.
- Decorated vehicle spectrum: window paint → magnets → flags → full body paint.
- Lot dressing from bare (tailgate counter only) to full camp (canopy + table +
  grill + flags). The lot itself ranges from grass (Wyoming, Husky photos) to
  full asphalt (`browns-muni-lot.jpg`, `meadowlands-aerial.jpg`).

## Readability against the current game (computed this session, Euclidean RGB)

The T-016 gate treats ≥ 0.20 as readable (pigeon body vs sidewalk = 0.230, the
gated minimum). Against the landed ground values (`scripts/city.gd:26-29`:
sidewalk 0.56/0.55/0.53, plaza 0.60/0.57/0.51, asphalt 0.29/0.29/0.31) and the
existing class palettes (`scripts/tourist.gd:20-24` shirts, `scripts/car.gd:23-27`
bodies):

| Pair | Distance | Implication |
| ---- | -------- | ----------- |
| team gold (1.0, 0.80, 0.0) vs shirt-palette yellow (0.95, 0.68, 0.20) | **0.239** | Barely above the 0.20 gate — a *single* gold garment is NOT a reliable visitor read against existing civilians. |
| cardinal (0.78, 0.06, 0.18) vs shirt-palette red (0.86, 0.30, 0.28) | **0.272** | Thin margin for a single-garment superfan read. |
| cardinal vs car-palette red (0.85, 0.25, 0.22) | **0.206** | Same problem on cars. |
| near-black garment (0.08, 0.08, 0.08) vs asphalt (0.29, 0.29, 0.31) | 0.376 | Passes but is the low-chroma direction from the air; the gold partner carries the read. |
| team gold vs sidewalk / plaza | 0.733 / 0.75+ | Gold pops strongly against every ground surface. |

**The load-bearing finding:** real fans are not one garment — the class read is
the **two-color pairing stacked on one body** (jersey + under-layer + hat, as in
`steeler-superfan.jpg`). No entry in the existing 8-color shirt palette produces
a two-color stack, so pairing — not any single albedo — is what separates
VISITOR and SUPERFAN from CIVILIAN at flight speed. Reserve the pairings
exclusively for the special classes; keep civilians in the current mixed palette.

## What the game should copy vs simplify

Copy the three distance cues the photos prove: (1) a team-color **torso block**
with the second color as under-layer/hat accent, (2) props held **above the head
line** (a ~0.5 m raised foam finger on visitors; nothing raised on civilians),
and (3) **full-body team-color paint on visitor cars** replacing the existing
mixed body palette for that class, with the flag up top as an optional accent.
Simplify by dropping lettering/logos entirely (the colors-only convention
already requires it), fabric folds and faces — at pigeon flight distance the
alabama-stands color-mass effect means two flat low-poly colors per NPC read
correctly, and tents/coolers matter only as static lot dressing if ticket 2's
steal surfaces need vehicle-anchored spots.

## Reviewed by

Researcher agent, 2026-10-11: I viewed every image kept here (`browns-muni-lot`,
`meadowlands-aerial`, `husky-tailgate-van`, `steeler-superfan`,
`cascades-tailgate-1`, `foam-finger-stands`, `rubbermaid-cooler`,
`alabama-stands`) and every rejected candidate on this date. Of 12 downloaded
image candidates, 4 were rejected after viewing: `war-memorial-lot.jpg` (960×231
pano crop, snowy, redundant with the Muni lot shot), `cascades-tailgate-2.jpg`
(posing students, no fan gear or furniture), `preds-in-the-stands.jpg` (mixed
crowd, no dominant team-color read), `foam-finger-1971.jpg` (historic b/w scan,
redundant with the color shot). A 13th download (`large-cooler-box.jpg`) was an
HTML error page (1.9 KB), not an image, and was deleted without being viewable.
