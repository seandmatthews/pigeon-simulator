# T-095 — Make the off-world return and the buzz flinch visible to pilot sessions

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-042 (landed — the guard this makes visible) · T-014 (landed — the pilot harness that reads the evidence)

## What

Two recurring gameplay events are invisible to pilot sessions, so their
human-verification lines have no evidence path:

1. **The off-world return (T-042):** when the guard snaps the pigeon home, the
   only trace is `off_world_resets` incrementing inside the guard branch
   (`scripts/player.gd:157-159`) — a var only the sim harness reads
   (`player.gd:64` documents it as test evidence). A pilot session shows just
   a normal `grounded` line when the pigeon lands home.
2. **The buzz flinch (T-007):** `tourist.gd:184` increments `buzz_count`
   (`tourist.gd:59`) but fires no signal, and the recorder never reads it — a
   pilot pass within the 2.6 m buzz sphere (`scenes/tourist.tscn:31`,
   `Shape_buzz` radius) at ≥ 12 m/s (`buzz_speed`, `tourist.gd:43`) flinches
   invisibly.

Purely additive observability, no gameplay change:

- `scripts/player.gd`: `signal off_world_reset` + one `off_world_reset.emit()`
  in the guard branch beside the `off_world_resets += 1`, before
  `reset_flight(respawn_point)` (`player.gd:157-159`) — the handler runs
  synchronously on emit, so a listener still sees the void position. Nothing
  in the game listens.
- `tests/capture_recorder.gd`: one more wire in `_ensure_connections`
  (`capture_recorder.gd:357-382` — nine `_connect_once` wires today, none for
  off-world or buzz): `_connect_once(player, "off_world_reset", ...)`
  logging `{"ev": "off_world_reset", "p": <player position at fire time>}`.
  Plus two additive state fields in `_snapshot()`:
  `out["off_world_resets"] = player.get("off_world_resets")` beside the player
  block, and a per-tourist `out["buzz"]` array of `buzz_count` ints built in
  the **same single pass** over the TouristSpawner children that builds
  `out["tourists"]` (`capture_recorder.gd:268`), so index i in `buzz` is the
  flinch count of tourist i in `tourists`.

What this does **not** claim: no behavior change anywhere — the signal has no
in-game consumer and the fields are read-only evidence. The recorder is an
autoload (`project.godot:24`) but inert in sim tests (no session id / flag
file → `_physics_process` returns before `_ensure_connections`,
`capture_recorder.gd:145-147`), so the harness never sees the new connection.

## Why

Verified from pilot session `s2opt1`
(`C:/Users/matth/Documents/pigeon-sim-wt/code-optimization-s2/.captures/session_s2opt1/`,
re-checked at ticket-writing time): `state.jsonl` at t_ms 244852 shows the
pigeon airborne at `p=[16.0, 11.67, -700.77]` — ~330 m past the ±367 m ground
box (`city_span` 234/2 + `ground_extra` 250) — gliding over the void at fwd
14.62 with hunger 18.3; the next events line is a bare
`{"ev":"grounded","t_ms":261151}`, and `state.jsonl` at t_ms 261154 is
`p=[16.0, 0.35, -0.11]`, hunger 10.97 — the guard fired invisibly mid-gap and
the feed recorded an ordinary landing. `grep -c off_world` and
`grep -c buzz` over `events.jsonl` both return 0. Meanwhile T-042's/T-036's two
pending Gate 3 lines (the return reads as "came home" [screenshot]; the hunger
bar never pauses — `VERIFICATION.md:293-294,297-298`) cannot be evidenced from
pilot sessions, and no pilot session can show a buzz flinch happening.

## Acceptance criteria

- [ ] Gate 1b `off_world_fall_returns_home` extended
      (`tests/sim_test.gd:3312-3348`): connect a local counter to
      `Player.off_world_reset` at scenario start (after the
      `off_world_resets = 0` zeroing at `:3320`; disconnect at scenario end —
      the harness player is shared across scenarios, the `hunger.free()`
      housekeeping pattern at `:3342`) and assert the signal fired exactly
      once alongside the existing `off_world_resets == 1` asserts (`:3332`,
      still 1 after the stability window `:3336-3338`)
- [ ] Gate 1b full suite green — no new scenario needed (the signal rides the
      existing guard path; the recorder is inert in the harness, so the
      scenario counter is the only sim consumer)
- [ ] A pilot session flying the T-036 excursion (out past the apron, dive
      below the guard) shows an `off_world_reset` events line carrying the
      void position between the last outbound state and the corridor
      `grounded` line, and `off_world_resets` rising 0 → 1 in the state
      stream — the evidence path for the two pending Gate 3 lines
- [ ] A pilot session performing a ≥ 12 m/s pass within ~3 m of a strolling
      tourist shows a non-zero entry in the state stream's `buzz` array,
      aligned with that tourist's index in `tourists`
- [ ] No gameplay change: every existing Gate 1b scenario outcome unchanged
      (the emit is beside the increment; the fields are read-only)

## Verification

Gate 1 + Gate 1b (extend `off_world_fall_returns_home` only, as above) +
Gate 2 unchanged (autoplay unaffected) + a pilot-harness rerun in place of new
machine gates for the observability itself: repeat the T-036 excursion
(fly ~400 m past the apron, dive below the guard) and a fast flyby past a
stroller; verify the events/state evidence in the two pilot criteria above.
Gate 3: the T-042/T-036 lines keep their pending status until a human pass —
this ticket gives them the pilot-evidence path they were missing.
