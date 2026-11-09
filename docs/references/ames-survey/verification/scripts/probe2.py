#!/usr/bin/env python3
"""Follow-up probes: downtown Main Street W->E order, named venue POIs,
stadium relation description, Main x Duff distance checks."""
import json, math

PATH = r"C:\Users\matth\Documents\pigeon-simulator\docs\references\ames-survey\osm\raw\ames_merged.json"

def main():
    with open(PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    raw_nodes = data["nodes"]
    nodes = {int(k): tuple(v) for k, v in raw_nodes.items()}
    ways = []
    for k, v in data["ways"].items():
        v["id"] = int(k); ways.append(v)
    rels = []
    for k, v in data["relations"].items():
        v["id"] = int(k); rels.append(v)

    def wc(w):
        return [nodes[n] for n in w.get("nodes", []) if n in nodes]

    def sec(t): print("\n==== " + t + " ====")

    # 1. Downtown cross streets at Main Street latitude
    sec("1. Downtown streets crossing Main Street (lat ~42.0251), W->E")
    cross = {}
    for w in ways:
        tg = w.get("tags") or {}
        nm = tg.get("name")
        if not nm or tg.get("highway") not in ("primary", "secondary", "tertiary", "residential", "unclassified", "service", "living_street", "pedestrian"):
            continue
        pts = [c for c in wc(w) if abs(c[1] - 42.0251) < 0.0008 and -93.626 < c[0] < -93.606]
        if pts:
            d = cross.setdefault(nm, [0.0, 0])
            for c in pts:
                d[0] += c[0]; d[1] += 1
    for lon, nm, n in sorted((v[0]/v[1], nm, v[1]) for nm, v in cross.items()):
        print(f"  {nm:26s} lon {lon:.5f} (n={n})")

    # Main Street extent
    sec("2. Main Street named-way extent downtown")
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("name") in ("Main Street", "East Main Street", "West Main Street") and tg.get("highway") in ("tertiary","residential","primary","secondary"):
            cs = wc(w)
            if cs:
                lons = [c[0] for c in cs]; lats = [c[1] for c in cs]
                print(f"  way {w['id']} {tg.get('name')} class={tg.get('highway')} lat {min(lats):.5f}..{max(lats):.5f} lon {min(lons):.5f}..{max(lons):.5f}")

    # 3. Named venue POIs
    sec("3. Named venue POIs (ways/nodes/rels by name)")
    names = ("Welch Ave Station", "Pizza Pit", "Mickey", "Paddy", "Sips", "Beaudelaire",
             "Mr. Burrito", "Jeff's", "Superdog", "Blaze", "Blue Owl", "Dogtown",
             "Cornbred", "Aunt Maude", "depot", "Depot", "The Cafe", "Stomping Grounds",
             "Es Tas", "The Stan Tap", "People's", "EsTas", "Stomping")
    def show(kind, eid, c0, tg):
        keep = ("amenity","building","shop","cuisine","addr:housenumber","addr:street","building:levels","operator","sport","capacity","leisure")
        print(f"  [{kind} {eid}] ({c0[0]:.5f},{c0[1]:.5f}) name={tg.get('name')} " +
              " ".join(f"{k}={tg[k]}" for k in sorted(tg) if k in keep))
    for w in ways:
        tg = w.get("tags") or {}
        nm = tg.get("name") or ""
        if any(s.lower() in nm.lower() for s in names):
            cs = wc(w)
            if cs:
                c0 = (sum(c[0] for c in cs)/len(cs), sum(c[1] for c in cs)/len(cs))
                show("way", w["id"], c0, tg)
    for r in rels:
        tg = r.get("tags") or {}
        nm = tg.get("name") or ""
        if any(s.lower() in nm.lower() for s in names):
            print(f"  [rel {r['id']}] name={tg.get('name')} " + " ".join(f"{k}={tg[k]}" for k in sorted(tg)[:8]))

    # 4. Stadium relation description (orientation wording)
    sec("4. Jack Trice relation tags/description")
    for r in rels:
        tg = r.get("tags") or {}
        if "trise" in (tg.get("name") or "").lower() or "trice" in (tg.get("description") or "").lower():
            print(f"  rel {r['id']} name={tg.get('name')} cap={tg.get('capacity')}")
            desc = tg.get("description") or ""
            print("  description:", desc[:600])

    # 5. Distance checks
    sec("5. Distance recomputes")
    ML = 82700.0
    # find Main x Duff: Duff Avenue nodes near Main lat
    def near(pts, lat, lon, tol=0.0008):
        return [c for c in pts if abs(c[1]-lat) < tol and abs(c[0]-lon) < tol*2]
    duff_main = None
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("name") == "Duff Avenue" and tg.get("highway"):
            pts = [c for c in wc(w) if abs(c[1]-42.0251) < 0.001]
            if pts:
                duff_main = (sum(c[0] for c in pts)/len(pts), 42.0251)
    camp_pt = (-93.64604, 42.02543)
    welch_lw = (-93.65015, 42.0228)
    if duff_main:
        print(f"  Main x Duff at lon {duff_main[0]:.5f}")
        d1 = abs(duff_main[0]-camp_pt[0]) * ML
        d2 = abs(duff_main[0]-welch_lw[0]) * ML
        print(f"  Main x Duff -> Campanile: {d1:.0f} m (SUMMARY TL;DR claims 2,940)")
        print(f"  Main x Duff -> Lincoln Way x Welch: {d2:.0f} m (SUMMARY TL;DR claims 3,290)")
        print(f"  Main x Duff -> MU (2229 LW): {abs(duff_main[0]-(-93.64584))*ML:.0f} m")
    # Lincoln Way x Welch coords
    print(f"  Lincoln Way lat at Campustown = 42.0227-42.0229; Welch centerline lon = -93.65015; Stanton = -93.64850")
    # Memorial Union vs Lincoln Way lat gap
    print(f"  MU building lat 42.02317..42.02416 vs LW 42.0227-42.0229 -> entirely N of LW")

if __name__ == "__main__":
    main()
