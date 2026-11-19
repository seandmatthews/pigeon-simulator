#!/usr/bin/env bash
## gate-box.sh — run all three verification gates for one pushed ref on the
## Linux gate box (T-213). Usage: gate-box.sh <ref> [--skip-gate2]
##
## Fetches <ref> from origin, stages a reusable worktree under ~/gate-runs/,
## runs Gate 1 (import + boot) and Gate 1b (sim harness) headless, then
## Gate 2 (autoplay) on the hardware-GL display :98 (pigeon-xorg.service).
## Prints one machine-greppable line per gate ("GATE1 PASS", "GATE1B PASS
## checks=N", "GATE2 PASS AUTOPLAY DONE ok=true fps=F floor=30") and a final
## "GATE-BOX RESULT: PASS|FAIL ref=<ref>"; exits non-zero if any gate failed.
## Everything runs nice(1)'d so Caddy and the web roots stay snappy.
##
## (T-215) Gate 2 enforces the entry-hardware perf bar: the autoplay's DONE
## fps must be ≥ 30 (half of the 60 Hz target, the owner's pick) — below it
## GATE2 FAILs, so the perf budget stays machine-checked on the 2015
## mid-range machine forever. The floor is overridable for testing with
## GATE2_FPS_MIN=<n> (a run at floor=999 exercises the FAIL path).
##
## (T-215) Gate 2 also wakes the gate display first: the iGPU's panel
## DPMS-powers-off after 600 idle seconds and the GL present path crawls to
## ~1 Hz — glxgears included — while the panel sleeps. The whole "1 fps
## budget" the T-215 profiling chased was a sleeping monitor: woken, the
## same box runs the world at 51–60 fps at every probe pose and glxgears at
## 60. xset dpms force on + xset -dpms before the run makes the measured fps
## the hardware's, not the monitor's power state, and keeps the panel from
## re-sleeping mid-run.
##
## Run it from any box checkout (it fetches the ref itself):
##   ssh -i ~/.ssh/basement_box sean@192.168.1.247 \
##       'cd ~/pigeon-simulator && tools/gate-box.sh ames/campaign'

set -u

REF="${1:?usage: gate-box.sh <ref> [--skip-gate2]}"
SKIP_GATE2="${2:-}"
GODOT="${GODOT_BIN:-$HOME/bin/Godot_v4.7.2-stable_linux.x86_64}"
[ -x "$GODOT" ] || { echo "GATE-BOX FAIL: godot binary not at $GODOT (export GODOT_BIN)"; exit 2; }

REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/pigeon-simulator")"
cd "$REPO" || exit 2
SANITIZED="$(printf '%s' "$REF" | tr -c 'A-Za-z0-9._-' '_')"
WT="$HOME/gate-runs/$SANITIZED"

if printf '%s' "$REF" | grep -qE '^[0-9a-f]{40}$'; then
    WANT="$REF"
else
    WANT="origin/$REF"
fi

echo "GATE-BOX ref=$REF worktree=$WT"
git fetch --quiet origin "$REF" 2>/dev/null || true
if [ -e "$WT/.git" ]; then
    git -C "$WT" fetch --quiet origin "$REF" 2>/dev/null || true
    git -C "$WT" reset --hard "$WANT" >/dev/null || { echo "GATE-BOX FAIL: no $WANT"; exit 2; }
else
    mkdir -p "$HOME/gate-runs"
    git worktree add --detach "$WT" "$WANT" >/dev/null || { echo "GATE-BOX FAIL: no $WANT"; exit 2; }
fi
git -C "$WT" clean -fdq >/dev/null 2>&1 || true

## The per-machine addon is untracked and never rides a worktree — after
## clean -fdq the worktree has NO addons/ parent at all, so create it or the
## cp silently dies (T-210 baseline box-runner:no-output, root cause #2).
mkdir -p "$WT/addons"
if [ ! -d "$WT/addons/godot_mcp" ] && [ -d "$REPO/addons/godot_mcp" ]; then
    cp -r "$REPO/addons/godot_mcp" "$WT/addons/godot_mcp"
fi

FAILED=0

