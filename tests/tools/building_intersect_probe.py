#!/usr/bin/env python3
"""Building-intersection probe over the Ames bake (investigation, 2026-11-22).

Loads every chunk under data/ames/chunks/ and reports 3D AABB intersections
between building masses that should NOT share volume:

  A. massing x massing     - two distinct buildings' boxes poking through
                             each other (hero slots excluded: they are
                             hidden at render and superseded 1:1).
  B. massing x placeholder - a filler box punched by a hero silhouette part
                             or a venue fixup ("buried" fixups -- fully
                             inside a massing -- are the T-205 design).
  C. placeholder x placeholder - two different heroes' masses overlapping
                             (parts of the SAME hero stack by design).
  D. dress x foreign massing   - a porch/cornice/parapet of building X
                             poking into building Y's box (own-parent is
                             the T-206 design).
  E. dress/roof x placeholder - filler dressing into a hero mass.

Pure stdlib. Run from the repo root:  python -I tests/tools/building_intersect_probe.py
"""
import glob
import json
import os
import sys
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHUNKS = os.path.join(REPO, "data", "ames", "chunks")
PACK = os.path.join(REPO, "data", "ames", "ames_core.json")

CELL = 256.0  # spatial-hash cell (the bake's own tile size; boxes span few cells)


def aabb(p, s):
    """Center/size -> (x0, x1, y0, y1, z0, z1)."""
    return (
        p[0] - s[0] / 2, p[0] + s[0] / 2,
        p[1] - s[1] / 2, p[1] + s[1] / 2,
        p[2] - s[2] / 2, p[2] + s[2] / 2,
    )


def overlap(a, b):
    """Overlap depths per axis; negatives clamped to 0."""
    ox = min(a[1], b[1]) - max(a[0], b[0])
    oy = min(a[3], b[3]) - max(a[2], b[2])
    oz = min(a[5], b[5]) - max(a[4], b[4])
    return ox, oy, oz


def contains(outer, inner):
    """True when `inner` AABB sits fully inside `outer` (small tolerance)."""
    tol = 0.5
    return (outer[0] - tol <= inner[0] and inner[1] <= outer[1] + tol and
            outer[2] - tol <= inner[2] and inner[3] <= outer[3] + tol and
            outer[4] - tol <= inner[4] and inner[5] <= outer[5] + tol)


