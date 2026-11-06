# T-169 — Dev tool 3: the call verb — one-hop method invocation on the running world from a JSONL line

- **Status:** doing · **Category:** tooling · **Value (1-5):** 3 ·
  **Risk (1-5):** 3
- **Depends on:** T-167 (the `_execute_dev` seam, the `_dev_allowed()`
  debug-build gate, the `pilot_dev`/`pilot_dev_unknown` event contract);
  T-168 recommended but not required (the pack proves the dispatcher
  pattern and covers the Vector-heavy cases the call verb deliberately
  does not sugar)
- **Refs:** `tests/capture_recorder.gd` (`_execute_dev` dispatch chain,
  T-167) · `scripts/hunger.gd:91-93` (`eat(amount)` — the float-arg happy
  path used by the Gate 1b scenario) · `game.gd:189-192` (autoloads are
  reachable by name — the resolution root) · the pilot channel contract,
  `capture_recorder.gd:200-216` (JSONL, consume-and-delete, works while
  paused)

## What

The owner's end game: "the ability to invoke whatever functions you want in
the world at run time." This ticket adds ONE verb that makes one-off
investigation stop needing tickets at all:

```json
{"dev":"call","node":"Game.hunger","method":"eat","args":[10.0]}
```

1. **Resolution:** `node` is an autoload name, a dotted path from an
   autoload (`Game.hunger`), or a `/root/...` path — resolved with
   `get_node_or_null`, no wildcards, no search. Method resolved via
   `has_method` + `callv`. Results and errors are EVENTS, not crashes:
   `pilot_call_result` `{node, method, result}` on success,
   `pilot_call_error` `{node, method, error}` for unknown node, unknown
   method, or arity/type failure — the session continues either way.
2. **The single coercion rule:** JSON arrays of 2–4 numbers coerce to
   Vector2/Vector3/Vector4 ONLY when the method's declared parameter type
   demands it (read once per method name from `get_method_list()`).
   Everything else passes as raw JSON types (float/string/bool/null/
   array/dict) — `callv` semantics, no magic. Without the rule, every
   position-taking method is unreachable; with ONLY this rule, the surface
   stays predictable. Return values serialize the same way in reverse
   (known math types → arrays, everything else via `str()` with the type
   named).
3. **The safety fence — this is a remote procedure call, NOT a scripting
   console.** The anti-rabbit-hole contract, stated here so future
   extensions argue against a written line:
   - **One hop only.** A call is one method on one resolvable node. No
     expression evaluation, no chaining on results (a returned object is
     serialized as inert data), no global function calls, no arbitrary
     property writes (`set`-with-coercion would smuggle the chaining back).
   - **Denylist:** node paths resolving inside the CaptureRecorder itself
     (no self-calls into the channel), and the methods `free` /
     `queue_free` / `_pilot_step` — logged `pilot_call_error` if aimed at.
     Release exports refuse everything anyway behind the T-167
     `_dev_allowed()` gate.
   - **Debug-build only**, inherited from T-167 — the shipped game has no
     invocation surface.
4. **Gate 1b scenario `dev_call_verb`** (registered in the
   `sim_test.gd:242` block; the T-167/T-168 scenarios stay as landed),
   driven through `_execute_dev` with explicit dicts: (a) happy path —
   drain `Game.hunger` some, `call eat [10.0]`, read the value rose by
   10; (b) the coercion rule — a call passing `[x,y,z]` into a
   Vector3-typed parameter lands as a Vector3 (a `reset_flight`-style
   method on the player, or a dedicated probe node if touching the player
   is disruptive); (c) error paths — unknown node, unknown method, wrong
   arity each log `pilot_call_error` and the harness continues; (d) the
   denylist — `free` aimed at a real node is refused; (e) `allowed=false`
   refuses the verb.