echo "--- Gate 1: import + boot"
nice -n 10 "$GODOT" --headless --path "$WT" --import > "$WT.gate1_import.log" 2>&1
IMPORT_RC=$?
nice -n 10 "$GODOT" --headless --path "$WT" --quit-after 120 > "$WT.gate1_boot.log" 2>&1
BOOT_RC=$?
## Godot's benign exit-cleanup line ("ERROR: N resources still in use at
## exit") fires on pristine trees too — the Windows gate scan strips it
## (the pipeline def has done so since T-133), so the box scan does as well.
HARD_ERRS="$(grep -hE '^ERROR: |^SCRIPT ERROR:' "$WT.gate1_import.log" "$WT.gate1_boot.log" 2>/dev/null \
    | grep -v 'still in use at exit' || true)"
if [ "$IMPORT_RC" -eq 0 ] && [ "$BOOT_RC" -eq 0 ] && [ -z "$HARD_ERRS" ]; then
    echo "GATE1 PASS"
else
    echo "GATE1 FAIL (import rc=$IMPORT_RC boot rc=$BOOT_RC; logs: $WT.gate1_*.log)"
    echo "$HARD_ERRS" | head -5
    FAILED=1
fi

echo "--- Gate 1b: sim harness"
nice -n 10 "$GODOT" --headless --fixed-fps 60 --path "$WT" res://tests/sim_test.tscn > "$WT.gate1b.log" 2>&1
SIM_RC=$?
SIM_PASS=$(grep -c "^SIM PASS" "$WT.gate1b.log")
SIM_FAIL=$(grep -c "^SIM FAIL" "$WT.gate1b.log")
if [ "$SIM_RC" -eq 0 ] && [ "$SIM_FAIL" -eq 0 ]; then
    echo "GATE1B PASS checks=$SIM_PASS"
else
    echo "GATE1B FAIL rc=$SIM_RC fails=$SIM_FAIL (log: $WT.gate1b.log)"
    FAILED=1
fi

echo "--- Gate 2: autoplay"
if [ "$SKIP_GATE2" = "--skip-gate2" ]; then
    echo "GATE2 SKIP (--skip-gate2)"
else
    ## (T-215) Wake the gate display and disarm DPMS: a sleeping panel
    ## throttles the GL present path to ~1 Hz and every fps the gate would
    ## report is the monitor's power state, not the hardware's.
    DISPLAY=:98 xset dpms force on >/dev/null 2>&1 || true
    DISPLAY=:98 xset -dpms >/dev/null 2>&1 || true
    nice -n 10 env DISPLAY=:98 "$GODOT" --path "$WT" --rendering-method gl_compatibility \
        --rendering-driver opengl3 --audio-driver Dummy res://tests/autoplay.tscn > "$WT.gate2.log" 2>&1
    AUTO_RC=$?
    AUTO_DONE="$(grep -o 'AUTOPLAY DONE ok=[a-z]*' "$WT.gate2.log" | tail -1)"
    AUTO_FPS_RAW="$(grep -o 'fps=[0-9]*' "$WT.gate2.log" | tail -1)"
    AUTO_FPS="${AUTO_FPS_RAW#fps=}"
    ## (T-215) The entry-hardware bar: the DONE line's fps must clear the
    ## floor (default 30 — half of the 60 Hz target, the owner's pick).
    ## The floor reads INDEPENDENTLY of the autoplay's own exit code — a
    ## below-floor fps is the perf signal the gate exists to catch, so it
    ## reports even when the autoplay's loop gate failed first.
    GATE2_FPS_MIN="${GATE2_FPS_MIN:-30}"
    if [ "$AUTO_RC" -eq 0 ] && [ "$AUTO_DONE" = "AUTOPLAY DONE ok=true" ] \
            && [ -n "$AUTO_FPS" ] && [ "$AUTO_FPS" -ge "$GATE2_FPS_MIN" ]; then
        echo "GATE2 PASS $AUTO_DONE $AUTO_FPS_RAW floor=$GATE2_FPS_MIN"
    elif [ -n "$AUTO_FPS" ] && [ "$AUTO_FPS" -lt "$GATE2_FPS_MIN" ]; then
        echo "GATE2 FAIL fps=$AUTO_FPS below floor=$GATE2_FPS_MIN (log: $WT.gate2.log)"
        FAILED=1
    else
        echo "GATE2 FAIL rc=$AUTO_RC (${AUTO_DONE:-no DONE line}; log: $WT.gate2.log)"
        FAILED=1
    fi
fi

echo "GATE-BOX RESULT: $([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL) ref=$REF"
exit "$FAILED"
