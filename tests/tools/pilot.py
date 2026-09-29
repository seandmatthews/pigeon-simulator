"""Pigeon pilot harness — launch and drive N concurrent play sessions.

Every session is its own game process with an isolated channel directory
under `.captures/session_<id>/` (state.jsonl, events.jsonl, frame PNGs, and
the pilot_cmd_*.jsonl command file the game polls). Session ids keep
instances from stealing each other's inputs; there are no ports involved.

The game side lives in tests/capture_recorder.gd (session mode). Sessions
default to muted audio and high-score persistence OFF so a fleet of agents
never wrecks the real record or the ears of the person at the keyboard.

Usage:
  pilot.py start  --session <id> [--scene res://scenes/menu.tscn]
                  [--images 0.2|off] [--sound] [--persist] [--pos X,Y] [--size WxH]
  pilot.py send   --session <id> '{"action":"flap","frames":7}'
  pilot.py state  --session <id> [--tail 1]
  pilot.py events --session <id> [--tail 20]
  pilot.py wait   --session <id> --scene Main [--timeout 15]
  pilot.py shot   --session <id> --out shot.png      (OS window grab)
  pilot.py stop   --session <id> [--force]
  pilot.py list
  pilot.py clean

Pilot commands (one JSON object per line):
  {"action": "flap", "frames": 7}   hold an input action N physics frames
  {"key": "Space", "frames": 2}     a real InputEventKey (menus react to this)
  {"quit": true}                    end the session

Exit codes: 0 ok · 2 bad usage/owner alive · 3 game died on boot · 4 timeout.
"""
import argparse
import ctypes
import json
import os
import random
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / ".captures"
TOOLS = Path(__file__).resolve().parent

CREATE_NO_WINDOW = 0x08000000
STILL_ACTIVE = 259


def godot_bin() -> Path:
    candidates = []
    if os.environ.get("PIGEON_BIN"):
        candidates.append(Path(os.environ["PIGEON_BIN"]))
    home = Path.home()
    candidates += [
        home / "bin" / "Godot_v4.7.2-stable_win64_console.exe",
        home / "bin" / "Godot_v4.7.2-stable_win64.exe",
    ]
    for c in candidates:
        if c.is_file():
            return c
    sys.exit("pilot: no Godot binary found (set PIGEON_BIN)")


def pid_info(pid: int):
    """(alive, image_name) for a pid, or None if it can't be queried."""
    if os.name != "nt":
        try:
            os.kill(pid, 0)
            return (True, "?")
        except OSError:
            return (False, "?")
    k32 = ctypes.windll.kernel32
    h = k32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return (False, "?")
    try:
        buf = ctypes.create_unicode_buffer(512)
        size = ctypes.c_ulong(512)
        name = "?"
        if k32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)):
            name = os.path.basename(buf.value)
        code = ctypes.c_ulong()
        k32.GetExitCodeProcess(h, ctypes.byref(code))
        return (code.value == STILL_ACTIVE, name)
    finally:
        k32.CloseHandle(h)


def godot_alive(pid: int) -> bool:
    info = pid_info(pid)
    # Image-name check absorbs Windows pid reuse: a recycled pid that now
    # belongs to a non-Godot process counts as a dead owner.
    return bool(info and info[0] and "godot" in info[1].lower())


def session_dir(sid: str) -> Path:
    return CAPTURES / f"session_{sid}"


def read_claim(sid: str):
    f = session_dir(sid) / "started.json"
    if not f.is_file():
        return None
    try:
        return json.loads(f.read_text(encoding="utf-8"))
    except Exception:
        return None


def live_sessions() -> dict:
    out = {}
    if not CAPTURES.is_dir():
        return out
    for d in sorted(CAPTURES.glob("session_*")):
        claim = None
        cf = d / "started.json"
        if cf.is_file():
            try:
                claim = json.loads(cf.read_text(encoding="utf-8"))
            except Exception:
                pass
        pid = int(claim.get("pid", 0)) if claim else 0
        out[d.name[len("session_"):]] = {"pid": pid, "alive": godot_alive(pid) if pid else False}
    return out


def tail_lines(path: Path, n: int):
    if not path.is_file():
        return []
    lines = path.read_text(encoding="utf-8", errors="replace").strip().splitlines()
    return lines[-n:] if n else lines


def drop_command(sid: str, text: str) -> Path:
    """Atomically create a command file the game will execute and delete."""
    name = f"pilot_cmd_{time.time_ns()}_{random.randint(100, 999)}.jsonl"
    path = session_dir(sid) / name
    for line in text.strip().splitlines():
        if line.strip() and not isinstance(json.loads(line), dict):
            sys.exit("pilot: each command line must be a JSON object")
    path.write_text(text.strip() + "\n", encoding="utf-8")
    return path


