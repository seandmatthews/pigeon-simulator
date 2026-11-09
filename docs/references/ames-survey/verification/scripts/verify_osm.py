#!/usr/bin/env python3
"""Verification-lane analysis of the sibling OSM extract (ames_merged.json).
Run with: python -I verify_osm.py
Reads ONLY; prints a verification report to stdout.
"""
import json, math, sys

PATH = r"C:\Users\matth\Documents\pigeon-simulator\docs\references\ames-survey\osm\raw\ames_merged.json"

M_PER_DEG_LAT = 111074.0  # per sibling SUMMARY.md, matches ~42.02N

def main():
    with open(PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    ways = []
    rels = []
    node_tags = []
    if isinstance(data, dict) and "nodes" in data:
        raw_nodes = data["nodes"]
        raw_ways = data["ways"]
        raw_rels = data["relations"]
        if isinstance(raw_nodes, dict):
            nodes = {int(k): tuple(v) for k, v in raw_nodes.items()}
        else:
            nodes = {n["id"]: (n["lon"], n["lat"]) for n in raw_nodes}
        if isinstance(raw_ways, dict):
            for k, v in raw_ways.items():
                v["id"] = int(k)
                ways.append(v)
        else:
            ways = list(raw_ways)
        if isinstance(raw_rels, dict):
            for k, v in raw_rels.items():
                v["id"] = int(k)
                rels.append(v)
        else:
            rels = list(raw_rels)
        elements = []
    else:
        elements = data["elements"] if isinstance(data, dict) else data
        nodes = {}
        for el in elements:
            t = el.get("type")
            if t == "node":
                if el.get("tags"):
                    node_tags.append(el)
                nodes[el["id"]] = (el.get("lon"), el.get("lat"))
            elif t == "way":
                ways.append(el)
            elif t == "relation":
                rels.append(el)

    print(f"dataset: {len(nodes)} nodes / {len(ways)} ways / {len(rels)} relations")

    # tagged nodes for dict layout: nodes dict values are [lon,lat] without tags,
    # so scan way tags only; node-level addr tags are rare in this merge.

    def wc(w):
        out = []
        for nid in w.get("nodes", []):
            c = nodes.get(nid)
            if c:
                out.append(c)
        return out

    def m_per_deg_lon(lat):
        return 82700.0 * math.cos(math.radians(lat)) / math.cos(math.radians(42.02))

    def bbox(cs):
        xs = [c[0] for c in cs]; ys = [c[1] for c in cs]
        return (min(xs), min(ys), max(xs), max(ys))

    def bbox_m(cs):
        x0, y0, x1, y1 = bbox(cs)
        lat = (y0 + y1) / 2
        ml = m_per_deg_lon(lat)
        return ((x1 - x0) * ml, (y1 - y0) * M_PER_DEG_LAT)

    def centroid(cs):
        xs = [c[0] for c in cs]; ys = [c[1] for c in cs]
        return (sum(xs) / len(xs), sum(ys) / len(ys))

    def shoelace_m2(cs):
        if len(cs) < 3:
            return 0.0
        lat0 = sum(c[1] for c in cs) / len(cs)
        ml = m_per_deg_lon(lat0)
        pts = [(c[0] * ml, c[1] * M_PER_DEG_LAT) for c in cs]
        a = 0.0
        n = len(pts)
        for i in range(n):
            x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % n]
            a += x1 * y2 - x2 * y1
        return abs(a) / 2.0

    def named(sub, tag="name"):
        sub = sub.lower()
        hits = []
        for w in ways:
            tg = w.get("tags") or {}
            if sub in (tg.get(tag) or "").lower():
                hits.append(w)
        for r in rels:
            tg = r.get("tags") or {}
            if sub in (tg.get(tag) or "").lower():
                hits.append(("rel", r))
        return hits

    def sec(t):
        print("\n" + "=" * 8 + " " + t + " " + "=" * 8)

    # ---------- A. Lincoln Way latitude at Campustown ----------
    sec("A. Lincoln Way geometry")
    lw_all = []
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("name") in ("Lincoln Way", "East Lincoln Way"):
            cs = wc(w)
            lw_all.extend(cs)
            print(f"  way {w['id']} name={tg.get('name')} class={tg.get('highway')} "
                  f"n={len(cs)} bbox_m={tuple(round(v) for v in bbox_m(cs))} center=({centroid(cs)[0]:.5f},{centroid(cs)[1]:.5f})")
    camp = [c for c in lw_all if -93.662 < c[0] < -93.628]
    if camp:
        lats = [c[1] for c in camp]
        print(f"  Lincoln Way nodes in Campustown window (lon -93.662..-93.628): n={len(camp)} "
              f"lat min={min(lats):.5f} max={max(lats):.5f} mean={sum(lats)/len(lats):.5f}")

    lw_lat = sum(c[1] for c in camp) / len(camp) if camp else 42.0229

    # ---------- B. every named street crossing Lincoln Way, W->E ----------
    sec("B. Named streets crossing Lincoln Way (true W->E order by mean lon)")
    cross = {}
    for w in ways:
        tg = w.get("tags") or {}
        nm = tg.get("name")
        if not nm or tg.get("highway") not in ("primary", "secondary", "tertiary", "residential", "unclassified", "service", "trunk", "living_street"):
            continue
        pts = [c for c in wc(w) if abs(c[1] - lw_lat) < 0.0009 and -93.665 < c[0] < -93.605]
        if pts:
            d = cross.setdefault(nm, [0.0, 0])
            for c in pts:
                d[0] += c[0]; d[1] += 1
    order = sorted(((v[0] / v[1], nm, v[1]) for nm, v in cross.items()))
    for lon, nm, n in order:
        print(f"  {nm:28s} lon {lon:.5f}  (n={n})")

    # ---------- C. Memorial Union polygon(s) ----------
    sec("C. Memorial Union")
    for w in ways:
        tg = w.get("tags") or {}
        nm = (tg.get("name") or "") + " " + (tg.get("building") or "") + " " + (tg.get("amenity") or "")
        if "memorial union" in (tg.get("name") or "").lower() or "memorial_union" in (tg.get("name") or "").lower():
            cs = wc(w)
            if cs:
                bb = bbox(cs)
                bm = bbox_m(cs)
                print(f"  way {w['id']} name={tg.get('name')} addr={tg.get('addr:housenumber','')} {tg.get('addr:street','')} "
                      f"lat {bb[1]:.5f}..{bb[3]:.5f}  lon {bb[0]:.5f}..{bb[2]:.5f}  {tuple(round(v) for v in bm)} m  bld={tg.get('building')} amenity={tg.get('amenity')}")
    # unnamed MU detection: amenity=community_centre near Lincoln Way & Stanton
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("amenity") in ("community_centre", "university", "college") and "memorial" in (tg.get("name") or "").lower():
            cs = wc(w)
            if cs:
                bb = bbox(cs)
                print(f"  [alt] way {w['id']} name={tg.get('name')} amenity={tg.get('amenity')} lat {bb[1]:.5f}..{bb[3]:.5f} lon {bb[0]:.5f}..{bb[2]:.5f}")

    # ---------- D. key campus buildings ----------
    sec("D. Campus building centroids (N/S of Lincoln Way?)")
    for nm in ("Campanile", "Parks Library", "Beardshear", "Curtiss Hall", "MacKay",
               "Marston Water Tower", "Morrill Hall", "Farm House", "Memorial Lutheran",
               "St. Thomas Aquinas", "Legacy"):
        for w in ways:
            tg = w.get("tags") or {}
            if nm.lower() in (tg.get("name") or "").lower() and (tg.get("building") or tg.get("amenity") or tg.get("man_made")):
                cs = wc(w)
                if cs:
                    c0 = centroid(cs)
                    bb = bbox(cs)
                    side = "N of LW" if c0[1] > lw_lat else "S of LW"
                    lv = tg.get("building:levels", "")
                    print(f"  {tg.get('name'):24s} center=({c0[0]:.5f},{c0[1]:.5f}) {side}  "
                          f"bbox_m={tuple(round(v) for v in bbox_m(cs))} levels={lv} bld={tg.get('building')}")

    # ---------- E. ISU campus relation ----------
    sec("E. ISU campus relation")
    for r in rels:
        tg = r.get("tags") or {}
        if tg.get("amenity") == "university" or r.get("id") == 3501275:
            coords = []
            for m in r.get("members", []):
                if m.get("type") == "way":
                    w = next((x for x in ways if x["id"] == m["ref"]), None)
                    if w:
                        coords.extend(wc(w))
            if coords:
                bb = bbox(coords)
                print(f"  rel {r['id']} name={tg.get('name')} bbox lon {bb[0]:.5f}..{bb[2]:.5f} lat {bb[1]:.5f}..{bb[3]:.5f}")

    # ---------- F. Campustown commercial polygon ----------
    sec("F. Campustown landuse=commercial polygon")
    best = None
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("landuse") == "commercial":
            cs = wc(w)
            if not cs:
                continue
            c0 = centroid(cs)
            if -93.660 < c0[0] < -93.640 and 42.017 < c0[1] < 42.026:
                bm = bbox_m(cs)
                print(f"  way {w['id']} name={tg.get('name','(none)')} center=({c0[0]:.5f},{c0[1]:.5f}) "
                      f"bbox lat {min(c[1] for c in cs):.5f}..{max(c[1] for c in cs):.5f} size={tuple(round(v) for v in bm)} m")

    # ---------- G. Campustown avenues: full extent ----------
    sec("G. Campustown avenue extents (lat range)")
    for nm in ("Welch Avenue", "Hayward Avenue", "Sheldon Avenue", "Stanton Avenue", "State Avenue", "Ash Avenue"):
        for w in ways:
            tg = w.get("tags") or {}
            if tg.get("name") == nm and tg.get("highway"):
                cs = wc(w)
                if cs:
                    lats = [c[1] for c in cs]; lons = [c[0] for c in cs]
                    print(f"  {nm:16s} way {w['id']:9d} lat {min(lats):.5f}..{max(lats):.5f} lon {min(lons):.5f}..{max(lons):.5f} class={tg.get('highway')}")

    welch_lon = None
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("name") == "Welch Avenue" and tg.get("highway"):
            pts = [c for c in wc(w) if 42.018 < c[1] < 42.0225]
            if pts:
                welch_lon = sum(c[0] for c in pts) / len(pts)
    print(f"  Welch Ave centerline lon (100-200 block window) = {welch_lon:.5f}")

    # ---------- H. venue spot-check via addr tags ----------
    sec("H. Addressed POIs (addr:housenumber/addr:street)")
    targets = {}
    def tgt(hn, st):
        targets[(str(hn), st.lower())] = None
    for hn in ("109","116","117","121","124","126","127","132","203","204","206","207","208","217","223","303"):
        tgt(hn, "Welch Avenue")
    for hn in ("2210","2228","2300","2306","2320","2402","2504","2508","2546","2650","3605","3720","3800"):
        tgt(hn, "Lincoln Way")
    for hn in ("2401","2410","2514","2515","2519","2520","2522","2530"):
        tgt(hn, "Chamberlain Street")
    for hn in ("119","216"):
        tgt(hn, "Stanton Avenue")
    for hn in ("111","119","123","124","125","129","132","134","212","229","526","547"):
        tgt(hn, "Main Street")
    tgt("120", "Kellogg Avenue"); tgt("504", "Burnett Avenue")
    tgt("534", "South Duff Avenue"); tgt("1404", "South Duff Avenue")
    tgt("2229", "Lincoln Way")
    tgt("2616", "Northridge Parkway"); tgt("2400", "North Loop Drive")

    found = {}
    def collect(el, c0, extra_name=""):
        tg = el.get("tags") or {}
        hn = str(tg.get("addr:housenumber") or "")
        st = (tg.get("addr:street") or "").lower()
        key = (hn, st)
        if key in targets:
            found.setdefault(key, []).append((el.get("type"), el.get("id"), c0, tg.get("name") or extra_name, tg))

    for w in ways:
        cs = wc(w)
        if not cs:
            continue
        collect(w, centroid(cs))
    for nid, c0 in nodes.items():
        pass  # too many; scan tagged nodes below

    # tagged nodes (need tags): re-scan node_tags
    for el in node_tags:
        if el.get("tags"):
            tg = el["tags"]
            hn = str(tg.get("addr:housenumber") or "")
            st = (tg.get("addr:street") or "").lower()
            key = (hn, st)
            if key in targets and key not in found:
                found.setdefault(key, []).append(("node", el["id"], (el["lon"], el["lat"]), tg.get("name") or "", tg))

    main_lat = None
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("name") == "Main Street" and tg.get("highway"):
            pts = [c for c in wc(w) if -93.622 < c[0] < -93.615]
            if pts:
                main_lat = sum(c[1] for c in pts) / len(pts)
    chamb_lon = None
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("name") == "Chamberlain Street" and tg.get("highway"):
            pts = [c for c in wc(w) if 42.017 < c[1] < 42.021]
            if pts:
                chamb_lon = sum(c[0] for c in pts) / len(pts)

    for key in sorted(found.keys(), key=lambda k: (k[1], int(k[0]) if k[0].isdigit() else 0)):
        for typ, eid, c0, nm, tg in found[key]:
            note = ""
            if key[1].startswith("welch") and welch_lon:
                note = "W side" if c0[0] < welch_lon else "E side"
            if key[1].startswith("chamberlain") and welch_lon:
                note = "W of Welch" if c0[0] < welch_lon else "E of Welch"
            if key[1].startswith("lincoln") :
                note = "N side" if c0[1] > lw_lat else "S side"
            if key[1].startswith("main") and main_lat:
                note = "N side" if c0[1] > main_lat else "S side"
            print(f"  {key[1]:20s} #{key[0]:>4s} {typ}/{eid} ({c0[0]:.5f},{c0[1]:.5f}) [{note}] name={nm} "
                  + " ".join(f"{k}={tg[k]}" for k in sorted(tg) if k in ("amenity","building","shop","cuisine","building:levels","operator") ) )
    for key in sorted(targets.keys()):
        if key not in found:
            print(f"  {key[1]:20s} #{key[0]:>4s} -- NOT FOUND in extract")

    # ---------- I. Jack Trice Stadium ----------
    sec("I. Jack Trice Stadium & pitch orientation")
    for w in ways:
        tg = w.get("tags") or {}
        if (tg.get("leisure") == "stadium" or "jack trice" in (tg.get("name") or "").lower()
                or "midamerican" in (tg.get("name") or "").lower()):
            cs = wc(w)
            if not cs:
                continue
            bb = bbox(cs)
            bm = bbox_m(cs)
            c0 = centroid(cs)
            print(f"  way {w['id']} name={tg.get('name','')} {tg.get('leisure','')} sport={tg.get('sport','')} "
                  f"cap={tg.get('capacity','')} center=({c0[0]:.5f},{c0[1]:.5f}) bbox_m E-W={bm[0]:.0f} N-S={bm[1]:.0f}")
            if bm[0] and bm[1]:
                axis = "E-W long axis" if bm[0] > bm[1] else "N-S long axis"
                print(f"      -> {axis}")

    # ---------- J. Lake LaVerne area ----------
    sec("J. Lake LaVerne")
    laverne_rels = [r for r in rels if "laverne" in ((r.get("tags") or {}).get("name") or "").lower() or r.get("id") == 3329428]
    for r in laverne_rels:
        tg = r.get("tags") or {}
        print(f"  rel {r['id']} name={tg.get('name')} members={len(r.get('members', []))}")
        outer_ways = []
        for m in r.get("members", []):
            if m.get("type") == "way" and m.get("role") in ("outer", "outer_ring", ""):
                w = next((x for x in ways if x["id"] == m["ref"]), None)
                if w:
                    outer_ways.append(wc(w))
        # chain rings
        if outer_ways:
            ring = list(outer_ways[0])
            rest = outer_ways[1:]
            while rest:
                end = ring[-1]
                joined = False
                for i, seg in enumerate(rest):
                    for cand in (seg, list(reversed(seg))):
                        if cand and abs(cand[0][0] - end[0]) < 1e-9 and abs(cand[0][1] - end[1]) < 1e-9:
                            ring.extend(cand[1:]); rest.pop(i); joined = True; break
                    if joined:
                        break
                if not joined:
                    break
            area = shoelace_m2(ring)
            bm = bbox_m(ring)
            c0 = centroid(ring)
            print(f"    chained ring n={len(ring)} area={area:.0f} m2 = {area/10000:.2f} ha = {area/4046.86:.2f} ac "
                  f"bbox E-W={bm[0]:.0f} N-S={bm[1]:.0f} center=({c0[0]:.5f},{c0[1]:.5f})")

    # ---------- K. parks/gardens areas ----------
    sec("K. Park/garden areas (shoelace, single ways)")
    for nm in ("Brookside Park", "Reiman Gardens", "Central Campus", "Ada Hayden"):
        for w in ways:
            tg = w.get("tags") or {}
            if nm.lower() in (tg.get("name") or "").lower():
                cs = wc(w)
                if cs and len(cs) > 3:
                    a = shoelace_m2(cs)
                    bm = bbox_m(cs)
                    print(f"  {tg.get('name'):22s} way {w['id']} area={a/10000:.1f} ha ({a/4046.86:.1f} ac) bbox E-W={bm[0]:.0f} N-S={bm[1]:.0f}")

    # ---------- L. grain elevators / storage tanks / heights ----------
    sec("L. Grain elevators, storage tanks, tagged heights")
    for w in ways:
        tg = w.get("tags") or {}
        blob = json.dumps(tg).lower()
        if ("grain" in blob or "elevator" in blob or "silage" in blob
                or tg.get("man_made") in ("storage_tank", "silo") or "height" in tg):
            cs = wc(w)
            if cs:
                c0 = centroid(cs)
                print(f"  way {w['id']} ({c0[0]:.5f},{c0[1]:.5f}) " + " ".join(f"{k}={tg[k]}" for k in sorted(tg)))
    for el in node_tags:
        if el.get("tags"):
            tg = el["tags"]
            lon = el.get("lon") or (el.get("lon"))
            lat = el.get("lat")
            blob = json.dumps(tg).lower()
            if ("grain" in blob or "elevator" in blob or tg.get("man_made") in ("storage_tank", "silo") or "height" in tg):
                print(f"  node {el['id']} ({lon},{lat}) " + " ".join(f"{k}={tg[k]}" for k in sorted(tg)))
                print(f"  node {el['id']} ({el['lon']:.5f},{el['lat']:.5f}) " + " ".join(f"{k}={tg[k]}" for k in sorted(tg)))

    # ---------- M. airlines of interest ----------
    sec("M. Named stores/landmarks quick check")
    for nm in ("Kum & Go", "Hy-Vee", "Fareway", "Fire Station", "The Foundry", "23 Twenty",
               "Pizza Pit", "Welch Crown", "Iowa State Center", "Mucky Duck", "Hickory"):
        for w in ways:
            tg = w.get("tags") or {}
            if nm.lower() in (tg.get("name") or "").lower():
                cs = wc(w)
                if cs:
                    c0 = centroid(cs)
                    print(f"  {nm:16s} way {w['id']} ({c0[0]:.5f},{c0[1]:.5f}) name={tg.get('name')} "
                          + " ".join(f"{k}={tg[k]}" for k in sorted(tg) if k in ("amenity","building","shop","addr:housenumber","addr:street","landuse")))

    # ---------- N. University Blvd crossing ----------
    sec("N. University Blvd at Lincoln Way")
    for w in ways:
        tg = w.get("tags") or {}
        if tg.get("name") == "University Boulevard" and tg.get("highway"):
            pts = [c for c in wc(w) if abs(c[1] - lw_lat) < 0.0009]
            if pts:
                print(f"  crossing lon ~{sum(c[0] for c in pts)/len(pts):.5f} (n={len(pts)})")

if __name__ == "__main__":
    main()
