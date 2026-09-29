"""Summarize a capture run folder: events timeline + trajectory + stats.
Usage: python summarize.py <run_dir>"""
import json, math, os, sys

run = sys.argv[1]
events = []
for line in open(os.path.join(run, 'events.jsonl'), encoding='utf-8'):
    line = line.strip()
    if line:
        try:
            events.append(json.loads(line))
        except Exception:
            pass
states = []
for line in open(os.path.join(run, 'state.jsonl'), encoding='utf-8'):
    line = line.strip()
    if line:
        try:
            states.append(json.loads(line))
        except Exception:
            pass  # tail line truncated by a hard kill

if not states:
    print('no state'); sys.exit(1)

t0 = states[0]['t_ms']
def sec(ms): return round((ms - t0) / 1000.0, 2)

print(f"=== {os.path.basename(run)}  |  {len(states)} state frames, {len(events)} events, span {sec(states[-1]['t_ms'])}s")

print('\n--- events timeline')
for e in events:
    extra = {k: v for k, v in e.items() if k not in ('ev', 't_ms')}
    print(f"  t={sec(e['t_ms']):7.2f}s  {e['ev']:16s} {json.dumps(extra) if extra else ''}")

# trajectory summary
grounded_changes = 0
min_alt, max_alt = 1e9, -1e9
xs, zs = [], []
hunger_series = []
for s in states:
    p = s.get('player')
    if not p: continue
    pos = p['p']
    xs.append(pos[0]); zs.append(pos[2])
    min_alt = min(min_alt, pos[1]); max_alt = max(max_alt, pos[1])
    if s.get('hunger') is not None:
        hunger_series.append((sec(s['t_ms']), s['hunger']))
print(f"\n--- trajectory: x [{min(xs):.0f}..{max(xs):.0f}]  z [{min(zs):.0f}..{max(zs):.0f}]  alt [{min_alt:.1f}..{max_alt:.1f}]")
if hunger_series:
    h0, h1 = hunger_series[0], hunger_series[-1]
    print(f"--- hunger: {h0[1]}% @t={h0[0]}s -> {h1[1]}% @t={h1[0]}s")
    starved = [e for e in events if e['ev'] == 'game_over']
    if starved: print('--- GAME OVER (starved) at t=', sec(starved[0]['t_ms']))

# score over time
score_series = [(sec(s['t_ms']), s.get('score')) for s in states if s.get('score') is not None]
if score_series:
    print(f"--- score: final {score_series[-1][1]} (tourist=100, car=30)")

# every Nth frame reference for contact sheet
n = len(states)
print(f"\n--- frames: state.jsonl frame indexes 0..{states[-1].get('frame', n)}, images f%08d.jpg @10Hz")
