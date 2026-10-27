"""Ground navigation + state reading for a pilot session (proven live in the
2026-10-27 beat-the-game run, T-140).

Commands:
  python tests/tools/pilot_nav.py --session <id> state [--field player|hunger|...]
  python tests/tools/pilot_nav.py --session <id> goto X Z [--face YAW] [--stop D]

`state` prints the last COMPLETE line of the session's state.jsonl (the game
flushes every 30 physics frames; the newest line can be mid-write and kills a
naive JSON parse — this walks back to the newest parseable one).

`goto` waddle-walks the pigeon to (X, Z) on the ground: it pauses the world
first (step windows only run from pause — the T-140 frame-step protocol), then
turns in place, walks, and verifies each leg. No obstacle avoidance: route
around cars/buildings with intermediate goto legs.

Yaw semantics (player.gd): forward = (-sin yaw, -cos yaw) — yaw 0 north (-Z),
+pi/2 west, +/-pi south, -pi/2 east. turn_left raises yaw at 3.12 rad/s
game-time; pitch_up walks forward at 2.64 m/s. Step windows pad +6 ticks of
engine unpause lag (the tree hands PAUSABLE nodes their first live tick ~2-3
recorder ticks after the flip — measured live, see the T-140 ticket).
"""
import argparse
import json
import math
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TURN_RATE = 3.12   # rad/s game-time (waddle turn)
WALK_SPEED = 2.64  # m/s game-time (waddle walk)
TICK = 1.0 / 60.0


def session_dir(sid: str) -> Path:
    return ROOT / ".captures" / f"session_{sid}"


def last_state(sid: str):
    path = session_dir(sid) / "state.jsonl"
    for line in reversed(path.read_text(encoding="utf-8", errors="replace")
                         .strip().splitlines()[-8:]):
        try:
            return json.loads(line)
        except Exception:
            continue
    raise SystemExit("pilot_nav: no parseable state line for session '%s'" % sid)


def send(sid: str, cmd_text: str, ticks: int = 0) -> None:
    subprocess.run(["python", "tests/tools/pilot.py", "send", "--session", sid, cmd_text],
                   cwd=str(ROOT), check=True, capture_output=True)
    time.sleep(max(0.35, ticks * TICK + 0.55))


def step(sid: str, n: int) -> None:
    send(sid, '{"step":%d}' % n, ticks=n)


def wrap(a: float) -> float:
    return (a + math.pi) % (2 * math.pi) - math.pi


def turn_to(sid: str, target_yaw: float, tries: int = 3) -> None:
    for _ in range(tries):
        yaw = last_state(sid)["player"]["yaw"]
        delta = wrap(target_yaw - yaw)
        if abs(delta) < 0.12:
            return
        ticks = max(1, round(abs(delta) / TURN_RATE / TICK))
        action = "turn_left" if delta > 0 else "turn_right"
        send(sid, '{"action":"%s","frames":%d}\n{"step":%d}' % (action, ticks + 2, ticks + 6),
             ticks=ticks + 6)
    print("pilot_nav: WARNING yaw still %.2f (wanted %.2f)"
          % (last_state(sid)["player"]["yaw"], target_yaw))


def goto(sid: str, tx: float, tz: float, face: float = None, stop: float = 0.6) -> None:
    send(sid, '{"pause":true}')  # step windows only run from pause
    for leg in range(4):
        p = last_state(sid)["player"]["p"]
        dx, dz = tx - p[0], tz - p[2]
        dist = math.hypot(dx, dz)
        if dist <= stop:
            break
        turn_to(sid, math.atan2(-dx, -dz))
        walk_ticks = max(1, round((dist - stop) / WALK_SPEED / TICK))
        send(sid, '{"action":"pitch_up","frames":%d}\n{"step":%d}' % (walk_ticks + 2, walk_ticks + 6),
             ticks=walk_ticks + 6)
        p2 = last_state(sid)["player"]["p"]
        left = math.hypot(tx - p2[0], tz - p2[2])
        print("pilot_nav: leg %d done, %.1f m left" % (leg + 1, left))
    if face is not None:
        turn_to(sid, face)
    p = last_state(sid)["player"]
    print("pilot_nav: at (%.2f, %.2f) yaw %.2f" % (p["p"][0], p["p"][2], p["yaw"]))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--session", required=True)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sp = sub.add_parser("state")
    sp.add_argument("--field", action="append", default=[])
    sg = sub.add_parser("goto")
    sg.add_argument("x", type=float)
    sg.add_argument("z", type=float)
    sg.add_argument("--face", type=float, default=None)
    sg.add_argument("--stop", type=float, default=0.6)
    a = ap.parse_args()

    if a.cmd == "state":
        d = last_state(a.session)
        if a.field:
            for f in a.field:
                print(f, json.dumps(d.get(f)))
        else:
            print(json.dumps(d, indent=1))
    elif a.cmd == "goto":
        goto(a.session, a.x, a.z, face=a.face, stop=a.stop)


if __name__ == "__main__":
    main()