5. **Docs in the same change-set:** VERIFICATION.md Gate 1b row; AGENTS.md
   pilot verb list gains `call` with the one-hop contract summarized
   (agents read the fence before reaching for it).

**Prior art (the industry shapes this ticket copies — checked against the
record 2026-11-05, not from taste):** Source's
`ent_fire <target> <input> <parameter>` — in every Source game since 2004,
behind `sv_cheats 1` — is this verb's ancestor and its strongest
validation: a named input with a parameter on a named entity, ONE hop, no
chaining, the most-used entity-debug tool of that ecosystem (its `!picker`
crosshair selector is the T-168 "nearest car" idea). Unreal's
`CheatManager` + `UFUNCTION(Exec)` is the ALLOWLIST pattern — named
functions callable from the console, compiled out of shipping builds;
T-168's pack is that pattern, and this verb is deliberately MORE
permissive (reflection over a denylist) but fenced harder (debug-build
only, one hop, denylist). Firaxis' FireTuner is the pilot-channel
architecture at studio scale — an external process executing against the
live game, opt-in, achievements disabled while attached (our "verbs do
nothing in release" contract). Unity's ecosystem (RuntimeDebugAction,
IngameDebugConsole) is registration-based dev-build invocation — the
dispatcher pattern again. Loosening the one-hop fence therefore departs
from ~20 years of precedent, not just this ticket's taste; it takes its
own ticket.

**No reference photos:** dev tooling; no research phase, no image opened.

**Not claimed:** no expression language, no chaining, no property-set
verb, no global-function surface (the fence above is the ticket's core
design, not an omission to fill later by default — loosening it is a
future owner decision with its own ticket); no `pilot.py` wrapper (`pilot.py
call <json>` as a REPL-ish sugar is optional follow-up; the raw JSONL line
works today); no new named verbs (T-168 owns the pack; sugar wrappers get
added when a ticket needs them); no return-value marshalling back into the
command stream (results are events an agent reads via `pilot.py events`).

## Why

T-168's pack covers the verbs someone predicted; the call verb covers all
the ones nobody predicted — "what does the favor ledger actually hold
right now", "call the spawner's debug dump", "tick this one timer manually"
— without a ticket, a code edit, or a restart. It is deliberately LAST in
the sequence and deliberately fenced: the named pack (T-168) plus one-hop
calls (this ticket) give an agent effectively everything a debug console
would, at a fraction of the safety surface, on a channel that already
works headless and while paused. If a real workflow needs chaining or
expressions, that argument happens against the written fence — not by
drift.

## Acceptance criteria

- [x] `{"dev":"call",...}` resolves autoload/dotted/root paths, calls via
      `callv`, and acks `pilot_call_result` with a serialized return
- [x] The coercion rule works and ONLY for declared Vector2/3/4 parameters
      (a float-array into an untyped or Array parameter stays an array —
      pinned by the scenario)
- [x] Unknown node / method / arity and denylisted targets log
      `pilot_call_error` and the session continues; release builds refuse
      behind `_dev_allowed()`
- [x] *(Gate 1b)* new `dev_call_verb` scenario registered in the
      `_run_scenarios` block with the five legs above; full suite 0
      failures: `godot --headless --fixed-fps 60 --path .
      res://tests/sim_test.tscn`
