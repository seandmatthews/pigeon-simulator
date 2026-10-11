# T-115 — Sufficiently hostile: the favor-max victory ending

- **Milestone:** M2 — the town's pigeon (ticket 3 of 3, the payoff) · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** T-114 (the favor book and its deliberately undefined ceiling — `scripts/game.gd:154-159`, the `%FavorLabel` meter), T-010 (the GameOverScreen contract and the `restart_run()` flow this extends), T-113 (the citizen classes the economy pays out on) — all done
- **Refs:** owner contract (2026-10-11): the play session ends when the elders' favor MAXES OUT — a VICTORY beat, not a game over — or when hunger depletes (the existing T-010 starvation ending, unchanged); the victory read is "the town is yours" warmth, comedic not triumphalist, per the tone guardrail (silly bird, goofy nuisance visitors); this ticket is the ENDING ONLY — no game-day calendar arc, no new visitor behavior, no epilogue simulation · T-114's Follow-ups section (this ticket named) · `docs/DESIGN.md` → Milestone 2

## What

T-113 made the invasion visible, T-114 made it matter — and deliberately left the ceiling
undefined ("the ceiling is T-115's to define", `scripts/game.gd:154-156`). This ticket
defines it: a ceiling tunable on the favor book, and the ending it fires. When `Game.favor`
first reaches the ceiling, the run ends as a victory — the same screen contract as the
T-010 starvation ending, in a different register. Starvation is untouched. When this lands,
a pigeon run has two ways to end, and one of them is winning.

