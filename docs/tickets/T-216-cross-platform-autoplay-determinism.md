# T-216 — Cross-platform autoplay determinism: the world's citizens diverge by platform

- **Status:** proposed · **Category:** code-optimization (diagnosis-first) ·
  **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** nothing (the evidence landed with T-215)
- **Refs:** T-215 (this ticket's instrument and its gate) ·
  `tests/autoplay.gd` (the AMESDBG=1 diagnostic line, landed there) ·
  `docs/references/ames-survey/perf/probe-gatebox-2026-11-18.md` (the gate
  runs table) · the gate box (i7-6700, Ubuntu, Mesa 26.0.8) vs the dev
  desktop (Windows, RTX 4080)

## What

The two platforms run the SAME seed, the SAME code and the SAME AI inputs
and still diverge. Measured with the autoplay's per-second trace and the
AMESDBG diagnostic (sub-metre y, vy, nearest-crumb distance), headless on
both machines at the T-215 branch tip:

- The runs are identical through **t=17** (player y 0.962 / vy −1.578 on
  both platforms, three decimals) — the boot, the world build, the crumb
  seed and the AI's first two cruise legs are platform-stable.
- They diverge at **t≈20–25**: identical glide inputs, but Windows
  descends into its landing (t=25: y 1.561, vy −1.076) while the gate box
  climbs off the same flare (t=25: y 2.068, vy +0.751) — a marginal
  plate-contact/flight-math resolution differing by platform ULPs, which
  the bang-bang AI then amplifies.
- The consequence chain: the world's citizens diverge (poop splat counts
  34 vs 42 pre-fix, 20 vs 21 post-fix — the pigeons' own trajectories
  still end within a decimetre of each other), while crumb placement and
  player gross trajectory stay aligned.
- The eat loop itself is FIXED in T-215 (the autoplay's settle press makes
  the land→waddle→eat cycle close on both platforms — eaten=8 on both at
  the landing tree); what remains divergent is everything the AI does not
  actively pin: citizen wander paths, contact chains, splat targets.

So the open question this ticket owns: **is cross-platform bit-level
determinism a goal for this repo's checks?** The Gate 1b suite runs
headless on both machines and passes — its scenarios pin their own state
and never byte-compare a live world across platforms. The autoplay (Gate
2) now also closes on both. The residual divergence matters only if a
future check wants to compare citizen-level streams (state.jsonl car/
tourist rows) across machines — today nothing does.

Candidate seams, in the order the evidence points:
1. The physics engine's contact solving differing across the platform
   toolchains (MSVC vs GCC builds of the same GodotPhysics3D source —
   FMA/reassociation ULPs), flipping marginal landings.
2. Platform libm in the flight model's transcendentals (`atan2`/`sin`/
   `cos` in `player.gd`'s flight and the AI's bang-bang heading compares).
3. Any wall-clock read leaking into gameplay ordering (none found yet —
   the boot/populate chain is seed-deterministic on both platforms per
   the t=17 identity).

## Why

The T-215 round-1 review held the box gate open on this: the eat loop's
platform fragility masked itself as a perf failure, and the only honest
fix (the AI's settle press) left the underlying divergence unnamed and
unowned. This ticket gives it a name, an owner and a decision: either a
targeted determinism fix (pin the marginal-contact classes the game's
checks lean on) or a documented reality (the repo's checks never
cross-compare citizen streams — record that contract in VERIFICATION.md
and close).

## Acceptance criteria

- [ ] The diverging seam identified with evidence (a minimal repro: the
      same input stream, one physics step, differing contact resolution —
      or the libm call whose result differs)
- [ ] Either the seam pinned (the game's checks get a platform-stable
      contract) or the no-cross-compare contract recorded in
      VERIFICATION.md
- [ ] *(Gate 1b)* full suite green on both machines after whatever lands
- [ ] *(box gate)* still `GATE-BOX RESULT: PASS` (the T-215 bar holds)

## Verification (proposed)

Gate 1 · Gate 1b (both machines) · the box gate at the enforced 30 fps
floor · Gate 3: none (the divergence is sub-perceptual — the player sees
the same game on both; this is a harness/CI concern).
