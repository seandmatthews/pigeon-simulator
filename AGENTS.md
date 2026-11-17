# AGENTS.md

Guidance for AI agents (and humans) working in this repo. Read this before making
changes, and follow [`VERIFICATION.md`](VERIFICATION.md) before calling any change done.

## What this project is

**Pigeon Simulator** — a third-person 3D flight game in Godot. You are a pigeon in a
city: eat bread to survive, and earn points by pooping on tourists and their cars.
Design rationale lives in [`docs/DESIGN.md`](docs/DESIGN.md); work is tracked in
[`docs/tickets/`](docs/tickets/README.md).

**The world (T-177 cutover):** the game boots **Ames, Iowa** — the resident baked
world (`scripts/ames_world.gd` over the committed `data/ames/` pack + chunk bake),
spawn over Central Campus near the campanile. The world is selected by the
`Game.world` setting (`"ames"` is the default AND the only legal value since the
cutover; the pilot's `PIGEON_WORLD`/`AMES_AUTOPLAY` switches are accepted aliases).
The old procedural **Windrow city was retired at the cutover** (owner fork
2026-11-09, master plan §11.2 — no debug toggle): `city.tscn`/`city.gd` survive only
as the staged node `main.tscn` swaps away at `_ready` and as the base-class seam
(`AmesWorld extends City`) the citizen systems read — and since the **T-184 R2
cutover the town is ALIVE at every boot, nothing flag-gated**: since T-178 the
TRAFFIC system drives the real street graph (`scripts/ames_traffic_graph.gd`: a
live 14-moving + 12-parked car fleet with right-hand lanes, speed classes and the
rail-crossing facts), T-179 ported the T-166 calm etiquette onto those graph
routes, T-180 painted the real corners (crosswalks, stop bars, signals the
fleet obeys), since T-181 the PEDESTRIAN ZONES put the people where Ames
actually has them (`scripts/ames_ped_zones.gd`: the Welch strip, downtown
Main, Central Campus, the LaVerne shore and the MU corner — pinned caps, T-165
gait constants, benches at the T-163 sit law, the crossing fence at T-180's
bands), T-182 staged the PARKING stock on the census curbs and lots
(`scripts/ames_parking.gd`), and T-183 put the FAVOR economy on the real
gathering places (the zone benches seat the favor elders — campus 3 + downtown
2 + shore 2, each with its bread spot at the toss line; the trust/share loop
runs there). Since the **T-196 R3 cutover the town's LANDMARKS are the real
ones at every boot** (the R3 heroes all live default-on, no flags): the
LaVerne swans (T-185), the campanile hero in buff/tan (T-186), the Central
Campus lawn with its crossing axes + fountain (T-187), the campus row west
heroes (T-188), the MU + Parks pair at the corrected corner (T-189), the
Marston water tower (T-190), the Jack Trice bowl + Hilton drum + tailgate
lots (T-191), the downtown bandshell/civic pair + Main Street fabric
(T-192), the civic water tanks with their AMES diamonds (T-193), the rail
corridor's depot/crossbucks/coal drag (T-194) and the SE grain-elevator
cluster (T-195) — every placeholder slot these heroes own is superseded
1:1 (`r3_cutover_swap_set` pins the swap set complete and the venue-fixup
gray boxes as honest LOD0); the fidelity walk (F-01..F-24) lives in
T-196's ticket. Since the **T-202 R4 cutover the town has its NAME on
things at every boot — all R4 text lives default-on, no flags**: the
T-197 text capability (the `SignText` component — Oswald letterforms
through a pinned per-typology legibility budget: plaque 140 / box 200 /
blade 160 / street 200 / pole 260 metres of readable distance per metre
of capital height, visual-only, no colliders) carries the tier-1 venue
signs (T-198 — the fourteen names a student says first; 13 placed + The
Cafe staged for T-205), the tiers 2–3 venue signs + the mourned ghost
plaques (T-199 — 27 signed of the 34 tier-2/3 POIs, the unsigned set
closed with reasons; 11 memorial plaques at their closed rooms), the
MUTCD street-name blades (T-200 — 85 green blades over the 70 pinned
spine corners at the R4 landing; T-203's bbox east pinned four more
all-way corners on East Lincoln Way, taking the set to 89 blades over
74 corners, mast stacks at signals, posts at the all-way stops; T-204's
bbox south pinned the south fabric's spine corners — University
Boulevard × Mortensen Parkway / South 16th Street / McCarthy Road /
Beach Avenue and the residential joins — taking the set to 99 blades
over 79 corners; the unreached spine names stay a closed ledger,
now just [Mortensen Road — the data spells it "Mortensen Parkway" —
and Stange Road]) and
the campus + civic name plaques (T-201 — the nominative names in plain
type on the heroes' own faces + the Marston base marker; T-204 placed
Reiman Gardens on its ticket's own hero, so the table places all 12 —
no marks anywhere, names and years only).
`r4_cutover_text_ledger` pins the whole ring joined: every family live
at its pinned count on the default boot with the legibility law re-run
over all 162 texts (T-204's re-pin: the blades ring 99 + the placed
Reiman plaque 12; T-203's re-pin had carried the 151-text ring) — the
cutover's Gate 3 is the owner's
fly-to-your-bar test (the fly-by-reading sign-off recorded in T-202's
ticket closes the ring). The tank diamond's letterforms stay the legal
pass's honest remainder — no R4 ticket staged them. Since the **T-203
bbox east the playable core reaches Bandshell Park**: the game-core box
grew +248 m east (E edge −93.6100 → −93.6070, data pack v2), landing
Bandshell Park's block inside the
core (the T-192 bandshell hero's ground is now playable around, the
census §5 ⚠ closed) and the S Duff corridor's east context blocks with
it; every count the citizen systems pin carries its recorded v1 + strip
delta, diff-proven by the `ames_bbox_east` Gate 1b scenario. Since the
**T-204 bbox south the town has its garden gate**: the core box grew
+1.0 km south (S edge 42.0120 → 42.0030, data pack v3 — SUMMARY §3's
planned window), landing Reiman Gardens' whole 73,202 m² grounds, the
ISU Vet Med campus and the south blocks inside; the QA's biggest
blocks-build find got its structural fix here (the conservatory hero
builds as the WHOLE 59 × 88 m building — way/180765068, superseded 1:1 —
with the named Hughes glasshouse a DISTINCT 465 m² volume in the scene
tree), the wing-form blue-glass roof + the butterfly-wing entrance
canopy (spans UNVERIFIED, the estimate recorded) carry the silhouette,
8 ambient butterflies dress the entrance beds (count ≤ 12, ambient
only), and the T-201 plaque reads the arrival face; the south strip's
census §6 rule split is 47/9/657 over 713 buildings, and the tailgate
zone's lat/lon window revealed its southern tail (19 → 33 lots /
8.9 → 11.9 ha — the game's tailgate stock grows with the map).

## Stack & tooling

- **Engine:** Godot 4.7, standard build (no .NET). Language is GDScript 2.0 — no C#, no GDExtension.
- **Editor binary:** `~/bin/Godot_v4.7.2-stable_win64.exe` (the `_console.exe` variant is
  better for terminal/headless runs). Not on PATH by default.
- **Version control:** git. Never commit `.godot/`. Do commit the `*.import` and `*.uid`
  files Godot generates next to assets and scripts.
- **Addons/plugins:** don't add any without agreeing with the user first.

## Layout

```
project.godot   engine config: input actions, physics layer names, main scene
scenes/         .tscn files, snake_case, one gameplay entity per scene
scripts/        .gd files, snake_case
tests/          headless sim harness (VERIFICATION.md Gate 1b)
assets/         art / audio / fonts; third-party credits in assets/CREDITS.md
tools/          owner ops scripts (web deploy: tools/deploy-web.sh)
docs/           DESIGN.md and tickets/
```

## Conventions

### GDScript
- **Tabs** for indentation. snake_case for files, functions and variables; PascalCase
  for node names inside scenes.
- Static typing wherever the language allows (`var speed: float`, `-> void`, typed signals).
- Use `##` docstrings on scripts and non-obvious functions.
- Node access: `@onready var label := %StatsLabel` with "unique name in owner" set on the
  target node. Avoid `get_node("A/B/C")` chains into other nodes' subtrees.
- Prefer composition (child nodes + signals) over deep inheritance.
- Game-wide state (score, hunger, settings) belongs in autoload singletons under
  `scripts/` — add one only when a ticket calls for it; don't stash globals on `Main`.

### Input
- All input actions are declared in `project.godot` under `[input]` and referenced by
  name only (`Input.is_action_pressed("flap")`). Never use raw keycodes in scripts.
- Current actions: `flap` (Space), `poop` (F), `pitch_up`/`pitch_down` (W/S),
  `turn_left`/`turn_right` (A/D), `boost` (Shift), `pause` (Esc).
- Adding or changing an action requires updating the controls tables in `README.md`
  and `VERIFICATION.md` in the same change.

### Physics
- Use the named collision layers from `project.godot` and set **layer and mask**
  deliberately on every physics body:
  1 `world` · 2 `player` · 3 `npc` · 4 `vehicle` · 5 `pickup` · 6 `projectile`

### Scenes
- New entity → new scene + its script (`scenes/tourist.tscn` + `scripts/tourist.gd`).
- Keep `.tscn` files hand-editable: translation-only transforms are fine in the file;
  do rotations in `_ready()`/scripts (the Sun in `main.gd` shows the pattern) so
  scene files stay free of hand-computed basis matrices.

## Agent play: godot-mcp (eyes-on verification)

An MCP server lets agents launch the game, inject input, and capture screenshots.
Wiring lives in `.zcode/config.json` (`godot` → `http://127.0.0.1:9090/mcp`), the
editor-side pieces in `addons/godot_mcp/` (editor plugin + the `MCPRuntimeProbe`
autoload — the probe no-ops outside debug sessions, leave both in place).

- **Shared server first.** The server is shared with the cozy-carnival suite and
  lives in that sibling checkout — this repo deliberately names no foreign path
  (the suite was renamed once already). If port 9090 isn't answering, start it
  before opening the editor:
  `cmd //c .zcode/tools/serve-godot-mcp.cmd` (run it in the background; it
  resolves the suite — `GODOT_MCP_REPO` env var or sibling probe — and keeps the
  suite's identity-checked shared server. If the suite's packaged launcher dies
  silently, as it does as of 2026-10-12, the wrapper falls back to a direct
  `python -m` start that the suite's port checker still classifies as OURS).
  Idempotent. Editor bridge: `ws://127.0.0.1:9080`.
- **One editor per bridge.** Open this project's editor
  (`~/bin/Godot_v4.7.2-stable_win64.exe --path . --editor`) and preflight with
  `godot_get_server_info` before any runtime tool — if `bridge_connected` is false,
  the tool is talking to nobody (or another project).
- **A fresh MCP session has only core+inspection.** Enable what the session needs
  once: `godot_enable_toolset` with category `runtime`, `input`, `testing` (and
  `editor` for editor screenshots).
- **Play loop:** `godot_runtime_play_scene` (e.g. `res://scenes/menu.tscn`) →
  `godot_runtime_capture_game_screenshot` → input → screenshot → … →
  `godot_runtime_stop_scene`.
- **Input must be press+release pairs.** A lone `pressed=true` may never complete
  (the focused button waits for release). Use `godot_input_play_sequence` with a
  down event and an up event ~120 ms apart; confirm delivery via
  `godot_input_get_stats` (`injected` count). This is how the title screen's Space
  shortcut was proven to start a run.
- **Gameplay input is action events, not raw keys.** The movement bindings use
  *physical* keycodes, which synthesized `{"type":"key"}` events don't carry —
  a raw W press moves nothing. Use `{"type":"action","action":"pitch_up"}`-style
  events for in-game driving; raw keys only reach menus (Space works either way).
- **Known defects (2026-09-17, from the cozy-carnival suite):** screenshots can wedge
  after game events — capture first, and restart the play session if one times out;
  `monitor_property` sampling pauses the SceneTree and drops injected input — arm it
  while idle and never interleave with input. Bridge acting up: run
  `../cozy-carnival/tools/port-doctor.cmd`; ports are identity-checked, a SQUAT is a
  foreign process, not our server.
- **More defects (2026-10-12 session, 3 runs / 120 injected events):** any capture
  wedges while the SceneTree is *paused* — the game-over screen pauses the tree
  (`game_over_screen.gd`), so death screenshots time out every time. Grab the
  window at the OS level instead:
  `powershell -File ../cozy-carnival/tools/window-shot.ps1 "Pigeon Simulator (DEBUG)" out.png`.
  After the menu→main scene swap, `godot_runtime_get_game_scene_tree` and
  `is_playing`'s scene field can serve stale data (they kept reporting
  `menu.tscn` mid-run) — trust screenshots over them.

Without the bridge (headless CI), `tests/` Gate 1b still works — the MCP path is
for the eyes-on human-judgement gate (feel, look, sound).

## Agent play: pilot harness (standalone, multi-instance)

For gameplay verification — and always when more than one agent needs to play at
the same time — use the standalone pilot harness instead of the editor bridge
(editor play sessions freeze during real gameplay, and the bridge is one-editor-
only). Sessions are isolated by id, need no ports, and scale with CPU/GPU only:

```bash
python tests/tools/pilot.py start --session <your-unique-id>   # boots menu.tscn, hidden off-screen (T-170)
python tests/tools/pilot.py wait  --session <id> --scene Menu  # Menu → Main after Space
python tests/tools/pilot.py send  --session <id> '{"key":"Space","frames":2}'
python tests/tools/pilot.py send  --session <id> '{"action":"flap","frames":7}'
python tests/tools/pilot.py send  --session <id> '{"dev":"hunger_lock"}'    # dev verbs: freeze the
python tests/tools/pilot.py send  --session <id> '{"dev":"hunger_refill"}'  #   survival clock (refill to max),
python tests/tools/pilot.py send  --session <id> '{"dev":"hunger_unlock"}'  #   then resume the drain
python tests/tools/pilot.py send  --session <id> '{"dev":"freeze_traffic","on":true}'  # verb pack: hold every car,
python tests/tools/pilot.py send  --session <id> '{"dev":"spawn_car"}'      #   spawn one NEAR the pigeon (ack names node + p),
python tests/tools/pilot.py send  --session <id> '{"dev":"teleport","x":<p.x>,"y":<p.y+1.6>,"z":<p.z>}'  #   hop onto THAT car (read p off the ack),
python tests/tools/pilot.py send  --session <id> '{"dev":"car_blinker","side":"left","on":true}'  #   force ITS lights (the ack's car must equal the spawn node),
python tests/tools/pilot.py send  --session <id> '{"dev":"teleport","x":<p.x>,"y":<p.y+9.0>,"z":<p.z-9.0>,"yaw_deg":180}'  #   pose overhead, then `shot`
python tests/tools/pilot.py send  --session <id> '{"dev":"call","node":"Game.hunger","method":"eat","args":[10.0]}'  # call verb: ONE method on ONE node (see the fence below)
python tests/tools/pilot.py state --session <id>               # last world-state JSONL line
python tests/tools/pilot.py events --session <id> --tail 20    # what happened
python tests/tools/pilot.py shot  --session <id>               # OS grab of that window
python tests/tools/pilot.py stop  --session <id>               # graceful quit
python tests/tools/pilot.py list / clean                       # fleet overview / sweep dead dirs
```

- **One session id per agent, unique while you live.** Your channel is
  `.captures/session_<id>/` (state/events JSONL + frame PNGs + the command
  queue); nobody else's commands can reach your instance. `start` refuses an id
  owned by a live process — pick a fresh one rather than reusing.
- **Session defaults are safe for fleets:** muted audio, high-score persistence
  OFF (`--sound` / `--persist` to opt in), frame PNGs every 0.2 s (`--images
  off|N`; they run 10–20 MB/s per session, so `clean` once reviewed). The title
  screen to run transition is `{"key":"Space"}` — real key events reach menus,
  action commands (`flap`, `poop`, …) only reach gameplay.
- **Sessions never steal the desktop (T-170).** The default launch hides the
  window: the recorder flags it no-activate, moves it fully off-screen and
  re-lights it unactivated a moment after boot (a sub-second blip at the
  cascade corner before the hide is unavoidable — the engine shows the window
  before autoloads run; a `pilot_window_hidden` event acks the resolved
  position). The window keeps its taskbar button but never appears on screen
  and never takes focus. Nothing an agent needs cares: frame PNGs, `shot`
  (PrintWindow, fresh off-screen) and channel input all work unfocused. Eyes-on
  sessions opt back in with `--shown` (visible cascade window, focusable); a
  visible window at a specific spot is `--shown --pos=X,Y` (argparse needs the
  `=` form for negative coordinates).
  `python tests/tools/pilot.py focuscheck` re-proves the whole contract on
  Windows (boots a hidden + a `--shown` session, checks placement/foreground/
  ack/capture/input, stops both, exit 0/1).
- **`--time-scale 0.1` slows the world, not the frames (T-132).** Sets
  `Engine.time_scale` (clamped to [0.01, 1.0], default off): every delta,
  timer and tween runs scaled, so your seconds-per-decision latency buys 10×
  the game time at 0.1× — line up dives instead of recovering from them. The
  flight model per game-second is unchanged. Three slow-mo realities the
  dogfood paid for: the PNG stream timer is a *scaled* Timer (a "0.5 s" stream
  delivers every 0.5 game-seconds — 5 wall-s at 0.1×; game-time sampling
  density is unchanged, and `shot` is an instant unscaled eye); command
  `frames` are wall ticks, so at 0.1× a `{"frames":600}` hold takes 10 wall-s
  and a fat queue of steering holds executes minutes of stale geometry — pace
  one batch at a time; and the hunger clock runs on game time, so a session at
  0.1× has ~60 wall-min per run before starvation. Working presets: 0.1 for
  precision maneuvers, 0.02 for near-turn-based staging.
- **Command files are consumed-and-deleted** by the game oldest-first; queue
  several in one file by passing multiple JSON lines. `state`'s `scene` field
  drives `wait` (`Menu`, `Main`).
- **Dev verbs — `{"dev":...}` lines (T-167).** `hunger_lock` freezes the whole
  survival clock (drain and flap heat — the bar and the HUD just sit), so an
  investigation session stops dying at the ≈3.7-min starvation ceiling and the
  0.1× ~60 wall-min budget; `hunger_refill` refills to max (prevention, not
  revive — it does NOT clear an already-fired game over); `hunger_unlock`
  resumes the drain. Each success acks a `pilot_dev` event with the verb and
  the resulting bar; unknown dev verbs log `pilot_dev_unknown`; debug builds
  only — a release export refuses every verb (`pilot_dev_refused`). The verbs
  flow while the tree is PAUSED (the recorder is PROCESS_MODE_ALWAYS). This
  family is the discovery surface for further verbs — they extend
  `CaptureRecorder._execute_dev`, never bypass it.
- **Dev verb pack — the starter staging verbs (T-168; T-178 world note: the
  traffic graph stages a LIVE car fleet on the resident Ames world, so the
  staging verbs work on it — `spawn_car` parks a car at the nearest free REAL
  curb, `car_blinker` forces the nearest fleet car, `teleport` and
  `freeze_traffic` work world-independently; the full hop-onto-the-spawn
  staging flow below is usable again, with R2·calm-port re-deriving the
  pass/corridor constants for the real lane widths).** `freeze_traffic`
  (`{"on":true|false}`) holds EVERY car: route progress, honk clocks and the
  blinker machine stop, transforms stay put for screenshots, and the
  spawner's spawn cadence is gated — `on:false` resumes exactly where
  everything stopped (no re-pathing, no teleports). `spawn_car` stages ONE
  car near the pigeon through the spawner's own parked spawn path (it joins
  the managed fleet — cleanup, crosswalk yield, quotas — never an orphan;
  parked, so it stays put while you stage): the nearest blocks' nearest free
  curb spot, typically single-digit metres from the pigeon (the round-1
  review — no spawn band, no sightline gate; a dev spawn is meant to be
  seen and used). `car_blinker`
  (`"side":"left"|"right"`, `"on":true|false`) forces the NEAREST car's
  amber pair solid-lit — the T-162 blinkers ARE the car's lights — and
  hands control back on `on:false`; it targets whatever car is nearest the
  pigeon, staged or fleet. `teleport` (`"x"`,`"y"`,`"z"` world coords,
  optional `"yaw_deg"`) calls `Player.reset_flight`, so the pigeon arrives
  with zeroed velocity in a hover-friendly glide. Every verb acks a
  `pilot_dev` event with a machine-checkable payload (`spawn_car`'s node
  path and fleet size, `teleport`'s resolved position, `car_blinker`'s
  car/side/on, `freeze_traffic`'s on); refusals (`no_player`, `no_spawner`,
  `no_car`, `bad_side`, `no_spot`) log `pilot_dev_refused` with the reason.
  `car_blinker` forces the car NEAREST the pigeon at the moment it fires, so
  to dress the car `spawn_car` just made, hop onto it first: the spawn ack's
  `p` is the position — teleport there, THEN blink, and confirm the blink
  ack's `car` equals the spawn ack's `node` (the round-1 review: blinking
  from afar forced a nearer fleet car three runs out of three).
  `car_blinker` `on:false` releases the car THIS SESSION FORCED — remembered
  at force time, not whatever is nearest later (a stray release refuses with
  `no_forced` when nothing is forced) — and a forced tell dies with the
  car's re-staging (recycle re-route and re-park clear it), so T-134/T-162
  blinker observations stay clean. The owner's staging flow is the lines
  above in order: freeze, spawn, hop onto the spawn, blink, pose overhead,
  `shot`.
- **The call verb — one-hop RPC (T-169).** `{"dev":"call","node":"Game.hunger","method":"eat","args":[10.0]}`
  invokes ONE method on ONE resolvable node and acks `pilot_call_result`
  `{node, method, result}` (errors ack `pilot_call_error` `{node, method,
  error}` — the session continues either way; results are events you read
  with `pilot.py events`, not values you get back). `node` is an autoload
  name (`Game`), a dotted path from one (`Game.hunger` — child nodes and
  node-holding script properties resolve), or a `/root/...` path; no
  wildcards, no search. Args pass as raw JSON (float/string/bool/null/
  array/dict) with THE one coercion rule: an array of 2–4 numbers becomes a
  Vector2/3/4 only when the method's declared parameter type demands it.
  The channel delivers every JSON number as a float and typed int
  parameters accept it (the engine converts — `set_blinker_forced [1]`
  works), as String converts into NodePath/StringName/Color parameters.
  Arity refuses pre-call in BOTH directions — over the declared total and
  under the required count (get_method_list's `default_args`; the
  defaulted tail still fills: `reset_flight [pos]` works) — and unknown
  node/method/type-mismatch and denylisted aims refuse pre-call too;
  returns serialize as arrays for math types, `str()` with the type named
  for everything else. **Read the fence before reaching for it:** this
  is a remote procedure call, NOT a scripting console — no expression
  evaluation, no chaining on results (a returned object comes back as inert
  text), no property writes, no global functions, and the denylist covers
  Object's whole enumerable WRITE/DISPATCH family, not a point list:
  everything that dispatches by name (`call`, `callv`, `call_deferred`,
  `call_thread_safe`, `call_deferred_thread_group`, `propagate_call`,
  `emit_signal`), everything that writes by property name or path (`set`,
  `set_deferred`, `set_indexed`, `set_thread_safe`,
  `set_deferred_thread_group`), the destructive `set_script` (strips a
  class from a live node), and the teardown `free` / `queue_free` /
  `_pilot_step` — plus anything resolving inside the CaptureRecorder.
  Review rounds made the family explicit: round 1 — a
  `{"method":"call","args":["queue_free"]}` wrap freed the live Game
  autoload and `propagate_call` on /root reached the recorder itself;
  round 2 — the `*-thread-safe`/`set_indexed` siblings wrote hunger and
  dispatched methods past the six, and a null `set_script` stripped a
  car's script out of the managed fleet. Deliberately NOT denied:
  `notification`/`notify_*` (int codes, no callable payload — not
  arbitrary dispatch), `rpc`/`rpc_id`/`rpc_config` (inert here — the
  engine refuses unconfigured RPCs and this game configures none), and
  the fixed-purpose config setters (`set_name`, `set_process`, `set_meta`,
  …) — ordinary one-hop methods. Debug builds only (release refuses
  behind the `_dev_allowed()` gate); flows while the tree is paused like
  every dev verb. Loosening any of that is a future owner ticket argued
  against this written line.
- **`shot` vs frame PNGs:** `shot` grabs the OS window by its
  `Pigeon pilot <id>` title (works even with `--images off`); the frame stream
  is the in-process viewport. Review with `tests/review/summarize.py
  .captures/session_<id>` and `contact_sheet.py` — both take the session dir.
- Launch only through `pilot.py` (it warms `.godot/` imports before a fleet and
  owns the liveness checks); `stop` when done so the desktop doesn't fill with
  pigeons.

## Ticket workflow

- Backlog: `docs/tickets/` — index in `docs/tickets/README.md`, one file per ticket,
  IDs like `T-004`.
- Statuses: `todo` → `doing` → `done` (or `blocked`, with a note in the file). Update
  the status in both the ticket file and the index table.
- One ticket per change-set; reference the ID in commit messages,
  e.g. `feat(flight): stall behavior (T-001)`.
- A ticket is **done** when: all acceptance criteria are checked off, the
  [`VERIFICATION.md`](VERIFICATION.md) gates pass, and the ticket's status/checkboxes
  are updated in the same commit.

### The ticket loop

Work one ticket at a time, in the build order from the backlog index:

1. Flip the ticket to `doing` in its file and the index table.
2. Implement it (conventions above).
3. **Extend `VERIFICATION.md` in the same change-set.** Every feature, input or
   mechanic that lands gets a matching verification entry: an automated scenario in
   the sim harness (`tests/`, Gate 1b) where one is possible, otherwise a Gate 3
   playtest line. Never ship a feature without a way to re-verify it later.
4. Run the gates from `VERIFICATION.md` and fix until green. Machine-verified
   acceptance criteria get checked off; anything needing human judgement (feel,
   look, sound) is recorded in the ticket as a pending human playtest note.
5. Record tuned values in the ticket, flip it to `done`, commit (one commit per
   ticket, ID in the message) — then pick the next ticket.

## Commit style

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`) with the ticket ID in
parentheses. Small, focused commits; never mix a gameplay change with .godot cache junk.