def cascade_pos() -> tuple:
    idx = sum(1 for s in live_sessions().values() if s["alive"])
    off = 48 * (idx % 10)
    return (40 + off, 40 + off)


def cmd_start(a):
    sid = a.session
    d = session_dir(sid)
    claim = read_claim(sid)
    if claim and godot_alive(int(claim.get("pid", 0) or 0)):
        sys.exit(f"pilot: session '{sid}' is already owned by a live instance "
                 f"(pid {claim['pid']}) — pick another id")
    if not CAPTURES.is_dir():
        CAPTURES.mkdir()
    d.mkdir(exist_ok=True)
    # A predecessor that died without consuming its commands leaves poison
    # behind: a stale {"quit": true} executes at this boot and kills the
    # session ~1 s in (observed live, T-018). Sweep the channel before
    # claiming it.
    for stale in d.glob("pilot_cmd_*.jsonl"):
        stale.unlink()

    godot = godot_bin()
    # First launch on a fresh checkout: imports must exist before any game
    # instance starts, and N concurrent imports would race in .godot/.
    if not (ROOT / ".godot" / "imported").is_dir():
        print(f"pilot: warming imports with {godot.name} ...")
        subprocess.run([str(godot), "--headless", "--path", str(ROOT), "--import"],
                       check=True, timeout=300,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    env = os.environ.copy()
    env["PIGEON_PILOT_SESSION"] = sid
    env["PIGEON_IMAGE_INTERVAL"] = "0" if a.images == "off" else a.images
    env["PIGEON_MUTE"] = "" if a.sound else "1"
    env["PIGEON_NO_PERSIST"] = "" if a.persist else "1"

    pos = tuple(int(v) for v in a.pos.split(",")) if a.pos else cascade_pos()
    argv = [str(godot), "--path", str(ROOT), "--position", f"{pos[0]},{pos[1]}"]
    if a.size:
        argv += ["--resolution", a.size]
    argv += [a.scene, "--", f"--pilot-session={sid}"]

    log = (d / "godot.log").open("wb")
    proc = subprocess.Popen(argv, cwd=str(ROOT), stdout=log, stderr=subprocess.STDOUT,
                            env=env, creationflags=CREATE_NO_WINDOW if os.name == "nt" else 0)
    print(f"pilot: session '{sid}' pid {proc.pid} spawning (pos {pos[0]}x{pos[1]}) ...")

    deadline = time.time() + 30
    while time.time() < deadline:
        if proc.poll() is not None:
            tail = tail_lines(d / "godot.log", 25)
            print("\n".join(tail), file=sys.stderr)
            sys.exit(f"pilot: game exited during boot (code {proc.poll()}) — log tail above")
        claim = read_claim(sid)
        if claim and claim.get("pid"):
            if int(claim["pid"]) != proc.pid:
                print(f"pilot: WARNING claim pid {claim['pid']} != spawned {proc.pid}")
            break
        time.sleep(0.25)
    else:
        stop_force(proc.pid)
        sys.exit("pilot: timed out waiting for the session claim (started.json)")

    print(f"pilot: session '{sid}' READY")
    print(f"  dir     {d}")
    print(f"  log     {d / 'godot.log'}")
    print(f"  images  {'off' if a.images == 'off' else a.images + 's interval'}"
          f"  sound {'on' if a.sound else 'muted'}  persistence {'on' if a.persist else 'off'}")
    print("  drive   python tests/tools/pilot.py send --session "
          f"{sid} '{{\"action\":\"flap\",\"frames\":7}}'")
    print(f"  stop    python tests/tools/pilot.py stop --session {sid}")


def cmd_send(a):
    text = " ".join(a.payload) if a.payload else sys.stdin.read()
    if not text.strip():
        sys.exit("pilot: no command given (argument or stdin)")
    if not read_claim(a.session):
        sys.exit(f"pilot: session '{a.session}' has no live claim — did start finish?")
    path = drop_command(a.session, text)
    print(f"pilot: queued {path.name}")


def cmd_state(a):
    lines = tail_lines(session_dir(a.session) / "state.jsonl", a.tail)
    if not lines:
        sys.exit("pilot: no state yet")
    print("\n".join(lines))


def cmd_events(a):
    lines = tail_lines(session_dir(a.session) / "events.jsonl", a.tail)
    if not lines:
        print("pilot: no events yet")
        return
    print("\n".join(lines))


def cmd_wait(a):
    deadline = time.time() + a.timeout
    last = ""
    while time.time() < deadline:
        lines = tail_lines(session_dir(a.session) / "state.jsonl", 1)
        if lines:
            try:
                last = json.loads(lines[-1]).get("scene", "")
            except Exception:
                pass
            if last == a.scene:
                print(f"pilot: {a.session} reached scene '{last}'")
                return
        time.sleep(0.25)
    last_desc = last or "none"
    print(f"pilot: TIMEOUT waiting for scene '{a.scene}' (last: '{last_desc}')", file=sys.stderr)
    sys.exit(4)


def cmd_shot(a):
    ps1 = TOOLS / "window-shot.ps1"
    out = a.out or str(session_dir(a.session) / "window.png")
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                        "-File", str(ps1), "-TitlePattern", f"Pigeon pilot {a.session}",
                        "-OutPath", str(out)], capture_output=True, text=True)
    print((r.stdout or r.stderr).strip())
    sys.exit(r.returncode)


