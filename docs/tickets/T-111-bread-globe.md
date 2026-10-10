# T-111 — The bread globe: a pigeon-frame 3D bread finder replaces the 2D chevron pointer

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (replaces the landed pointer lineage T-037 → T-057 → T-098/T-058; nothing open)
- **Refs:** owner request (2026-10-10): replace the 2D bread pointer with a "genuinely 3D bread
  finder — a small globe/sphere on the HUD with a segment protruding from it"; the segment must
  carry the bread's direction **relative to the pigeon's own orientation** (contract verbatim in
  What) · retires the T-058 stern text (its job becomes geometric) and the T-098 climb cue
  (absorbed — the segment tilts) · sibling pattern for a per-frame HUD indicator: the PoopReticle
  (T-105) and its 30 Hz live refresh (T-110) · land-order agnostic: touches only
  `scripts/main.gd`, `scenes/main.tscn`, `scripts/bread_globe.gd` (new) and the pointer scenario

## What

**The contract (owner's geometry — the acceptance bar).** Imagine a line drawn from the closest
piece of bread to the pigeon: the segment protruding from the globe matches that same angle
**relative to the pigeon's own orientation** — if you steered the pigeon along the segment's
direction and flew, you would intersect that bread perfectly. Level flight with the crumb dead
ahead = the segment pointing straight ahead; a crumb above/below/left/right/behind tilts and
swings the segment to match, so a stern target reads "behind you" at a glance. Every criterion
below pins THIS; the rendering choices are the settled implementation, not the bar.

**Settled screen mapping: a 2D-projected segment on a drawn globe (pigeon-frame instrument).**
The widget is drawn — a custom `Control._draw()`, the `Chevron` Polygon2D's slot — not a
SubViewport 3D scene. The projection IS 3D math (a fixed tilted vantage, foreshortening and all);
only the rasterization is 2D. The owner's 2D-vs-3D-widget fork settles this way because:

- A true occluding 3D ball *hides* near-axis segments — dead ahead, the primary case, the
  segment falls entirely inside the ball's silhouette (geometrically unavoidable: any tail
  length inside ~`arcsin(r/L)` of the view axis is occluded), so real implementations fall back
  to no-depth-test drawing, which is the same 2D math with a render pass on top.
- A drawn Control is the repo's HUD idiom (every HUD element in `scenes/main.tscn:99-213` is a
  Control), costs no second render target against the T-018 budget, and is fully
  machine-checkable headless (published vectors, not pixels).
- Rejected too: a screen-true arrow (T-057's convention upgraded) — it cannot represent stern
  targets at all (they unproject behind the lens), which is the exact hole T-058 patched with
  text. The owner's contract is pigeon-frame; this ticket deletes that text crutch.

**The mapping, exactly.** All math in `scripts/main.gd` (which owns target selection today,
`_update_bread_pointer` `scripts/main.gd:253-267`, `_aim_bread_pointer`
`scripts/main.gd:289-317`); the widget only draws what it is handed.

```gdscript
## Pigeon-local direction to the target: +X starboard, +Y up, -Z the nose.
var dir_local: Vector3 = player.global_transform.basis.inverse() \
        * (target - player.global_position).normalized()
## Projected through the widget's fixed vantage: a camera hovering behind and
## above the pigeon, pitched down by vantage_tilt_deg (25.0). Canvas y is down.
var s := deg_to_rad(25.0)
var screen := Vector2(dir_local.x, -(dir_local.y * cos(s) - dir_local.z * sin(s)))
var tip := screen * segment_px   ## drawn endpoint, px from the widget center
```

The tilt is load-bearing, not decoration: at a straight-on (untilted) projection a dead-ahead
crumb projects to a **zero-length dot** and "the segment pointing straight ahead" is
undrawable. 25° keeps the widget's vertical sense aligned with the chase view (the chase rig
rests pitched −18°, `scripts/chase_camera.gd:18`) while lengthening the ahead/stern projections
to a readable 0.42×full (sin 25° ≈ 0.42, cos 25° ≈ 0.91). Read of the result:

