"""The parked-visitor-car splat grind — the worked example from the 2026-10-27
beat-the-game run (T-140). Won that run: 17 re-splats of one parked visitor
car = favor 100 ("THE TOWN IS YOURS!").

  python tests/tools/pilot_splat.py --session <id> --x 51.95 --z 37.5 --cycles 6

The exploit it exercises (2026-10-27 owner note: possibly TOO effective — see
IDEAS.md B-6): cars never flee and splats never dedup, so a parked VISITOR car
is a +6-favor fountain. Per cycle: settle-land, waddle to an attack point 8.2 m
north or south of the car center on the road (the car's long axis), pause,
takeoff hop, and release the poop AT ARC APEX — the drop inherits the pigeon's
velocity, so the release moment is the whole aim (±0.1 s = ±2 m of impact;
release-at-apex from 8.2 m crosses the 1.05 m roof at the car center). The
north/south points alternate so the post-splat landing is always a 4-5 m walk
from the next shot with no car to route around.

Assumptions: the car is PARKED with its long axis north-south and the road is
clear north and south; the pigeon starts landed (or near-ground) on that road.
Holds the frame-step protocol (pause → input+step windows → re-freeze), so the
session must run the T-140 recorder build. Leaves the world paused.
"""
import argparse
import json
import math
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent))
import pilot_nav  # noqa: E402

STANDOFF = 8.2     # m from the car center: the full-power hop's roof-height crossing
FLAP_TICKS = 31    # takeoff flap + arc ticks before the release (apex)
CAR_HALF_LEN = 2.2 # north/south attack points sit clear of the 4.4 m body


def event_count(session_dir: Path):
    splats = crumbs = 0
    path = session_dir / "events.jsonl"
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("ev") == "car_splatted":
            splats += 1
        elif d.get("ev") == "crumb_eaten":
            crumbs += 1
    return splats, crumbs


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--session", required=True)
    ap.add_argument("--x", type=float, required=True, help="parked visitor car center x")
    ap.add_argument("--z", type=float, required=True, help="parked visitor car center z")
    ap.add_argument("--cycles", type=int, default=6)
    ap.add_argument("--hunger-floor", type=float, default=55.0)
    a = ap.parse_args()

    sid = a.session
    sdir = pilot_nav.session_dir(sid)
    # Attack points on the car's long axis: south point walks north (yaw 0),
    # north point walks south (yaw pi).
    points = [(a.x, a.z + STANDOFF + CAR_HALF_LEN - 0.6, 0.0),
              (a.x, a.z - STANDOFF - CAR_HALF_LEN + 0.6, math.pi)]
    splats = crumbs = misses = 0
    for i in range(a.cycles):
        pilot_nav.step(sid, 35)  # settle the previous arc into a landing
        base_splats, base_crumbs = event_count(sdir)
        tx, tz, face = points[i % 2]
        pilot_nav.goto(sid, tx, tz, face=face)
        pilot_nav.send(sid, '{"action":"flap","frames":6}\n{"step":%d}' % FLAP_TICKS,
                       ticks=FLAP_TICKS + 6)
        pilot_nav.send(sid, '{"action":"poop","frames":2}\n{"step":3}', ticks=9)
        pilot_nav.step(sid, 30)
        s_now, c_now = event_count(sdir)
        got, ate = s_now - base_splats, c_now - base_crumbs
        splats += got
        crumbs += ate
        hunger = pilot_nav.last_state(sid).get("hunger", 0.0)
        print("cycle %d: splats+%d crumbs+%d hunger %.1f" % (i + 1, got, ate, hunger))
        misses = 0 if got else misses + 1
        if hunger < a.hunger_floor:
            print("pilot_splat: hunger floor — stop and eat")
            break
        if misses >= 2:
            print("pilot_splat: two dry cycles — take a screenshot and re-aim")
            break
    print("pilot_splat: total splats %d, crumbs %d (favor approx %+d)"
          % (splats, crumbs, 6 * splats + sum((1, -1)[i % 2] for i in range(crumbs))))


if __name__ == "__main__":
    main()
