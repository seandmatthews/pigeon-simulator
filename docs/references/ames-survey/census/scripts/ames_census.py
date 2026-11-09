#!/usr/bin/env python3
"""Build-census lane for the Ames survey.

Run with:  python -I ames_census.py <mode> [arg]

Modes (each prints a section of the census; all numbers traceable to a mode):
  buildings   1. building census for the game-core bbox (+ top 25 + authored split)
  districts   2. downtown + Campustown per-block analysis, setbacks
  venues      2b. VENUES.md Tier 1-2 -> OSM anchor cross-check (scans raw tiles)
  campus      3. campus inventory, campanile, stadium footprints, parking census
  streets     4. road km by class in core, intersections by degree, signals
  green       5. parks, trees, water extents in core
  rail        5b. rail corridor in core + every road-rail crossing
  cache       (re)build the tagged-node cache from the 42 raw tiles

Inputs (READ ONLY):
  ../../osm/raw/ames_merged.json           merged OSM extract (nodes w/o tags)
  ../../osm/raw/tile_r*.json               42 raw tiles (for tagged NODES)
  ./tagged_nodes.json                      cache written by `cache` mode
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MERGED = os.path.join(HERE, "..", "..", "osm", "raw", "ames_merged.json")
RAWTILES = os.path.join(HERE, "..", "..", "osm", "raw")
NODECACHE = os.path.join(HERE, "tagged_nodes.json")

# Game-core bbox (from osm/SUMMARY.md section 3), W, S, E, N
CORE = (-93.6590, 42.0120, -93.6100, 42.0355)

M_PER_DEG_LAT = 111074.0          # sibling SUMMARY.md standard at 42.02 N


def m_per_deg_lon(lat):
    return 111320.0 * math.cos(math.radians(lat))


def to_xy(p, lat0=42.0237):
    """lon/lat -> local planar meters (origin at core center)."""
    return ((p[0] - -93.6345) * m_per_deg_lon(lat0),
            (p[1] - 42.02375) * M_PER_DEG_LAT)


def load_data():
    with open(MERGED, encoding="utf-8") as f:
        d = json.load(f)
    nodes = {int(k): tuple(v) for k, v in d["nodes"].items()}
    ways = {int(k): v for k, v in d["ways"].items()}
    rels = {int(k): v for k, v in d["relations"].items()}
    return nodes, ways, rels


def load_cached_nodes():
    """tagged nodes from the raw tiles: {id: (lon, lat, tags)}"""
    with open(NODECACHE, encoding="utf-8") as f:
        raw = json.load(f)
    return {int(k): (v[0], v[1], v[2]) for k, v in raw.items()}


def build_node_cache():
    """One pass over the 42 raw tiles collecting every tagged node."""
    import glob
    out = {}
    files = sorted(glob.glob(os.path.join(RAWTILES, "tile_r*.json")))
    for path in files:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        for e in d.get("elements", []):
            if e.get("type") == "node" and e.get("tags"):
                out[str(e["id"])] = [e["lon"], e["lat"], e["tags"]]
    with open(NODECACHE, "w", encoding="utf-8") as f:
        json.dump(out, f)
    print(f"cached {len(out)} tagged nodes from {len(files)} tiles -> {NODECACHE}")


# ---------------- shared geometry helpers ----------------

def way_pts(w, nodes):
    return [nodes[n] for n in w.get("nodes", []) if n in nodes]


def bbox_center(pts):
    lons = [p[0] for p in pts]
    lats = [p[1] for p in pts]
    return ((min(lons) + max(lons)) / 2, (min(lats) + max(lats)) / 2)


def in_bbox(c, bbox=CORE, margin=0.0):
    return (bbox[0] - margin <= c[0] <= bbox[2] + margin
            and bbox[1] - margin <= c[1] <= bbox[3] + margin)


def shoelace_m2(pts):
    if len(pts) < 3:
        return 0.0
    xy = [to_xy(p) for p in pts]
    s = 0.0
    n = len(xy)
    for i in range(n):
        x1, y1 = xy[i]
        x2, y2 = xy[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0


def is_closed(pts):
    return len(pts) >= 4 and pts[0] == pts[-1]


def bbox_dims_m(pts):
    lons = [p[0] for p in pts]
    lats = [p[1] for p in pts]
    latc = (min(lats) + max(lats)) / 2
    return ((max(lons) - min(lons)) * m_per_deg_lon(latc),
            (max(lats) - min(lats)) * M_PER_DEG_LAT)


def ring_of(w, nodes):
    """w: a way dict, or a pre-collected list of points."""
    pts = w if isinstance(w, list) else way_pts(w, nodes)
    if is_closed(pts):
        return pts[:-1]
    return pts


def point_in_ring(c, ring):
    """Ray casting in planar meters."""
    x, y = to_xy(c)
    pts = [to_xy(p) for p in ring]
    inside = False
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xint = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < xint:
                inside = not inside
    return inside


def seg_len_m(a, b):
    ax, ay = to_xy(a)
    bx, by = to_xy(b)
    return math.hypot(bx - ax, by - ay)


def polyline_length_m(pts):
    return sum(seg_len_m(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def point_seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 < 1e-12:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def dist_to_polyline_m(pt, pts):
    px, py = to_xy(pt)
    best = float("inf")
    for i in range(len(pts) - 1):
        ax, ay = to_xy(pts[i])
        bx, by = to_xy(pts[i + 1])
        best = min(best, point_seg_dist(px, py, ax, ay, bx, by))
    return best


def segs_in_bbox(pts, bbox=CORE):
    """Split a polyline into the sub-segments whose midpoint lies in bbox."""
    out = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        mx = (a[0] + b[0]) / 2
        my = (a[1] + b[1]) / 2
        if bbox[0] <= mx <= bbox[2] and bbox[1] <= my <= bbox[3]:
            out.append((a, b))
    return out


def seg_intersection(a, b, c, d):
    """Planar segment intersection; returns (x, y) or None."""
    ax, ay = to_xy(a)
    bx, by = to_xy(b)
    cx, cy = to_xy(c)
    dx, dy = to_xy(d)
    rx, ry = bx - ax, by - ay
    sx, sy = dx - cx, dy - cy
    den = rx * sy - ry * sx
    if abs(den) < 1e-9:
        return None
    t = ((cx - ax) * sy - (cy - ay) * sx) / den
    u = ((cx - ax) * ry - (cy - ay) * rx) / den
    if -1e-6 <= t <= 1 + 1e-6 and -1e-6 <= u <= 1 + 1e-6:
        return (ax + t * rx, ay + t * ry)
    return None


def xy_to_lonlat(x, y):
    return (-93.6345 + x / m_per_deg_lon(42.02375),
            42.02375 + y / M_PER_DEG_LAT)


def fmt_c(lonlat):
    return f"({lonlat[0]:.5f}, {lonlat[1]:.5f})"


# ---------------- mode: buildings ----------------

def collect_buildings(nodes, ways, rels):
    """All building ways/relations with centroid inside the core bbox."""
    bw = []
    for wid, w in ways.items():
        t = w.get("tags") or {}
        b = t.get("building")
        if not b or b == "no":
            continue
        pts = way_pts(w, nodes)
        if len(pts) < 2:
            continue
        c = bbox_center(pts)
        bw.append({"id": wid, "tags": t, "pts": pts, "c": c, "kind": "way"})
    br = []
    for rid, r in rels.items():
        t = r.get("tags") or {}
        b = t.get("building")
        if not b or b == "no":
            continue
        pts = []
        for m in r.get("members", []):
            if m.get("type") == "way" and m.get("ref") in ways:
                pts.extend(way_pts(ways[m["ref"]], nodes))
        if not pts:
            continue
        c = bbox_center(pts)
        br.append({"id": rid, "tags": t, "pts": pts, "c": c, "kind": "relation"})
    return bw, br


def mode_buildings(nodes, ways, rels):
    bw, br = collect_buildings(nodes, ways, rels)
    incore = [b for b in bw if in_bbox(b["c"])]
    incore_rel = [b for b in br if in_bbox(b["c"])]
    anynode = [b for b in bw if any(in_bbox(p) for p in b["pts"])]
    print(f"== 1. BUILDING CENSUS — game-core bbox "
          f"(W{CORE[0]} S{CORE[1]} E{CORE[2]} N{CORE[3]})")
    print(f"building ways, centroid-in-core: {len(incore)}")
    print(f"building relations, centroid-in-core: {len(incore_rel)}")
    print(f"building ways with >=1 node in core: {len(anynode)}  "
          f"(reconciliation aid vs sibling '3733 buildings')")
    blds = incore + incore_rel

    named = [b for b in blds if (b["tags"].get("name") or "").strip()]
    print(f"named (name tag): {len(named)}")
    noname = [b for b in blds if not (b["tags"].get("name") or "").strip()]

    # levels / height tags
    def flt(v):
        try:
            return float(str(v).strip())
        except (TypeError, ValueError):
            return None

    levels = {}
    heights = []
    no_level = 0
    for b in blds:
        lv = flt(b["tags"].get("building:levels"))
        h = flt(b["tags"].get("height"))
        if h is not None:
            heights.append(h)
        if lv is None:
            no_level += 1
        else:
            levels[round(lv * 2) / 2] = levels.get(round(lv * 2) / 2, 0) + 1
    print(f"with building:levels tag: {len(blds) - no_level}  "
          f"({100.0 * (len(blds) - no_level) / len(blds):.1f} %)")
    print(f"with height tag (any): {len(heights)}")
    if heights:
        hs = sorted(heights)
        print(f"  height m: min {hs[0]:.1f} p50 {hs[len(hs)//2]:.1f} p90 {hs[int(len(hs)*0.9)]:.1f} max {hs[-1]:.1f}")
    print("levels histogram (building:levels, 0.5 buckets):")
    for k in sorted(levels):
        bar = "#" * min(60, levels[k])
        print(f"  {k:5.1f}: {levels[k]:4d} {bar}")
    lv_big = [(b["tags"].get("name") or "(unnamed)", b["tags"].get("building:levels"),
               b["tags"].get("height"), b["id"]) for b in blds
              if (flt(b["tags"].get("building:levels")) or 0) >= 6]
    lv_big.sort(key=lambda x: -float(flt(x[1]) or 0))
    print(f"buildings with levels >= 6: {len(lv_big)}")
    for nm, lv, h, wid in lv_big[:20]:
        print(f"   {nm[:40]:40s} levels={lv} height={h} way {wid}")

    # footprint areas
    areas = []
    open_ways = 0
    for b in blds:
        if b["kind"] == "way" and not is_closed(b["pts"]):
            open_ways += 1
            continue
        a = shoelace_m2(ring_of(b["pts"], nodes) if b["kind"] == "way"
                        else b["pts"])
        areas.append((a, b))
    areas.sort(key=lambda x: -x[0])
    tot = sum(a for a, _ in areas)
    print(f"closed-polygon footprints: {len(areas)}; open/incomplete ways: {open_ways}")
    print(f"total footprint area: {tot/1e6:.3f} km^2 = {tot/10000:.1f} ha "
          f"({100.0*tot/(4053*2610):.1f} % of the 10.58 km2 core)")
    asc = sorted(a for a, _ in areas)
    print(f"footprint m2: p10 {asc[len(asc)//10]:.0f} p50 {asc[len(asc)//2]:.0f} "
          f"p90 {asc[9*len(asc)//10]:.0f} max {asc[-1]:.0f}")

    print("\ntop 25 largest footprints in core:")
    for a, b in areas[:25]:
        t = b["tags"]
        nm = t.get("name") or "(unnamed)"
        c = b["c"]
        print(f"  {a/10000:7.3f} ha  {nm[:38]:38s} {fmt_c(c)}  bld={t.get('building','')} "
              f"lv={t.get('building:levels','')} {b['kind']} {b['id']}")

    # authored vs procedural split (section 6 fodder, computed here too)
    poi_tags = ("amenity", "shop", "leisure", "tourism", "historic", "office",
                "craft", "healthcare", "man_made")
    authored_named = named
    semi = [b for b in noname if any(b["tags"].get(k) for k in poi_tags)]
    procedural = [b for b in noname if not any(b["tags"].get(k) for k in poi_tags)]
    print(f"\n== 6. AUTHOR VS PROCEDURAL (computed here; see section 6 of the report)")
    print(f"named buildings: {len(authored_named)}")
    print(f"unnamed but use-tagged (amenity/shop/leisure/tourism/historic/office/..."
          f"): {len(semi)}")
    print(f"fully anonymous (procedural filler): {len(procedural)}")
    semikinds = {}
    for b in semi:
        for k in poi_tags:
            if b["tags"].get(k):
                semikinds[k + "=" + b["tags"][k]] = semikinds.get(k + "=" + b["tags"][k], 0) + 1
                break
    for k, v in sorted(semikinds.items(), key=lambda kv: -kv[1])[:25]:
        print(f"   {k}: {v}")
    print("\nnamed building list (the authored list):")
    named_area = []
    for b in named:
        a = shoelace_m2(ring_of(b["pts"], nodes) if b["kind"] == "way" else b["pts"])
        named_area.append((a, b))
    named_area.sort(key=lambda x: -x[0])
    for a, b in named_area:
        t = b["tags"]
        print(f"   {t.get('name','')[:44]:44s} {fmt_c(b['c'])} {a:7.0f} m2 "
              f"bld={t.get('building','')[:18]:18s} lv={t.get('building:levels','')} "
              f"{b['kind']}{b['id']}")


# ---------------- mode: districts ----------------

def find_poly(nodes, ways, want_name):
    for wid, w in ways.items():
        t = w.get("tags") or {}
        if t.get("name") == want_name and is_closed(way_pts(w, nodes) or [0] * 4):
            return wid, t, ring_of(w, nodes)
    return None, None, None


def mode_districts(nodes, ways, rels):
    print("== 2. AUTHORED DISTRICTS")
    bw, br = collect_buildings(nodes, ways, rels)
    blds = bw + br

    for want in ("Downtown", "Campustown"):
        wid, t, ring = find_poly(nodes, ways, want)
        if not ring:
            print(f"  !! polygon '{want}' not found")
            continue
        bb_d = bbox_dims_m(ring + [ring[0]])
        c = bbox_center(ring)
        inside = [b for b in blds if point_in_ring(b["c"], ring)]
        areas = sorted((shoelace_m2(ring_of(b["pts"], nodes) if b["kind"] == "way" else b["pts"])
                        for b in inside))
        named = [b for b in inside if (b["tags"].get("name") or "").strip()]
        print(f"\npolygon '{want}' way {wid}: {len(ring)} pts, bbox "
              f"{bb_d[0]:.0f} x {bb_d[1]:.0f} m, center {fmt_c(c)}")
        print(f"  buildings with centroid inside: {len(inside)} "
              f"(named {len(named)}); total footprint {sum(areas)/10000:.2f} ha; "
              f"p50 {areas[len(areas)//2]:.0f} m2 p90 {areas[9*len(areas)//10]:.0f} m2")

    # street centerlines for block slicing
    def street_line(name, lon_rng=None, lat_rng=None):
        pts = []
        for wid, w in ways.items():
            t = w.get("tags") or {}
            if t.get("name") != name or not t.get("highway"):
                continue
            for p in way_pts(w, nodes):
                if lon_rng and not (lon_rng[0] <= p[0] <= lon_rng[1]):
                    continue
                if lat_rng and not (lat_rng[0] <= p[1] <= lat_rng[1]):
                    continue
                pts.append(p)
        return pts

    def mean_along(pts, axis):
        vals = [p[axis] for p in pts]
        return sum(vals) / len(vals) if vals else None

    # DOWNTOWN: N-S cross streets measured within lat band 42.0240..42.0270
    dt_ns = {}
    for nm in ("Northwestern Avenue", "Grand Avenue", "Pearle Avenue", "Clark Avenue",
               "Burnett Avenue", "Kellogg Avenue", "Douglas Avenue", "Duff Avenue",
               "Burnett"):
        pts = street_line(nm, lat_rng=(42.0235, 42.0275))
        if pts:
            dt_ns[nm] = mean_along(pts, 0)
    # E-W streets measured within downtown lon band
    dt_ew = {}
    for nm in ("Main Street", "5th Street", "6th Street", "Douglas Avenue"):
        pts = street_line(nm, lon_rng=(-93.6220, -93.6100))
        if pts:
            dt_ew[nm] = mean_along(pts, 1)
    print("\ndowntown cross-street centerlines (measured):")
    for nm, v in dt_ns.items():
        print(f"  {nm:24s} lon {v:.5f}")
    for nm, v in dt_ew.items():
        print(f"  {nm:24s} lat {v:.5f}")

    # per-block building counts along Main St: cells between consecutive N-S lons
    order = sorted(dt_ns.items(), key=lambda kv: kv[1])
    main_lat = dt_ew.get("Main Street", 42.0251)
    fifth_lat = dt_ew.get("5th Street")
    sixth_lat = dt_ew.get("6th Street")
    print(f"\ndowntown per-block buildings (Main Street band lat "
          f"{main_lat - 0.0012:.5f}..{main_lat + 0.0012:.5f}):")
    for i in range(len(order) - 1):
        (n1, x1), (n2, x2) = order[i], order[i + 1]
        cell = [b for b in blds
                if x1 < b["c"][0] < x2
                and main_lat - 0.0012 < b["c"][1] < main_lat + 0.0012]
        ar = sorted(shoelace_m2(ring_of(b["pts"], nodes) if b["kind"] == "way" else b["pts"])
                    for b in cell)
        p50 = ar[len(ar) // 2] if ar else 0
        print(f"  {n1[:16]:16s} -> {n2[:16]:16s} ({(x2-x1)*m_per_deg_lon(main_lat):5.0f} m): "
              f"{len(cell):3d} bldgs, p50 {p50:5.0f} m2")
    # E-W band structure
    if fifth_lat:
        d = abs(main_lat - fifth_lat) * M_PER_DEG_LAT
        side = "N" if fifth_lat > main_lat else "S"
        print(f"Main->5th spacing: {d:.0f} m (5th is {side} of Main)")
    if fifth_lat and sixth_lat:
        print(f"5th->6th spacing: {abs(sixth_lat - fifth_lat) * M_PER_DEG_LAT:.0f} m")

    # setbacks: buildings near Main St centerline
    main_pts = street_line("Main Street", lon_rng=(-93.6225, -93.6100))
    main_line = main_pts
    near = [b for b in blds if dist_to_polyline_m(b["c"], main_line) < 60]
    ds = sorted(min(dist_to_polyline_m(nd, main_line) for nd in b["pts"])
                for b in near)
    if ds:
        print(f"setbacks to Main St centerline (n={len(ds)} buildings within 60 m): "
              f"min {ds[0]:.1f} p25 {ds[len(ds)//4]:.1f} p50 {ds[len(ds)//2]:.1f} "
              f"p75 {ds[3*len(ds)//4]:.1f} max {ds[-1]:.1f} m")

    # CAMPUSTOWN: N-S avenues measured in the Campustown lat band
    ct_ns = {}
    for nm in ("State Avenue", "Howard Avenue", "Campus Avenue",
               "North Hyland Avenue", "South Hyland Avenue",
               "Sheldon Avenue", "Hayward Avenue", "Welch Avenue", "Stanton Avenue"):
        pts = street_line(nm, lat_rng=(42.0190, 42.0225))
        if pts:
            ct_ns[nm] = mean_along(pts, 0)
    ct_ew = {}
    for nm in ("Lincoln Way", "Chamberlain Street", "Hunt Street"):
        pts = street_line(nm, lon_rng=(-93.6600, -93.6460))
        if pts:
            ct_ew[nm] = mean_along(pts, 1)
    print("\nCampustown centerlines (measured):")
    for nm, v in ct_ns.items():
        print(f"  {nm:18s} lon {v:.5f}")
    for nm, v in ct_ew.items():
        print(f"  {nm:18s} lat {v:.5f}")

    lw_lat = ct_ew.get("Lincoln Way", 42.0228)
    order = sorted(ct_ns.items(), key=lambda kv: kv[1])
    print(f"\nCampustown per-block buildings (Lincoln Way south frontage band "
          f"lat {lw_lat - 0.0016:.5f}..{lw_lat - 0.0002:.5f}):")
    for i in range(len(order) - 1):
        (n1, x1), (n2, x2) = order[i], order[i + 1]
        cell = [b for b in blds
                if x1 < b["c"][0] < x2
                and lw_lat - 0.0016 < b["c"][1] < lw_lat - 0.0002]
        ar = sorted(shoelace_m2(ring_of(b["pts"], nodes) if b["kind"] == "way" else b["pts"])
                    for b in cell)
        p50 = ar[len(ar) // 2] if ar else 0
        print(f"  {n1[:14]:14s} -> {n2[:14]:14s} ({(x2-x1)*m_per_deg_lon(lw_lat):5.0f} m): "
              f"{len(cell):3d} bldgs, p50 {p50:5.0f} m2")

    # Welch Ave setbacks
    welch_pts = street_line("Welch Avenue", lat_rng=(42.018, 42.0226))
    if welch_pts:
        near = [b for b in blds if dist_to_polyline_m(b["c"], welch_pts) < 50]
        ds = sorted(min(dist_to_polyline_m(nd, welch_pts) for nd in b["pts"])
                    for b in near)
        if ds:
            print(f"setbacks to Welch Ave centerline (n={len(ds)} buildings within 50 m): "
                  f"min {ds[0]:.1f} p25 {ds[len(ds)//4]:.1f} p50 {ds[len(ds)//2]:.1f} "
                  f"p75 {ds[3*len(ds)//4]:.1f} max {ds[-1]:.1f} m")
    lw_pts = street_line("Lincoln Way", lon_rng=(-93.6600, -93.6460))
    if lw_pts:
        near = [b for b in blds if dist_to_polyline_m(b["c"], lw_pts) < 60
                and b["c"][1] < lw_lat]
        ds = sorted(min(dist_to_polyline_m(nd, lw_pts) for nd in b["pts"])
                    for b in near)
        if ds:
            print(f"setbacks to Lincoln Way centerline, SOUTH side only "
                  f"(n={len(ds)} buildings within 60 m): "
                  f"min {ds[0]:.1f} p25 {ds[len(ds)//4]:.1f} p50 {ds[len(ds)//2]:.1f} "
                  f"p75 {ds[3*len(ds)//4]:.1f} max {ds[-1]:.1f} m")


# ---------------- mode: venues ----------------

TIER1 = [
    ("Welch Ave Station", ("welch ave station",), ("207", "welch avenue")),
    ("Paddy's Irish Pub", ("paddy",), ("124", "welch avenue")),
    ("Cy's Roost", ("roost",), ("121", "welch avenue")),
    ("Sips", ("sips",), ("126", "welch avenue")),
    ("Mickey's Irish Pub", ("mickey",), ("109", "welch avenue")),
    ("AJ's Ultra Lounge", ("aj's ultra", "ajs ultra", "aj ultra"), ("2401", "chamberlain street")),
    ("Outlaws", ("outlaws",), ("2522", "chamberlain street")),
    ("Cafe Beaudelaire", ("beaudelaire",), ("2504", "lincoln way")),
    ("Jeff's Pizza Shop", ("jeff's pizza", "jeffs pizza"), ("2402", "lincoln way")),
    ("Mr. Burrito", ("mr. burrito", "mr burrito"), ("2508", "lincoln way")),
    ("Superdog (cart)", ("superdog",), ("208", "welch avenue")),
    ("Hickory Park", ("hickory park",), ("1404", "south duff avenue")),
    ("The Cafe", ("the cafe",), ("2616", "northridge parkway")),
    ("Great Plains Sauce & Dough", ("great plains",), ("129", "main street")),
]

TIER2 = [
    ("Mother's Pub & Coffee", ("mother's pub", "mothers pub"), ("2900", "west street")),
    ("Thumbs", ("thumbs",), ("2816", "west street")),
    ("West Street Deli", ("west street deli",), ("2810", "west street")),
    ("BNC Field House", ("bnc",), ("206", "welch avenue")),
    ("Blue Owl Bar", ("blue owl",), ("223", "welch avenue")),
    ("Cornbred Barbecue", ("cornbred",), ("526", "main street")),
    ("Whiskey River", ("whiskey river",), ("134", "main street")),
    ("London Underground", ("london underground",), ("212", "main street")),
    ("Time Out", ("time out", "timeout"), ("120", "kellogg avenue")),
    ("The Mucky Duck Pub", ("mucky duck",), ("3100", "south duff avenue")),
    ("Torrent Brewing", ("torrent",), ("504", "burnett avenue")),
    ("Aunt Maude's", ("aunt maude", "aunt maudes"), ("547", "main street")),
    ("The Grove Cafe", ("grove cafe", "the grove"), ("124", "main street")),
    ("Provisions Lot F", ("provisions",), ("2400", "north loop drive")),
    ("The Stan Tap", ("stan tap",), ("216", "stanton avenue")),
    ("Sam's Place", ("sam's place", "sams place"), ("125", "main street")),
    ("Lost and Found Lounge", ("lost and found",), ("121", "welch avenue")),
]


def norm(s):
    return (s or "").lower().replace("'", "").replace(".", " ").replace("&", "and")


def mode_venues(nodes, ways, rels, cached):
    print("== 2b. VENUES.md Tier 1-2 -> OSM anchor cross-check")
    blds_all = []
    for wid, w in ways.items():
        t = w.get("tags") or {}
        b = t.get("building")
        if not b or b == "no":
            continue
        pts = way_pts(w, nodes)
        if len(pts) < 2:
            continue
        blds_all.append({"id": wid, "tags": t, "c": bbox_center(pts), "kind": "way"})
    # all named/addr ways (non-building too, e.g. shop nodes on ways)
    named_ways = {}
    addr_ways = {}
    for wid, w in ways.items():
        t = w.get("tags") or {}
        nm = norm(t.get("name"))
        if nm:
            named_ways.setdefault(wid, (t, bbox_center(way_pts(w, nodes) or [(0, 0)])))
        hn, st = t.get("addr:housenumber"), norm(t.get("addr:street"))
        if hn and st:
            addr_ways.setdefault(wid, (t, bbox_center(way_pts(w, nodes) or [(0, 0)])))

    def scan(tier, entries):
        print(f"\n-- {tier}")
        for disp, pats, addr in entries:
            hits = []
            # name match on ways
            for wid, (t, c) in named_ways.items():
                nm = norm(t.get("name"))
                if any(p in nm for p in pats):
                    hits.append(("way-name", wid, c, t))
            # name match on tagged nodes
            for nid, (lon, lat, t) in cached.items():
                nm = norm(t.get("name"))
                if nm and any(p in nm for p in pats):
                    hits.append(("node-name", nid, (lon, lat), t))
            # addr match on ways
            for wid, (t, c) in addr_ways.items():
                hn, st = str(t.get("addr:housenumber")), norm(t.get("addr:street"))
                if hn == addr[0] and st == norm(addr[1]):
                    hits.append(("way-addr", wid, c, t))
            # addr match on nodes
            for nid, (lon, lat, t) in cached.items():
                hn, st = str(t.get("addr:housenumber")), norm(t.get("addr:street"))
                if hn == addr[0] and st == norm(addr[1]):
                    hits.append(("node-addr", nid, (lon, lat), t))
            if not hits:
                print(f"  {disp:30s} addr {addr[0]:>5s} {addr[1]:22s} -> NO OSM ANCHOR")
                continue
            # pick best: way-addr > way-name > node-name > node-addr
            prio = {"way-addr": 0, "way-name": 1, "node-name": 2, "node-addr": 3}
            hits.sort(key=lambda h: prio[h[0]])
            kind, eid, c, t = hits[0]
            incore = in_bbox(c)
            tagdesc = " ".join(f"{k}={t[k]}" for k in ("amenity", "shop", "building",
                                                       "building:levels", "name")
                               if t.get(k))[:70]
            extra = ""
            if len(hits) > 1:
                kinds = sorted(set(h[0] for h in hits))
                extra = f" [{len(hits)} hits: {','.join(kinds)}]"
            print(f"  {disp:30s} addr {addr[0]:>5s} {addr[1]:22s} -> {kind:9s} "
                  f"{eid:>9d} {fmt_c(c)} core={str(incore):5s} {tagdesc}{extra}")

    scan("TIER 1", TIER1)
    scan("TIER 2", TIER2)


# ---------------- mode: campus ----------------

def mode_campus(nodes, ways, rels, cached):
    print("== 3. CAMPUS INVENTORY")
    # ISU relation 3501275 polygon (outer rings)
    uni_rings = []
    uni_rel = None
    for rid, r in rels.items():
        t = r.get("tags") or {}
        if t.get("amenity") == "university" or rid == 3501275:
            nm = t.get("name", "?")
            outer = []
            for m in r.get("members", []):
                if m.get("type") == "way" and m.get("role") in ("outer", "") and m.get("ref") in ways:
                    pts = way_pts(ways[m["ref"]], nodes)
                    if len(pts) > 3:
                        outer.append(pts)
            if outer:
                uni_rings.extend(outer)
                if "Iowa State" in nm or rid == 3501275:
                    uni_rel = (rid, nm, outer)
    if uni_rel:
        rid, nm, outer = uni_rel
        allpts = [p for ring in outer for p in ring]
        d = bbox_dims_m(allpts)
        c = bbox_center(allpts)
        print(f"ISU campus relation {rid} '{nm}': {len(outer)} outer rings, "
              f"bbox {d[0]:.0f} x {d[1]:.0f} m center {fmt_c(c)}")

    def in_uni(c):
        return any(point_in_ring(c, ring) for ring in uni_rings)

    bw, br = collect_buildings(nodes, ways, rels)
    blds = bw + br
    incore_uni = [b for b in blds if in_bbox(b["c"]) and in_uni(b["c"])]
    named_uni = [b for b in incore_uni if (b["tags"].get("name") or "").strip()]
    print(f"buildings inside ISU polygon AND core bbox: {len(incore_uni)}; "
          f"named: {len(named_uni)}")
    btag = {}
    for b in incore_uni:
        k = b["tags"].get("building", "?")
        btag[k] = btag.get(k, 0) + 1
    print("building=* mix (in-campus, in-core):",
          dict(sorted(btag.items(), key=lambda kv: -kv[1])[:12]))

    print("\n30 biggest named campus buildings (footprint area):")
    na = []
    for b in named_uni:
        a = shoelace_m2(ring_of(b["pts"], nodes) if b["kind"] == "way" else b["pts"])
        d = bbox_dims_m(b["pts"])
        na.append((a, d, b))
    na.sort(key=lambda x: -x[0])
    for a, d, b in na[:30]:
        t = b["tags"]
        print(f"  {t['name'][:36]:36s} {a:7.0f} m2  {d[0]:4.0f}x{d[1]:4.0f} m  "
              f"{fmt_c(b['c'])} lv={t.get('building:levels','')} way{b['id']}")

    # campanile
    print("\nCampanile:")
    for wid, w in ways.items():
        t = w.get("tags") or {}
        if "campanile" in (t.get("name") or "").lower():
            pts = way_pts(w, nodes)
            d = bbox_dims_m(pts)
            print(f"  way {wid} name={t.get('name')} center={fmt_c(bbox_center(pts))} "
                  f"bbox {d[0]:.1f} x {d[1]:.1f} m area={shoelace_m2(ring_of(pts, nodes)):.0f} m2 "
                  f"bld={t.get('building')} tags={ {k: v for k, v in t.items() if k not in ('name',)} }")
    for nid, (lon, lat, t) in cached.items():
        if "campanile" in norm(t.get("name")):
            print(f"  node {nid} {fmt_c((lon, lat))} tags={t}")

    # Jack Trice + Hilton footprints
    print("\nStadiums:")
    for pat in ("jack trice", "hilton", "midamerican"):
        for wid, w in ways.items():
            t = w.get("tags") or {}
            if pat in norm(t.get("name")) or (pat == "jack trice" and t.get("leisure") == "stadium"):
                pts = way_pts(w, nodes)
                if not pts:
                    continue
                d = bbox_dims_m(pts)
                a = shoelace_m2(ring_of(pts, nodes)) if is_closed(pts) else 0
                print(f"  way {wid} '{t.get('name')}' center={fmt_c(bbox_center(pts))} "
                      f"bbox {d[0]:.0f} x {d[1]:.0f} m area={a:.0f} m2 "
                      f"{t.get('leisure','')}/{t.get('building','')} cap={t.get('capacity','')}")
    for rid, r in rels.items():
        t = r.get("tags") or {}
        if "jack trice" in norm(t.get("name")) or "hilton" in norm(t.get("name")):
            pts = []
            for m in r.get("members", []):
                if m.get("type") == "way" and m.get("ref") in ways:
                    pts.extend(way_pts(ways[m["ref"]], nodes))
            if pts:
                d = bbox_dims_m(pts)
                print(f"  rel {rid} '{t.get('name')}' center={fmt_c(bbox_center(pts))} "
                      f"bbox {d[0]:.0f} x {d[1]:.0f} m")

    # parking census
    print("\nParking census (amenity=parking, centroid in core):")
    lots = []
    for wid, w in ways.items():
        t = w.get("tags") or {}
        if t.get("amenity") == "parking":
            pts = way_pts(w, nodes)
            if len(pts) < 3:
                continue
            c = bbox_center(pts)
            if not in_bbox(c):
                continue
            a = shoelace_m2(ring_of(pts, nodes)) if is_closed(pts) else 0
            lots.append((a, wid, c, t))
    for nid, (lon, lat, t) in cached.items():
        if t.get("amenity") == "parking" and in_bbox((lon, lat)):
            lots.append((0.0, nid, (lon, lat), t))
    lots.sort(key=lambda x: -x[0])
    tot = sum(a for a, _, _, _ in lots)
    print(f"  {len(lots)} parking areas in core, total {tot/10000:.1f} ha")
    for a, wid, c, t in lots[:12]:
        print(f"   {a/10000:6.3f} ha  {wid:>10d} {fmt_c(c)} "
              f"{t.get('name','')[:30]:30s} {t.get('parking','')} {t.get('access','')}")
    # tailgate zone: the Iowa State Center / stadium lot sea
    tz = [(a, wid, c, t) for a, wid, c, t in lots
          if c[1] < 42.0225 and -93.6445 < c[0] < -93.6260]
    print(f"  Iowa State Center tailgate zone (lat<42.0225, lon -93.6445..-93.6260): "
          f"{len(tz)} lots, {sum(a for a, _, _, _ in tz)/10000:.1f} ha")
    tz2 = [(a, wid, c, t) for a, wid, c, t in tz if a > 0]
    tz2.sort(key=lambda x: -x[0])
    for a, wid, c, t in tz2[:10]:
        print(f"   {a/10000:6.3f} ha  {wid:>10d} {fmt_c(c)} {t.get('name','')[:26]:26s} "
              f"{t.get('parking','')} {t.get('access','')}")


# ---------------- mode: streets ----------------

ROAD_CLASSES = ("motorway", "trunk", "primary", "secondary", "tertiary",
                "unclassified", "residential", "living_street")

def mode_streets(nodes, ways, rels, cached):
    print("== 4. STREET & INTERSECTION STOCK (game-core bbox)")
    # km by class: segments with midpoint in core
    by_class = {}
    named_len = 0.0
    for wid, w in ways.items():
        t = w.get("tags") or {}
        hw = t.get("highway")
        if not hw:
            continue
        pts = way_pts(w, nodes)
        ln = sum(seg_len_m(a, b) for a, b in segs_in_bbox(pts))
        if ln <= 0:
            continue
        by_class[hw] = by_class.get(hw, 0.0) + ln
        if hw in ROAD_CLASSES and t.get("name"):
            named_len += ln
    print("road length by highway=* class inside core (segment midpoints):")
    for k in sorted(by_class, key=lambda k: -by_class[k]):
        print(f"  {k:16s} {by_class[k]/1000:8.2f} km")
    drv = sum(v for k, v in by_class.items() if k in ROAD_CLASSES)
    print(f"drivable total ({', '.join(ROAD_CLASSES)}): {drv/1000:.1f} km; "
          f"of which named {named_len/1000:.1f} km")

    # intersections by degree — downtown + Campustown windows
    def intersection_census(name, bbox):
        deg = {}
        for wid, w in ways.items():
            t = w.get("tags") or {}
            if t.get("highway") not in ROAD_CLASSES:
                continue
            pts = way_pts(w, nodes)
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                for p in (a, b):
                    if bbox[0] <= p[0] <= bbox[2] and bbox[1] <= p[1] <= bbox[3]:
                        deg.setdefault(p, set()).add(wid)
        counts = {}
        for p, ws in deg.items():
            d = len(ws)
            counts[d] = counts.get(d, 0) + 1
        total = sum(v for k, v in counts.items() if k >= 3)
        print(f"  {name}: nodes touched by >=3 road ways (intersections): {total}; "
              + ", ".join(f"deg{k}={counts.get(k, 0)}" for k in sorted(counts) if k >= 3))
        return deg

    print("intersection census (way-degree per node; OSM splits ways at junctions):")
    DT = (-93.6225, 42.0230, -93.6100, 42.0275)     # downtown Main/5th/6th grid
    CT = (-93.6600, 42.0180, -93.6460, 42.0230)     # Campustown Lincoln Way strip
    intersection_census("downtown window (Clark..Duff, Main..6th)", DT)
    intersection_census("Campustown window (State..Stanton, LW..Hunt+)", CT)

    # traffic signals + crossings from tagged nodes
    sig = [(lon, lat, t) for lon, lat, t in cached.values()
           if t.get("highway") == "traffic_signals" and in_bbox((lon, lat))]
    cross = [(lon, lat, t) for lon, lat, t in cached.values()
             if t.get("highway") == "crossing" and in_bbox((lon, lat))]
    print(f"signalized nodes (highway=traffic_signals) in core: {len(sig)}")
    for zone, bbox in (("downtown", DT), ("Campustown", CT)):
        n = sum(1 for lon, lat, _ in sig
                if bbox[0] <= lon <= bbox[2] and bbox[1] <= lat <= bbox[3])
        print(f"  {zone}: {n}")
    print(f"pedestrian crossing nodes (highway=crossing) in core: {len(cross)} "
          f"({sum(1 for _,_,t in cross if t.get('crossing')=='traffic_signals')} signal-controlled)")


# ---------------- mode: green ----------------

def mode_green(nodes, ways, rels, cached):
    print("== 5. GREEN & WATER")
    # parks
    parks = []
    for wid, w in ways.items():
        t = w.get("tags") or {}
        if t.get("leisure") in ("park", "garden") or t.get("natural") in ("wood", "scrub") \
                or t.get("landuse") in ("recreation_ground", "forest", "grass", "meadow", "village_green"):
            pts = way_pts(w, nodes)
            if len(pts) < 4 or not is_closed(pts):
                continue
            c = bbox_center(pts)
            if not in_bbox(c):
                continue
            a = shoelace_m2(ring_of(pts, nodes))
            parks.append((a, wid, c, t, "way"))
    for rid, r in rels.items():
        t = r.get("tags") or {}
        if t.get("leisure") in ("park", "garden") or t.get("natural") in ("wood",):
            pts = []
            for m in r.get("members", []):
                if m.get("type") == "way" and m.get("ref") in ways:
                    pts.extend(way_pts(ways[m["ref"]], nodes))
            if not pts:
                continue
            c = bbox_center(pts)
            if not in_bbox(c):
                continue
            a = shoelace_m2(pts)
            parks.append((a, rid, c, t, "rel"))
    parks.sort(key=lambda x: -x[0])
    print(f"green areas with centroid in core: {len(parks)}, "
          f"total {sum(p[0] for p in parks)/10000:.1f} ha")
    for a, eid, c, t, kind in parks[:30]:
        nm = t.get("name") or "(unnamed)"
        kindtag = t.get("leisure") or t.get("natural") or t.get("landuse")
        print(f"  {a/10000:7.3f} ha  {nm[:36]:36s} {fmt_c(c)} {kindtag} {kind}{eid}")

    # trees
    trees = [(lon, lat) for lon, lat, t in cached.values()
             if t.get("natural") == "tree" and in_bbox((lon, lat))]
    print(f"individual tree nodes (natural=tree) in core: {len(trees)}")

    # water
    def water_line(name):
        pts = []
        for wid, w in ways.items():
            t = w.get("tags") or {}
            if t.get("name") == name or (name == "South Skunk River" and
                                         t.get("waterway") == "river" and not t.get("name")):
                pts.extend(way_pts(w, nodes))
        for rid, r in rels.items():
            t = r.get("tags") or {}
            if t.get("name") == name:
                for m in r.get("members", []):
                    if m.get("type") == "way" and m.get("ref") in ways:
                        pts.extend(way_pts(ways[m["ref"]], nodes))
        return pts

    for nm in ("College Creek", "Ioway Creek", "South Skunk River", "Worrell Creek",
               "Clear Creek"):
        pts = water_line(nm)
        segs = segs_in_bbox(pts)
        ln = sum(seg_len_m(a, b) for a, b in segs)
        inpts = [p for a, b in segs for p in (a, b)]
        if inpts:
            d = bbox_dims_m(inpts)
            print(f"  {nm:18s} in-core: {ln/1000:6.2f} km of centerline/bank, "
                  f"bbox {d[0]:.0f} x {d[1]:.0f} m, "
                  f"lon {min(p[0] for p in inpts):.4f}..{max(p[0] for p in inpts):.4f} "
                  f"lat {min(p[1] for p in inpts):.4f}..{max(p[1] for p in inpts):.4f}")
        else:
            print(f"  {nm:18s} in-core: NOTHING (0 segments)")

    # Lake LaVerne (relation 3329428)
    for rid, r in rels.items():
        t = r.get("tags") or {}
        if "laverne" in norm(t.get("name")) or rid == 3329428:
            pts = []
            for m in r.get("members", []):
                if m.get("type") == "way" and m.get("ref") in ways:
                    pts.extend(way_pts(ways[m["ref"]], nodes))
            d = bbox_dims_m(pts)
            c = bbox_center(pts)
            print(f"  Lake LaVerne rel {rid}: bbox {d[0]:.0f} x {d[1]:.0f} m, "
                  f"center {fmt_c(c)}, area {shoelace_m2(pts):.0f} m2")


# ---------------- mode: rail ----------------

def mode_rail(nodes, ways, rels):
    print("== 5b. RAIL IN CORE")
    rail_ways = []
    for wid, w in ways.items():
        t = w.get("tags") or {}
        rw = t.get("railway")
        if rw in ("rail", "light_rail", "tram", "abandoned", "disused"):
            pts = way_pts(w, nodes)
            segs = segs_in_bbox(pts)
            ln = sum(seg_len_m(a, b) for a, b in segs)
            if ln > 0:
                rail_ways.append((wid, t, ln, pts))
    groups = {}
    for wid, t, ln, pts in rail_ways:
        key = (t.get("railway"), t.get("service") or "-",
               t.get("name") or t.get("operator") or "-")
        groups.setdefault(key, [0.0, 0])
        groups[key][0] += ln
        groups[key][1] += 1
    print("rail length in core by (railway, service, name/operator):")
    for k, (ln, n) in sorted(groups.items(), key=lambda kv: -kv[1][0]):
        print(f"  {str(k):70s} {ln/1000:7.2f} km  {n} ways")

    # road-rail crossings
    road_segs = []
    for wid, w in ways.items():
        t = w.get("tags") or {}
        if t.get("highway") not in ROAD_CLASSES + ("service", "footway", "pedestrian", "steps", "path", "cycleway", "track"):
            continue
        pts = way_pts(w, nodes)
        for a, b in segs_in_bbox(pts):
            road_segs.append((a, b, t.get("name") or t.get("highway"), t))
    rail_segs = []
    for wid, t, ln, pts in rail_ways:
        for a, b in segs_in_bbox(pts):
            rail_segs.append((a, b, t))
    VEH = ROAD_CLASSES + ("service",)
    crossings = []
    for a, b, rname, rt in road_segs:
        rkind = "veh" if rt.get("highway") in VEH else "foot"
        for c, d, rt2 in rail_segs:
            p = seg_intersection(a, b, c, d)
            if p:
                lonlat = xy_to_lonlat(*p)
                # grade-separated if either has bridge/tunnel or layer != 0
                gsep = any(x in (rt, rt2) for x in ("bridge", "tunnel")) or \
                    rt.get("layer") not in (None, "0") or rt2.get("layer") not in (None, "0")
                crossings.append((lonlat, rname, rt.get("highway"), rt2, gsep, rkind))
    # dedupe: same road kind AND same road name/class within 20 m
    crossings.sort(key=lambda x: (x[5], x[1], round(x[0][0], 4), round(x[0][1], 4)))
    kept = []
    for cr in crossings:
        dup = False
        for k in kept:
            if k[5] == cr[5] and k[1] == cr[1]:
                px, py = to_xy(cr[0]); qx, qy = to_xy(k[0])
                if math.hypot(px - qx, py - qy) < 20:
                    dup = True
                    break
        if not dup:
            kept.append(cr)
    kept.sort(key=lambda x: (0 if x[5] == "veh" else 1, -x[0][1]))
    at = [c for c in kept if not c[4]]
    gs = [c for c in kept if c[4]]
    veh = [c for c in kept if c[5] == "veh"]
    print(f"\nroad x rail crossing points in core (dedup 20 m within same road): "
          f"{len(kept)} total ({len(at)} at-grade, {len(gs)} grade-separated); "
          f"vehicular {len(veh)}, foot/bike {len(kept) - len(veh)}")
    for lonlat, rname, rcls, rt2, gsep, rkind in kept:
        kind = "GSEP" if gsep else "AT-GR"
        tag = "veh " if rkind == "veh" else "foot"
        print(f"  {fmt_c(lonlat)}  {kind}  road='{rname}' ({rcls})  "
              f"rail={rt2.get('railway')}/{rt2.get('service') or '-'} "
              f"rail_name={rt2.get('name') or rt2.get('operator') or '-'}")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "help"
    if mode == "cache":
        build_node_cache()
        return
    nodes, ways, rels = load_data()
    cached = {}
    if mode in ("venues", "campus", "streets", "green"):
        cached = load_cached_nodes()
    if mode == "buildings":
        mode_buildings(nodes, ways, rels)
    elif mode == "districts":
        mode_districts(nodes, ways, rels)
    elif mode == "venues":
        mode_venues(nodes, ways, rels, cached)
    elif mode == "campus":
        mode_campus(nodes, ways, rels, cached)
    elif mode == "streets":
        mode_streets(nodes, ways, rels, cached)
    elif mode == "green":
        mode_green(nodes, ways, rels, cached)
    elif mode == "rail":
        mode_rail(nodes, ways, rels)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