**References do not apply here:** the favor ceiling and its victory beat are game-invented
affordances with no real-world counterpart to photograph (like T-114's economy), so every
criterion below is derived from repo constants and landed machinery instead.

**Today (tree facts, verified this session).** `Game.favor` is an unbounded int: `add_favor`
adds and emits `favor_changed(favor, delta)`, "negatives allowed, **no floor and no cap**"
(`scripts/game.gd:157-159`); `splat_favor` resolves the eight-`@export` delta table above it
(`scripts/game.gd:165-175`); `reset_run()` zeroes favor with the score (`scripts/game.gd:199-209`).
The only run-ender is the hunger clock: `Hunger` fires `game_over` exactly once at zero
(`scripts/hunger.gd:86-88`, the one-shot latch at `:52-53`), `Main._on_game_over` locks the
pause menu and opens the T-010 score screen (`scripts/main.gd:570-574`), which freezes the run
via `get_tree().paused` (`scripts/game_over_screen.gd:31`), restarts through
`Main.restart_run()` and returns to the menu (`scripts/game_over_screen.gd:47-55`, buttons
wired at `scenes/main.tscn:372-373`). The T-073 dirty-record flush rides the starvation
ending (`hunger.game_over → _flush_high_score`, `scripts/game.gd:122`, plus the
close/teardown paths at `:263-265`). Splat favor books through Main's handlers beside the
score calls (`scripts/main.gd:492-507`); elder bread spends at the share
(`scripts/elder.gd:100-102`, the charge at `:143`); steals book through `crumb_favor`
(`scripts/main.gd:157`). The HUD meter is `%FavorLabel` (`scripts/main.gd:99`, rest text
`Favor: <n>`). The score screen's scene block: Dim `Color(0.12, 0.02, 0.02, 0.7)`
(`scenes/main.tscn:306`), static Title "STARVED!" (`:322-325`), BreakdownLabel
(`:346-351`), AgainButton/MenuButton (`:353-360`).

**The ceiling (`scripts/game.gd` — the book learns its top).** One export, one signal, one
latch, two changed methods:

```gdscript
signal favor_maxed ## (T-115) Fired once, the moment favor first reaches favor_max.

@export_group("Favor (T-114, T-115)")
@export var favor_max: int = 100 ## The elders' ceiling — reaching it ends the run as a victory (see the arithmetic below).
```

(the group label grows the T-115 marker; the eight shipped deltas are untouched — this
ticket defines the ceiling, it does not retune the economy)

```gdscript
## (T-115) Books a favor delta — negatives allowed, NO floor (debt stays legal,
## the T-114 lock), TOP-ONLY cap at favor_max: the balance never exceeds the
## ceiling. Emits favor_changed with the APPLIED delta (favor_after -
## favor_before — identical to the requested delta everywhere below the cap;
## on the clamping add the victory screen covers the difference). The first
## add to reach favor_max also flushes the T-073 dirty record (the run just
## ended — the victory path pays the flush the hunger path pays at
## scripts/game.gd:122) and fires favor_maxed exactly once per run; Main
## listens and ends the run. The autoload stays presentation-free.
func add_favor(delta: int) -> void:
	var before := favor
	favor = mini(favor + delta, favor_max)
	favor_changed.emit(favor, favor - before)
	if favor >= favor_max and not favor_maxed_emitted:
		favor_maxed_emitted = true
		_flush_high_score()
		favor_maxed.emit()
```

`var favor_maxed_emitted: bool = false` beside `favor` (`scripts/game.gd:74`) — the
`Hunger.game_over_emitted` latch pattern (`scripts/hunger.gd:52-53`); `reset_run()` clears it
beside `favor = 0` (`scripts/game.gd:199-209`). `splat_favor` needs zero changes (the clamp
lives inside `add_favor`; it keeps returning the requested table delta — "what the splat was
worth"). The one-shot flush on the win frame is a synchronous disk write, the same class of
cost the T-073 first-beat write already pays on its own frame (`scripts/game.gd:231-233`).

**The ending (`scripts/main.gd`).** A first-ending latch and one handler:

```gdscript
var _run_ended: bool = false ## (T-115) The FIRST ending to fire owns the run — starvation and victory both latch once, so this only guards the same-frame double fire.

func _on_favor_maxed() -> void:
	if _run_ended:
		return
	_run_ended = true
	pause_menu.locked = true
	game_over_screen.open_victory(Game.score, Game.high_score,
			Game.tourist_hits, Game.car_hits, Game.favor, Game.record_beaten)
```

`_ready()` gains `Game.favor_maxed.connect(_on_favor_maxed)` beside the hunger wiring;
`_on_game_over` gains the same two guard lines (`if _run_ended: return` / `_run_ended = true`,
`scripts/main.gd:570-574`); `restart_run()` clears `_run_ended = false` beside the other HUD
resets (`scripts/main.gd:583-615`). `_to_menu` needs nothing (`Game.reset_run()` there already
re-arms everything, `scripts/main.gd:619-623`). Without the guard, hunger reaching zero and a
splat crossing the ceiling in the same physics frame would open the screen twice — the second
open overwriting the first's register; first-wins is the honest rule and 3 lines.

**The victory register (`scripts/game_over_screen.gd`, `scenes/main.tscn`) — same screen
contract, different beat.** No new scene, no new input action: Space/R restart and M menu
already work through `_unhandled_input` and the buttons (`scripts/game_over_screen.gd:47-55`,
`scenes/main.tscn:372-373`), and the VERIFICATION controls table's Space row already reads
"fly again on the score screen". The screen gains a victory entry beside `open()`:

- `open_victory(score, high_score, tourist_hits, car_hits, favor, beaten)` — the same freeze
  contract as `open()` (`is_open`, `visible`, `get_tree().paused = true`, AgainButton focus,
  `scripts/game_over_screen.gd:28-38`), then the mode-dressed labels.
- **Both entries write EVERY mode-dependent property — neither relies on scene defaults** (a
  victory screen must never leak into a later starvation screen across restarts in one
  session, and vice versa). Mode-dependent: the Title text, the Dim color, the victory note's
  visibility, and the breakdown's favor suffix.
  - Title: starvation keeps "STARVED!", victory sets **"THE TOWN IS YOURS!"** (proposed copy —
    final wording is Gate 3 taste). The scene's static Title node
    (`scenes/main.tscn:322-325`) gains `unique_name_in_owner` and the script gains
    `@onready var title_label: Label = %Title`; the scene text stays as the at-rest editor
    preview, overwritten by whichever entry opens.
  - Dim: starvation writes the scene's dark red `Color(0.12, 0.02, 0.02, 0.7)`, victory writes
    a warm gold wash — proposed `Color(0.44, 0.32, 0.06, 0.65)`, `@export`ed on the screen as
    `victory_dim` (tunable; Gate 3 judges). The script reaches it as `@onready var dim_rect:
    ColorRect = $Dim` — direct child, no unique-name needed (and PauseMenu's sibling `Dim`
    would collide on a shared unique name anyway).
  - A new `VictoryNote` Label in the Box under BreakdownLabel (hidden at rest; the column
    treatment, 16 px, white-0.8 like the breakdown) carries the comedy line — proposed:
    **"Not an un-splatted invader left in town — the park elders are delighted with their
    pigeon."** Shown only by `open_victory`; final wording Gate 3.
  - Breakdown: starvation keeps the exact today format ("Tourists splatted: %d    Cars
    splatted: %d", `scripts/game_over_screen.gd:34`); victory appends the ceiling moment:
    `"…    Favor: %d"` with the (clamped = `favor_max`) balance. The suffix is additive, so
    the autoplay's `contains("Tourists splatted: %d")` asserts stay true in both modes
    (`tests/autoplay.gd:170-178`).
- `new_record_label` and the Hint footer work unchanged in both modes — the T-039 scenario
  asserts the footer byte-exact through a real main scene, so it is deliberately untouched.

**The ceiling's arithmetic (the balance leg — why 100).** The live population at the shipped
knobs (T-113's exact integer quotas, enforced by `citizen_classes_spawn_deterministic`): 6
VISITOR pedestrians + 1 SUPERFAN of 18 tourists; 14 VISITOR cars (6 parked + 8 traffic) + 2
SUPERFAN cars of 36. One clean pass — every visitor pedestrian and every visitor car splatted
exactly once — books 6×3 + 14×6 = **+102 favor**. `favor_max = 100` sits 2 under that: a
perfect sweep of the invasion wins with 2 points of slack, which absorbs exactly one civilian
pedestrian oops (−1) or one tabletop steal (−1); a superfan accident (−8) wipes the slack and
six jackpots' worth — the loyalists stay the hazard T-114 priced. The ceiling is never a
soft-lock: bodies stay live after a splat (`scripts/tourist.gd:144-153` panics and emits, no
disable; `scripts/car.gd:215-217` honks and emits) and recycle reseats them around the
player, so income is unbounded in time. Rate cross-check: drops throttle at 1/s
(`poop_cooldown` 1.0, `scripts/player.gd:127`); a targeted hunter booking ~3 jackpots + ~3
pedestrian splats a minute (misses inside that rate) grosses ≈ +20/min, and one glide bar
funds only 100/0.45 ≈ 3.7 min (`drain_per_second` 0.45, `scripts/hunger.gd:28`) — you MUST
eat on the way, and the bread economy is priced in favor (table steals −1, elder loaves
−4/share, gutter/roof crumbs free and respawning). Net of honest bread costs ≈ +12–18/min →
the ceiling arrives in roughly **6–8 minutes of targeted visitor work** — aspirational but
achievable, "a few solid minutes after bread costs". Deliberately above one hunger bar's
comfortable hunting, so the winning diet is the free gutter/roof bread while the casual
table-steal diet (−4 to −6 a run) still finishes inside the slack-plus-honest-hunting
envelope. `favor_max` is `@export`ed: if Gate 3 finds the drag wrong, the knob moves and this
arithmetic re-runs — the deltas do not.

**Scope of existing machines.** The suite's favor numbers come in two kinds, and neither can
trip a 100 ceiling. Direct stagings — `Game.favor = N` property writes that bypass `add_favor`
entirely — peak at 40 (`_scenario_elder_cooldown_blocks_second_share`'s "enough favor for both
shares and their spends", `tests/sim_test.gd:2727`; the shares scenario stages 8 at `:2620`,
the airborne and gate rigs stage 0 at `:2696`/`:5924`); the latch lives inside `add_favor`
(above), so a staging can no more fire `favor_maxed` than it could have hit T-114's uncapped
book, and under the top-only clamp the cooldown scenario's staged 40 still spends down
40 → 36 → 32 exactly as the uncapped book did. `add_favor` excursions — the only path the
latch watches — peak at +6 (the `splat_favor_follows_citizen_class` HUD gain leg,
`tests/sim_test.gd:5887`; the elder gate rig's `elder_loaf_cost × crumbs_per_share` = +4 at
`:5948`; the splat legs book single deltas through the real relays, cumulative −2 at
`:5849`). Worst case anywhere — staged balance plus booked excursion — is 40 + 6 = 46, far
below 100, so no existing scenario can trip the latch and none needs an edit. Gate 2's pilot
cannot realistically win in its 30 s run (single-digit hits per its own DONE line), and a
fluke victory would still pass — `_watch_score_screen` asserts only the three mode-invariant
labels (`tests/autoplay.gd:170-178`) — so the DONE criteria are unchanged.

What this does **NOT** claim: no starvation change — the hunger clock, its latch, `_on_game_over`'s
labels and the T-010 screen contract are byte-identical below the ceiling (both endings
coexist; the Gate 1b scenario proves both in one real Main); no game-day calendar arc, no
epilogue simulation, no post-victory world state — when favor crosses the ceiling the run ends
and the beat plays, full stop (the old M2 sketch's calendar is not in this sequence); no new
visitor or elder behavior — the world reacts exactly as T-113/T-114 built it, nothing new
spawns, nothing new path-finds; no score-table change — 100/30, combos and the style bonus
are untouched, and a winning run's score competes for the same record (the "race your best"
loop survives the win); no favor-delta retune — the eight shipped deltas and `elder_loaf_cost`
stand, only the ceiling is defined; no floor added — debt stays legal (the clamp is top-only,
the T-114 lock); no City/spawner change — zero RNG, zero layout movement, the seeded class
multisets and fingerprints hold; no new input action and no controls-table change — Space/R/M
already live on the score screen; and no persistence-semantics change beyond routing the
existing T-073 flush through the victory path.

## Why

The owner's contract: this is the payoff of the approved three-ticket M2 sequence — the play
session ends when the town is sufficiently hostile to the invasion, and that ending is a
VICTORY beat, not a game over. Until this lands, T-114's meter is a score with no
consequence: an aggressive anti-visitor run and a sloppy one read identically at minute ten,
and "endless" is still the only shape. Defining the ceiling makes the whole economy a goal:
the hunger clock stops being the only reason a run ends, elder bread becomes a real purchase
(every loaf is favor not banked — T-114's designed tension finally bites), and "one more go"
gains a win state worth chasing. The register is the owner's exact steer — "the town is
yours" warmth, comedic not triumphalist: the gold wash and the delighted-elders line, never a
conquest banner; the visitors stay a goofy nuisance even in defeat (colors-only, no real
branding, per the locked setting convention). Value 5 because this is the ticket that turns
the M2 foundation into a game. Risk 2 because the machinery is small and rides proven
patterns (a hunger-style latch, the T-010 screen contract, the T-073 flush) — the soft spot
is the ceiling's value, mitigated by the one-pass-harvest arithmetic above, the `@export`
knob, and the machine legs below.

## Acceptance criteria

- [ ] `Game.favor_max` exists as specified (the export at 100 in the Favor group), with
      `favor_maxed` + `favor_maxed_emitted`; `add_favor` clamps TOP-ONLY (a −50 add from zero
      still reads −50 — the T-114 no-floor lock intact), emits the applied delta, flushes the
      T-073 dirty record on the maxing add and fires `favor_maxed` exactly once per run;
      `reset_run()` re-arms it; `splat_favor` is unchanged; the autoload stays
      presentation-free (no node/HUD reference in `game.gd`)
- [ ] *(Gate 1b)* `favor_max_book_clamps_and_flushes` — bare autoload leg in the
      `highscore_save_throttled` window (`tests/sim_test.gd:6223`, `SIM_SAVE_PATH`
      `tests/sim_test.gd:21`): from `reset_run()`, `add_favor(-50)` reads −50 and emits delta
      −50 (no floor); staging the T-073 dirty state (`_saved_this_run` true,
      `_high_score_dirty` true, a beaten record) then one `add_favor(favor_max + 25)` leaves
      favor reading EXACTLY `favor_max` (never over), emits the applied delta, performs
      exactly one disk write, and `save_path` read back through an independent ConfigFile
      holds the final score (the victory path's flush — the hunger path's twin); further adds
      (`add_favor(10)`) clamp silently and fire NO second `favor_maxed`; `reset_run()`
      re-arms (a second climb re-fires exactly once)
- [ ] *(Gate 1b)* `favor_max_ends_run_victory` — through the REAL main scene (the
      instanced-Main pattern, `tests/sim_test.gd:5782-5911`), held airborne throughout:
      stage `Game.favor = Game.favor_max - Game.favor_visitor_car_splat`, force the parked
      cars all-VISITOR (`visitor_share = 1.0` + `_populate()`, the T-114 leg at
      `tests/sim_test.gd:5851-5861`), and drive ONE real parked visitor car's
      `on_splatted` through Main's relay — favor reads EXACTLY `favor_max` (the clamp in the
      real chain), the tree pauses, `game_over_screen.is_open`, the title reads the victory
      line, the breakdown carries the run's real splat counts plus the favor total,
      `Game.hunger.game_over_emitted` is false and `Game.hunger.value > 0` (this ending is
      NOT starvation — the two are independent), Esc is locked (`pause_menu.locked`, the
      `toggle()` refusal), and the latch is one-shot (a further splat books nothing past the
      clamp, no second emit). Then the coexistence legs: a direct `Game.hunger.game_over`
      emit while the victory screen is open changes NOTHING (first-wins — still
      victory-mode, still paused); `restart_run()` unpauses, closes the screen, zeroes favor
      and re-arms the latch (a staged sub-max add fires nothing); then with favor staged
      LOW, `drain_per_second = 60.0` starvation (the T-010 scenario's compression,
      `tests/sim_test.gd:6398-6411`) opens the screen in STARVED! register — title, dark red
      dim, no victory note, plain breakdown — proving both entries rewrite every
      mode-dependent property and both endings coexist in one Main; drain restored after
- [ ] Full Gate 1b suite green in one headless run UNTOUCHED — no existing scenario may need
      an edit (the scope note above: staged balances peak at 40 and bypass the latch, every
      pinned `add_favor` excursion is ≤ +6, worst case 40 + 6 = 46 < 100; if one trips,
      that is a red flag to raise, not a gate to re-derive); VERIFICATION.md gains the two
      new scenario rows in the same change-set
- [ ] Gate 2 unchanged: `AUTOPLAY DONE ok=true restart=true` re-run green with no pilot
      edits (the DONE line's asserts read the three mode-invariant labels)
- [ ] The docs fold-in, same change-set: `docs/DESIGN.md` → Milestone 2 gains the status
      line — **locked and delivered as the three-ticket sequence T-113 → T-114 → T-115
      (2026-10-11): the run shape is the goal run — a session ends when the elders' favor
      maxes out (victory) or hunger empties (starvation, unchanged)** — and the fork
      resolution line — **all four forks decided 2026-10-11: run shape = favor-max-or-starve
      goal run; elder depth = the anonymous class (the shared favor meter, no named elders);
      naming = Ames, colors-only; friendly fire = detractors only, no repair**
- [ ] **[screenshot] (Gate 3 — human judgement)** The victory beat reads as "the town is
      yours" warmth — comedic, not triumphalist: the gold wash, the delighted-elders line
      and the title land as a silly bird's good day, never a conquest banner; the visitors
      stay a goofy nuisance even in defeat; final copy (title, note) accepted or retuned by
      reviewer sign-off
- [ ] **[screenshot] (Gate 3 — human judgement)** The ending arrives readable in real play:
      the run ends the moment the meter hits the ceiling (no lag, no double beat), the
      frozen world sits under the victory screen, Space/R restart into a fresh same-seed run
      and M returns to the title — and a normal starvation ending in the same session still
      reads exactly as before, both registers never leaking into each other
- [ ] **(Gate 3 — human judgement)** The pace holds: a focused visitor-hunting run reaches
      the ceiling in roughly the arithmetic's 6–8 minutes (aspirational, not a slog; not
      accidental inside one hunger bar) — if the drag is wrong, `favor_max` moves and the
      ticket's arithmetic re-runs; the deltas do not

## Verification

Gate 1 (`--import` + 120-frame boot, exit 0) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the two new
scenarios (rig patterns: the bare-autoload `highscore_save_throttled` window
`tests/sim_test.gd:6223` for the book legs; the instanced-Main scene for the ending legs —
the T-114 splat scenario `tests/sim_test.gd:5782` for the all-visitor parked rig, the T-010
`game_over_shows_score_screen` compression `tests/sim_test.gd:6391` for the starvation leg;
registered in `_run_scenarios`, `tests/sim_test.gd:143`) · Gate 2 autoplay re-run (DONE
criteria unchanged — see the scope note) · Gate 3: the three human lines above, added to
VERIFICATION.md's playtest list in the same change-set. Tuned values (final `favor_max`, the
victory dim, the accepted copy, any retunes) recorded here when the ticket lands.