| crumb relative to pigeon | `dir_local` | drawn segment |
| --- | --- | --- |
| level, dead ahead | (0, 0, −1) | straight **up**, 0.42×full — tip lands on the fly-to pip |
| straight above | (0, 1, 0) | straight up, 0.91×full |
| abeam right / left | (±1, 0, 0) | right / left, full length |
| level, stern | (0, 0, 1) | straight **down**, 0.42×full — hollow tip |
| straight below | (0, −1, 0) | straight down, 0.91×full |

So the widget's upper half = in front of the pigeon, lower half = behind it; the segment's
slope carries the vertical component natively (that is the answer to "how is vertical shown" —
tilt, not an arrow glyph), and the projected *length* (foreshortening) separates ahead from
above and stern from below. **The vertical component is shown by the tilted vantage
projection; no ▲/▼ glyph survives.**

**The widget — `scripts/bread_globe.gd` (`class_name BreadGlobe extends Control`), new file.**
No separate .tscn: a single drawn Control is the Chevron precedent (`scenes/main.tscn:160-167`
is two inline Polygon2Ds). Instanced inline under `HUD` in `scenes/main.tscn`, node
`BreadGlobe`, `unique_name_in_owner` → `@onready var bread_globe: BreadGlobe = %BreadGlobe`
beside the other HUD accessors (`scripts/main.gd:71-98`); `mouse_filter = 2` (ignore),
`visible = false` at rest like the label. API (the harness reads these, never pixels):

- `aim(dir_local: Vector3)` — stores the direction and `queue_redraw()`s (changed-value guarded:
  redraw only when the projected tip moves ≥ 0.5 px or the flash phase steps — the
  T-035/T-055/T-077 idle-frame concern; the reticle's same-shaped guard is
  `scripts/poop_reticle.gd:119`).
- `flash()` — starts the target-change flash (below).
- `clear()` — `dir_local = Vector3.ZERO`, hidden (mirrors `bread_pointer.visible = false`,
  `scripts/main.gd:263-264`).
- Published: `dir_local: Vector3` (ZERO when cleared), `screen_offset: Vector2` (the drawn tip,
  px from center), `flash_active: bool`.
