# T-197 — Ames R4 · text capability: in-world signs become possible

- **Status:** doing · **Category:** code-optimization · **Ring:** R4 The Names ·
  **Value (1-5):** 5 · **Risk (1-5):** 4
- **Depends on:** T-196 (heroes carry the signs)
- **Refs:** `docs/AMES-MASTERPLAN.md` §7 · T-090 (the blank-signboard
  convention this RETIRES deliberately) · `venues/VENUES.md` exterior
  descriptions (sign typologies) · `images/campustown/`, `images/downtown/07`
  (box/blade/pole typology refs) · legal tiering (ames-campaign memory
  + master plan §0)

## What

The game renders ZERO in-world text today (T-090's convention). R4's
first ticket builds the capability, deliberately scoped:

1. **`scripts/sign_text.gd`** — a Label3D-based sign component:
   mesh plaque/box/blade/pole body + rendered text face; unshaded or
   SDF font at distance; legibility budget (readable at X m for a
   given letter height — pinned per typology).
2. **One OFL font** (candidate: a condensed grotesque for bar signs +
   a clean sans for plaques — exact pick in-ticket with license file
   bundled under `assets/fonts/` + credits entry).
3. **The three typologies as scenes**: box sign (Campustown's lit
   boxes), blade sign (downtown neon-ish verticals), pole sign (Lincoln
   Way's big-box poles) — geometry per the photo refs, text via the
   component.
4. **Credits screen** (menu, minimal): OSM attribution ("Map data ©
   OpenStreetMap contributors"), the photo CC credits (the survey's
   CREDITS.md files summarized), font license — the ODbL obligation
   lands here.
5. **No gameplay text changes**: HUD/menus untouched; in-world only.

## Why

"I fly to Welch Ave Station and find my bar" requires letterforms.
This ticket is deliberately hero-free — pure capability + the legal
screen — so every later sign ticket is content, not plumbing.

## Acceptance criteria

- [x] The component + three typology scenes exist and place into any
      slot; text legible at the pinned distances (per typology)
      — machine legs in `sign_text_legibility` (the four mounts at
      arbitrary transforms, the pole yawed, dims + letter heights +
      budget locks pinned); the agent screenshot set
      (`.captures/session_t197sign2/pose0..4.png`, `tests/sign_gallery.tscn`)
      reads every typology's letterforms; the physical at-distance
      read is the owner's T-202 fold-in per the Verification line.
- [x] Font license bundled; credits screen live with OSM + photo
      attributions — `assets/fonts/OFL.txt` beside the font, its row
      in `assets/CREDITS.md`; the credits screen proven live by
      `credits_screen_content` + the title screenshot
      (`.captures/session_t197menu/window.png`).
- [x] *(Gate 1b)* `sign_text_legibility`: per-typology letter-height →
      readable-distance pins; `credits_screen_content`: the three
      attribution classes present — suite 153 PASS / 0 FAIL, exit 0.
- [x] T-090's blank-plaques elsewhere unchanged (adoption is
      per-ticket, not global) — `scripts/city.gd` absent from the
      branch diff (verified `git diff --stat 255412b..HEAD`); the
      Windrow-seam plaque recipe stands byte-identical.
- [x] *(Gate 1/2)* clean — Gate 1 clean (import exit 0 with only the
      documented benign addon line; 120-frame boot exit 0, zero error
      lines); Gate 2 `AUTOPLAY DONE ok=true world=ames … loop_ok=true
      … restart=true`, exit 0, zero SCRIPT ERROR lines.

## Verification (proposed)

Gate 1 · Gate 1b + two rows · Gate 2 · Gate 3: screenshots of each
typology in-situ (test placements), owner eyeball pass folded into
T-202.

## Run record (2026-11-16, implementer)

- **Font pick:** Oswald (variable wght 200–700, default instance as
  shipped by google/fonts) — the one OFL file that reads on all three
  typologies plus plaques: the condensed grotesque of the Campustown
  bar boxes and the downtown blades is ALSO a clean enough sans for
  the plaques, so one file serves both candidates in the ticket's
  What. Metrics parsed from the TTF (Python struct walk, then re-parsed
  in-scenario by GDScript): unitsPerEm 1000, OS/2 v4 sCapHeight 810 →
  **cap_em 0.81**; the component letters through
  `pixel_size = letter_height / (96 × 0.81)` so the legibility budget
  applies to REAL capital heights, not em boxes.
- **Legibility budgets (the pinned per-typology values):** plaque 140
  m per m of cap height (0.16 → 22.4 m) · lit box 200 (0.30 → 60.0 m)
  · blade 160 (0.28 → 44.8 m) · pole 260 (0.55 → 143.0 m). One knob per
  typology: a sign ticket retuning a letter height moves its readable
  distance in the same proportion; the scenario locks both ends.
- **Default body dims:** box 3.0 × 1.0 × 0.25 m (photo-01's flat lit
  box) · blade 0.14 × 2.6 × 0.9 board + Ø0.9 rounded cap + two bracket
  arms (photo-07's vertical neon board) · pole Ø0.35 × 6.0 m with the
  2.6 × 2.6 × 0.4 m cabinet at y 4.4 (photo-04's big-box pole; pole
  tops just above the cabinet) · plaque 2.2 × 0.5 × 0.08 m (T-090's
  slab, lettered). Pole default text "POLE" — big cabinets carry short
  words; "POLE SIGN" at 0.55 m caps measures 2.60 m on the 2.60 m face
  and fires the overflow warning (the guard works).
- **Gate 1** — `--import` exit 0 (only the documented benign addon
  line); `--quit-after 120` exit 0, zero ERROR lines.
- **Gate 1b** — full suite `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn`: exit 0, **153 PASS / 0 FAIL** (the two
  new rows + every existing row untouched), including with the MSDF
  font import enabled (`multichannel_signed_distance_field=true`,
  msdf_pixel_range 8 / msdf_size 48 — crisp-at-distance letterforms;
  metrics unaffected, suite re-run green after the toggle).
- **Gate 2** — `godot --path . res://tests/autoplay.tscn`: exit 0,
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
  t=103.0 fps=141 … splats=26 tourists=24 … eaten=7 … restart=true`,
  zero SCRIPT ERROR lines — the full Ames window closes its loop with
  the sign capability along for the ride (in-world text changes
  nothing about play).
- **Gate 3** — screenshots of each typology at its test placement
  (pilot sessions, hidden windows per T-170): `.captures/session_t197sign2/`
  `pose0_triptych.png` (all three typologies + the plaque in one frame),
  `pose1_box.png` (the lit box face-on), `pose2_blade.png` (the blade's
  +x face, S/I/G/N stacked upright in neon red over the rounded top),
  `pose3_pole.png` (the cabinet from the drive-by side),
  `pose4_plaque.png` ("AMES" on the T-090 cream slab); credits screen
  live `.captures/session_t197menu/window.png` (focus-key driven on the
  real title). Zero errors in the session logs. The owner eyeball pass
  (do the letterforms read at flight distances; do the typologies read
  as their districts) folds into T-202 per the Verification line.
- **Two probe findings fixed during the run** (both recorded so the
  next agent skips them): FileAccess defaults to LITTLE-endian — the
  in-scenario TTF parser must set `big_endian = true` before reading
  the sfnt directory; and a `%`-format at the tail of a `+` concat
  chain binds to the LAST segment only (raw `%s` placeholders shipped
  in the first credits text — plain concatenation replaced it).

## Tuned values

`SignText.SPEC` per typology: letter heights 0.16 / 0.30 / 0.28 /
0.55 m; budget factors 140 / 200 / 160 / 260; `CAP_HEIGHT_EM` 0.81;
`FONT_SIZE_PX` 96; `FACE_PROUD` 0.01 m; pole Ø0.35 × 6.0, cabinet
2.6 × 2.6 × 0.4 at y 4.4; blade cap Ø0.9 at the board top, bracket
arms 0.30 m at y ±0.65; palettes — plaque cream Color(0.92, 0.87,
0.74) #EBDEBD (the T-090 COLOR_SIGNBOARD itself) on dark ink
Color(0.13, 0.12, 0.10), box warm-white Color(0.93, 0.91, 0.86) +
navy Color(0.09, 0.15, 0.24), blade near-black Color(0.07, 0.07,
0.08) + neon red Color(0.95, 0.16, 0.12), pole white Color(0.92,
0.92, 0.90) + navy. Scenes ship the typology defaults with explicit
texts ("BOX SIGN" / "SIGN" / "POLE").
