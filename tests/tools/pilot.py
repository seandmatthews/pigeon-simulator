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
                  [--time-scale 0.1] [--shown] [--gl] [--headless]
  pilot.py send   --session <id> '{"action":"flap","frames":7}'
  pilot.py state  --session <id> [--tail 1]
  pilot.py events --session <id> [--tail 20]
  pilot.py wait   --session <id> --scene Main [--timeout 15]
  pilot.py shot   --session <id> --out shot.png      (OS window grab)
  pilot.py stop   --session <id> [--force]
  pilot.py focuscheck                                 (T-170: prove the hidden launch)
  pilot.py list
  pilot.py clean

Linux gate box (T-211): set PIGEON_BIN to the Linux editor binary; deps are
python3 + xvfb (rendered sessions), xdotool + imagemagick (`shot`). `--gl`
forces the GL compatibility renderer for llvmpipe; `--headless` needs no X
at all. focuscheck is Windows-only by design. See VERIFICATION.md.

Pilot commands (one JSON object per line):
  {"action": "flap", "frames": 7}   hold an input action N physics frames
  {"key": "Space", "frames": 2}     a real InputEventKey (menus react to this)
  {"quit": true}                    end the session
  {"pause": true}                   freeze the whole tree (frame-step mode)
  {"step": 30}                      advance exactly 30 physics ticks, re-freeze
  {"resume": true}                  leave pause — normal play

Step mode: queue action holds in the SAME file as the step so they press on
the first stepped tick (a hold sent while frozen decays unspent).

Exit codes: 0 ok · 1 focuscheck failed · 2 bad usage/owner alive ·
3 game died on boot · 4 timeout.
"""
import argparse
import ctypes
import json
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / ".captures"
TOOLS = Path(__file__).resolve().parent

CREATE_NO_WINDOW = 0x08000000
STILL_ACTIVE = 259
SW_SHOWNOACTIVATE = 4  # T-170: the launcher's show-state leg (belt-and-suspenders)
FOCUS_MARGIN_PX = 32   # T-170: focuscheck's on/off-screen clearance bar


class _RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


def godot_bin() -> Path:
    candidates = []
    if os.environ.get("PIGEON_BIN"):
        candidates.append(Path(os.environ["PIGEON_BIN"]))
    home = Path.home()
    candidates += [
        home / "bin" / "Godot_v4.7.2-stable_win64_console.exe",
        home / "bin" / "Godot_v4.7.2-stable_win64.exe",
    ]
    if os.name != "nt":  # T-211: the Linux gate box — PIGEON_BIN wins, then the usual spots
        candidates += [
            home / "bin" / "Godot_v4.7.2-stable_linux.x86_64",
            home / ".local" / "bin" / "godot",
        ]
        on_path = shutil.which("godot")
        if on_path:
            candidates.append(Path(on_path))
    for c in candidates:
        if c.is_file():
            return c
    sys.exit("pilot: no Godot binary found (set PIGEON_BIN)")


def pid_info(pid: int):
    """(alive, image_name) for a pid, or None if it can't be queried."""
    if os.name != "nt":
        # T-211: the name must be REAL — godot_alive's image-name check is the
        # pid-reuse absorb on both platforms, and a "?" here made every POSIX
        # session read dead. /proc/<pid>/comm holds the executable's name
        # (15-char truncated, which both "Godot_v4.7.2-st…" and "godot" survive).
        try:
            comm = Path(f"/proc/{pid}/comm").read_text(encoding="utf-8").strip()
            return (True, comm)
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


