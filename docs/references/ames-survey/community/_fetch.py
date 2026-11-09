"""Helper for mining Reddit threads via the Arctic Shift API (public mirror).

Usage:
  python -I _fetch.py get <id> [<id> ...]   # fetch post + all comments into _cache/
  python -I _fetch.py show <id>             # print post title + top comments
  python -I _fetch.py grep <id> <pattern>   # print comments matching regex
Fetches are cached; delete _cache/<id>* to refetch.
"""
import json, os, re, subprocess, sys, time
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

BASE = "https://arctic-shift.photon-reddit.com/api"
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_cache")
os.makedirs(CACHE, exist_ok=True)

def _get(url):
    r = subprocess.run(["curl", "-s", "--max-time", "40", url],
                       capture_output=True)
    return json.loads(r.stdout.decode("utf-8", "replace"))

def fetch_post(pid):
    d = _get(f"{BASE}/posts/ids?ids={pid}")
    return d["data"][0] if d.get("data") else None

def fetch_comments(pid):
    out, after = [], None
    while True:
        url = f"{BASE}/comments/search?link_id={pid}&limit=100&sort=asc"
        if after:
            url += f"&after={after}"
        d = _get(url)
        batch = d.get("data", [])
        if not batch:
            break
        out.extend(batch)
        if len(batch) < 100 or not batch[-1].get("_id"):
            break
        after = batch[-1]["_id"]
        time.sleep(0.5)
    return out

def load(pid):
    pf = os.path.join(CACHE, f"{pid}_post.json")
    cf = os.path.join(CACHE, f"{pid}_comments.json")
    if not os.path.exists(pf):
        p = fetch_post(pid)
        json.dump(p, open(pf, "w", encoding="utf-8"), ensure_ascii=False)
    if not os.path.exists(cf):
        cs = fetch_comments(pid)
        json.dump(cs, open(cf, "w", encoding="utf-8"), ensure_ascii=False)
    return json.load(open(pf, encoding="utf-8")), json.load(open(cf, encoding="utf-8"))

def show(pid, pattern=None, topn=40):
    p, cs = load(pid)
    if p:
        when = time.strftime("%Y-%m", time.gmtime(p.get("created_utc", 0)))
        print(f"=== r/{p.get('subreddit')} | {p.get('title')} | {when} | score {p.get('score')} | id {p.get('id')} | comments {p.get('num_comments')}")
        if p.get("selftext"):
            print("BODY:", p["selftext"][:400].replace("\n", " / "))
    cs = [c for c in cs if c.get("author") not in ("AutoModerator",) and (c.get("body") or "[deleted]") not in ("[deleted]", "[removed]")]
    if pattern:
        rx = re.compile(pattern, re.I)
        cs = [c for c in cs if rx.search(c.get("body", ""))]
    cs.sort(key=lambda c: c.get("score", 0) or 0, reverse=True)
    for c in cs[:topn]:
        when = time.strftime("%Y-%m", time.gmtime(c.get("created_utc", 0)))
        body = (c.get("body") or "").replace("\n", " ¶ ")
        print(f"[{c.get('score'):>5}] {c.get('author')} ({when}): {body}")
        print()

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "get":
        for pid in sys.argv[2:]:
            p, cs = load(pid)
            print(pid, "post:", bool(p), "comments:", len(cs))
    elif cmd == "show":
        show(sys.argv[2], topn=int(sys.argv[3]) if len(sys.argv) > 3 else 40)
    elif cmd == "grep":
        show(sys.argv[2], pattern=sys.argv[3], topn=200)