def truth_pass(a_and_b_hits):
    """Second phase: re-classify A-class box pairs against the REAL OSM
    footprints (docs/references/ames-survey/osm/ames_merged.json, the pack's
    own source). A pair whose TRUE polygons overlap is a data-level overlap;
    a pair whose polygons are clean is an AABB artifact of the box render.

    Uses the pack projection (ames_data_pack.gd): x=(lon+93.65015)*82700.8758,
    z=-(lat-42.02278)*111074.0. Pairs whose ways the merged extract does not
    cover (pack v2-v4 bbox growth) land in `no truth`.
    """
    merged_path = os.path.join(REPO, "docs", "references", "ames-survey",
                               "osm", "ames_merged.json")
    if not os.path.exists(merged_path):
        print("truth pass: merged OSM not found, skipped")
        return
    m = json.load(open(merged_path))
    nodes = m["nodes"]
    ways = m["ways"]
    relations = m["relations"]
    M_LAT = 111074.0
    M_LON = 82700.8758
    ORIGIN_LON = -93.65015
    ORIGIN_LAT = 42.02278

    def proj(lon, lat):
        return ((lon - ORIGIN_LON) * M_LON, -(lat - ORIGIN_LAT) * M_LAT)

    ring_cache = {}

    def rings_for(osm_id):
        """-> list of outer rings (each a list of (x, z)), or None if absent."""
        if osm_id in ring_cache:
            return ring_cache[osm_id]
        kind, num = osm_id.split("/", 1)
        rings = None
        if kind == "way" and num in ways:
            refs = ways[num].get("nodes", [])
            ring = [proj(*nodes[str(r)]) for r in refs if str(r) in nodes]
            if len(ring) >= 3:
                rings = [ring]
        elif kind == "relation" and num in relations:
            rings = []
            for mem in relations[num].get("members", []):
                if mem.get("type") == "way" and mem.get("role") == "outer" \
                        and str(mem.get("ref")) in ways:
                    refs = ways[str(mem.get("ref"))].get("nodes", [])
                    ring = [proj(*nodes[str(r)]) for r in refs if str(r) in nodes]
                    if len(ring) >= 3:
                        rings.append(ring)
            if not rings:
                rings = None
        ring_cache[osm_id] = rings
        return rings

    def poly_aabb(ring):
        xs = [p[0] for p in ring]
        zs = [p[1] for p in ring]
        return min(xs), max(xs), min(zs), max(zs)

    def inside(ring, x, z):
        c = False
        n = len(ring)
        j = n - 1
        for i in range(n):
            xi, zi = ring[i]
            xj, zj = ring[j]
            if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
                c = not c
            j = i
        return c

    def true_overlap(ra, rb):
        """Approx overlap area (m2) of two ring sets, grid-sampled at 1 m
        (2 m over huge shared boxes)."""
        boxes = [poly_aabb(r) for rs in (ra, rb) for r in rs]
        x0 = max(b[0] for b in boxes)
        x1 = min(b[1] for b in boxes)
        z0 = max(b[2] for b in boxes)
        z1 = min(b[3] for b in boxes)
        if x1 <= x0 or z1 <= z0:
            return 0.0
        step = 2.0 if (x1 - x0) * (z1 - z0) > 10000.0 else 1.0
        cell = step * step
        hits = 0
        x = x0 + step / 2
        while x < x1:
            z = z0 + step / 2
            while z < z1:
                if any(inside(r, x, z) for r in ra) and any(inside(r, x, z) for r in rb):
                    hits += 1
                z += step
            x += step
        return hits * cell

    buckets = {"real overlap >=2m2": [], "aabb artifact (clean footprints)": [],
               "no truth (way not in merged extract)": []}
    for h in a_and_b_hits:
        ra = rings_for(h["a"])
        rb = rings_for(h["b"])
        if ra is None or rb is None:
            buckets["no truth (way not in merged extract)"].append(h)
            continue
        area = true_overlap(ra, rb)
        h["true_m2"] = round(area, 1)
        if area >= 2.0:
            buckets["real overlap >=2m2"].append(h)
        else:
            buckets["aabb artifact (clean footprints)"].append(h)

    print("== truth pass over A-class pairs (real footprints from ames_merged.json)")
    for k, lst in buckets.items():
        print(f"   {k}: {len(lst)}")
    real = sorted(buckets["real overlap >=2m2"], key=lambda h: -h.get("true_m2", 0))
    for h in real[:40]:
        print(f"   true={h['true_m2']:>8} m2 (box vol {h['vol']})  {h['a']} x {h['b']} "
              f"'{h['na']}' x '{h['nb']}' {h['pa']}")
    print()