- [x] *(Gate 1)* `godot --headless --path . --import` and the 120-frame
      boot exit clean, zero ERROR lines
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`)
- [x] VERIFICATION.md Gate 1b row + AGENTS.md `call` entry with the
      one-hop contract, same change-set
- [x] *(Gate 3)* none — same honesty as T-167: dev-only surface, refused
      in release exports, nothing player-visible to judge

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with
`dev_call_verb` registered and its VERIFICATION.md row · Gate 2 autoplay ·
Gate 3 explicitly none (dev-only, fenced, release-refused — same reasoning
as T-167). The real-world pass is implicit and ongoing: every agent session
that uses `call` without wedging the game is a Gate 3 data point.

## Recorded (2026-11-06, landed run)

- **Gate 1b bite** (the scenario's `SIM DATA` line, `drain_per_second`
  hand-raised to 60/s for the run and restored after):
  `SIM DATA dev_call_verb: eat +10.00 (acked void-null=true), tells vec='Vector3:(1.0, 2.0, 3.0)' arr='Array:3:float' untyped='Array:2', defaulted=true add=true tp=true, errors node/method/arity=true/true/true moved_nothing=true, deny free/qfree/self/step=true/true/true/true game_alive=true, refused=true no_leaked_eat=true`
  followed by `SIM PASS dev_call_verb`. The reads behind each arm: the
  `Game.hunger` eat lands +10.00 exactly with the void return serialized as
  JSON null; the `[1,2,3]` array coerced into the probe's Vector3-typed
  parameter (the method ran — an uncoercing verb would have type-refused
  pre-call) while the same shape into Array-typed and untyped parameters
  stayed an `Array` (the tell names the element type); the undershoot into
  `probe_defaulted` filled the 2.5 default; the `/root`-path `reset_flight`
  landed the pigeon on target with velocity exactly `Vector3.ZERO`; and
  every error/denylist arm refused with its named code while the session
  continued (exactly one eat result ack exists — a leaked refused call
  would log a second).
- **Engine behavior measured on 4.7.2** (a headless probe, before writing
  the verb): `get_method_list()` cannot see default values (required and
  defaulted args both read `usage: 0`; untyped params read `usage: 131072`)
  — so the arity gate refuses only OVERSHOOT pre-call and undershoot rides
  the engine, which fills defaults when they exist (the `probe_defaulted`
  pin) and refuses when they do not; `root.get_node_or_null("Game.hunger")`
  returns null for a dotted path (subnames do not resolve) — hence the
  resolver splits dots itself and walks child nodes first, node-holding
  script properties second; and `callv` with bad arity/types prints an
  engine ERROR and returns null (the method does not run) — hence the
  pre-call type table turns those failures into named `pilot_call_error`
  events instead of silent nulls.
- **Full suite:** 174 passes, `SIM SUMMARY: 0 failure(s)`, exit 0. The
  remaining log ERRORs are pre-existing baseline (the `route_exhausted`
  double-connects, the cafe-sitter lookups, and two Parse-JSON lines from
  the untouched `pilot_frame_step`/`dev_hunger_lock` live-channel reads).
- **One latent suite bug fixed in passing (T-167's scenario):** GDScript's
  `%` binds tighter than `+`, so an UNparenthesized `"...%s..." +
  "...%s..." % [args]` formats only the LAST string segment — the
  `dev_hunger_lock` `_check` detail has evaluated that way since T-167
  (spurious "not all arguments converted" ERROR after every pass; the
  failure detail would have printed mangled). Both detail strings (T-167's
  and this ticket's) are now parenthesized; the assertion expressions are
  untouched.
- **Gate 1:** `--import` exit 0 (the sole ERROR line is the documented,
  accepted godot_mcp "N resources still in use at exit" notice) and the
  120-frame `--quit-after 120` boot exit 0 with zero ERROR lines.
- **Gate 2:** `AUTOPLAY DONE ok=true t=33.0 fps=127 ... splats=8 ...
  restart=true` — exit 0.
- **Gate 3:** none, per the ticket — the surface is dev-only, refused in
  release exports behind `_dev_allowed()`, and nothing player-visible
  changed. Every future agent session that `call`s without wedging the
  game is the ongoing Gate 3 data point.

**Final tuned values:** none retuned — this ticket adds no gameplay
constants. The shipped surface is the `call` verb's behavior contract
(resolution arms, the single Vector2/3/4 coercion rule, the denylist, the
event names) plus the tests-only `CallProbe` (tests/call_probe.gd), whose
methods exist to be called by the scenario and ship with `tests/`.
