"""Generates the T-123 in-house sound effects as 16-bit mono WAVs.

Everything here is synthesized from scratch (sines + shaped noise) so the
license is clean by construction — no third-party recording involved. Run
from the repo root:

    python tools/gen_sfx.py

Writes into assets/generated/. The Godot side (scripts/sfx.gd) preloads the
outputs; levels are trimmed in the SOUNDS table, not here.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join("assets", "generated")


def _write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.85 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
            for s in samples))
    print("wrote %s (%.2f s)" % (path, len(samples) / RATE))


def _env(i, n, attack_s=0.025, release_s=0.08):
    a = int(attack_s * RATE)
    r = int(release_s * RATE)
    if i < a:
        return i / max(1, a)
    if i > n - r:
        return max(0.0, (n - i) / max(1, r))
    return 1.0


def _hoot(t0, dur, f0, f1, gain=1.0):
    """One pigeon hoot: a soft glide tone with a couple of harmonics."""
    n = int(dur * RATE)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n) + 3.0 * math.sin(2 * math.pi * 5.0 * i / RATE)
        phase += 2 * math.pi * f / RATE
        s = (math.sin(phase) + 0.4 * math.sin(2 * phase)
             + 0.12 * math.sin(3 * phase))
        out[i] = gain * _env(i, n) * s
    return t0, out


def _mix_into(canvas, t0, part):
    start = int(t0 * RATE)
    for i, s in enumerate(part):
        j = start + i
        if 0 <= j < len(canvas):
            canvas[j] += s


def _coo_idle():
    canvas = [0.0] * int(0.75 * RATE)
    _mix_into(canvas, *_hoot(0.0, 0.28, 340, 280))
    _mix_into(canvas, *_hoot(0.36, 0.33, 300, 240, 0.9))
    return canvas


def _coo_waddle():
    canvas = [0.0] * int(0.4 * RATE)
    _mix_into(canvas, *_hoot(0.0, 0.32, 320, 250, 0.8))
    return canvas


def _coo_smug():
    canvas = [0.0] * int(0.95 * RATE)
    _mix_into(canvas, *_hoot(0.0, 0.20, 280, 300, 0.7))
    _mix_into(canvas, *_hoot(0.24, 0.24, 300, 345, 0.9))
    _mix_into(canvas, *_hoot(0.52, 0.36, 340, 400, 1.1))
    return canvas


def _noise_burst(dur, decay, lp, thump_f0, thump_f1, thump_gain):
    rng = random.Random(20261017)
    n = int(dur * RATE)
    out = [0.0] * n
    acc = 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        acc += lp * (x - acc)  # one-pole low-pass
        e = math.exp(-i / (decay * RATE))
        out[i] = e * acc
    for i in range(int(0.2 * RATE)):
        f = thump_f0 + (thump_f1 - thump_f0) * (i / (0.2 * RATE))
        out[i] += thump_gain * math.exp(-i / (0.08 * RATE)) * math.sin(
            2 * math.pi * f * i / RATE)
    return out


def _note(canvas, t0, dur, f0, f1, gain, decay, harmonics):
    n = int(dur * RATE)
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * f / RATE
        s = sum(g * math.sin(phase * h) for h, g in harmonics)
        canvas_idx = int(t0 * RATE) + i
        if 0 <= canvas_idx < len(canvas):
            canvas[canvas_idx] += gain * math.exp(-i / (decay * RATE)) * s


def _stinger_win():
    canvas = [0.0] * int(1.3 * RATE)
    h = [(1.0, 1.0), (2.0, 0.3), (3.0, 0.1)]
    for k, f in enumerate([523.25, 659.26, 783.99]):
        _note(canvas, 0.14 * k, 0.5, f, f, 0.8, 0.16, h)
    _note(canvas, 0.42, 0.8, 1046.5, 1046.5, 1.0, 0.3, h)
    return [math.tanh(1.4 * s) for s in canvas]


def _stinger_lose():
    canvas = [0.0] * int(1.5 * RATE)
    h = [(1.0, 1.0), (2.0, 0.15)]
    for k, f in enumerate([440.0, 349.23]):
        _note(canvas, 0.0 + 0.24 * k, 0.65, f, f * 0.98, 0.8, 0.3, h)
    _note(canvas, 0.48, 0.95, 293.66, 277.0, 0.95, 0.45, h)
    return [math.tanh(1.3 * s) for s in canvas]


def main():
    _write_wav("coo_idle", _coo_idle())
    _write_wav("coo_waddle", _coo_waddle())
    _write_wav("coo_smug", _coo_smug())
    _write_wav("splat_2", _noise_burst(0.32, 0.09, 0.12, 85, 60, 0.9))
    _write_wav("splat_3", _noise_burst(0.22, 0.055, 0.3, 130, 90, 0.8))
    _write_wav("stinger_win", _stinger_win())
    _write_wav("stinger_lose", _stinger_lose())


if __name__ == "__main__":
    main()