def main():
    meta = {}
    if os.path.exists(PACK):
        meta = {b["id"]: b for b in json.load(open(PACK))["buildings"]}
        pois = {p["id"]: p for p in json.load(open(PACK))["pois"]}
    else:
        pois = {}

    manifest = json.load(open(os.path.join(CHUNKS, "manifest.json")))
    heroes = set(manifest["heroes"])

    massings = {}      # id -> dict (bake emits one chunk per centroid; assert unique)
    placeholders = []  # hero silhouette parts + venue fixups
    dresses = []
    roofs = []

    n_chunks = 0
    for f in sorted(glob.glob(os.path.join(CHUNKS, "chunk_*.json"))):
        c = json.load(open(f))
        n_chunks += 1
        for m in c.get("massing", []):
            mid = m["id"]
            if mid in massings:
                sys.exit(f"massing {mid} appears in two chunks: {f}")
            massings[mid] = m
        for ph in c.get("placeholders", []):
            s = ph["s"]
            placeholders.append({"id": ph["id"], "part": ph.get("part", "hero"),
                                 "p": ph["p"], "s": s, "box": aabb(ph["p"], s)})
        for d in c.get("dress", []):
            dresses.append({"id": d["id"], "role": d.get("role", "?"),
                            "p": d["p"], "s": d["s"], "box": aabb(d["p"], d["s"])})
        for r in c.get("roofs", []):
            # roof prism: p = eave center at box top, s = [ridge_len, span,
            # ridge_h] in RIDGE-AXIS order, `a` names the world axis the
            # ridge runs along ("x" -> len on X, span on Z; "z" swapped).
            if r["a"] == "x":
                s = [r["s"][0], r["s"][2], r["s"][1]]  # (x, y, z)
            else:
                s = [r["s"][1], r["s"][2], r["s"][0]]
            # y: eave line at p[1], ridge rises ridge_h above -> AABB
            p = [r["p"][0], r["p"][1] + r["s"][2] / 2, r["p"][2]]
            roofs.append({"id": r["id"], "p": p, "s": s, "box": aabb(p, s)})

    def name(i):
        b = meta.get(i)
        return (b.get("name") or "?") if b else i

    def klass(i):
        b = meta.get(i)
        return (b.get("class") or "?") if b else "?"

    # --- spatial hash: every box into every cell its AABB spans -------------
    grid = defaultdict(list)

    def put(idx, box):
        cx0, cx1 = int(box[0] // CELL), int(box[1] // CELL)
        cz0, cz1 = int(box[4] // CELL), int(box[5] // CELL)
        for cx in range(cx0, cx1 + 1):
            for cz in range(cz0, cz1 + 1):
                grid[(cx, cz)].append(idx)

    m_ids = [i for i in massings if i not in heroes]
    for k, i in enumerate(m_ids):
        m = massings[i]
        put(("m", i), aabb(m["p"], m["s"]))
    for k, ph in enumerate(placeholders):
        put(("p", k), ph["box"])
    for k, d in enumerate(dresses):
        put(("d", k), d["box"])
    for k, r in enumerate(roofs):
        put(("r", k), r["box"])

    # --- candidate pairs (each cell-pair visited once) -----------------------
    pair_set = set()

    def consider(key_a, key_b):
        if key_a > key_b:
            key_a, key_b = key_b, key_a
        pair_set.add((key_a, key_b))

    NEIGH = [(0, 0), (1, 0), (0, 1), (1, 1), (-1, 1)]
    for (cx, cz), members in grid.items():
        for nx, nz in NEIGH:
            other = grid.get((cx + nx, cz + nz))
            if not other:
                continue
            if (nx, nz) == (0, 0):
                for a in range(len(members)):
                    for b in range(a + 1, len(members)):
                        consider(members[a], members[b])
            else:
                for a in members:
                    for b in other:
                        consider(a, b)

    # --- classify ------------------------------------------------------------
    hits = defaultdict(list)  # check -> list of dicts
    for ka, kb in pair_set:
        ta, ia = ka
        tb, ib = kb
        if ta == "m":
            ba = aabb(massings[ia]["p"], massings[ia]["s"])
        elif ta == "p":
            ba = placeholders[ia]["box"]
        elif ta == "d":
            ba = dresses[ia]["box"]
        else:
            ba = roofs[ia]["box"]
        if tb == "m":
            bb = aabb(massings[ib]["p"], massings[ib]["s"])
        elif tb == "p":
            bb = placeholders[ib]["box"]
        elif tb == "d":
            bb = dresses[ib]["box"]
        else:
            bb = roofs[ib]["box"]
        ox, oy, oz = overlap(ba, bb)
        if ox <= 0 or oy <= 0 or oz <= 0:
            continue

        ida = massings[ia]["id"] if ta == "m" else (
            placeholders[ia]["id"] if ta == "p" else (
                dresses[ia]["id"] if ta == "d" else roofs[ia]["id"]))
        idb = massings[ib]["id"] if tb == "m" else (
            placeholders[ib]["id"] if tb == "p" else (
                dresses[ib]["id"] if tb == "d" else roofs[ib]["id"]))

        if ta == "m" and tb == "m":
            if ida == idb:
                continue
            kind = "A massing x massing"
        elif {ta, tb} == {"m", "p"}:
            ph = placeholders[ia if ta == "p" else ib]
            mid = massings[ia if ta == "m" else ib]["id"]
            if ph["id"] == mid:
                continue  # hero part on its own hidden slot (never renders twice)
            if ph["part"] != "fixup" and contains(bb if tb == "p" else ba,
                                                  ba if tb == "p" else bb):
                # placeholder fully inside the massing -> treat as buried too
                pass
            if ph["part"] == "fixup" and contains(ba if tb == "m" else bb,
                                                  ba if tb == "p" else bb):
                kind = "B2 fixup buried in massing (by design)"
            else:
                kind = "B massing x placeholder"
        elif ta == "p" and tb == "p":
            if ida == idb:
                continue  # same hero's stacked parts
            kind = "C placeholder x placeholder"
        elif {ta, tb} == {"d", "m"}:
            did = dresses[ia if ta == "d" else ib]["id"]
            mid = massings[ia if ta == "m" else ib]["id"]
            if did == mid:
                continue  # own-parent dressing (T-206 design)
            kind = "D dress x foreign massing"
        elif {ta, tb} == {"r", "m"}:
            rid = roofs[ia if ta == "r" else ib]["id"]
            mid = massings[ia if ta == "m" else ib]["id"]
            if rid == mid:
                continue  # own roof
            kind = "F roof x foreign massing"
        elif {ta, tb} == {"d", "p"} or {ta, tb} == {"r", "p"}:
            kind = "E dressing x placeholder"
        elif ta == tb == "d":
            if ida == idb:
                continue
            kind = "G dress x dress (different parents)"
        else:  # r x d
            if ida == idb:
                continue  # own roof over own dressing: same box top, by design
            kind = "G roof x dress"

        vol = ox * oy * oz
        hits[kind].append({
            "a": ida, "b": idb, "ox": round(ox, 2), "oy": round(oy, 2),
            "oz": round(oz, 2), "vol": round(vol, 1),
            "pa": (massings[ia]["p"] if ta == "m" else
                   placeholders[ia]["p"] if ta == "p" else
                   dresses[ia]["p"] if ta == "d" else roofs[ia]["p"]),
            "na": name(ida) if ta != "p" else pois.get(ida, {}).get("name", ida),
            "nb": name(idb) if tb != "p" else pois.get(idb, {}).get("name", idb),
            "ca": klass(ida), "cb": klass(idb),
            "role_a": (placeholders[ia].get("part") if ta == "p" else
                       dresses[ia].get("role") if ta == "d" else ""),
            "role_b": (placeholders[ib].get("part") if tb == "p" else
                       dresses[ib].get("role") if tb == "d" else ""),
        })

    print(f"chunks={n_chunks} massing={len(massings)} (heroes hidden={len(heroes)}) "
          f"placeholders={len(placeholders)} dress={len(dresses)} roofs={len(roofs)}")
    print()

    # A-class breakdown: district x class-pair (self-pairs already excluded)
    from collections import Counter
    a_pairs = hits.get("A massing x massing", [])
    truth_pass(a_pairs)
    district_of = {i: massings[i].get("d", "?") for i in massings}
    agg = Counter()
    for h in a_pairs:
        serious = min(h["ox"], h["oz"]) >= 1.0
        ka = "auth" if h["ca"] == "authored" else "proc"
        kb = "auth" if h["cb"] == "authored" else "proc"
        pair = "x".join(sorted((ka, kb)))
        agg[(h.get("da", district_of.get(h["a"], "?")), pair, serious)] += 1
    print("A breakdown by (district, class-pair): total / serious")
    keys = sorted({(d, p) for d, p, _ in agg})
    for d, p in keys:
        t = agg[(d, p, True)] + agg[(d, p, False)]
        print(f"   {d:<12} {p:<10} total={t:<5} serious={agg[(d, p, True)]}")
    print()

    for kind in sorted(hits):
        lst = hits[kind]
        serious = [h for h in lst if min(h["ox"], h["oz"]) >= 1.0]
        sliver = [h for h in lst if 0 < min(h["ox"], h["oz"]) < 1.0]
        print(f"== {kind}: {len(lst)} hits (serious>=1m-bite: {len(serious)}, "
              f"slivers<1m: {len(sliver)})")
        for h in sorted(lst, key=lambda x: -x["vol"])[:15]:
            print(f"   vol={h['vol']:>9} m3  d=({h['ox']},{h['oy']},{h['oz']})  "
                  f"{h['a']} [{h['ca']}/{h['role_a']}] x {h['b']} [{h['cb']}/{h['role_b']}]")
            print(f"      '{h['na']}' x '{h['nb']}'  at {h['pa']}")
        print()


if __name__ == "__main__":
    main()
