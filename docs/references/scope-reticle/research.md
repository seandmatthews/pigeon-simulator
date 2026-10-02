# Scope reticle — the real thing behind the poop target (T-046 successor idea)

Researched 2026-10-02 for the idea "replace the per-drop impact ring with one
persistent target reticle (ring + center dot + cross ticks), live while
airborne, frozen on F press". The reticle is the real-world referent; the
live/frozen mechanic and the damping fix are game math with no real-world
analogue (noted below). Photos: see `credits.md` in this folder.

## What it is

A **reticle** (from *reticulum*, little net) is the marking — crosshair, dot,
circle, ticks — superimposed on the aim point by an optical sight. The game's
proposed ring + center dot + cross ticks mixes two real families:

1. **The circle-dot reticle of reflex/holographic sights.** A large ring for
   fast acquisition with a fine dot in the exact center for precision. The
   classic spec is the EOTech holographic sight: a **68 MOA circle with a 1 MOA
   dot** in the middle; the ring is deliberately sized to subtend about a human
   torso at ~100 yd (manufacturer/dealer spec sheets for the EXPS3-0, XPS2, 512
   family). `eotech-512-reticle-through-hood.jpg` shows exactly this seen
   through the hood — red ring, tiny center dot, and four short tick marks
   breaking the ring at the 12/3/6/9 o'clock positions. `ps90-circle-dot-
   through-window.jpg` shows a circle-dot projected softly over a bright sky —
   the "readable against anything" look the game's emissive reticle wants.
2. **The crosshair-with-ticks of telescopic sights** — thin lines crossing at
   center, often thickening into posts ("duplex": *thick on the perimeter and
   thin out in the middle*, with the 30/30 variant's thin bars spanning **30
   arcminutes = 30 in at 100 yd = 90 cm at 100 m**). `m91-scope-crosshair-
   view.jpg` shows a fine crosshair seated on a target through the eyepiece.

The game already calls T-046's ring "the bombsight" (`scripts/poop_marker.gd:5`)
— the historical third family. A **reflector (reflex) gunsight** projects an
illuminated ring onto a tilted combining glass so the pilot aims at a floating
circle on the target; `revi-c12a-gunsight-section.jpg` is the WWII Luftwaffe
Revi C/12A in section, with its own 0–100 mm scale and a **445 mm overall
length** dimension line drawn on the drawing.

## Real dimensions and proportions

Angular sizes are the real spec (a reticle's job is to subtend a known angle at
the target). Reference angles, verified this session:

- **1 MOA ≈ 1.047 in at 100 yd ≈ 2.908 cm (29.1 mm) at 100 m**
  (Wikipedia, *Minute and second of arc*, firearms section).
- **68 MOA ring** (EOTech) → ≈ 1.98 m across at 100 m (derived: 68 × 29.1 mm) —
  i.e. "one person-wide" at 100 m.
- **Dot sizes:** 1 MOA dots sit in the EOTech circle-dot; a **5 MOA (1.5 mrad)
  dot** is described as the visibility/obscuration balance point; action
  shooting traditionally uses **7–20 MOA** dots (Wikipedia, *Reflex sight*).
- **Mil-dot tick spacing: 1 milliradian between marks**; 1 mrad = **10 cm at
  100 m** (Wikipedia, *Milliradian*: "Milliradian reticles often have dots or
  marks with a spacing of 1 mrad in between").
- **By design ratio:** in the EOTech reticle the dot is **1/68 of the ring's
  diameter** (1 MOA dot in a 68 MOA ring). In `eotech-512-reticle-through-
  hood.jpg` the four cardinal ticks each span roughly 1/5 to 1/6 of the ring
  diameter, crossing the ring line (approximate proportions read off that photo).
- **Physical sizes** (for scale sense only; not needed by the game): the Revi
  C/12A is 445 mm long per its own drawing; tube-style red dot sights (Aimpoint
  CompM2, `aimpoint-compm2-tube-sight.png`) are cylindrical housings "similar in
  appearance to telescopic sights" (Wikipedia, *Reflex sight*) — no verified mm
  figure was captured for that unit this session.

## Orientation of the parts (stated explicitly)

- The reticle lives in a **plane perpendicular to the line of sight**, centered
  on it: the **ring is concentric with the sight axis** and the **dot sits at
  the exact center** — never offset (`eotech-512-reticle-through-hood.jpg`,
  `ps90-circle-dot-through-window.jpg`).
- The **cross ticks sit at the 12, 3, 6 and 9 o'clock positions, symmetric
  about both the horizontal and vertical axes**, tips pointing inward toward
  the dot, crossing the ring line (the EOTech photo; the same pattern with
  range labels appears in the variant sheet `eotech-hws-reticle-variants.png`).
- **Drop/holdover marks hang BELOW the center along the vertical axis** — the
  variant sheet's ballistic reticles (XR308, FN303, SAGE) stack their extra aim
  dots downward with range numbers beside them. "Down = farther" is the
  universal reticle convention.
- Physically, the marking is on **glass tilted ~45°** to the sight axis
  (`leica-reflex-sight-combiner-glass.jpg` — the coated tilted plate is clearly
  visible; the Revi section and the EOTech diagram
  `eotech-projection-diagram.png` show the lamp → tilted optics → collimator
  path). The collimated image **appears at optical infinity**, i.e. painted on
  the target: "no parallax at infinity", with a finite-range error circle equal
  to the collimator diameter (some makers collimate for 25–50 yd instead;
  Wikipedia, *Reflex sight*). It tracks the aim point, not the eye.

## Common variants

Plain dot (Aimpoint tube sights) · circle-dot (EOTech 68 MOA + 1 MOA, Sig
circle-dot models) · circle-dot with cardinal ticks (`eotech-512-...jpg`, the
game's exact proposal) · duplex crosshair (thick posts, thin center, 30/30) ·
mil-dot crosshair with a below-center drop ladder (the variant sheet's XR308/
SAGE; historical ladder reticles like the rejected Z.F. candidates) ·
illuminated ring gunsights for aircraft (Revi C/12A) with ring-only or ring +
center pip. Brightness is a stepped control — real sights dim the marking for
dawn/dusk rather than hiding it.

## What the game should copy vs simplify

Copy the circle-dot-with-cardinal-ticks grammar — ring = "impact area", center
dot = the exact predicted point, four symmetric ticks = the windage/elevation
axes — in ONE fixed shape and one emissive color used identically in both
modes, because a real reticle never changes shape, only brightness (that maps
cleanly onto T-077's dim convention: dim the reticle during cooldown exactly as
a sight steps its dot down; hide it grounded where no sight exists). Simplify
by dropping all the ballistic apparatus — mil/MOA ladders, BDC dots, multiple
aiming points — since the game's live-prediction/frozen-lock pair replaces
them; note the frozen mode itself has no real referent (a real reticle never
"locks", it just follows the sight), and that T-046's world-space 0.8 m ring
grows/shrinks with distance whereas a real reticle holds constant angular size —
so if the live reticle is drawn in screen space it should hold constant screen
size, and if it stays world-space it should be justified as a "marked point",
not a sight. The damping fix (march must include the drop's `linear_damp`,
`scripts/poop_marker.gd:100-105`) is pure math with no visual research needed.

## Sources

- Wikipedia — [Minute and second of arc](https://en.wikipedia.org/wiki/Minute_and_second_of_arc)
  (1 MOA = 1.047 in @ 100 yd; ≈ 2.908 cm @ 100 m).
- Wikipedia — [Reflex sight](https://en.wikipedia.org/wiki/Reflex_sight)
  (5 MOA balance dot, 7–20 MOA action dots, collimation/parallax, tube vs open
  housing).
- Wikipedia — [Milliradian](https://en.wikipedia.org/wiki/Milliradian)
  (1 mrad = 10 cm @ 100 m; mil-dot marks spaced 1 mrad).
- Wikipedia — [Reticle](https://en.wikipedia.org/wiki/Reticle)
  (duplex 30/30 = 30 arcmin thin bars = 90 cm @ 100 m; etched range/drop
  sections).
- Manufacturer/dealer reticle specs surfaced by web search this session
  ([Primary Arms](https://www.primaryarms.com) EXPS3-0 listing and other EOTech
  dealers): 68 MOA circle + 1 MOA dot, ring sized to a torso at ~100 yd.
- The Revi C/12A drawing's own 445 mm dimension line and mm scale
  (`revi-c12a-gunsight-section.jpg`).

## Reviewed by

Researcher agent (GLM-5.3-Flash), 2026-10-02. Opened and visually reviewed all
8 kept images listed in `credits.md`, and all 14 other downloaded candidates
(rejected as off-geometry, reticle-invisible, or redundant: `q2_0` Marines
photo, `q2_5` Docter Sight, `q4_0` plain 4x crosshair, `q5_2` Tasco PDP2, `q5_3`
signal-mirror spot, `q6_0` gyro sight, `q6_3` ladder reticle, `q3_0`/`q3_1`
whole-rifle shots, `q7_5`/`q7_6` EOTech product shots, `q8_0`/`q8_1`/`q8_3`
collimator device shots). Five further candidates were rejected by the download
check alone (Wikimedia error pages or originals under the 20 KB bar: `q2_6`
diagram, `q4_2` PSO-1 reticle, `q4_3`/`q4_4` S&B P4 reticles, `q4_6` Z.F. 20E)
and were never opened. Staging dir `_refstaging/` (parser script + rejected
downloads) deleted after review.