def boot_session(sid: str, shown: bool, scene: str = "res://scenes/menu.tscn",
                 images: str = "0.2", sound: bool = False, persist: bool = False,
                 pos: str = "", size: str = "", time_scale=None,
                 announce: bool = True, gl: bool = False,
                 headless: bool = False) -> tuple:
    """The ONE launch path (T-170) — cmd_start and focuscheck both boot
    through here, so the checker exercises the real default. Returns
    (proc, session_dir, pos). Unless `shown`, the launch is hidden-from-focus:
    a STARTUPINFO show-state (SW_SHOWNOACTIVATE — apps honoring the launcher's
    show state get it; Godot's console wrapper doesn't, so this leg is
    belt-and-suspenders, not load-bearing) plus PIGEON_WINDOW_HIDDEN=1, the env
    lever the recorder acts on by flagging the window no-activate and moving it
    fully off-screen. `shown` skips both and reproduces the historical visible
    cascade path byte-for-byte (no startupinfo, no new env)."""
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
    # Same poison class (observed live, T-211): a predecessor's started.json
    # from a dead session with a REUSED id gets read by the claim-wait loop
    # below before this boot's claim lands — the stale pid wins and every
    # later check (list, stop) watches a corpse. Drop it so the wait can only
    # succeed on THIS boot's claim. (The recorder overwrites the claim itself
    # but only warns; a fresh claim from a SLOW boot can lose that race too.)
    (d / "started.json").unlink(missing_ok=True)

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
    env["PIGEON_IMAGE_INTERVAL"] = "0" if images == "off" else images
    env["PIGEON_MUTE"] = "" if sound else "1"
    env["PIGEON_SOUND"] = "1" if sound else ""  # T-101: --sound opts the game's own boot-mute policy in
    env["PIGEON_NO_PERSIST"] = "" if persist else "1"
    if not shown:  # T-170: the recorder reads this and hides the window
        env["PIGEON_WINDOW_HIDDEN"] = "1"

    pos = tuple(int(v) for v in pos.split(",")) if pos else cascade_pos()
    argv = [str(godot), "--path", str(ROOT), "--position", f"{pos[0]},{pos[1]}"]
    if size:
        argv += ["--resolution", size]
    if headless:  # T-211: no window at all — the recorder's OS legs guard-skip
        argv += ["--headless"]
    if gl:  # T-211: software-rendered servers — GL compatibility beats lavapipe
        argv += ["--rendering-method", "gl_compatibility",
                 "--rendering-driver", "opengl3"]
    if os.name != "nt" and not sound:  # T-211: a server has no audio device
        argv += ["--audio-driver", "Dummy"]
    # Engine flags go BEFORE the scene arg; everything after `--` is user args.
    argv += [scene, "--", f"--pilot-session={sid}"]
    if time_scale is not None:  # T-132: agent slow-mo — the game clamps to [0.01, 1.0]
        argv += [f"--time-scale={time_scale}"]

    startupinfo = None
    if os.name == "nt" and not shown:
        # T-170: the launcher's show-state leg. The engine never honors it
        # (stated in the ticket against the 4.7.2 wrapper source), but it
        # costs four lines and matches the intent.
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = SW_SHOWNOACTIVATE

    log = (d / "godot.log").open("wb")
    proc = subprocess.Popen(argv, cwd=str(ROOT), stdout=log, stderr=subprocess.STDOUT,
                            env=env, creationflags=CREATE_NO_WINDOW if os.name == "nt" else 0,
                            startupinfo=startupinfo)
    if announce:
        print(f"pilot: session '{sid}' pid {proc.pid} spawning "
              f"(pos {pos[0]}x{pos[1]}, {'shown' if shown else 'hidden off-screen'}) ...")

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
    return proc, d, pos


def cmd_start(a):
    sid = a.session
    proc, d, _pos = boot_session(sid, a.shown, a.scene, a.images, a.sound,
                                 a.persist, a.pos, a.size, a.time_scale,
                                 gl=a.gl, headless=a.headless)
    print(f"pilot: session '{sid}' READY"
          + ("" if a.shown else " (window hidden off-screen — --shown for eyes-on)"))
    print(f"  dir     {d}")
    print(f"  log     {d / 'godot.log'}")
    print(f"  images  {'off' if a.images == 'off' else a.images + 's interval'}"
          f"  sound {'on' if a.sound else 'muted'}  persistence {'on' if a.persist else 'off'}"
          + (f"  time-scale {a.time_scale}" if a.time_scale is not None else ""))
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


