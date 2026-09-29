# T-016 — Pigeon silhouette & readable backdrops

- **Milestone:** M1 · **Priority:** P1 · **Size:** S · **Status:** done
- **Depends on:** T-011, T-013 (landed)
- **Refs:** `docs/DESIGN.md` → Art style; playtest findings from the visual-design
  play pass (2026-09-29)

> Ticket ID note: T-015 is not in this worktree's index — sibling lanes branch in
> parallel and their tickets are not visible here. The workflow assigned T-016 to
> this lane; T-016 was free in `docs/tickets/README.md`, so it is claimed here.

## What

The player pigeon — the one object on screen in every frame — was near-invisible
against the two most common backdrops, and its grounded "folded" pose reads as a
glide:

- Body albedo (0.62, 0.64, 0.68) was virtually identical to the sidewalk
  (0.62, 0.61, 0.58) and lighter than the sandy-cream district facades; with the
  sun at energy 1.3 over sky ambient, mid-gray albedos clipped to white.
- Darkened/cooled the body toward a rock-dove blue-gray, kept the pale head and
  darker wingtips/tail as identity accents, and pulled the sun back so the city
  stops blowing out.
- Folded-pose tuck: re-tested in an A/B pilot experiment (review challenge
  upheld — the earlier validation captures did not show the claimed tuck). The
  deeper fold (−0.35 lift / 1.5 sweep) narrows the projected wing plane only
  ~15 % (109 → 93 px in the widest row) and is invisible at a glance, because
  the splay comes from the 0.24 m wing chord presenting laterally from the
  chase cam, not from the pose angles. **Pose values were held back**; fixing
  the grounded read needs a mesh/rig change (recorded in VERIFICATION.md →
  Known issues).

## Why

Flight-speed readability is the game's first presentation contract: you must be
able to track your own bird against road, sunlit sidewalk and facade at speed.
Everything else (juice, popups, districts) is judged through that read.

## Acceptance criteria

- [x] The pigeon's body reads against sunlit sidewalk and the sandy-cream facade
      family: Euclidean RGB distance ≥ 0.20 to sidewalk and all three cream
      colors *(machine-verified: Gate 1b `pigeon_silhouette_contrast` — sweep
      measures creams at 0.67 / 0.54 / 0.74; sidewalk 0.33 by the same metric)*
- [x] The body is darker than every district backdrop's mean luminance by
      ≥ 0.05 — it carries the silhouette against all four districts, not just
      the gated pair *(machine-verified, same scenario — worst margin 0.057
      vs brick 2)*
- [x] Wingtips/tail stay a readable step darker than the new body
      *(machine-verified: tip-vs-body Euclidean ≥ 0.15 — `Mat_dark` retuned to
      keep the step after the body darkened)*
- [x] The pale head stays lighter than the body *(machine-verified, same
      scenario)*
- [x] The sun no longer overdrives the city: energy ≤ 1.15 while staying warm
      *(machine-verified, piggybacked on `hit_shake_and_score_pulse` — the
      scenario's detail line now reports `sun_energy=1.10`)*
- [x] Folded-pose question resolved honestly: A/B pilot re-run (sessions
      `vd5a-baseline` / `vd5b-tucked`) showed no visible tuck; values held back,
      root cause recorded *(see What + VERIFICATION.md → Known issues)*
- [ ] Human pass: the bird reads at ~20 m against road / sunlit sidewalk / cream
      facade; overall city warmth/brightness still reads "warm sun" after the
      1.3 → 1.1 change (the T-013 warmth judgement is re-based, Gate 3 —
      pending in VERIFICATION.md)

## Verification

Gate 1 (import + 120-frame boot clean, exit 0) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`:
64/64 `SIM PASS`, exit 0, no SCRIPT ERROR lines (the workflow gate caught a
freed-Sun read in the scenario's detail string; fixed by snapshotting
`sun.light_energy` before `main_game.free()`, same pattern as the existing
scale/trauma locals), including the new `pigeon_silhouette_contrast` and the
amended `hit_shake_and_score_pulse` · Gate 2 autoplay runs in the workflow ·
Gate 3 human pass pending (two new playtest lines).

## Landed (implementation notes)

- `scenes/pigeon_visual.tscn` — `Mat_body` (0.62, 0.64, 0.68) →
  (0.38, 0.42, 0.47); `Mat_head` (0.52, 0.54, 0.6) → (0.6, 0.62, 0.66);
  `Mat_dark` (0.24, 0.24, 0.28) → (0.15, 0.15, 0.18) so wingtips/tail keep a
  readable step over the darker body. No physics nodes touched.
- `scenes/main.tscn` — Sun `light_energy` 1.3 → 1.1. The only runtime Sun
  reader is the sim harness, which checked color only — now also caps energy.
- `tests/sim_test.gd` — new `pigeon_silhouette_contrast` scenario (loads the
  live materials + `City` palette constants): Euclidean ≥ 0.20 vs sidewalk and
  the three cream colors; luminance ≥ 0.05 darker than every district backdrop
  mean; tip ≥ 0.15 darker than body; head lighter than body; the 12-color sweep
  prints informationally (a per-channel gate across all 13 backdrops is only
  satisfiable by a near-black bird — re-specced per review). Sun-energy cap
  piggybacked on the existing `hit_shake_and_score_pulse` main-scene
  instantiation instead of a new one.
- `VERIFICATION.md` — Gate 1b table row, amended hit-shake row, two Gate 3
  playtest lines, Known-issues entry for the open folded-pose read.

## Tuned values (final)

| Where | Old | New |
| ----- | --- | --- |
| `Mat_body` albedo | (0.62, 0.64, 0.68) | (0.38, 0.42, 0.47) |
| `Mat_head` albedo | (0.52, 0.54, 0.6) | (0.6, 0.62, 0.66) |
| `Mat_dark` albedo (tips/tail) | (0.24, 0.24, 0.28) | (0.15, 0.15, 0.18) |
| Sun `light_energy` | 1.3 | 1.1 |
| Gates | — | body↔sidewalk/cream Euclidean ≥ 0.20 · body mean ≥ 0.05 darker than every backdrop mean · tip step ≥ 0.15 · sun ≤ 1.15 |
