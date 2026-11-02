# T-146 — The elder sits IN the bench: thighs rest on the seat, no more clipping

- **Milestone:** Owner playtest 2026-11-02 (on the T-141 after-build, with
  screenshot: "he's still not sitting on the bench. His legs are clipping
  through the bench. and he's a few inches above the bench also") ·
  **Status:** done 2026-11-02 · **Category:** visual-design ·
  **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-141 (the seated composite this re-derives AGAIN — the
  T-141 target was derived from the hip bone to the GLUTE and was still
  ~0.07 m too high for the pose's thighs)
- **Refs:** `scripts/elder.gd` (`SEAT_SINK`), `tests/sim_test.gd`
  (`elder_seats_on_the_bench`), the owner's screenshot (2026-11-02 —
  thighs passing through the seat, a visible gap under the pelvis).

## What

T-141 landed the hips bone at seat + 0.105 aiming the glute underside at
the seat plane. The owner's screenshot shows the truth of the pose: the
SIT clip's thighs run nearly horizontal at hip height, so at that sink the
thighs ride ~0.07 m ABOVE the seat (clipping through the slab's top edge
at the knees) and the pelvis shows a visible gap above the seat — the
glute underside is ~0.05-0.06 below the hip bone, not the ~0.10 the
T-141 anthropometric estimate assumed.

**Fix.** The contact target moves from the glute to the THIGHS — the mass
that actually meets the bench: hips bone at **seat + 0.04**
(`SEAT_SINK` −0.399 → **−0.465**). The pose's thighs then rest ON the 0.60
seat, the glute underside settles 0.01-0.02 into the slab (reads as
sitting, the low-poly contact line), the knees sit at the slab's top edge
with the shins in front of it, and the feet stay ~0.22 above the pavement
(the same documented dangle). The clip's own chair height
(hips 0.518 − feet 0.087 = 0.43) is what the bench has to meet; the
elder's spot origin (seat top) is pinned by the T-137 state machine and
stays.

## Known pin breaks, amended in the same change-set

- `elder_seats_on_the_bench`: the value lock (−0.399 → −0.465) and the
  hips band (seat+0.07..0.14 → seat+0.00..0.08, target 0.04); the detail
  string's want value. The feet and hair legs re-verified (the hair
  metric is sink-independent — both bone and hair ride the same body).
- VERIFICATION.md's `elder_seats_on_the_bench` row re-derived.

## Not claimed

- Bench height (0.60 — the pose's natural chair is ~0.45; the dangle and
  the tall-knee look are the accepted geometry, documented since T-141).
- The café stools (0.45 — already pose-natural).

## Acceptance criteria

- [x] (Gate 3, screenshot) The elder's thighs rest ON the seat, no slab
      clipping, no pelvis gap — after pair in `.captures/t146_sit/`
      (`contact_zoom_far.png` + `after_contact_close.png`; the before is
      the owner's screenshot referenced above).
- [x] (Gate 1b) the re-banded `elder_seats_on_the_bench` green; FULL suite
      0 failures — the T-137 migration scenarios byte-unchanged (the root
      placement is the state machine's; only the visual sink moves).

## Implementation record (2026-11-02)

`SEAT_SINK` −0.399 → **−0.465** (hips bone seat +0.105 → **+0.04**); the
contact target moved from the glute line to the pose's THIGHS. The
scenario re-banded (hips [0.00, 0.08], value lock −0.465) and VERIFICATION's
row re-derived. Full suite green: `SIM PASS elder_seats_on_the_bench` +
`SIM SUMMARY: 0 failure(s)` (log `/tmp/sim_t146.log`); the pilot zooms
show the thighs resting on the seat, the pelvis at the slab, the knees at
its edge, the shins in front, the feet ~0.22 up (the documented dangle).

**Human playtest:** owner to confirm the contact line reads right in
play — note the contact is now the thighs, so the visible butt line sits
0.01–0.02 INTO the slab by design (the low-poly sitting read; the T-141
"kissing" target is what produced the gap).
