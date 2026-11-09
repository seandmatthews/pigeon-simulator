"""Analyze the merged Ames OSM dataset for the Pigeon Simulator city survey.

Usage:
  python -I analyze.py <merged_json> <mode> [arg]

Modes:
  streets <csv_out>   write full street-inventory CSV, print top table + spines
  names <substr>      list distinct named-road names containing substr
  water               water features: names, types, lengths, areas, bboxes
  rail                railway inventory: yard bbox, lines, stations
  poi                 landmarks/parks/university/landuse/place nodes
  spine <name>        intersections along a named spine street (block sizes)
  dist                distances between key points
  core                suggested game-core bbox from component features
  summary             run streets+water+rail+poi+dist+core in sequence
"""
import json
import math
import sys
import csv
import re

LAT_M = 111074.0            # meters per degree of latitude at ~42.04 N
ORIGIN = (-93.63, 42.04)    # planar origin for x/y math

def lon_scale(lat=ORIGIN[1]):
    return 111320.0 * math.cos(math.radians(lat))

LON_M = lon_scale()

def to_xy(lon, lat):
    return ((lon - ORIGIN[0]) * LON_M, (lat - ORIGIN[1]) * LAT_M)

def hav(a, b):
    lon1, lat1 = a
    lon2, lat2 = b
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6371000.0 * math.asin(math.sqrt(h))

ROAD_CLASSES = {"motorway", "trunk", "primary", "secondary", "tertiary",
                "unclassified", "residential"}

WATERWAY_KINDS = {"river", "stream", "canal", "drain", "ditch", "riverbank",
                  "canal", "artificial", "dam"}

NAME_HITS = re.compile(
    r"campanile|jack trice|hilton|reiman|laverne|ada hayden|inis grove|"
    r"brookside|moore|campustown|municipal|city hall|amtrak|depot", re.I)


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


class Data:
    def __init__(self, d):
        self.nodes = {int(k): tuple(v) for k, v in d["nodes"].items()}
        self.ways = {int(k): v for k, v in d["ways"].items()}
        self.rels = {int(k): v for k, v in d["relations"].items()}
        self.bbox = d["bbox_WSEN"]  # W,S,E,N

    def way_pts(self, wid):
        out = []
        for nid in self.ways[wid]["nodes"]:
            p = self.nodes.get(nid)
            if p is not None:
                out.append(p)
        return out

    def rel_pts(self, rid):
        out = []
        for m in self.rels[rid].get("members", []):
            if m.get("type") == "way" and m.get("ref") in self.ways:
                out.extend(self.way_pts(m["ref"]))
        return out

    def elem_pts(self, e_type, e_id):
        if e_type == "node":
            p = self.nodes.get(e_id)
            return [p] if p else []
        if e_type == "way":
            return self.way_pts(e_id)
        return self.rel_pts(e_id)


def seg_stats(pts):
    """Return (length_m, net_dx_m, net_dy_m, closed) for a polyline."""
    total = 0.0
    dx = dy = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        total += hav(a, b)
        xa, ya = to_xy(*a)
        xb, yb = to_xy(*b)
        dx += xb - xa
        dy += yb - ya
    closed = len(pts) > 3 and hav(pts[0], pts[-1]) < 5.0
    return total, dx, dy, closed


def orient_of(dx, dy):
    ang = abs(math.degrees(math.atan2(dy, dx)))  # 0 = due E, 90 = due N
    if ang <= 22.5 or ang >= 157.5:
        return "E-W"
    if 67.5 <= ang <= 112.5:
        return "N-S"
    return "diag"


def bbox_of(pts):
    lons = [p[0] for p in pts]
    lats = [p[1] for p in pts]
    return min(lons), min(lats), max(lons), max(lats)


def bbox_dims_m(bb):
    w, s, e, n = bb
    latc = (s + n) / 2
    return (e - w) * lon_scale(latc), (n - s) * LAT_M


def shoelace_m2(pts):
    if len(pts) < 3:
        return 0.0
    xy = [to_xy(*p) for p in pts]
    s = 0.0
    for i in range(len(xy) - 1):
        x1, y1 = xy[i]
        x2, y2 = xy[i + 1]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0