def take_shot(sid: str, out: str) -> tuple:
    """One OS window grab: Windows through window-shot.ps1 (PrintWindow needs
    no focus, so an off-screen hidden session captures fine — T-170); POSIX
    through xdotool (find the window by title — the recorder's title is
    WM_NAME, the unanchored prefix match rides out the engine's re-stamping)
    piped xwd → ImageMagick convert (T-211 — the Linux gate box). X11's
    X_GetImage cannot read a drawable that sits outside the root, so unlike
    PrintWindow an off-screen hidden window is NOT grabbable — sessions that
    need `shot` run --shown (under Xvfb that disturbs nothing). Returns
    (returncode, printed text)."""
    if os.name != "nt":
        title = f"Pigeon pilot {sid}"
        try:
            find = subprocess.run(["xdotool", "search", "--name", f"^{re.escape(title)}"],
                                  capture_output=True, text=True)
        except FileNotFoundError:
            return 1, "pilot: shot on Linux needs xdotool + x11-apps (xwd) + imagemagick"
        wids = [w for w in find.stdout.split() if w.strip()]
        if find.returncode != 0 or not wids:
            return 1, f"pilot: no window matching '{title}' (is the session up?)"
        try:
            xwd = subprocess.run(["xwd", "-id", wids[0], "-silent"], capture_output=True)
        except FileNotFoundError:
            return 1, "pilot: shot on Linux needs xdotool + x11-apps (xwd) + imagemagick"
        if xwd.returncode != 0 or not xwd.stdout:
            return 1, (f"pilot: xwd failed on window {wids[0]} (rc {xwd.returncode}) — "
                       "an off-screen hidden window is ungrabbable over X11; start "
                       "the session with --shown")
        try:
            conv = subprocess.run(["convert", "xwd:-", out], input=xwd.stdout,
                                  capture_output=True)
        except FileNotFoundError:
            return 1, "pilot: shot on Linux needs xdotool + x11-apps (xwd) + imagemagick"
        if conv.returncode != 0:
            msg = (conv.stderr or b"").decode(errors="replace").strip()
            return 1, msg or f"convert failed on window {wids[0]}"
        return 0, f"shot window {wids[0]} -> {out}"
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                        "-File", str(TOOLS / "window-shot.ps1"), "-TitlePattern",
                        f"Pigeon pilot {sid}", "-OutPath", str(out)],
                       capture_output=True, text=True)
    return r.returncode, (r.stdout or r.stderr).strip()


def cmd_shot(a):
    out = a.out or str(session_dir(a.session) / "window.png")
    code, text = take_shot(a.session, out)
    print(text)
    sys.exit(code)


def stop_session(sid: str, force: bool = False) -> None:
    claim = read_claim(sid)
    pid = int(claim.get("pid", 0)) if claim else 0
    if not pid or not godot_alive(pid):
        print(f"pilot: session '{sid}' is not running")
        return
    if not force:
        try:
            drop_command(sid, '{"quit": true}')
        except Exception:
            pass
        deadline = time.time() + 6
        while time.time() < deadline and godot_alive(pid):
            time.sleep(0.25)
    if godot_alive(pid):
        print(f"pilot: quit not acknowledged, killing pid {pid}")
        stop_force(pid)
        time.sleep(0.5)
    print(f"pilot: session '{sid}' stopped"
          + (" (graceful)" if not godot_alive(pid) and not force else " (killed)"))


def cmd_stop(a):
    stop_session(a.session, a.force)


def stop_force(pid: int):
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
    else:
        # T-211: SIGTERM with a short grace, then SIGKILL — the Windows path is
        # /F (forceful), but a TERM first lets the engine flush .captures.
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            return
        for _ in range(20):  # ~2 s
            info = pid_info(pid)
            if not (info and info[0]):
                return
            time.sleep(0.1)
        try:
            os.kill(pid, signal.SIGKILL)
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


## --- T-170 focuscheck: the hidden-launch tooling scenario --------------------


def _monitor_rects() -> list:
    """Every connected monitor's rect (left, top, right, bottom)."""
    import ctypes.wintypes as wt
    user32 = ctypes.windll.user32
    rects: list = []
    proc = ctypes.WINFUNCTYPE(wt.BOOL, wt.HMONITOR, wt.HDC,
                              ctypes.POINTER(_RECT), wt.LPARAM)

    def _cb(_hmon, _hdc, lprect, _ldata):
        r = lprect.contents
        rects.append((r.left, r.top, r.right, r.bottom))
        return True

    user32.EnumDisplayMonitors(None, None, proc(_cb), 0)
    return rects


def _find_window(title: str):
    """The top-level window whose title is EXACTLY `title`, or None."""
    import ctypes.wintypes as wt
    user32 = ctypes.windll.user32
    found: list = []
    proc = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)

    def _cb(hwnd, _lparam):
        n = user32.GetWindowTextLengthW(hwnd)
        buf = ctypes.create_unicode_buffer(n + 2)
        user32.GetWindowTextW(hwnd, buf, n + 2)
        if buf.value == title:
            found.append(hwnd)
        return True

    user32.EnumWindows(proc(_cb), 0)
    return found[0] if found else None


def _window_rect(hwnd) -> tuple:
    import ctypes.wintypes as wt
    user32 = ctypes.windll.user32
    user32.GetWindowRect.argtypes = [wt.HWND, ctypes.POINTER(_RECT)]
    r = _RECT()
    if not user32.GetWindowRect(hwnd, ctypes.byref(r)):
        return None
    return (r.left, r.top, r.right, r.bottom)


