# T-221 — The pigeon's map: points of interest and the elder parks

- **Status:** proposed · **Category:** ui-ux · **Ring:** R6 (owner pick) ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** nothing in code — it reads the committed pack (`AmesDataPack`) and
  the built world. One coupling to get right: the elder-park list must be ONE table
  that both the map and the elder system read.
- **Refs:** owner pick 2026-11-24 — "In the long term, we'll implement a map feature
  that displays, if not the exact location of elders, at least the park locations that
  they will migrate between" (near-term, same pick: one bread-sharing elder on a bench
  in plain sight at spawn) · the 2026-11-23 difficulty research — the spawn view is an
  empty lawn, the nearest sharing elder sits under ~94 % tree canopy 33 m away, and
  nothing in the HUD names a single place in a 4.9 × 8.5 km town

## What

A toggleable map in the HUD: a pigeon's-eye schematic of the whole town, drawn by one
Control (`_draw()` — the `BreadGlobe` pattern; no textures, nothing allocated per
frame).

- **Points of interest** — the pack's named places (`AmesDataPack.pois()`), tiered the
  way the in-world signs already tier them (T-198, T-199): tier-1 names always drawn
  with a label, the lower tiers as dots.
- **The elder parks** — the places elders live in and will migrate between, shaded and
  named so the player reads "there are elders over there". Today that is the three
  favor zones (`ElderSpawner.FAVOR_ZONE_IDS`: Central Campus, downtown Main Street, the
  Lake LaVerne shore). **Not live elder positions** — a park is marked, an elder is not
  tracked.
- **You are here** — the pigeon's position and heading.
- **Nothing else.** No objectives, no arrows to targets, no timers: DESIGN.md's M2
  guardrail stands ("you're a pigeon, not an errand runner").

The elder-park list is one table both the map and the elder system read. Today that is
`FAVOR_ZONE_IDS`; when elders get a park-to-park migration (T-137's shuffle has no
effect on Ames — the migration pool refuses a zone elder), it re-homes them onto the
same list and the map follows with no second edit.

## Why

A new player has no picture of the town. The bread globe answers "where is the next
crumb"; nothing answers "where are the people", "where do I go", or "how far is the
stadium". In the original city that didn't matter — everything was within one screen.
On Ames the gathering places are 0.3–2.5 km apart and the starter elder is invisible,
so the first minutes are flying blind over lawns.

## Open decisions (the owner picks at pickup — defaults in brackets)

- **How it opens.** A new input action means the controls tables in `README.md` and
  `VERIFICATION.md` move with it, and the InputMap pin
  (`touch_layer_desktop_inert`: exactly the shipped eleven actions) is re-pinned to
  twelve. Touch needs a button beside Pause. *[Default: toggle, Tab.]* No `map` action
  ships without both tables updated (AGENTS.md — Input).
- **Whole town, or a window on the pigeon.** The town is 4.9 × 8.5 km, so a whole-town
  map is tall: about 380 × 660 px at 720p, one pixel ≈ 13 m — room for tier-1 labels
  only. *[Default: whole town, height-fit, centred.]*
- **What else appears.** *[Default: nothing — points of interest, elder parks, you.]*
  Bread and cars would turn it into a radar; that is a different feature.

## Acceptance criteria (proposed)

- [ ] Opening and closing the map is one input on desktop and one button on touch;
      closed, it costs nothing per frame (no draw, no polling)
- [ ] Every tier-1 point of interest is on the map with its name and the lower tiers
      are dots; the set equals the pack's (count and ids pinned against
      `AmesDataPack.pois()`)
- [ ] The elder parks are shaded and named, and the set equals the elder system's own
      list — pinned against `ElderSpawner.FAVOR_ZONE_IDS`, so a zone added there
      appears on the map with no map edit
- [ ] No elder position is drawn: with elders staged at known positions, the map draws
      nothing at them
- [ ] The pigeon's marker is where the pigeon is — world → map → world round-trips
      within one pixel at spawn, at the map's corners, and at the far north edge
      (Ada Hayden)
- [ ] The map fits the window at 1280 × 720 and respects the touch safe area (the
      `HUD` layer's inset law in `scripts/hud.gd`)
- [ ] While open it redraws only when something moved (the pigeon, the toggle); no
      per-frame allocation; the draw budget is unchanged while closed
- [ ] The controls tables in `README.md` and `VERIFICATION.md` list the new action and
      the InputMap pin is re-pinned
- [ ] Full Gate 1b green
- [ ] [screenshot] Gate 3: a new player can name the three elder parks and point at
      the nearest one from the map *(owner)*

## Verification (proposed)

Gate 1b — one scenario per criterion: the closed map is inert; the open map's
point-of-interest and elder-park sets equal their sources; the no-elder-dots arm; the
marker round-trip at four anchors; the fit and safe-area reads. Gate 2 unchanged. Gate
3 the screenshot line above.

## Risks

- **Label legibility at 13 m per pixel** — tier-1 only, and the owner judges it on
  screen; a zoomed window on the pigeon is the fallback.
- **Scope creep into a minimap or quest markers** — the What section's "nothing else"
  is the line to hold.
- **Touch layout** — the HUD column is already anchored for the safe area; the MAP
  button joins the Pause button's row.