def centroid(pts):
    bb = bbox_of(pts)
    return ((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2)


def fmt_bb(pts):
    bb = bbox_of(pts)
    w, h = bbox_dims_m(bb)
    c = centroid(pts)
    return f"bbox {w:.0f} x {h:.0f} m, center ({c[0]:.5f}, {c[1]:.5f})"


def seg_int(a, b, c, d):
    x1, y1 = to_xy(*a); x2, y2 = to_xy(*b)
    x3, y3 = to_xy(*c); x4, y4 = to_xy(*d)
    rx, ry = x2 - x1, y2 - y1
    sx, sy = x4 - x3, y4 - y3
    den = rx * sy - ry * sx
    if abs(den) < 1e-9:
        return None
    t = ((x3 - x1) * sy - (y3 - y1) * sx) / den
    u = ((x3 - x1) * ry - (y3 - y1) * rx) / den
    if -1e-6 <= t <= 1 + 1e-6 and -1e-6 <= u <= 1 + 1e-6:
        return (x1 + t * rx, y1 + t * ry)
    return None


def street_groups(data):
    groups = {}
    unnamed = {}
    for wid, w in data.ways.items():
        tags = w.get("tags", {})
        hw = tags.get("highway")
        if hw not in ROAD_CLASSES:
            continue
        name = tags.get("name")
        if not name:
            unnamed[hw] = unnamed.get(hw, 0) + 1
            continue
        pts = data.way_pts(wid)
        if len(pts) < 2:
            continue
        ln, dx, dy, _ = seg_stats(pts)
        g = groups.setdefault(name, {"length": 0.0, "ways": 0, "classes": {},
                                     "ew": 0.0, "ns": 0.0, "pts": []})
        g["length"] += ln
        g["ways"] += 1
        g["classes"][tags.get("highway")] = g["classes"].get(tags.get("highway"), 0.0) + ln
        o = orient_of(dx, dy)
        if o == "E-W":
            g["ew"] += ln
        elif o == "N-S":
            g["ns"] += ln
        else:
            g["ew"] += ln / 2
            g["ns"] += ln / 2
        g["pts"].extend(pts)
    return groups, unnamed


def mode_streets(data, csv_out):
    groups, unnamed = street_groups(data)
    rows = []
    for name, g in groups.items():
        cls = ",".join(c for c, _ in sorted(g["classes"].items(), key=lambda kv: -kv[1]))
        ang = abs(math.degrees(math.atan2(g["ns"], g["ew"])))
        if ang <= 22.5 or ang >= 157.5:
            o = "E-W"
        elif 67.5 <= ang <= 112.5:
            o = "N-S"
        else:
            o = "diag"
        bb = bbox_of(g["pts"])
        w_m, h_m = bbox_dims_m(bb)
        rows.append({
            "name": name, "orientation": o, "classes": cls,
            "length_m": round(g["length"]), "ways": g["ways"],
            "bbox_w_m": round(w_m), "bbox_h_m": round(h_m),
            "center_lon": round((bb[0] + bb[2]) / 2, 5),
            "center_lat": round((bb[1] + bb[3]) / 2, 5),
        })
    rows.sort(key=lambda r: -r["length_m"])
    if csv_out:
        with open(csv_out, "w", newline="", encoding="utf-8") as fh:
            wr = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            wr.writeheader()
            wr.writerows(rows)
        print(f"wrote {csv_out} ({len(rows)} named streets)")
    print(f"\nnamed streets: {len(rows)}; total named length {sum(r['length_m'] for r in rows)/1000:.1f} km")
    print(f"unnamed road ways by class: {unnamed}")
    print("\ntop 45 by length:")
    print(f"{'name':38s} {'orient':5s} {'class':22s} {'len m':>7s} {'ways':>4s}")
    for r in rows[:45]:
        print(f"{r['name'][:38]:38s} {r['orientation']:5s} {r['classes'][:22]:22s} {r['length_m']:7d} {r['ways']:4d}")
    spines = ["Lincoln Way", "East Lincoln Way", "Main Street", "5th Street",
              "6th Street", "South Duff Avenue", "Duff Avenue", "Grand Avenue",
              "South Grand Avenue", "University Boulevard", "Mortensen Road",
              "South 16th Street", "Southeast 16th Street", "Stange Road",
              "Welch Avenue", "Burnett Avenue", "Hayward Avenue", "Sheldon Avenue",
              "State Avenue", "Douglas Avenue", "Clark Avenue", "Kellogg Avenue",
              "Campus Avenue", "Beach Avenue", "South Dakota Avenue",
              "Carroll Avenue", "Onondaga Street", "Brookside Avenue",
              "Lincoln Highway", "Ontario Street", "24th Street", "20th Street"]
    print("\nspine candidates (all classes):")
    for s in spines:
        r = next((r for r in rows if r["name"].lower() == s.lower()), None)
        if r:
            print(f"  {r['name']:24s} {r['orientation']:5s} {r['classes'][:26]:26s} "
                  f"{r['length_m']:6d} m  {r['ways']:3d} ways  bbox {r['bbox_w_m']}x{r['bbox_h_m']} m  "
                  f"center ({r['center_lon']}, {r['center_lat']})")


def mode_names(data, sub):
    groups, _ = street_groups(data)
    hits = [n for n in groups if sub.lower() in n.lower()]
    for n in sorted(hits):
        g = groups[n]
        print(f"  {n:36s} len {g['length']:6.0f} m  ways {g['ways']:3d}  "
              f"{','.join(g['classes'])[:40]:40s} {orient_of(g['ew'], g['ns'])}")


def collect_water(data):
    out = []
    for wid, w in data.ways.items():
        tags = w.get("tags", {})
        if "natural" in tags and tags["natural"] == "water" or "waterway" in tags:
            pts = data.way_pts(wid)
            if len(pts) < 2:
                continue
            out.append(("way", wid, tags, pts))
    for rid, r in data.rels.items():
        tags = r.get("tags", {})
        if tags.get("natural") == "water" or "waterway" in tags:
            pts = data.rel_pts(rid)
            if pts:
                out.append(("relation", rid, tags, pts))
    return out


def mode_water(data):
    feats = collect_water(data)
    from collections import Counter
    kinds = Counter()
    names = {}
    for typ, eid, tags, pts in feats:
        kind = tags.get("waterway") or tags.get("natural") or "?"
        if typ == "relation":
            kind = "rel:" + kind
        kinds[kind] += 1
        name = tags.get("name") or tags.get("waterway") or "(unnamed water)"
        ln, dx, dy, closed = seg_stats(pts)
        e = names.setdefault(name, {"kind": set(), "len": 0.0, "closed": None, "pts": []})
        e["kind"].add(kind)
        e["pts"].extend(pts)
        e["len"] += ln
        if closed and e["closed"] is None:
            e["closed"] = True
    print("water kinds:", dict(kinds))
    print(f"\nnamed water features ({len([n for n in names if n != '(unnamed water)'])}):")
    for name, e in sorted(names.items(), key=lambda kv: -kv[1]["len"]):
        if name == "(unnamed water)":
            continue
        bb = bbox_of(e["pts"])
        w_m, h_m = bbox_dims_m(bb)
        area = shoelace_m2(e["pts"]) if len(e["pts"]) > 3 else 0
        extra = f"area ~{area/10000:.1f} ha" if area > 1000 else ""
        print(f"  {name[:34]:34s} {'/'.join(sorted(e['kind'])):22s} len {e['len']:7.0f} m  "
              f"bbox {w_m:6.0f} x {h_m:5.0f} m  {extra}")


def collect_rail(data):
    lines, yards, stations = [], [], []
    for wid, w in data.ways.items():
        tags = w.get("tags", {})
        if "railway" in tags:
            pts = data.way_pts(wid)
            if len(pts) < 2:
                continue
            ln, _, _, _ = seg_stats(pts)
            rec = (wid, tags, pts, ln)
            if tags["railway"] == "yard":
                yards.append(rec)
            else:
                lines.append(rec)
    return lines, yards


def mode_rail(data):
    from collections import Counter
    lines, yards = collect_rail(data)
    cnt = Counter()
    for wid, tags, pts, ln in lines:
        cnt[tags.get("railway")] += ln
    for wid, tags, pts, ln in yards:
        cnt["yard"] += ln
    print("track length by railway tag (m):", {k: round(v) for k, v in cnt.most_common()})
    yard_pts = []
    for wid, tags, pts, ln in yards:
        yard_pts.extend(pts)
    if yard_pts:
        bb = bbox_of(yard_pts)
        w_m, h_m = bbox_dims_m(bb)
        c = centroid(yard_pts)
        print(f"YARD bbox: {w_m:.0f} m E-W x {h_m:.0f} m N-S, center ({c[0]:.5f}, {c[1]:.5f}), "
              f"track length {sum(r[3] for r in yards):.0f} m in {len(yards)} ways")
    print("\nrail lines (railway=rail etc.), grouped by name/operator/usage:")
    combo = {}
    for wid, tags, pts, ln in lines:
        key = (tags.get("railway"), tags.get("name") or "(unnamed)", tags.get("usage", "-"),
               tags.get("operator", "-"), tags.get("passenger", "-"))
        e = combo.setdefault(key, [0.0, 0])
        e[0] += ln
        e[1] += 1
    for key, (ln, n) in sorted(combo.items(), key=lambda kv: -kv[1][0]):
        print(f"  {key[1][:28]:28s} {key[0]:12s} usage={key[2]:12s} op={key[3][:24]:24s} "
              f"pass={key[4]:8s} {ln:8.0f} m  {n:3d} ways")


def collect_poi(data):
    uni, parks, sports, landuse, named, places = [], [], [], [], [], []
    for wid, w in data.ways.items():
        tags = w.get("tags", {})
        pts = data.way_pts(wid)
        if len(pts) < 2:
            continue
        route(data, tags, pts, uni, parks, sports, landuse, named, places, "way", wid)
    for rid, r in data.rels.items():
        tags = r.get("tags", {})
        pts = data.rel_pts(rid)
        if len(pts) < 2:
            continue
        route(data, tags, pts, uni, parks, sports, landuse, named, places, "relation", rid)
    # nodes: our store dropped node tags, so scan tiles for named nodes of interest
    return uni, parks, sports, landuse, named, places


def route(data, tags, pts, uni, parks, sports, landuse, named, places, typ, eid):
    nm = tags.get("name", "")
    if tags.get("amenity") in ("university", "college"):
        uni.append((typ, eid, tags, pts))
    if tags.get("leisure") == "park":
        parks.append((typ, eid, tags, pts))
    if tags.get("leisure") in ("stadium", "sports_centre", "track", "pitch"):
        sports.append((typ, eid, tags, pts))
    if tags.get("landuse") in ("retail", "commercial"):
        landuse.append((typ, eid, tags, pts))
    if NAME_HITS.search(nm):
        named.append((typ, eid, tags, pts))


def scan_named_nodes(data_dir, pattern):
    """Node tags are not kept in the merged dataset; rescan raw tiles.
    Pattern is matched against 'key value' pairs joined by spaces."""
    import os, glob
    rx = re.compile(pattern, re.I)
    hits = []
    for path in sorted(glob.glob(os.path.join(data_dir, "tile_*.json"))):
        with open(path, encoding="utf-8") as fh:
            d = json.load(fh)
        for e in d.get("elements", []):
            if e["type"] == "node" and e.get("tags"):
                joined = " ".join(f"{k} {v}" for k, v in e["tags"].items())
                if rx.search(joined):
                    hits.append(e)
    return hits


def mode_poi(data, data_dir):
    uni, parks, sports, landuse, named, places = collect_poi(data)

    def show(title, items, with_area=True):
        print(f"\n== {title} ({len(items)})")
        for typ, eid, tags, pts in items:
            nm = tags.get("name", "(unnamed)")
            w_m, h_m = bbox_dims_m(bbox_of(pts))
            c = centroid(pts)
            extra = ""
            if with_area:
                a = shoelace_m2(pts)
                if a > 500:
                    extra = f" area ~{a/10000:.1f} ha"
            keytags = {k: v for k, v in tags.items() if k in (
                "leisure", "amenity", "landuse", "operator", "capacity",
                "building", "historic", "tourism", "sport", "place")}
            print(f"  {nm[:32]:32s} {typ:8s} {w_m:6.0f}x{h_m:5.0f} m  ({c[0]:.5f},{c[1]:.5f}){extra}  {keytags}")

    show("UNIVERSITY/COLLEGE polygons", uni)
    print("\n== NAMED NODES of interest (rescanned from tiles)")
    for e in scan_named_nodes(data_dir, r"campanile|jack trice|hilton|reiman|laverne"):
        t = e["tags"]
        print(f"  node {e['id']} ({e['lon']:.5f},{e['lat']:.5f}) name={t.get('name')!r} tags={t}")
    show("NAMED WAYS/RELS of interest", named)
    show("PARKS", parks)
    show("SPORTS (named stadium/track/pitch/sports_centre)", [s for s in sports if s[2].get("name")])
    show("RETAIL/COMMERCIAL landuse", landuse)
    print("\n== PLACE nodes")
    for e in scan_named_nodes(data_dir, r"\bplace\s"):
        t = e["tags"]
        if "place" in t:
            print(f"  {t.get('place'):14s} {t.get('name','?')[:30]:30s} ({e['lon']:.5f},{e['lat']:.5f})")


def spine_segs(data, name, groups):
    segs = []
    for wid, w in data.ways.items():
        tags = w.get("tags", {})
        if tags.get("name") != name or tags.get("highway") not in ROAD_CLASSES:
            continue
        pts = data.way_pts(wid)
        for i in range(len(pts) - 1):
            segs.append((pts[i], pts[i + 1]))
    return segs


def mode_spine(data, spine_name, window=None):
    groups, _ = street_groups(data)
    segs = spine_segs(data, spine_name, groups)
    if window:
        wlon0, wlat0, wlon1, wlat1 = window
        segs = [s for s in segs
                if window_hit(s, wlon0, wlat0, wlon1, wlat1)]
    if not segs:
        print(f"no segments for {spine_name}")
        return
    all_pts = [p for s in segs for p in s]
    bb = bbox_of(all_pts)
    w_m, h_m = bbox_dims_m(bb)
    print(f"spine {spine_name}: {len(segs)} segs, corridor bbox {w_m:.0f} x {h_m:.0f} m, "
          f"lon {bb[0]:.4f}..{bb[2]:.4f}, lat {bb[1]:.4f}..{bb[3]:.4f}")
    # collect intersections with every other named street
    groups_bbox = {}
    for nm, g in groups.items():
        groups_bbox[nm] = bbox_of(g["pts"])
    found = {}
    for nm, g in groups.items():
        if nm == spine_name:
            continue
        gb = groups_bbox[nm]
        if gb[0] > bb[2] + 0.0005 or gb[2] < bb[0] - 0.0005 or \
           gb[1] > bb[3] + 0.0005 or gb[3] < bb[1] - 0.0005:
            continue
        for wid, w in data.ways.items():
            t = w.get("tags", {})
            if t.get("name") != nm or t.get("highway") not in ROAD_CLASSES:
                continue
            pts = data.way_pts(wid)
            for i in range(len(pts) - 1):
                for sa, sb in segs:
                    p = seg_int(sa, sb, pts[i], pts[i + 1])
                    if p:
                        found.setdefault(nm, []).append(p)
    # dedupe per street
    cross = []
    for nm, pts in found.items():
        kept = []
        for p in sorted(pts, key=lambda q: (q[0], q[1])):
            if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > 20 ** 2 for q in kept):
                kept.append(p)
        for p in kept:
            cross.append((nm, p))
    # order along spine: project onto spine net direction
    xs = [(to_xy(*p)) for _, p in cross]
    net_x = sum(p[0] for p in xs) - min(p[0] for p in xs)
    dx_total = 0.0
    dy_total = 0.0
    for sa, sb in segs:
        xa, ya = to_xy(*sa); xb, yb = to_xy(*sb)
        dx_total += xb - xa
        dy_total += yb - ya
    ux, uy = dx_total, dy_total
    n = math.hypot(ux, uy) or 1.0
    ux, uy = ux / n, uy / n
    cross.sort(key=lambda cr: (cr[1][0] * ux + cr[1][1] * uy))
    prev = None
    prev_nm = None
    print(f"crossings along {spine_name} ({len(cross)}):")
    for nm, p in cross:
        d = 0.0 if prev is None else math.hypot(p[0] - prev[0], p[1] - prev[1])
        print(f"  {nm[:30]:30s} at ({p[0]:7.0f},{p[1]:7.0f}) m  gap {d:6.0f} m from prev")
        prev = p
        prev_nm = nm