def cmd_stop(a):
    claim = read_claim(a.session)
    pid = int(claim.get("pid", 0)) if claim else 0
    if not pid or not godot_alive(pid):
        print(f"pilot: session '{a.session}' is not running")
        return
    if not a.force:
        try:
            drop_command(a.session, '{"quit": true}')
        except Exception:
            pass
        deadline = time.time() + 6
        while time.time() < deadline and godot_alive(pid):
            time.sleep(0.25)
    if godot_alive(pid):
        print(f"pilot: quit not acknowledged, killing pid {pid}")
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"],
                       capture_output=True)
        time.sleep(0.5)
    print(f"pilot: session '{a.session}' stopped"
          + (" (graceful)" if not godot_alive(pid) and not a.force else " (killed)"))


def stop_force(pid: int):
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
    else:
        try:
            os.kill(pid, 9)
        except OSError:
            pass


def cmd_list(_a):
    rows = live_sessions()
    if not rows:
        print("pilot: no sessions")
        return
    print(f"{'session':<20} {'live':<5} {'pid':<8} scene / frames")
    for sid, s in rows.items():
        scene, frames = "-", "-"
        lines = tail_lines(session_dir(sid) / "state.jsonl", 1)
        if lines:
            try:
                scene = json.loads(lines[-1]).get("scene", "?")
            except Exception:
                scene = "?"
        frames = len(list(session_dir(sid).glob("f*.png")))
        print(f"{sid:<20} {'yes' if s['alive'] else 'no':<5} {s['pid'] or '-':<8} {scene} / {frames} frames")


def cmd_clean(_a):
    if not CAPTURES.is_dir():
        print("pilot: nothing to clean")
        return
    for sid, s in live_sessions().items():
        if s["alive"]:
            print(f"pilot: keeping live session {sid}")
            continue
        if not s["pid"]:
            print(f"pilot: skipping {sid} (no claim — maybe still booting)")
            continue
        shutil.rmtree(session_dir(sid))
        print(f"pilot: removed dead session {sid}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    def sess(sp):
        sp.add_argument("--session", required=True, help="pilot session id")

    s = sub.add_parser("start", help="launch a game instance")
    sess(s)
    s.add_argument("--scene", default="res://scenes/menu.tscn")
    s.add_argument("--images", default="0.2", help="seconds between frame PNGs, or 'off'")
    s.add_argument("--sound", action="store_true", help="don't mute audio")
    s.add_argument("--persist", action="store_true", help="allow user:// high-score writes")
    s.add_argument("--pos", help="window position X,Y (default: cascade)")
    s.add_argument("--size", help="window size, e.g. 1280x720")
    s.set_defaults(fn=cmd_start)

    s = sub.add_parser("send", help="queue a pilot command")
    sess(s)
    s.add_argument("payload", nargs="*", help='JSON, e.g. {"action":"flap","frames":7}')
    s.set_defaults(fn=cmd_send)

    for name, fn in (("state", cmd_state), ("events", cmd_events)):
        s = sub.add_parser(name, help=f"tail the session's {name}.jsonl")
        sess(s)
        s.add_argument("--tail", type=int, default=1 if name == "state" else 20)
        s.set_defaults(fn=fn)

    s = sub.add_parser("wait", help="block until the state's scene field matches")
    sess(s)
    s.add_argument("--scene", required=True, help="e.g. Menu, Main")
    s.add_argument("--timeout", type=float, default=15)
    s.set_defaults(fn=cmd_wait)

    s = sub.add_parser("shot", help="OS-level grab of this session's window")
    sess(s)
    s.add_argument("--out", default="", help="PNG path (default: <session>/window.png)")
    s.set_defaults(fn=cmd_shot)

    s = sub.add_parser("stop", help="quit the session's game (kill as fallback)")
    sess(s)
    s.add_argument("--force", action="store_true", help="skip graceful quit, taskkill now")
    s.set_defaults(fn=cmd_stop)

    sub.add_parser("list", help="all sessions and liveness").set_defaults(fn=cmd_list)
    sub.add_parser("clean", help="delete dead sessions' capture dirs").set_defaults(fn=cmd_clean)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