def _foreground_hwnd():
    import ctypes.wintypes as wt
    user32 = ctypes.windll.user32
    user32.GetForegroundWindow.restype = wt.HWND
    return user32.GetForegroundWindow()


def _axis_separation(rect: tuple, other: tuple) -> tuple:
    """Per-axis separation between two rects — positive = gap on that axis,
    negative = overlap there. Two rects sit >= m px apart (the clearance
    notion focuscheck and the hide math share) iff separation_x >= m OR
    separation_y >= m."""
    l, t, r, b = rect
    ol, ot, oright, ob = other
    return (max(ol - r, l - oright), max(ot - b, t - ob))


def _wait_for_window(sid: str, timeout_s: float):
    """Poll for the session's exact window title (the recorder re-stamps it
    for ~600 frames against the engine's own re-titling)."""
    title = f"Pigeon pilot {sid}"
    deadline = time.time() + timeout_s
    hwnd = None
    while time.time() < deadline and hwnd is None:
        hwnd = _find_window(title)
        if hwnd is None:
            time.sleep(0.25)
    return hwnd, title


def _events_list(sid: str) -> list:
    out = []
    f = session_dir(sid) / "events.jsonl"
    if not f.is_file():
        return out
    for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        if isinstance(e, dict):
            out.append(e)
    return out


def _fresh_sid(base: str) -> str:
    """A session id no live instance owns — `start` refuses live ids, so the
    checker picks a fresh suffix instead of failing on a stale one."""
    for i in range(100):
        sid = base if i == 0 else f"{base}_{i}"
        claim = read_claim(sid)
        if not (claim and godot_alive(int(claim.get("pid", 0) or 0))):
            return sid
    sys.exit("pilot: no free focuscheck session id")