def window_hit(seg, lon0, lat0, lon1, lat1):
    return any(lon0 <= p[0] <= lon1 and lat0 <= p[1] <= lat1 for p in seg)


def key_points(data, data_dir):
    pts = {}
    # campanile node
    for e in scan_named_nodes(data_dir, r"campanile"):
        pts["campanile"] = (e["lon"], e["lat"])
    groups, _ = street_groups(data)
    # Main Street x Duff Avenue intersection (downtown center)
    p = first_cross(data, groups, "Main Street", "Duff Avenue")
    if p:
        pts["main_duff"] = p
    p = first_cross(data, groups, "Lincoln Way", "Welch Avenue")
    if p:
        pts["lincoln_welch"] = p
    # Jack Trice / stadium
    uni, parks, sports, landuse, named, places = collect_poi(data)
    for typ, eid, tags, wpts in named + sports:
        nm = tags.get("name", "")
        if "jack trice" in nm.lower():
            pts["jack_trice"] = centroid(wpts)
        if "la Verne" in nm or "LaVerne" in nm or "la Verne".lower() in nm.lower():
            pts["lake_laverne_c"] = centroid(wpts)
    return pts


def first_cross(data, groups, a_name, b_name):
    sa = spine_segs(data, a_name, groups)
    sb = spine_segs(data, b_name, groups)
    for a1, a2 in sa:
        for b1, b2 in sb:
            p = seg_int(a1, a2, b1, b2)
            if p:
                # seg_int returns planar meters; convert back to lon/lat
                return (ORIGIN[0] + p[0] / LON_M, ORIGIN[1] + p[1] / LAT_M)
    return None


