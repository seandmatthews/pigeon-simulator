#!/usr/bin/env python3
"""QA-lane probes against the sibling OSM extract (read-only).
Run: python -I probe_qa.py <path/to/ames_merged.json> <path/to/tagged_nodes.json>
Cross-checks five disputed claims (see QA-REPORT.md section 2)."""
import json
import math
import sys

MERGED = sys.argv[1]
NODECACHE = sys.argv[2]

M_PER_DEG_LAT = 111074.0
LAT0 = 42.02
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(LAT0))  # ~82,650


def load():
    with open(MERGED, encoding="utf-8") as f:
        d = json.load(f)
    nodes = {int(k): tuple(v) for k, v in d["nodes"].items()}
    ways = {int(k): v for k, v in d["ways"].items()}
    return nodes, ways


def way_nodes(w, nodes):
    return [nodes[n] for n in w["nodes"] if n in nodes]


def centroid(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return sum(xs) / len(xs), sum(ys) / len(ys)


def bbox(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def dist_m(a, b):
    return math.hypot((a[0] - b[0]) * M_PER_DEG_LON, (a[1] - b[1]) * M_PER_DEG_LAT)


def shoelace_m2(pts):
    s = 0.0
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        s += (x1 * M_PER_DEG_LON) * (y2 * M_PER_DEG_LAT) - (x2 * M_PER_DEG_LON) * (y1 * M_PER_DEG_LAT)
    return abs(s) / 2.0


def main():
    nodes, ways = load()
    print("=== probe 1: Hy-Vee ways ===")
    for wid, w in ways.items():
        name = w.get("tags", {}).get("name", "")
        if "hy-vee" in name.lower():
            pts = way_nodes(w, nodes)
            if not pts:
                continue
            c = centroid(pts)
            b = bbox(pts)
            ew = (b[2] - b[0]) * M_PER_DEG_LON
            ns = (b[3] - b[1]) * M_PER_DEG_LAT
            print(f"  way/{wid} name={name!r} tags={ {k:v for k,v in w['tags'].items() if k in ('name','shop','building','addr:housenumber','addr:street','levels')} }")
            print(f"    centroid=({c[0]:.5f}, {c[1]:.5f}) bbox {ew:.0f}x{ns:.0f} m area={shoelace_m2(pts) if len(pts) > 2 else 0:.0f} m2")

    print("=== probe 2: Reiman Conservatory way(s) ===")
    for wid, w in ways.items():
        name = w.get("tags", {}).get("name", "")
        t = w.get("tags", {})
        if "conservatory" in name.lower():
            pts = way_nodes(w, nodes)
            c = centroid(pts)
            b = bbox(pts)
            ew = (b[2] - b[0]) * M_PER_DEG_LON
            ns = (b[3] - b[1]) * M_PER_DEG_LAT
            print(f"  way/{wid} name={name!r} tags={ {k:v for k,v in t.items() if k in ('name','building','amenity','leisure','height','building:levels')} }")
            print(f"    centroid=({c[0]:.5f}, {c[1]:.5f}) bbox {ew:.0f}x{ns:.0f} m area={shoelace_m2(pts) if len(pts) > 2 else 0:.0f} m2")

    print("=== probe 3: Hilton vs stadium bowl distance ===")
    hilton = way_nodes(ways[180651868], nodes)
    bowl = way_nodes(ways[613735866], nodes)
    hc = centroid(hilton)
    sc = centroid(bowl)
    hb, bb = bbox(hilton), bbox(bowl)
    print(f"  Hilton centroid=({hc[0]:.5f},{hc[1]:.5f}) bbox {((hb[2]-hb[0])*M_PER_DEG_LON):.0f}x{((hb[3]-hb[1])*M_PER_DEG_LAT):.0f} m")
    print(f"  Bowl centroid=({sc[0]:.5f},{sc[1]:.5f}) bbox {((bb[2]-bb[0])*M_PER_DEG_LON):.0f}x{((bb[3]-bb[1])*M_PER_DEG_LAT):.0f} m")
    print(f"  center-to-center = {dist_m(hc, sc):.0f} m; bearing = {'N' if sc[1] < hc[1] else 'S'}{abs(sc[0]-hc[0])*M_PER_DEG_LON:.0f}m lon / {abs(sc[1]-hc[1])*M_PER_DEG_LAT:.0f}m lat")
    print(f"  edge gap (bowl N edge -> Hilton S edge) = {(bb[3]-hb[1])*M_PER_DEG_LAT:.0f} m lat-wise")

    print("=== probe 4: Szechuan House / Welch centerline distance ===")
    with open(NODECACHE, encoding="utf-8") as f:
        tnodes = json.load(f)
    tnodes = {int(k): v for k, v in tnodes.items()} if isinstance(tnodes, dict) else tnodes
    # tagged nodes cache format: id -> {tags..., lon, lat}? inspect one
    sample = next(iter(tnodes.items()))
    # find Welch Ave ways (residential) nodes south of LW
    welch_lons = []
    for wid, w in ways.items():
        t = w.get("tags", {})
        if t.get("name") == "Welch Avenue":
            for n in way_nodes(w, nodes):
                welch_lons.append(n[0])
    welch_lon = sum(welch_lons) / len(welch_lons)
    print(f"  Welch centerline mean lon = {welch_lon:.5f} (n={len(welch_lons)})")
    print(f"  tagged-node cache sample entry: {str(sample)[:200]}")
    for nid, nd in (tnodes.items() if isinstance(tnodes, dict) else []):
        tags = nd.get("tags", nd) if isinstance(nd, dict) else {}
        blob = json.dumps(nd)
        if "Szechuan" in blob or "3605" in blob:
            print(f"  node/{nid}: {str(nd)[:300]}")
    # also scan way names for Szechuan
    for wid, w in ways.items():
        if "szechuan" in w.get("tags", {}).get("name", "").lower():
            pts = way_nodes(w, nodes)
            c = centroid(pts)
            print(f"  way/{wid} Szechuan way centroid=({c[0]:.5f},{c[1]:.5f}) -> {dist_m(c,(welch_lon,42.0228)):.0f} m from Welch/LW corner (lon-only {abs(c[0]-welch_lon)*M_PER_DEG_LON:.0f} m)")

    print("=== probe 5: Campustown polygon (way 918491523) extent ===")
    poly = way_nodes(ways[918491523], nodes)
    b = bbox(poly)
    c = centroid(poly)
    ew = (b[2] - b[0]) * M_PER_DEG_LON
    ns = (b[3] - b[1]) * M_PER_DEG_LAT
    print(f"  bbox lon {b[0]:.5f}..{b[2]:.5f}  lat {b[1]:.5f}..{b[3]:.5f}")
    print(f"  size {ew:.0f} x {ns:.0f} m; centroid ({c[0]:.5f},{c[1]:.5f}); area {shoelace_m2(poly):.0f} m2 = {shoelace_m2(poly)/10000:.1f} ha")
    # street centerlines: mean lon of nodes in campustown lat band for each name
    for nm in ["State Avenue", "South Hyland Avenue", "Sheldon Avenue", "Hayward Avenue", "Welch Avenue", "Stanton Avenue", "Morrill Road", "Lynn Avenue", "Ash Avenue"]:
        lons = []
        for wid, w in ways.items():
            t = w.get("tags", {})
            if t.get("name") == nm:
                for p in way_nodes(w, nodes):
                    if 42.019 < p[1] < 42.024:
                        lons.append(p[0])
        if lons:
            m = sum(lons) / len(lons)
            inside = b[0] <= m <= b[2]
            print(f"  {nm}: corridor mean lon {m:.5f} -> {'INSIDE' if inside else 'outside'} polygon lon-range (edge at {b[0]:.5f}/{b[2]:.5f})")

    print("=== probe 6: old SUMMARY 'Duff at -93.6154' sanity (V-05 settled) ===")
    for wid, w in ways.items():
        t = w.get("tags", {})
        if t.get("name") == "Duff Avenue":
            pts = way_nodes(w, nodes)
            near = [p for p in pts if 42.023 < p[1] < 42.027]
            if near:
                m = sum(p[0] for p in near) / len(near)
                print(f"  Duff Ave downtown-band mean lon = {m:.5f}")
                break


if __name__ == "__main__":
    main()
