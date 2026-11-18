#!/usr/bin/env bash
## gate-box.sh — run all three verification gates for one pushed ref on the
## Linux gate box (T-213). Usage: gate-box.sh <ref> [--skip-gate2]
##
## Fetches <ref> from origin, stages a reusable worktree under ~/gate-runs/,
## runs Gate 1 (import + boot) and Gate 1b (sim harness) headless, then
## Gate 2 (autoplay) on the hardware-GL display :98 (pigeon-xorg.service).
## Prints one machine-greppable line per gate ("GATE1 PASS", "GATE1B PASS
## checks=N", "GATE2 PASS AUTOPLAY DONE ok=true fps=F") and a final
## "GATE-BOX RESULT: PASS|FAIL ref=<ref>"; exits non-zero if any gate failed.
## Everything runs nice(1)'d so Caddy and the web roots stay snappy.
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

## The per-machine addon is untracked and never rides a worktree.
if [ ! -d "$WT/addons/godot_mcp" ] && [ -d "$REPO/addons/godot_mcp" ]; then
    cp -r "$REPO/addons/godot_mcp" "$WT/addons/godot_mcp"
fi

FAILED=0

echo "--- Gate 1: import + boot"
nice -n 10 "$GODOT" --headless --path "$WT" --import > "$WT.gate1_import.log" 2>&1
IMPORT_RC=$?
nice -n 10 "$GODOT" --headless --path "$WT" --quit-after 120 > "$WT.gate1_boot.log" 2>&1
BOOT_RC=$?
if [ "$IMPORT_RC" -eq 0 ] && [ "$BOOT_RC" -eq 0 ] \
        && ! grep -qE "^ERROR: |^SCRIPT ERROR:" "$WT.gate1_import.log" "$WT.gate1_boot.log"; then
    echo "GATE1 PASS"
else
    echo "GATE1 FAIL (import rc=$IMPORT_RC boot rc=$BOOT_RC; logs: $WT.gate1_*.log)"
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
    nice -n 10 env DISPLAY=:98 "$GODOT" --path "$WT" --rendering-method gl_compatibility \
        --rendering-driver opengl3 --audio-driver Dummy res://tests/autoplay.tscn > "$WT.gate2.log" 2>&1
    AUTO_RC=$?
    AUTO_DONE="$(grep -o 'AUTOPLAY DONE ok=[a-z]*' "$WT.gate2.log" | tail -1)"
    AUTO_FPS="$(grep -o 'fps=[0-9]*' "$WT.gate2.log" | tail -1)"
    if [ "$AUTO_RC" -eq 0 ] && [ "$AUTO_DONE" = "AUTOPLAY DONE ok=true" ]; then
        echo "GATE2 PASS $AUTO_DONE $AUTO_FPS"
    else
        echo "GATE2 FAIL rc=$AUTO_RC (${AUTO_DONE:-no DONE line}; log: $WT.gate2.log)"
        FAILED=1
    fi
fi

echo "GATE-BOX RESULT: $([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL) ref=$REF"
exit "$FAILED"