def cmd_focuscheck(_a):
    """The T-170 tooling scenario, self-contained: boots two short muted
    menu-scene sessions itself — one through the default (hidden) launch, one
    through --shown — checks the hidden-launch contract against the OS, stops
    both, prints measurements and FOCUSCHECK PASS/FAIL. Exit 0/1; non-Windows
    prints SKIP and exits 0 (window placement is a Win32 contract)."""
    if os.name != "nt":
        print("FOCUSCHECK SKIP (non-Windows — window placement is a Win32 contract)")
        return
    checks: list = []

    def note(name: str, ok: bool, detail: str = "") -> None:
        checks.append((name, ok))
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}"
              + (f" — {detail}" if detail else ""))

    def claim_pid(sid: str) -> int:
        claim = read_claim(sid)
        return int(claim.get("pid", 0)) if claim else 0

    sid_h = _fresh_sid("fchk_hidden")
    print(f"pilot: focuscheck hidden leg — session '{sid_h}' (default launch)")
    try:
        proc_h, _d_h, _p = boot_session(sid_h, shown=False, images="0.2",
                                        announce=False)
    except SystemExit as e:
        note("hidden_boot", False, str(e))
        proc_h = None
    if proc_h is not None:
        # A reused session dir carries the previous run's frame PNGs — the
        # recorder's f%08d names restart every boot, so the new stream
        # OVERWRITES stale files and the file count stays pinned until the
        # numbering passes the old max (observed live: "frames 50 -> 50" on a
        # reused dir while the stream itself ran every 0.2 s, mtimes
        # continuous). Sweep them so the growth check counts THIS run.
        for stale in session_dir(sid_h).glob("f0*.png"):
            stale.unlink()
        hwnd, title = _wait_for_window(sid_h, 20)
        note("hidden_window_found", hwnd is not None, f"title='{title}'")
        if hwnd is not None:
            # The claim lands when the recorder starts and the hide leg has
            # already run by then (it sits before the claim write in
            # _start_session); the settle absorbs the boot foreground race.
            time.sleep(2.5)
            rect = _window_rect(hwnd)
            mons = _monitor_rects()
            if rect is None or not mons:
                note("hidden_rect_offscreen", False,
                     f"GetWindowRect failed or no monitors (rect={rect}, monitors={mons})")
            else:
                clear = min(max(_axis_separation(rect, m)) for m in mons)
                outside = clear >= FOCUS_MARGIN_PX
                note("hidden_rect_offscreen", outside,
                     f"rect={rect} monitors={mons} min_clearance={clear}px "
                     f"(bar {FOCUS_MARGIN_PX}px)")
            fg_ok = True
            samples = []
            for _i in range(3):
                fg = _foreground_hwnd()
                samples.append("pilot" if fg == hwnd else "other")
                fg_ok = fg_ok and fg != hwnd
                time.sleep(1.0)
            note("hidden_never_foreground", fg_ok, f"samples={samples}")
        acks = [e for e in _events_list(sid_h) if e.get("ev") == "pilot_window_hidden"]
        note("hidden_ack_event",
             len(acks) == 1 and acks[0].get("no_focus") is True,
             f"ack={acks}")
        shot_path = session_dir(sid_h) / "focuscheck_shot.png"
        code, text = take_shot(sid_h, str(shot_path))
        shot_ok = code == 0 and shot_path.is_file() and shot_path.stat().st_size > 0
        note("hidden_shot_alive", shot_ok,
             f"rc={code} {text} bytes={shot_path.stat().st_size if shot_path.is_file() else 0}")
        frames0 = len(list(session_dir(sid_h).glob("f0*.png")))
        time.sleep(1.5)
        frames1 = len(list(session_dir(sid_h).glob("f0*.png")))
        note("hidden_frame_stream_grows", frames1 > frames0,
             f"frames {frames0} -> {frames1}")
        drop_command(sid_h, '{"action":"flap","frames":7}')
        time.sleep(1.5)
        presses = [e for e in _events_list(sid_h)
                   if e.get("ev") == "pilot_press" and e.get("action") == "flap"]
        note("hidden_input_flows", len(presses) >= 1, f"pilot_press={presses[:1]}")
        stop_session(sid_h)
        note("hidden_stopped_clean",
             not godot_alive(claim_pid(sid_h)), f"pid={claim_pid(sid_h)}")

    sid_s = _fresh_sid("fchk_shown")
    print(f"pilot: focuscheck shown leg — session '{sid_s}' (--shown)")
    try:
        proc_s, _d_s, _p = boot_session(sid_s, shown=True, images="off",
                                        announce=False)
    except SystemExit as e:
        note("shown_boot", False, str(e))
        proc_s = None
    if proc_s is not None:
        hwnd_s, _title_s = _wait_for_window(sid_s, 20)
        rect_s = _window_rect(hwnd_s) if hwnd_s else None
        mons = _monitor_rects()
        on_any = False
        if rect_s is not None:
            for m in mons:
                sx, sy = _axis_separation(rect_s, m)
                if sx < 0 and sy < 0:
                    on_any = True
        note("shown_rect_onscreen", on_any,
             f"rect={rect_s} monitors={mons}")
        time.sleep(1.0)
        leaked = [e for e in _events_list(sid_s) if e.get("ev") == "pilot_window_hidden"]
        note("shown_no_hide_ack", not leaked, f"pilot_window_hidden={leaked}")
        stop_session(sid_s)
        note("shown_stopped_clean",
             not godot_alive(claim_pid(sid_s)), f"pid={claim_pid(sid_s)}")

    ok = bool(checks) and all(c[1] for c in checks)
    print("FOCUSCHECK " + ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


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
    s.add_argument("--time-scale", type=float, default=None,
                   help="slow the whole simulation (Engine.time_scale), 0.01..1.0 — "
                        "frames keep painting, the flight model per game-second is "
                        "unchanged; default off")
    s.add_argument("--pos", help="window position X,Y (default: cascade; with the "
                        "default hidden launch the window ends off-screen regardless — "
                        "stage a visible window at a spot with --shown --pos=X,Y; use "
                        "the = form for negative coordinates)")
    s.add_argument("--size", help="window size, e.g. 1280x720")
    s.add_argument("--shown", action="store_true",
                   help="launch visible + focusable at the cascade position (T-170: "
                        "the default launch is hidden off-screen and no-activate so "
                        "agent batches never steal the desktop)")
    s.add_argument("--gl", action="store_true",
                   help="T-211: force the GL compatibility renderer (software-"
                        "rendered Linux boxes: llvmpipe/Xvfb; the desktop default "
                        "is forward_plus/Vulkan)")
    s.add_argument("--headless", action="store_true",
                   help="T-211: no window at all — box/CI runs; the recorder's OS "
                        "legs guard-skip, the frame stream is off, shot finds no "
                        "window; channel/state/events/stop all work")
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
    sub.add_parser("focuscheck",
                   help="T-170: prove the hidden launch end to end (boots a hidden "
                        "and a --shown session, checks, stops both; Windows only)"
                   ).set_defaults(fn=cmd_focuscheck)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