- Draw list (all `draw_*`, outline treatment = a `Color(0,0,0,0.85)` under-stroke then the ink,
  the label outline convention `scenes/main.tscn:156-158`):
  1. **Ball disc** — filled circle `ball_radius_px` 13.0, fill `Color(0,0,0,0.35)` + rim
     `Color(0,0,0,0.85)` (the T-080 hunger track StyleBoxFlat pair, `scenes/main.tscn:30-40` —
     the HUD's existing "dark puck" grammar).
  2. **Level ring** — stroked ellipse, semi-axes `(segment_px, segment_px·sinθ)` = (21, 8.9),
     faint `Color(1,1,1,0.25)`: the projection of the pigeon's local level plane. Tip on the
     ring = level with you; above the ring = an up-component; below = down. Its top point IS
     level-dead-ahead.
  3. **Fly-to pip** — 2 px dot at the ring's top `(0, −segment_px·sinθ)`: where the tip lands
     when the crumb is level dead ahead. "Fly at the pip" is the whole instruction.
  4. **Segment** — from the widget center to `tip`, `segment_px` 21.0, rest color
     `Color(1,1,1,0.75)` (the pointer label's font color, `scenes/main.tscn:158`) over the dark
     under-stroke.
  5. **Tip marker** — 2.5 px filled dot when `dir_local.z < 0` (bow), hollow ring when
     `dir_local.z > 0` (stern). Redundant with the geometry by design — T-058's lesson is that
     a symbol may REINFORCE but never be the sole carrier of a convention.
- Exports (tune at Gate 3 without touching layout): `ball_radius_px` 13.0, `segment_px` 21.0,
  `vantage_tilt_deg` 25.0, plus the colors above.

**Flash on target change (owner add).** Main gains `var _last_bread_target: BreadCrumb`. In the
bread branch of `_update_bread_pointer`: when the named crumb is a different instance than the
one last drawn — a just-eaten (freed) previous counts as a change, so the eat→re-aim moment
flashes; first acquisition from nothing never flashes; city-mode frames never flash and never
touch the memory (returning inside the ring re-flashes only if the nearest crumb actually
differs) — call `bread_globe.flash()`. The flash mixes the widget's ink (segment, tip, ring,
pip) toward the game's score gold `Color(1.0, 0.85, 0.3)` (`scripts/main.gd:225`) and back over
`flash_seconds` 0.4 **game time** — the hunger-pulse shape (`scripts/main.gd:181-185`), the
combo-strip countdown pattern (`scripts/main.gd:190-194`): deterministic under `--fixed-fps`,
frozen while paused or over. The label's font color stays at rest — the flash marks the
instrument, not the text. `restart_run()` adds `_last_bread_target = null` and clears any
running flash to the reset block (`scripts/main.gd:550-559`), so a fresh run's first
acquisition is flash-less.

**Text: the minimal remainder.** The readout becomes exactly `"<what> <n> m"` — "bread 23 m" /
"city 141 m". Deleted outright: `STERN_SUFFIX` (`scripts/main.gd:49-54` — the segment IS the
stern read now) and `POINTER_CLIMB_CUE_M` + the ▲/▼ cue (`scripts/main.gd:48`,
`:294-298` — the segment's slope IS the climb cue now; keeping three encodings of one fact is
noise, and "whatever minimal text remains" is the owner's wording). The `_aim_bread_pointer`
signature loses `with_climb_cue`; the stern world-space dot test (`:299-306`) and both camera
guards (`:309-317` — the widget reads no camera, so behind-lens and degenerate-unprojection
hazards do not exist) die with them; only a zero-delta guard survives
(`to_target.length_squared() < 0.0001` → keep the last drawn direction — a normalized()
NaN-guard, the shape of the old degenerate bail `:315-316`). Docstrings (`:238-252`,
`:270-288`) rewritten; `bread_pointer_chevron` (`:86-90`) and the Chevron/Fill nodes
(`scenes/main.tscn:160-167`) deleted.

**Layout (concrete, `scenes/main.tscn`).** `BreadGlobe` 40×40 at `offset_left 16.0 /
offset_top 82.0` (center 36, 102 — the old chevron sat at 22, 102); `BreadPointer`
`offset_left` 34.0 → 64.0 (`:151`), box otherwise untouched (92..112); the three rows below
nudge down 8 px to clear the 40 px globe: ComboStrip `offset_top/bottom` 116/136 → 124/144
(`:172-173`), HomeNote 140/160 → 148/168 (`:184-185`), ComboNote 160/180 → 168/188
(`:196-197`). Known worst-case overdraw: a near-vertical full-extension tip reaches absolute
y ≈ 81 (center 102 − segment_px 21), ~7 px into the hint row's box (68..88) and up to ~3 px
under its glyph band (~70..84) — only while the crumb rides near-straight up; `segment_px` is
the Gate 3 trim knob. The window is 1280×720 (`project.godot:28-29`).

What this does **NOT** claim: no target-selection change — `nearest_crumb` stays pure
3D-nearest (`scripts/bread_spawner.gd:61-75`) and the city-ring flip stays at half
`city_span` (`scripts/main.gd:255-257`); no chase-camera change, and the widget deliberately
reads no camera — an attitude instrument moves when the PIGEON moves, unlike T-057's
screen-space chevron which followed the damped lens (during a hard camera swing the two
conventions differ; the owner's contract picks the pigeon); the full basis (bank included) is
used, so a banked turn rolls the segment with the bird — that IS "relative to the pigeon's own
orientation"; no input action, `project.godot`, autoload, sound or addon change (no
controls-table edit); no new physics; the distance label keeps its T-019 outline treatment and
14 px font.

References do not apply — no research phase ran: this is a game-invented HUD affordance with no
real-world counterpart (no magical bread-finding beacon exists to photograph), so every
constraint above is grounded in the repo (file:line), not in reference photos.

## Why

The pointer is the core loop's spine — hunger (T-005) forces a bread run every minute, and
T-037's slot has been patched three times precisely where a flat 2D arrow cannot go: T-057 had
to rebuild it in screen space because nose-relative angles rendered as lies; T-098 had to bolt
a ▲ glyph on because a chevron cannot say "up"; T-058 had to bolt " — turn around" on because a
screen arrow cannot say "behind" (behind the lens it renders mirrored garbage — the guard at
`scripts/main.gd:310` holds the last bearing instead). Each patch taught a text convention,
which is the pattern T-058 itself called unteachable. The globe settles the whole class: one
geometric encoding where steer-along, vertical and stern are all the same fact — the segment's
direction in your frame — so a stern crumb reads "behind you" with zero text and a roof crumb
reads "above" with zero glyphs. Player value: fewer HUD-reading seconds at cruise, more
flying; the gold flash turns "the metres changed" into "fresh crumb" — a small silly-bird
reward beat in the T-013 register. Risk 3 because it rewrites the pointer's aim semantics AND
retires three tickets' worth of scenario arms (the suite's most-extended row) in one
change-set; the mapping itself is three lines of trig.

## Acceptance criteria

- [ ] **The steering contract (Gate 1b only):** for scan-decided nearest crumbs placed
      dead-ahead-level (~10 m on the nose axis, `drop_crumb`, `scripts/bread_spawner.gd:111`),
      ~10 m overhead (grounded pigeon — the T-098 placement), and ~5 m stern (the T-058 bread
      stern placement), the widget's published `dir_local` matches the scenario's independent
      pigeon-local recompute (`basis.inverse() * delta.normalized()` from the live player
      basis — dot ≥ 0.999) at two opposing yaws; the dead-ahead arm's `dir_local` is
      (0, 0, −1) within 0.01 — the machine form of "steer along the segment and you intersect
      the bread"
- [ ] **Screen-direction ordering (Gate 1b, formula-free properties):** dead-ahead arm's
      `screen_offset.y < 0` and `|screen_offset.x| < 1.0` (up, axial); stern arm's
      `screen_offset.y > 0` (down); overhead arm's `|screen_offset|` strictly exceeds the
      dead-ahead arm's (foreshortening orders ahead < above — the tilt is load-bearing); the
      dead-ahead tip lands on the fly-to pip within 1 px
- [ ] **Text is the minimal remainder (Gate 1b):** every readout parses as exactly
      `<what> <n> m` — `_pointer_distance_m` reverts to the strict 3-part shape
      (`tests/sim_test.gd:5542-5550`; the ▲/▼ tolerance and the " — " strip both die), so any
      re-introduced stern suffix or climb cue turns every distance assert to −1.0 and fails;
      the overhead and stern arms assert the bare text explicitly (T-098/T-058 retired)
- [ ] **City/home mode survives (Gate 1b):** beyond half the city span the slot still reads
      "city <n> m" (±2 m of the horizontal distance, the existing yaw-90 hover geometry) and
      the globe aims at `city.spawn_point` through the same mapping (independent recompute,
      dot ≥ 0.999) — a stern homing read is now geometric
- [ ] **Flash state machine (Gate 1b):** crumb→different-crumb flips `flash_active` true
      immediately and the text re-aims within ±1 m; after `flash_seconds` of game time the
      widget is back at rest; first acquisition after `restart_run()` never flashes;
      city-mode frames never flash; steady same-crumb frames never re-flash; a just-eaten
      target's re-aim DOES flash
- [ ] **Zero-delta guard (Gate 1b):** `_aim_bread_pointer(pigeon_pos, "bread", 0.0)` keeps the
      last drawn direction, finite — never a NaN
- [ ] **Full Gate 1b suite green** — including `combo_strip_reports_last_hit`'s layout leg
      (`tests/sim_test.gd:6334`, `strip.offset_top >= bread_pointer.offset_bottom` — the +8 px
      nudge keeps it: 124 ≥ 112) and `density_cpu_budget`
- [ ] **VERIFICATION.md in the same change-set:** the pointer row (`VERIFICATION.md:115`)
      rewritten (chevron half-plane/behind-camera/cue/suffix descriptions die, the globe arms
      described), the T-098/T-058 landed notes annotated as retired, and the Gate 3 lines below
      added to the playtest list
- [ ] **[screenshot] (Gate 3 — human judgement)** Flying past a crumb at cruise, the segment
      swings down-short and reads "behind you" at a glance with no text — the T-058 bar,
      geometric
- [ ] **[screenshot] (Gate 3 — human judgement)** Grounded before a building with a roof crumb,
      the segment tilts up and reads "above" at a glance — T-098's motivating case on the new
      instrument
- [ ] **[screenshot] (Gate 3 — human judgement)** The gold flash reads as "fresh crumb" —
      noticeable at 40 px, calm not alarming — and the widget stays legible over white pavement
      and bright sky with the outline treatment; level dead-ahead flight reads as "tip on the
      pip" and is teachable in one sentence

## Verification

Gate 1 (`--import` + 120-frame boot, exit 0; deliberately NO `--check-only` leg — broken
repo-wide, `VERIFICATION.md:434-435`) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` · Gate 2 (autoplay
homes on its own `_nearest_crumb` scan, `tests/autoplay.gd:403-409`, and asserts nothing about
the pointer — unaffected; run anyway) · Gate 3: the three [screenshot] lines, addable to the
T-037/T-058 playtest session (`VERIFICATION.md:351-355`).

Gate 1b — rework `hud_bread_pointer_tracks_nearest_crumb` (`tests/sim_test.gd:5615`,
registered `:209`, check `:5996`; same real-Main rig and cleanup tail). A simplification first:
the widget reads no camera, so T-057's 9×5-frame chase-camera convergence loops die — every arm
becomes `reset_flight` (`scripts/player.gd:178`) → 2-frame wait → sample. All expectations come
from the scenario's own recompute off the live player basis and crumb positions — never through
the widget's code (the T-057 no-self-test rule):

- **Retired arms:** the chevron half-plane bearing/flip arms (`:5662-5685`), the
  behind-camera hold arm (`:5686-5726` — no camera is read anymore), the synthetic
  degenerate-unprojection arm (`:5727-5746`, replaced by the zero-delta guard arm), the ▲/▼
  cue arms (`:5784-5869`), the city yaw-270/yaw-0 stern-suffix arms and the bread stern
  suffix arm (`:5877-5929`, `:5930-5985`). Deleted helpers:
  `_chevron_screen_dot` (`:5568-5575`) and `_wrap180` (`:5555-5556`) — grep-verified
  2026-10-10 as used nowhere else.
- **Kept arms:** query-vs-scan, distance ±1 m, approach countdown, eat-and-re-aim, city mode
  ±2 m, the label's T-019 theme read, the null arm.
- **New arms:** (1) dead-ahead-level — hover, `drop_crumb` on the nose axis
  (`pigeon_pos − basis.z * 10`), scan-decided; (2) overhead — the T-098 grounded pattern;
  (3) stern — the T-058 placement, `dir_local.z > 0` and `screen_offset.y > 0`; (4) yaw
  follow — same crumb at yaw 0 and 180, each against its own recompute; (5) city arm at the
  existing yaw-90 hover; (6) flash — with crumb A named, `drop_crumb` a nearer B:
  `flash_active` true immediately, then rest after 0.4 s of game time
  (`_wait_frames( roundi(0.4 * 60) )`), plus the three no-flash negatives; (7) zero-delta
  guard via the direct `_aim_bread_pointer` call (the old degenerate arm's call shape,
  `:5743`).
- `combo_strip_reports_last_hit`'s placement leg re-run explicitly (the row nudge touches its
  subject's neighborhood).

VERIFICATION.md: rewrite the pointer row (`:115`) in the same change-set — one scenario, same
name, new description — annotate the T-098/T-058 landed notes (`:522-526`, `:600-606`
neighborhood) as retired by T-111, and add the three Gate 3 lines beside the pointer playtest
block (`:351-355`).