def mode_dist(data, data_dir):
    pts = key_points(data, data_dir)
    names = sorted(pts)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            pa = to_xy(*pts[a]); pb = to_xy(*pts[b])
            d = math.hypot(pa[0] - pb[0], pa[1] - pb[1])
            print(f"  {a:16s} -> {b:16s} {d:7.0f} m   "
                  f"({pts[a][0]:.5f},{pts[a][1]:.5f}) -> ({pts[b][0]:.5f},{pts[b][1]:.5f})")


def mode_core(data, data_dir):
    uni, parks, sports, landuse, named, places = collect_poi(data)
    boxes = {}

    def add(name, pts):
        if pts:
            boxes[name] = bbox_of(pts)

    for typ, eid, tags, pts in uni:
        add("campus:" + tags.get("name", str(eid))[:20], pts)
    for typ, eid, tags, pts in named + sports:
        nm = tags.get("name", "")
        if "jack trice" in nm.lower():
            add("stadium", pts)
    # Lake LaVerne, downtown, campustown
    groups, _ = street_groups(data)
    for nm in ("Lincoln Way", "East Lincoln Way"):
        if nm in groups:
            add("street:" + nm, groups[nm]["pts"])
    # Lincoln Way corridor restricted to the game-relevant stretch (State Ave..Duff)
    if "Lincoln Way" in groups:
        lw = [p for p in groups["Lincoln Way"]["pts"] if -93.6595 <= p[0] <= -93.6100]
        add("lincoln_way_core_stretch", lw)
    for typ, eid, tags, pts in collect_water(data):
        nm = tags.get("name", "")
        if "laverne" in nm.replace("La Verne", "LaVerne").lower() or "la verne" in nm.lower():
            add("lake_laverne", pts)
    # downtown = Main St ways with lon in downtown range (from bbox of Main+Duff..Grand)
    main = groups.get("Main Street")
    if main:
        add("street:Main Street", main["pts"])
    if "5th Street" in groups:
        add("street:5th Street", groups["5th Street"]["pts"])
    for typ, eid, tags, pts in landuse:
        nm = tags.get("name", "")
        c = centroid(pts)
        if "campustown" in nm.lower() or "downtown" in nm.lower() or ("lincoln" in nm.lower()):
            add("landuse:" + nm[:24], pts)
    for k, bb in sorted(boxes.items()):
        w_m, h_m = bbox_dims_m(bb)
        print(f"  {k:36s} bbox lon {bb[0]:.4f}..{bb[2]:.4f} lat {bb[1]:.4f}..{bb[3]:.4f}  "
              f"{w_m:6.0f} x {h_m:5.0f} m")


def main():
    data = Data(load(sys.argv[1]))
    mode = sys.argv[2]
    if mode == "streets":
        mode_streets(data, sys.argv[3] if len(sys.argv) > 3 else None)
    elif mode == "names":
        mode_names(data, sys.argv[3])
    elif mode == "water":
        mode_water(data)
    elif mode == "rail":
        mode_rail(data)
    elif mode == "poi":
        mode_poi(data, sys.argv[3] if len(sys.argv) > 3 else ".")
    elif mode == "spine":
        mode_spine(data, sys.argv[3])
    elif mode == "dist":
        mode_dist(data, sys.argv[3] if len(sys.argv) > 3 else ".")
    elif mode == "core":
        mode_core(data, sys.argv[3] if len(sys.argv) > 3 else ".")
    else:
        print("unknown mode", mode)


if __name__ == "__main__":
    main()
