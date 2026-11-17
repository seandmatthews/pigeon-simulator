#!/usr/bin/env python3
"""Ames R1 data-pack distiller (T-171).

Reads the COMMITTED ring-0 survey inputs and emits data/ames/ames_core.json —
the versioned city database every later Ames ticket consumes (master plan §2).

Run from the repo root (offline, stdlib only):

    python -I tools/ames_distill.py

Canonical invocation has NO arguments; it is byte-identical on every re-run
from the same committed inputs (no timestamps, no RNG, sorted iteration).
`--distill-commit` only stamps provenance into meta.distill_commit and is NOT
part of the canonical byte-identity contract.

Committed inputs (all under docs/references/ames-survey/):
  osm/ames_merged.json            merged OSM extract, pulled 2026-11-08
                                  (309,870 nodes / 37,531 ways / 251 relations;
                                  merged nodes carry NO tags)
  census/authored-buildings.csv   the census classification of all 3,737
                                  in-core buildings (BUILD-CENSUS.md §6)
  census/tagged-nodes-core.json   tagged NODES (natural=tree, venue name/addr
                                  anchors) — a verbatim snapshot of the census
                                  lane's tagged_nodes.json cache, committed at
                                  T-171 so the pack builds without the 84 MB
                                  raw tiles (which stay local per the survey's
                                  owner-approved commit split; every node in it
                                  is © OpenStreetMap contributors, ODbL, same as
                                  the merged dataset — see ODBL-NOTE.md)

Coordinate convention (master plan §2, the ONE transform in to_local()):
  local meters; origin at Lincoln Way × Welch (the campus/Campustown seam);
  +X east, −Z north, Y up; equirectangular scale at lat 42.02.
  Re-centering the origin is a pack-version bump (bump `version`, change the
  `origin` constants, re-run) — never a refactor.

Pack version history:
  v1 (T-171): the census core bbox W−93.6590 S42.0120 E−93.6100 N42.0355.
  v2 (T-203): the bbox-east — E −93.6100 → −93.6070 (+248 m; Bandshell Park
      and the S Duff corridor's context blocks come inside; W/S/N and the
      origin unchanged). Counts re-pinned against the grown box (the deltas
      recorded in T-203's ticket).
  v3 (T-204): the bbox-south — S 42.0120 → 42.0030 (+1.0 km south, exactly
      SUMMARY §3's planned "cheap optional extension" window; Reiman
      Gardens, the ISU Vet Med campus and the town's south blocks come
      inside; W/E/N and the origin unchanged). Counts re-pinned against the
      grown box (the v2 pins and the south-strip deltas recorded in
      T-204's ticket).
  v4 (T-205): the bbox-north — N 42.0355 → 42.0780 (+4.72 km north). The
      ticket's parks/fabric/Cafe band (Moore Memorial + Inis Grove parks,
      The Cafe at 2616 Northridge Pkwy, the north residential blocks) sits
      inside SUMMARY §3's planned "+1.6 km north" window (N 42.0500); but
      the ticket's own What/AC put ADA HAYDEN HERITAGE PARK in the build —
      twin quarry lakes at data geometry, trail ring walkable-adjacent —
      and the data places that park at lat 42.05999..42.07618 (relation
      12032468, 1500 × 1798 m; SUMMARY §3 itself lists it "farther out").
      Landing the acceptance criteria therefore grows the box past the
      park: N 42.0780 covers the whole park way + its Ada Hayden Road +
      Grand Avenue's north end. W/S/E and the origin unchanged; the v3
      north edge is stamped `core_bbox_north_v3` and buildings north of it
      ride the census §6 rule exactly like the east/south strips. v4 also
      joins two data families the small windows never needed: NAMED
      natural=water ways (≥ 1 ha in-core — Ada Hayden Lake 52.1 ha, Arnold
      Lake 2.0 ha) and the R5-north parks' TRAILS (footway/path/cycleway
      runs inside the Ada Hayden / Inis Grove / Moore Memorial park
      polygons).

Census faithfulness: every count/geometry rule below is the census lane's rule
(docs/references/ames-survey/census/scripts/ames_census.py), so the pack's
numbers ARE the census's numbers. The script hard-fails if any pinned count
drifts.
"""
import argparse
import csv
import json
import math
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SURVEY = os.path.join(REPO, "docs", "references", "ames-survey")
MERGED = os.path.join(SURVEY, "osm", "ames_merged.json")
AUTHORED_CSV = os.path.join(SURVEY, "census", "authored-buildings.csv")
TAGGED_NODES = os.path.join(SURVEY, "census", "tagged-nodes-core.json")
OUT = os.path.join(REPO, "data", "ames", "ames_core.json")

# --- core constants (BUILD-CENSUS.md definitions + T-203 east / T-204 south) -

# Game-core bbox W, S, E, N. The v1 census box (E −93.6100) left Bandshell
# Park ~30 m outside its east edge (census §5's own ⚠ — "decide: widen the E
# edge"). T-203 widens it: E −93.6100 → −93.6070, +248 m east (the ticket's
# 200–300 m band). T-204 widens south: S 42.0120 → 42.0030, +1.0 km south
# (9.0e-3° through the pack's own transform ≈ 999.7 m — SUMMARY §3's planned
# "+1.0 km south" window, the town's garden gate): the whole Reiman Gardens
# grounds (the 414 × 475 m garden way, bbox south 42.00633), the conservatory
# (way/180765068), the ISU Vet Med campus and the south blocks + their trees
# come inside. T-205 widens north: N 42.0355 → 42.0780, +4.72 km north —
# past the whole Ada Hayden Heritage Park (relation 12032468, bbox lat
# 42.05999..42.07618: the ticket's twin-lakes/trail-ring acceptance criteria
# need the park AT data geometry and walkable, and SUMMARY §3's own +1.6 km
# north window (N 42.0500) stops ~2 km short of it — see the version
# history), landing the park + its Ada Hayden Road (bbox north 42.07794) +
# Grand Avenue's north end + the Moore Memorial / Inis Grove parks + The
# Cafe (2616 Northridge Pkwy, lat 42.04874) + the north residential blocks.
# W/S/E are the census/T-203/T-204 lines, untouched.
CORE = (-93.6590, 42.0030, -93.6070, 42.0780)  # game-core bbox W, S, E, N

# The v1 census east edge — the window the committed census classification
# (authored-buildings.csv) covers. Buildings east of it ride the census §6
# rule mechanically (see build_buildings); the const is also stamped into
# meta so consumers can derive strip membership from the pack alone.
CENSUS_V1_EAST = -93.6100

# The v2 south edge — the OTHER boundary the census CSV window sits inside
# (the v2 box = the CSV window grown east only). Buildings south of it ride
# the census §6 rule mechanically, the exact T-203 treatment mirrored; the
# const is stamped into meta the same way.
CENSUS_V2_SOUTH = 42.0120

# The v3 north edge — the third boundary the census CSV window sits inside
# (the v3 box = the CSV window grown east AND south). Buildings north of it
# ride the census §6 rule mechanically, the T-204 treatment mirrored once
# more; the const is stamped into meta the same way (T-205).
CENSUS_V3_NORTH = 42.0355

# --- coordinate convention (master plan §2) — THE transform -----------------

SCALE_LAT = 42.02  # equirectangular scale latitude
M_PER_DEG_LAT = 111074.0  # survey standard at 42.02 N (SUMMARY §1)
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(SCALE_LAT))  # ≈ 82,700 m/°
ORIGIN_LON = -93.65015  # Lincoln Way × Welch (survey verification §1 scan)
ORIGIN_LAT = 42.02278   # Lincoln Way mean lat in the Campustown window


def to_local(lon, lat):
    """WGS84 lon/lat -> local meters (x, z). +X east, −Z north. THE helper."""
    return (round((lon - ORIGIN_LON) * M_PER_DEG_LON, 2),
            round(-(lat - ORIGIN_LAT) * M_PER_DEG_LAT, 2))


def local_to_lonlat(x, z):
    """Local meters -> WGS84 lon/lat (inverse of to_local, unrounded)."""
    return (ORIGIN_LON + x / M_PER_DEG_LON,
            ORIGIN_LAT - z / M_PER_DEG_LAT)


def in_core(p, margin=0.0):
    return (CORE[0] - margin <= p[0] <= CORE[2] + margin
            and CORE[1] - margin <= p[1] <= CORE[3] + margin)


# --- census geometry helpers (verbatim rules from ames_census.py) -----------

def way_pts(w, nodes):
    return [nodes[n] for n in w.get("nodes", []) if n in nodes]


def bbox_center(pts):
    return ((min(p[0] for p in pts) + max(p[0] for p in pts)) / 2,
            (min(p[1] for p in pts) + max(p[1] for p in pts)) / 2)


def bbox_dims_m(pts):
    latc = (min(p[1] for p in pts) + max(p[1] for p in pts)) / 2
    return ((max(p[0] for p in pts) - min(p[0] for p in pts)) * m_per_deg_lon_at(latc),
            (max(p[1] for p in pts) - min(p[1] for p in pts)) * M_PER_DEG_LAT)


def m_per_deg_lon_at(lat):
    return 111320.0 * math.cos(math.radians(lat))


def is_closed(pts):
    return len(pts) >= 4 and pts[0] == pts[-1]


def ring_of(pts):
    return pts[:-1] if is_closed(pts) else pts


def shoelace_m2(pts):
    if len(pts) < 3:
        return 0.0
    xy = [to_local_lonlat_free(p) for p in pts]
    s = 0.0
    n = len(xy)
    for i in range(n):
        x1, y1 = xy[i]
        x2, y2 = xy[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0


def to_local_lonlat_free(p):
    """Unrounded planar projection (for areas/lengths; never stored)."""
    return ((p[0] - ORIGIN_LON) * M_PER_DEG_LON,
            -(p[1] - ORIGIN_LAT) * M_PER_DEG_LAT)


def segs_in_bbox(pts, bbox=CORE):
    """Sub-segments whose midpoint lies in bbox (the census in-core rule)."""
    out = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if bbox[0] <= mx <= bbox[2] and bbox[1] <= my <= bbox[3]:
            out.append((a, b))
    return out


def seg_len_m(a, b):
    ax, ay = to_local_lonlat_free(a)
    bx, by = to_local_lonlat_free(b)
    return math.hypot(bx - ax, by - ay)


def hav_m(a, b):
    """Haversine meters (analyze.py's hav — the survey's street-stat rule)."""
    p1, p2 = math.radians(a[1]), math.radians(b[1])
    dp = p2 - p1
    dl = math.radians(b[0] - a[0])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6371000.0 * math.asin(math.sqrt(h))


def named_highway_extra3_km(nodes, ways):
    """SUMMARY §3's '99.6 km of named street' — the extra3.py §5 rule verbatim:

    every way carrying a `highway` tag and a name, NODES filtered to the
    core bbox, haversine over the consecutive survivors. This is a survey
    statistic over a different node-filter than streets[] (it rejoins gaps
    across dropped nodes and folds cycleway/service/pedestrian into one
    sum); the pack carries it so the survey figure is derivable from
    committed data, while the streets[] graph itself pins the census §4
    midpoint rule (see build_streets).
    """
    total = 0.0
    by_class = {}
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        if "highway" not in t or not t.get("name"):
            continue
        pts = [p for p in way_pts(w, nodes)
               if CORE[1] <= p[1] <= CORE[3] and CORE[0] <= p[0] <= CORE[2]]
        ln = sum(hav_m(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
        by_class[t["highway"]] = by_class.get(t["highway"], 0.0) + ln
        total += ln
    return total, by_class


def seg_intersection(a, b, c, d):
    """Planar segment intersection; returns (x, y) lon/lat or None."""
    ax, ay = to_local_lonlat_free(a)
    bx, by = to_local_lonlat_free(b)
    cx, cy = to_local_lonlat_free(c)
    dx, dy = to_local_lonlat_free(d)
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


def runs_from_segments(segs):
    """Stitch midpoint-in-core segments into contiguous point runs.

    Each run becomes one polyline; runs partition the in-core segments, so
    summing run lengths reproduces the census's in-core length exactly.
    """
    if not segs:
        return []
    pts = [list(s[0]) for s in segs] + [list(segs[-1][1])]
    runs = []
    cur = [pts[0]]
    for i in range(len(segs)):
        a, b = segs[i]
        if cur[-1] == list(a):
            cur.append(list(b))
        else:
            runs.append(cur)
            cur = [list(a), list(b)]
    runs.append(cur)
    return runs


def run_local_m(run):
    return sum(seg_len_m(run[i], run[i + 1]) for i in range(len(run) - 1))


def poly_local(pts):
    """Store a lon/lat polyline as rounded local-meter points [[x, z], ...]."""
    return [[to_local(p[0], p[1])[0], to_local(p[0], p[1])[1]] for p in pts]


def polyline_km_local(points):
    """Length of a STORED (rounded, local) polyline, in km."""
    total = 0.0
    for i in range(len(points) - 1):
        total += math.hypot(points[i + 1][0] - points[i][0],
                            points[i + 1][1] - points[i][1])
    return total / 1000.0


# --- loading ----------------------------------------------------------------

def load_inputs():
    with open(MERGED, encoding="utf-8") as f:
        d = json.load(f)
    nodes = {int(k): tuple(v) for k, v in d["nodes"].items()}
    ways = {int(k): v for k, v in d["ways"].items()}
    rels = {int(k): v for k, v in d["relations"].items()}
    authored = {}
    with open(AUTHORED_CSV, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            authored[f"{row['osm_type']}/{row['osm_id']}"] = row
    with open(TAGGED_NODES, encoding="utf-8") as f:
        raw = json.load(f)
    tagged = {int(k): (v[0], v[1], v[2]) for k, v in raw.items()}
    return nodes, ways, rels, authored, tagged


# --- sections ---------------------------------------------------------------

ROAD_CLASSES = ("motorway", "trunk", "primary", "secondary", "tertiary",
                "unclassified", "residential", "living_street")

# Census §7.3 generator width defaults (OSM carries no lane/width detail for
# Ames — SUMMARY §10). motorway/trunk/unclassified/living_street have no
# in-core census row; they extend the same arterials-to-local ladder.
WIDTH_BY_CLASS = {
    "motorway": 24.0, "trunk": 20.0, "primary": 20.0, "secondary": 16.0,
    "tertiary": 13.0, "residential": 11.0, "unclassified": 11.0,
    "living_street": 9.0, "service": 7.0,
}

GREEN_TAGS = (("leisure", ("park", "garden")),
              ("natural", ("wood", "scrub")),
              ("landuse", ("recreation_ground", "forest", "grass", "meadow",
                           "village_green")))


def build_streets(nodes, ways):
    """Named drivable centerlines, midpoint-in-core segments, run-split."""
    entries = []
    km_census_rule = 0.0  # unrounded census method (meta audit field)
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        hw = t.get("highway")
        name = (t.get("name") or "").strip()
        if hw not in ROAD_CLASSES or not name:
            continue
        pts = way_pts(w, nodes)
        segs = segs_in_bbox(pts)
        if not segs:
            continue
        for a, b in segs:
            km_census_rule += seg_len_m(a, b)
        for run in runs_from_segments(segs):
            points = poly_local(run)
            km = polyline_km_local(points)
            entries.append({
                "name": name,
                "class": hw,
                "width_m": WIDTH_BY_CLASS[hw],
                "width_source": "census-§7.3-default",
                "km": round(km, 3),
                "points": points,
            })
    entries.sort(key=lambda e: (e["name"], e["class"], e["points"][0]))
    return entries, km_census_rule


def collect_building_set(nodes, ways, rels):
    """The census buildings mode: footprint bbox centroid inside the core."""
    blds = []
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        b = t.get("building")
        if not b or b == "no":
            continue
        pts = way_pts(w, nodes)
        if len(pts) < 2:
            continue
        c = bbox_center(pts)
        if in_core(c):
            blds.append({"id": f"way/{wid}", "tags": t, "pts": pts, "c": c})
    for rid in sorted(rels):
        r = rels[rid]
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
        if in_core(c):
            blds.append({"id": f"relation/{rid}", "tags": t, "pts": pts, "c": c})
    return blds


def flt(v):
    try:
        return float(str(v).strip())
    except (TypeError, ValueError):
        return None


# The census §6 class rule (ames_census.py buildings mode, verbatim key set):
# named -> authored-named; unnamed but use-tagged -> semi-tagged; else
# procedural. Applied ONLY to the strips' CSV-less buildings: the T-203 east
# strip (east of CENSUS_V1_EAST), the T-204 south strip (south of
# CENSUS_V2_SOUTH) and the T-205 north strip (north of CENSUS_V3_NORTH — the
# guards are disjoint, an SE-corner building counts in the east strip and an
# NE-corner one in the north strip, the first guard wins).
CENSUS_POI_TAGS = ("amenity", "shop", "leisure", "tourism", "historic",
                   "office", "craft", "healthcare", "man_made")


def census_class_of(tags):
    if (tags.get("name") or "").strip():
        return "authored-named"
    if any(tags.get(k) for k in CENSUS_POI_TAGS):
        return "semi-tagged"
    return "procedural"


def build_buildings(blds, authored_csv):
    entries = []
    missing_csv = []
    strip_n = {"authored-named": 0, "semi-tagged": 0, "procedural": 0}
    south_n = {"authored-named": 0, "semi-tagged": 0, "procedural": 0}
    north_n = {"authored-named": 0, "semi-tagged": 0, "procedural": 0}
    for b in sorted(blds, key=lambda x: x["id"]):
        row = authored_csv.get(b["id"])
        t = b["tags"]
        name = (t.get("name") or "").strip()
        if row is None:
            # The strips: the census CSV classified the v1 core only, and
            # every building OUTSIDE its window rides the census's OWN §6
            # rule, applied mechanically — named -> authored-named, unnamed
            # + POI tag -> semi-tagged, else procedural. East of the v1 edge
            # = the T-203 east strip; south of the v2 south edge = the T-204
            # south strip; north of the v3 north edge = the T-205 north
            # strip (disjoint: the east guard wins an SE-corner building,
            # the north guard an NE-corner one). The authored set stays
            # CLOSED: no hand curation ever happens here — a CSV-less
            # building inside ALL edges is census-window drift and
            # hard-fails.
            if b["c"][0] > CENSUS_V1_EAST:
                census_class = census_class_of(t)
                strip_n[census_class] += 1
            elif b["c"][1] < CENSUS_V2_SOUTH:
                census_class = census_class_of(t)
                south_n[census_class] += 1
            elif b["c"][1] > CENSUS_V3_NORTH:
                census_class = census_class_of(t)
                north_n[census_class] += 1
            else:
                missing_csv.append(b["id"])
                continue
        else:
            census_class = row["class"]
        dims = bbox_dims_m(b["pts"])
        x, z = to_local(*b["c"])
        entries.append({
            "id": b["id"],
            "name": name if name else None,
            "class": "authored" if census_class == "authored-named" else "procedural",
            "census_class": census_class,
            "levels": flt(t.get("building:levels")),
            "height_m": flt(t.get("height")),
            "centroid": [x, z],
            "bbox_m": [round(dims[0], 1), round(dims[1], 1)],
            "wgs84": [round(b["c"][0], 6), round(b["c"][1], 6)],
        })
    return entries, missing_csv, strip_n, south_n, north_n


def build_water(nodes, ways, rels):
    out = []
    # Lake LaVerne — relation 3329428, two chained outer ways (SUMMARY §7).
    for rid in sorted(rels):
        r = rels[rid]
        t = r.get("tags") or {}
        if rid != 3329428 and "laverne" not in (t.get("name") or "").lower():
            continue
        pts = []
        for m in r.get("members", []):
            if m.get("type") == "way" and m.get("ref") in ways:
                pts.extend(way_pts(ways[m["ref"]], nodes))
        area = shoelace_m2(pts)
        if not (10800.0 <= area <= 11300.0):  # V-12 settled 11,050 m²
            raise SystemExit(f"Lake LaVerne ring area out of band: {area:.0f} m2")
        cx, cz = to_local(*bbox_center(pts))
        out.append({
            "kind": "lake",
            "name": t.get("name") or "Lake LaVerne",
            "polygon": poly_local(pts),
            "area_m2": round(area),
            "bbox_m": [round(v, 1) for v in bbox_dims_m(pts)],
            "center": [cx, cz],
            "wgs84": [round(bbox_center(pts)[0], 6), round(bbox_center(pts)[1], 6)],
        })
        break
    # Named water bodies (T-205): every NAMED natural=water CLOSED way whose
    # bbox center sits in core and whose area clears 1 ha joins as a lake
    # entry. This is the north-Ames rule the twin-quarry-lake read needs:
    # Ada Hayden Lake (way/44802137, 52.1 ha over a 860 × 1125 m bbox — ONE
    # closed ring tracing both quarry lobes around the isthmus pinch) and
    # Arnold Lake (way/50107227, 2.0 ha farm pond at the park's SW). LaVerne
    # predates the rule (admitted above, by relation) and its own shoreline
    # ways are unnamed, so the two rules are disjoint. The lake ways'
    # `bank` field carries the shore character the survey's cluster note
    # gives ("flat quarry-banked shoreline", IMAGE_INDEX nature notes):
    # Ada Hayden = "quarry" (the bake paints its shore band pale gravel),
    # everything else the default mown shore.
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        if t.get("natural") != "water":
            continue
        name = (t.get("name") or "").strip()
        if not name:
            continue
        pts = way_pts(w, nodes)
        if not is_closed(pts):
            continue
        c = bbox_center(pts)
        if not in_core(c):
            continue
        area = shoelace_m2(ring_of(pts))
        if area < 10000.0:
            continue
        cx, cz = to_local(*c)
        out.append({
            "kind": "lake",
            "name": name,
            "bank": "quarry" if "hayden" in name.lower() else None,
            "polygon": poly_local(ring_of(pts)),
            "area_m2": round(area),
            "bbox_m": [round(v, 1) for v in bbox_dims_m(pts)],
            "center": [cx, cz],
            "wgs84": [round(c[0], 6), round(c[1], 6)],
        })
    # The named lakes join AFTER LaVerne (biggest first): the v3 list order
    # is load-bearing — the swan/gate consumers read the FIRST lake entry as
    # Lake LaVerne, so LaVerne keeps index 0 exactly as the v1/v2/v3 packs
    # carried it.
    named_lakes = [e for e in out if e.get("name") != "Lake LaVerne"]
    laverne = [e for e in out if e.get("name") == "Lake LaVerne"]
    named_lakes.sort(key=lambda e: -e["area_m2"])
    out = laverne + named_lakes
    # College / Ioway Creek centerlines (mapped waterway lines, in core).
    for creek in ("College Creek", "Ioway Creek"):
        runs = []
        km = 0.0
        for wid in sorted(ways):
            w = ways[wid]
            t = w.get("tags") or {}
            if t.get("name") != creek or not t.get("waterway"):
                continue
            segs = segs_in_bbox(way_pts(w, nodes))
            if not segs:
                continue
            for a, b in segs:
                km += seg_len_m(a, b)
            for run in runs_from_segments(segs):
                points = poly_local(run)
                if polyline_km_local(points) > 0.005:  # drop sub-5 m slivers
                    runs.append(points)
        runs.sort(key=lambda p: (p[0], p[-1]))
        out.append({
            "kind": "creek",
            "name": creek,
            "centerlines": runs,
            "width_m": 6.0,
            "width_source": "default",
            "in_core_km": round(km / 1000.0, 2),
        })
    return out


def build_rail(nodes, ways):
    """UP Clinton Sub main line + every vehicular road crossing (census §5b)."""
    main_runs = []
    km = 0.0
    rail_segs = []
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        # census §5b crossing scan covers rail/light_rail/tram/abandoned/disused
        if t.get("railway") not in ("rail", "light_rail", "tram", "abandoned",
                                    "disused"):
            continue
        is_main = (t.get("railway") == "rail"
                   and t.get("usage") == "main"
                   and not t.get("service")
                   and "clinton" in (t.get("name") or t.get("operator") or "").lower())
        segs = segs_in_bbox(way_pts(w, nodes))
        if not segs:
            continue
        rail_segs.extend((a, b, t) for a, b in segs)
        if is_main:
            for a, b in segs:
                km += seg_len_m(a, b)
            for run in runs_from_segments(segs):
                points = poly_local(run)
                if polyline_km_local(points) > 0.005:
                    main_runs.append(points)
    main_runs.sort(key=lambda p: (p[0], p[-1]))
    # Vehicular road segments (census VEH set), midpoint-in-core.
    veh = ROAD_CLASSES + ("service",)
    crossings = []
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        if t.get("highway") not in veh:
            continue
        pts = way_pts(w, nodes)
        for a, b in segs_in_bbox(pts):
            for c, d, rt2 in rail_segs:
                p = seg_intersection(a, b, c, d)
                if not p:
                    continue
                # census grade rule: bridge/tunnel or layer != 0 on either side
                gsep = any(x in (t, rt2) for x in ("bridge", "tunnel")) or \
                    t.get("layer") not in (None, "0") or rt2.get("layer") not in (None, "0")
                crossings.append({
                    "pos": [round(p[0], 2), round(p[1], 2)],
                    "wgs84": [round(v, 6) for v in local_to_lonlat(p[0], p[1])],
                    "road_name": (t.get("name") or "").strip(),
                    "road_class": t.get("highway"),
                    "grade": "separated" if gsep else "at_grade",
                    "rail": rt2.get("name") or rt2.get("operator") or "rail",
                })
    # census dedup: same road name+class within 20 m
    crossings.sort(key=lambda c: (c["road_name"], c["road_class"],
                                  round(c["wgs84"][0], 4), round(c["wgs84"][1], 4)))
    kept = []
    for cr in crossings:
        dup = False
        for k in kept:
            if (k["road_name"] == cr["road_name"]
                    and k["road_class"] == cr["road_class"]
                    and math.hypot(k["pos"][0] - cr["pos"][0],
                                   k["pos"][1] - cr["pos"][1]) < 20):
                dup = True
                break
        if not dup:
            kept.append(cr)
    kept.sort(key=lambda c: (0 if c["grade"] == "at_grade" else 1,
                             -c["wgs84"][1], c["road_name"]))
    return {
        "name": "UP Clinton Subdivision",
        "centerlines": main_runs,
        "in_core_km": round(km / 1000.0, 2),
        "crossings": kept,
    }


def build_parks(nodes, ways, rels, lakes):
    entries = []
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        hit = any(t.get(k) in vals for k, vals in GREEN_TAGS)
        if not hit:
            continue
        pts = way_pts(w, nodes)
        if len(pts) < 4 or not is_closed(pts):
            continue
        c = bbox_center(pts)
        if not in_core(c):
            continue
        name = (t.get("name") or "").strip()
        area = shoelace_m2(ring_of(pts))
        if not name and area < 50000.0:  # unnamed green: only the big set
            continue
        cx, cz = to_local(*c)
        entries.append({
            "name": name if name else None,
            "polygon": poly_local(ring_of(pts)),
            "area_m2": round(area),
            "center": [cx, cz],
            "wgs84": [round(c[0], 6), round(c[1], 6)],
        })
    # Named leisure=park RELATIONS north of the v3 edge (T-205): the north
    # parks' multipolygon law. Ada Hayden Heritage Park (relation 12032468 —
    # one 180-ha outer ring, the city's full 437-acre bought tract; the
    # city's own "~190 acres" figure is the DEVELOPED park inside it),
    # Moore Memorial Park (14721919 — TWO DISJOINT outer rings) and Charles
    # & June Calhoun Park (12463402) are mapped as relations, not tagged
    # ways, so the ways-only census rule above never saw them. One entry per
    # closed outer ring (a disjoint two-ring park lands two entries under
    # one name — chaining disjoint rings would corrupt the shoelace and the
    # bake's ring split); the census's ways-only rule south of the line is
    # untouched (Emma McCarthy Lee Park, already in-core but relation-mapped,
    # stays a recorded data grain of the pre-v4 rule).
    for rid in sorted(rels):
        r = rels[rid]
        t = r.get("tags") or {}
        if t.get("leisure") != "park" or not (t.get("name") or "").strip():
            continue
        member_rings = []
        for m in r.get("members", []):
            if m.get("type") != "way" or m.get("ref") not in ways:
                continue
            pts = way_pts(ways[m["ref"]], nodes)
            if len(pts) >= 4 and is_closed(pts):
                member_rings.append(ring_of(pts))
        if not member_rings:
            continue
        all_pts = [p for ring in member_rings for p in ring]
        c = bbox_center(all_pts)
        if not in_core(c) or c[1] <= CENSUS_V3_NORTH:
            continue
        name = t["name"].strip()
        for ring in member_rings:
            area = shoelace_m2(ring)
            cx, cz = to_local(*bbox_center(ring))
            entries.append({
                "name": name,
                "polygon": poly_local(ring),
                "area_m2": round(area),
                "center": [cx, cz],
                "wgs84": [round(bbox_center(ring)[0], 6),
                          round(bbox_center(ring)[1], 6)],
            })
    # Park-lake hole cut (T-205): a park ring that strictly contains a named
    # lake gives that lake its water flat back — the bake's flats stack lawn
    # ABOVE water, so the uncut polygon would paint mown lawn over the whole
    # lake. The keyhole-splice cut lands one simple bridged ring (see
    # cut_ring_holes); the entry records what it lost.
    lake_rings = [(l.get("name") or "", [tuple(p) for p in l["polygon"]])
                  for l in lakes if l.get("kind") == "lake"]
    for e in entries:
        poly = [tuple(p) for p in e["polygon"]]
        holes = [hr for nm, hr in lake_rings
                 if all(_point_in_ring(p, poly) for p in hr)]
        if holes:
            e["polygon"] = [list(p) for p in cut_ring_holes(poly, holes)]
            e["area_m2"] = round(_ring_abs_area_local(
                [(p[0], p[1]) for p in e["polygon"]]))
            e["holes_cut"] = [nm for nm, hr in lake_rings if hr in holes]
    entries.sort(key=lambda e: -e["area_m2"])
    return entries


# --- park-lake hole cutting (T-205) -----------------------------------------
#
# The Ada Hayden park ring CONTAINS its twin-quarry lake (52.1 ha inside the
# 180-ha tract), and the bake's flats stack lawn (y 0.04) ABOVE water
# (y 0.02) — an uncut park polygon would paint mown lawn over the whole
# lake. The bake has no hole concept (its ring split sees only chained
# loops), so the distiller cuts the hole structurally: the classic keyhole
# splice — the hole's eastmost vertex bridges EAST to the nearest outer-edge
# crossing, the hole walks once inside the outer ring, and the two seam
# vertex pairs (P, E) get a 3 cm epsilon so their stored keys stay distinct
# (the bake's ring-split can never re-split the loop, and a 3 cm slit is
# sub-visible at park scale). Area conservation is asserted: the bridged
# ring's shoelace must equal outer minus hole within 0.1 %.

HOLE_EPS_M = 0.03  # the seam epsilon (m) — 3 grid steps at the 0.01 rounding


def _ring_pts_local(ring_lonlat):
    return [to_local_lonlat_free(p) for p in ring_lonlat]


def _ring_area_local(pts):
    s = 0.0
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def _ring_abs_area_local(pts):
    return abs(_ring_area_local(pts))


def _point_in_ring(pt, ring):
    """Even-odd point-in-ring (planar local meters)."""
    x, y = pt
    inside = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > y) != (yj > y):
            x_at = xj + (y - yj) / (yi - yj) * (xi - xj)
            if x < x_at:
                inside = not inside
        j = i
    return inside


def _cut_one_hole(outer, hole):
    """Splice one hole ring out of an outer ring (local meters)."""
    e_i = max(range(len(hole)), key=lambda i: (hole[i][0], hole[i][1]))
    ex, ey = hole[e_i]
    best = None  # (dist, j, px) — nearest strictly-east outer-edge crossing
    n = len(outer)
    for j in range(n):
        ax, ay = outer[j]
        bx, by = outer[(j + 1) % n]
        if (ay - ey) == 0 or (by - ey) == 0:
            continue  # an endpoint ON the ray — skip the degenerate straddle
        if (ay > ey) == (by > ey):
            continue
        px = ax + (ey - ay) / (by - ay) * (bx - ax)
        if px <= ex:
            continue
        if best is None or (px - ex) < best[0] - 1e-9:
            best = (px - ex, j, px)
    if best is None:
        raise SystemExit("cut_ring_holes: east ray found no outer crossing — "
                         "hole is not strictly inside the outer ring")
    _, j, px = best
    # The hole must traverse OPPOSITE the outer for the shoelace subtraction.
    if (_ring_area_local(outer) >= 0.0) == (_ring_area_local(hole) >= 0.0):
        hole = list(reversed(hole))
        e_i = max(range(len(hole)), key=lambda i: (hole[i][0], hole[i][1]))
        ex, ey = hole[e_i]
    out = outer[:j + 1]
    out.append((px, ey))            # P — seam split on the outer edge
    out.append((ex, ey))            # E — the bridge out to the hole
    for k in range(1, len(hole)):   # the hole WITHOUT its E vertex — the
        out.append(hole[(e_i + k) % len(hole)])  # walk must NOT revisit E,
        # or the ring split at the bake would re-cut the hole loop out.
    out.append((ex, ey - HOLE_EPS_M))   # E' — 3 cm south of E (distinct key)
    out.append((px, ey - HOLE_EPS_M))   # P' — 3 cm south of P
    out.extend(outer[j + 1:])
    return out


def cut_ring_holes(outer_local, holes_local):
    """Cut strictly-contained lake rings out of a park ring (LOCAL meters
    in and out — one simple bridged ring). Asserts the area law: the
    bridged ring's shoelace must equal outer minus holes within 0.1 %."""
    for hr in holes_local:
        if not all(_point_in_ring(p, outer_local) for p in hr):
            raise SystemExit("cut_ring_holes: a hole ring is not strictly "
                             "inside the park ring — refusing a partial cut")
    ring = list(outer_local)
    for hr in sorted(holes_local, key=_ring_abs_area_local, reverse=True):
        ring = _cut_one_hole(ring, hr)
    got = _ring_abs_area_local(ring)
    want = _ring_abs_area_local(outer_local) - sum(_ring_abs_area_local(h)
                                                   for h in holes_local)
    if want <= 0.0 or abs(got - want) > want * 0.001:
        raise SystemExit(f"cut_ring_holes: bridged area {got:.0f} m2 not the "
                         f"outer-minus-holes {want:.0f} m2 (0.1% band)")
    return [(round(p[0], 2), round(p[1], 2)) for p in ring]


# --- trails (T-205): the R5-north parks' mapped trail runs -------------------

TRAIL_KINDS = ("footway", "path", "cycleway", "pedestrian")

# The parks whose mapped trails join the pack (T-205's What list: Ada Hayden
# as the trail-ring hero, Inis Grove + Moore Memorial as green massing +
# trails). Name-matched against the parks section (ways AND relation rings).
NORTH_TRAIL_PARKS = ("Ada Hayden Heritage Park", "Inis Grove Park",
                     "Moore Memorial Park")


def build_trails(nodes, ways, parks):
    """Trail runs (footway/path/cycleway/pedestrian) whose midpoints sit
    inside a north-park ring AND in core, stitched per way like streets.
    Park rings are the pack's OWN stored local-meter polygons."""
    park_rings = [(e["name"], [(float(p[0]), float(p[1])) for p in e["polygon"]])
                  for e in parks if e.get("name") in NORTH_TRAIL_PARKS]
    entries = []
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        kind = t.get("highway")
        if kind not in TRAIL_KINDS:
            continue
        pts = way_pts(w, nodes)
        segs = []
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            if not in_core((mx, my)):
                continue
            p = to_local(mx, my)
            for _, ring in park_rings:
                if _point_in_ring(p, ring):
                    segs.append((a, b))
                    break
        for run in runs_from_segments(segs):
            points = poly_local(run)
            km = polyline_km_local(points)
            if km < 0.005:  # drop sub-5 m slivers
                continue
            mid = bbox_center(run)
            park_name = None
            for nm, ring in park_rings:
                if _point_in_ring(to_local(*mid), ring):
                    park_name = nm
                    break
            if park_name is None:
                continue
            entries.append({
                "park": park_name,
                "kind": kind,
                "km": round(km, 3),
                "points": points,
            })
    entries.sort(key=lambda e: (e["park"], e["kind"], e["points"][0]))
    return entries


def build_trees(tagged):
    pts = []
    for nid in sorted(tagged):
        lon, lat, t = tagged[nid]
        if t.get("natural") == "tree" and in_core((lon, lat)):
            x, z = to_local(lon, lat)
            pts.append([x, z])
    return pts


# --- parking lots (T-182): the census §3 amenity=parking stock, verbatim ----
#
# Census rule (ames_census.py mode "campus", the parking census block): every
# amenity=parking WAY with a bbox center in core (polygon areas by shoelace;
# non-closed ways area 0) PLUS every cached tagged NODE with amenity=parking
# in core (area 0 — unmapped-position lot). That exact rule reproduces the
# census §3 record: 480 areas / 73.6 ha, 19 lots / 8.9 ha in the Iowa State
# Center tailgate zone (lat < 42.0225, lon −93.6445…−93.6260 — the game's
# tailgate stock). The `kind` field carries the OSM `parking` subtype —
# `street_side` / `lane` are the CURB bay stock the T-182 curb re-target
# marks the graph runs from; `surface` / `multi-storey` are the lot stock.

TAILGATE_LON_W = -93.6445  # census §3 tailgate window (lon W..E, lat < N)
TAILGATE_LON_E = -93.6260
TAILGATE_LAT_N = 42.0225


def build_parking(nodes, ways, tagged):
    entries = []
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        if t.get("amenity") != "parking":
            continue
        pts = way_pts(w, nodes)
        if len(pts) < 3:
            continue
        c = bbox_center(pts)
        if not in_core(c):
            continue
        area = shoelace_m2(ring_of(pts)) if is_closed(pts) else 0.0
        cx, cz = to_local(*c)
        entries.append({
            "id": "way/" + str(wid),
            "kind": (t.get("parking") or "").strip() or None,
            "name": (t.get("name") or "").strip() or None,
            "polygon": poly_local(ring_of(pts)) if is_closed(pts) else [],
            "area_m2": round(area),
            "center": [cx, cz],
            "wgs84": [round(c[0], 6), round(c[1], 6)],
        })
    node_entries = []
    for nid in sorted(tagged):
        lon, lat, t = tagged[nid]
        if not isinstance(t, dict) or t.get("amenity") != "parking":
            continue
        if not in_core((lon, lat)):
            continue
        x, z = to_local(lon, lat)
        node_entries.append({
            "id": "node/" + str(nid),
            "kind": (t.get("parking") or "").strip() or None,
            "name": (t.get("name") or "").strip() or None,
            "polygon": [],
            "area_m2": 0,
            "center": [x, z],
            "wgs84": [round(lon, 6), round(lat, 6)],
        })
    entries.sort(key=lambda e: (-e["area_m2"], e["id"]))
    entries.extend(node_entries)
    return entries


def parking_tailgate(lots):
    """The census §3 tailgate-zone slice (the game's tailgate stock)."""
    return [e for e in lots
            if e["wgs84"][1] < TAILGATE_LAT_N
            and TAILGATE_LON_W < e["wgs84"][0] < TAILGATE_LON_E]


# --- POIs: the 48 venues (VENUES.md) + the landmark list (LANDMARKS §5) ----
#
# Anchors resolve at distill time from the COMMITTED data:
#   ("way", id)      -> footprint bbox center from ames_merged.json
#   ("relation", id) -> bbox center over member ways (ames_merged.json)
#   ("node", id)     -> position from census/tagged-nodes-core.json
#   ("lit", (lon,lat)) -> literal coordinate recorded in a committed survey doc
#   None             -> unplaced (the survey records no position; addr kept)
# Every row names the committed doc it came from. T-171 is data plumbing over
# the survey — no new research, no invented coordinates.

CAMPUS_ANCHOR_TRIAD_LAT = 42.02278  # Lincoln Way (verification §1)
WELCH_LON = -93.65015               # Welch centerline (verification §1)


def _venue(slug, name, tier, address, anchor, src, note=None):
    return {"slug": slug, "name": name, "kind": "venue", "tier": tier,
            "address": address, "anchor": anchor, "src": src, "note": note}


def venue_table():
    v = []
    # --- Tier 1 (14; anchors per BUILD-CENSUS.md §2 table)
    v.append(_venue("welch_ave_station", "Welch Ave Station", 1, "207 Welch Ave",
                    ("node", 2531586094),
                    "census §2: addr node (named Pizza Pit — same building)"))
    v.append(_venue("paddys_irish_pub", "Paddy's Irish Pub", 1, "124 Welch Ave",
                    ("node", 1941751171), "census §2: amenity=bar node"))
    v.append(_venue("cys_roost", "Cy's Roost", 1, "121 Welch Ave",
                    ("way", 241365820), "census §2: way anchor (exact)"))
    v.append(_venue("sips", "Sips", 1, "126 Welch Ave",
                    ("node", 8530394477), "census §2: node (Paddy's basement)"))
    v.append(_venue("mickeys_irish_pub", "Mickey's Irish Pub", 1, "109 Welch Ave",
                    ("node", 2531586091), "census §2: amenity=pub node + addr"))
    v.append(_venue("ajs_ultra_lounge", "AJ's Ultra Lounge", 1, "2401 Chamberlain St",
                    ("way", 246079558), "census §2: way anchor (exact)"))
    v.append(_venue("outlaws", "Outlaws", 1, "2522 Chamberlain St",
                    ("way", 272522425), "census §2: way anchor (exact)"))
    v.append(_venue("cafe_beaudelaire", "Café Beaudelaire", 1, "2504 Lincoln Way",
                    ("node", 2400994656), "census §2: amenity=cafe node + addr"))
    v.append(_venue("jeffs_pizza_shop", "Jeff's Pizza Shop", 1, "2402 Lincoln Way",
                    ("node", 2447728161), "census §2: amenity=restaurant node + addr"))
    v.append(_venue("mr_burrito", "Mr. Burrito", 1, "2508 Lincoln Way",
                    ("node", 2531586092), "census §2: addr node"))
    v.append(_venue("superdog", "Superdog", 1, "208 Welch Ave (cart)",
                    ("curb_rule", None),
                    "census §2: cart prop at the 200-block east curb across "
                    "Kum & Go — Welch centerline + half the residential width, "
                    "at the Kum & Go frontage lat",
                    "hand-placed prop, not an OSM feature"))
    v.append(_venue("hickory_park", "Hickory Park", 1, "1404 S Duff Ave",
                    ("way", 196541966),
                    "census §2: way anchor (exact); out of core, 220 m south"))
    v.append(_venue("the_cafe", "The Cafe", 1, "2616 Northridge Pkwy",
                    ("node", 1292348200),
                    "census §2: node anchor; ~1.5 km north of the core"))
    v.append(_venue("great_plains_sauce_dough", "Great Plains Sauce & Dough Co.",
                    1, "129 Main St", ("way", 237834149),
                    "census §2: way anchor (exact)"))
    # --- Tier 2 (17)
    v.append(_venue("mothers_pub_coffee", "Mother's Pub & Coffee", 2, "2900 West St",
                    ("way", 251728629), "census §2: way anchor (exact)"))
    v.append(_venue("thumbs", "Thumbs", 2, "2816 West St",
                    ("way", 251728624), "census §2: way anchor (exact)"))
    v.append(_venue("west_street_deli", "West Street Deli", 2, "2810 West St",
                    ("way", 251728626), "census §2: way anchor (exact)"))
    v.append(_venue("bnc_field_house", "BNC Field House", 2, "206 Welch Ave",
                    ("way", 241365816), "census §2: way anchor (exact)"))
    v.append(_venue("blue_owl_bar", "Blue Owl Bar", 2, "223 Welch Ave",
                    ("node", 2445161035), "census §2: named node"))
    v.append(_venue("cornbred_barbecue", "Cornbred Barbecue", 2, "526 Main St",
                    ("node", 8395552560), "census §2: depot node + addr"))
    v.append(_venue("whiskey_river", "Whiskey River", 2, "134 Main St",
                    ("way", 269752175), "census §2: way anchor (exact)"))
    v.append(_venue("london_underground", "London Underground", 2, "212 Main St",
                    ("way", 269752154), "census §2: way anchor (exact)"))
    v.append(_venue("time_out", "Time Out", 2, "120 Kellogg Ave",
                    ("way", 236565187), "census §2: way anchor (exact)"))
    v.append(_venue("mucky_duck_pub", "The Mucky Duck Pub", 2, "3100 S Duff Ave",
                    None, "census §2: NO OSM anchor anywhere in the extract"))
    v.append(_venue("torrent_brewing", "Torrent Brewing Company", 2, "504 Burnett Ave",
                    ("way", 931902030), "census §2: way anchor (exact)"))
    v.append(_venue("aunt_maudes", "Aunt Maude's", 2, "547 Main St",
                    ("node", 5064244865), "census §2: node + addr"))
    v.append(_venue("grove_cafe", "The Grove Cafe", 2, "124 Main St",
                    ("way", 269752153), "census §2: way anchor (exact)"))
    v.append(_venue("provisions_lot_f", "Provisions Lot F", 2, "2400 N Loop Dr",
                    ("way", 846310912),
                    "census §2: way anchor (exact); out of core, S research park"))
    v.append(_venue("the_stan_tap", "The Stan Tap", 2, "216 Stanton Ave",
                    ("way", 273536249),
                    "census §2: addr way (unnamed ex-Es Tas building); "
                    "centroid from ames_merged.json"))
    v.append(_venue("sams_place", "Sam's Place", 2, "125 Main St",
                    ("way", 237834143), "census §2: way anchor (exact)"))
    v.append(_venue("lost_and_found_lounge", "Lost and Found Lounge", 2,
                    "121 Welch Ave (upper)", ("way", 241365820),
                    "census §2: shares the Cy's Roost way"))
    # --- Tier 3 (17)
    v.append(_venue("stomping_grounds", "Stomping Grounds Cafe", 3, "303 Welch Ave",
                    ("node", 1933284322),
                    "tagged-nodes-core.json: named addr node (Bar La Tosca room)"))
    v.append(_venue("clouds", "Clouds", 3, "119 Stanton Ave (Legacy Tower, 7th floor)",
                    ("way", 236800162),
                    "census appendix: Legacy Tower way (V-16: 7th floor)"))
    v.append(_venue("labyrinth_coffee", "Labyrinth Coffee", 3, "159 Sheldon Ave",
                    None, "VENUES §3.3/§7: UNVERIFIED exact suite — unplaced"))
    v.append(_venue("ichiban", "Ichiban Japanese Restaurant", 3, "117 Welch Ave",
                    ("way", 231767126), "census appendix: way"))
    v.append(_venue("blue_fish_poke", "Blue Fish Poke Bowl", 3, "127 Welch Ave",
                    ("node", 8530394479), "tagged-nodes-core.json: named addr node"))
    v.append(_venue("macubana", "Macubana", 3, "116 Welch Ave",
                    ("way", 241365821), "census appendix: way"))
    v.append(_venue("dogtown_university", "Dogtown University", 3,
                    "217 Welch Ave (Welch Crown Center)",
                    ("way", 377558129), "census appendix: Welch Crown Center way"))
    v.append(_venue("thai_kitchen", "Thai Kitchen", 3, "2410 Chamberlain St",
                    ("node", 2533115029), "tagged-nodes-core.json: named addr node"))
    v.append(_venue("szechuan_house", "Szechuan House", 3, "3605 Lincoln Way",
                    ("lit", (WELCH_LON - 1440.0 / M_PER_DEG_LON, CAMPUS_ANCHOR_TRIAD_LAT + 8.0 / M_PER_DEG_LAT)),
                    "VENUES §3.9 (QA fix): north side, ~1.4 km west of Welch — "
                    "doc-interpolated on the Lincoln Way line"))
    v.append(_venue("restaurant_888", "888 Restaurant", 3, "809 Wheeler St Ste 106",
                    None, "VENUES §3.10: north Ames; no committed position"))
    v.append(_venue("el_azteca", "El Azteca", 3, "2727 Stange Rd / 2120 Isaac Newton Dr",
                    None, "VENUES §3.11: two locations; no committed position"))
    v.append(_venue("carlos_quesadilla", "Carlos Quesadilla", 3, "food truck",
                    ("lit", (-93.63576, 42.01401)),
                    "VENUES §3.12: truck — gameday spot inside Jack Trice Stadium "
                    "(SUMMARY §9 stadium center)",
                    "truck prop; gameday position"))
    v.append(_venue("isu_creamery", "Iowa State Creamery", 3,
                    "536 Farm House Lane (Food Sciences Bldg 2953)",
                    ("relation", 2507887), "census appendix: Food Sciences relation"))
    v.append(_venue("perfect_games", "Perfect Games", 3, "1320 Dickinson Ave",
                    None, "VENUES §3.14: north Ames; no committed position"))
    v.append(_venue("whatcha_smokin", "Whatcha Smokin' BBQ", 3,
                    "403 Iowa Ave, Luther IA", None,
                    "VENUES §3.15: out of Ames entirely — unplaced"))
    v.append(_venue("morning_bell", "Morning Bell Coffee Roasters", 3,
                    "111 Main St Ste 101", ("name", "Morning Bell Coffee Roasters"),
                    "census appendix row; resolved by unique building name"))
    v.append(_venue("cafe_diem", "Cafe Diem", 3, "229 Main St",
                    ("name", "Cafe Diem"),
                    "census appendix row; resolved by unique building name"))
    return v


def _landmark(slug, name, rank, anchor, src, note=None):
    return {"slug": slug, "name": name, "kind": "landmark", "tier": rank,
            "address": None, "anchor": anchor, "src": src, "note": note}


def landmark_table():
    l = []
    # LANDMARKS.md §5 "Top 15 from the air" (rank = tier); coordinates from
    # the committed census/SUMMARY/verification docs.
    l.append(_landmark("jack_trice_stadium", "Jack Trice Stadium", 1,
                       ("way", 613735866), "census appendix: bowl way 183x208 m"))
    l.append(_landmark("hilton_coliseum", "Hilton Coliseum", 2,
                       ("way", 180651868), "census appendix: way 138x105 m"))
    l.append(_landmark("lake_laverne", "Lake LaVerne", 3,
                       ("lit", (-93.64792, 42.02354)),
                       "verification V-12 settled center"))
    l.append(_landmark("campanile", "Campanile", 4,
                       ("way", 183041212),
                       "census §3: way 183041212 — SENTINEL (−93.64604, 42.02543)"))
    l.append(_landmark("central_campus", "Central Campus lawn", 5,
                       ("way", 486943973), "census §5: the quad lawn way"))
    l.append(_landmark("marston_water_tower", "Marston Water Tower", 6,
                       ("way", 861201396), "census appendix: way (51.2 m)"))
    l.append(_landmark("beardshear_hall", "Beardshear Hall", 7,
                       ("way", 33725619), "census appendix: way (green dome)"))
    l.append(_landmark("memorial_union", "Memorial Union", 8,
                       ("way", 183224150),
                       "census §3: way 183224150 — SENTINEL (2229 Lincoln Way, "
                       "NORTH of it)"))
    l.append(_landmark("parks_library", "Parks Library", 9,
                       ("way", 33725897), "census appendix: way"))
    l.append(_landmark("reiman_gardens", "Reiman Gardens", 10,
                       ("lit", (-93.63832, 42.01057)),
                       "SUMMARY §9; out of core, 1 km south"))
    l.append(_landmark("ada_hayden", "Ada Hayden Heritage Park", 11,
                       ("lit", (-93.63095, 42.06808)),
                       "SUMMARY §9; out of core, north Ames"))
    l.append(_landmark("up_main_line", "UP Clinton Subdivision main line", 12,
                       ("rail_duff_crossing", None),
                       "census §5: the downtown at-grade set; positioned at the "
                       "Duff Ave crossing (the busiest)"))
    l.append(_landmark("downtown_bandshell", "Downtown grid + Bandshell Park", 13,
                       ("lit", (-93.60960, 42.02649)),
                       "census §5: Bandshell Park center (just east of the core "
                       "edge; R5 bbox-east ticket lands it)"))
    l.append(_landmark("grain_elevators", "Grain elevator cluster (SE)", 14,
                       None,
                       "LANDMARKS T7 / V-30: heights AND positions unmapped/"
                       "unknowable — unplaced"))
    l.append(_landmark("ames_airport", "Ames Municipal Airport (KAMW)", 15,
                       ("lit", (-93.62188, 41.99047)),
                       "SUMMARY §9; out of core, south"))
    return l


def resolve_anchor(anchor, nodes, ways, rels, tagged, rail):
    """Anchor tuple -> (lon, lat) or None (unplaced)."""
    if anchor is None:
        return None
    kind, ref = anchor
    if kind == "way":
        w = ways.get(int(ref))
        if w is None:
            raise SystemExit(f"anchor way {ref} not in ames_merged.json")
        return bbox_center(way_pts(w, nodes))
    if kind == "relation":
        r = rels.get(int(ref))
        if r is None:
            raise SystemExit(f"anchor relation {ref} not in ames_merged.json")
        pts = []
        for m in r.get("members", []):
            if m.get("type") == "way" and m.get("ref") in ways:
                pts.extend(way_pts(ways[m["ref"]], nodes))
        if not pts:
            raise SystemExit(f"anchor relation {ref} has no resolvable member ways")
        return bbox_center(pts)
    if kind == "node":
        if int(ref) not in tagged:
            raise SystemExit(f"anchor node {ref} not in tagged-nodes-core.json")
        lon, lat, _ = tagged[int(ref)]
        return (lon, lat)
    if kind == "lit":
        return (ref[0], ref[1])
    if kind == "name":
        hits = []
        for wid in sorted(ways):
            w = ways[wid]
            t = w.get("tags") or {}
            if t.get("building") and (t.get("name") or "").strip() == ref:
                pts = way_pts(w, nodes)
                if len(pts) >= 2 and in_core(bbox_center(pts)):
                    hits.append(bbox_center(pts))
        if len(hits) != 1:
            raise SystemExit(f"anchor name '{ref}' resolved to {len(hits)} "
                             f"in-core buildings (need exactly 1)")
        return hits[0]
    if kind == "curb_rule":
        # Superdog cart: 200-block EAST curb across Kum & Go (census §2).
        kum_lonlat = (-93.650558, 42.021245)  # census appendix, Kum & Go way
        curb_lon = WELCH_LON + (WIDTH_BY_CLASS["residential"] / 2.0) / m_per_deg_lon_at(CAMPUS_ANCHOR_TRIAD_LAT)
        return (curb_lon, kum_lonlat[1])
    if kind == "rail_duff_crossing":
        for cr in rail["crossings"]:
            if cr["road_name"] == "Duff Avenue" and cr["grade"] == "at_grade":
                return (cr["wgs84"][0], cr["wgs84"][1])
        raise SystemExit("rail_duff_crossing anchor: no Duff Avenue at-grade crossing")
    raise SystemExit(f"unknown anchor kind {kind}")


def build_pois(nodes, ways, rels, tagged, rail, streets):
    entries = []
    for table in (venue_table(), landmark_table()):
        for row in table:
            lonlat = resolve_anchor(row["anchor"], nodes, ways, rels, tagged, rail)
            placed = lonlat is not None
            facing = 0.0
            facing_src = "unplaced" if not placed else None
            if placed:
                x, z = to_local(*lonlat)
                facing, facing_src, _ = nearest_street_local(streets, x, z)
                entries.append({
                    "id": row["slug"],
                    "name": row["name"],
                    "kind": row["kind"],
                    "tier": row["tier"],
                    "address": row["address"],
                    "position": [x, z],
                    "wgs84": [round(lonlat[0], 6), round(lonlat[1], 6)],
                    "facing_deg": facing,
                    "facing_src": facing_src,
                    "in_core": in_core(lonlat),
                    "placed": True,
                    "src": row["src"],
                    "note": row["note"],
                })
            else:
                entries.append({
                    "id": row["slug"],
                    "name": row["name"],
                    "kind": row["kind"],
                    "tier": row["tier"],
                    "address": row["address"],
                    "position": None,
                    "wgs84": None,
                    "facing_deg": None,
                    "facing_src": "unplaced",
                    "in_core": False,
                    "placed": False,
                    "src": row["src"],
                    "note": row["note"],
                })
    entries.sort(key=lambda e: (e["kind"], e["tier"], e["id"]))
    return entries


def nearest_street_local(streets, x, z):
    """Compass facing (0=N/−Z, 90=E/+X) toward the nearest centerline point."""
    best = (None, None, None, None)  # dist2, name, px, pz
    for e in streets:
        pts = e["points"]
        for i in range(len(pts) - 1):
            ax, az = pts[i]
            bx, bz = pts[i + 1]
            dx, dz = bx - ax, bz - az
            l2 = dx * dx + dz * dz
            if l2 < 1e-12:
                px, pz = ax, az
            else:
                t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / l2))
                px, pz = ax + t * dx, az + t * dz
            d2 = (x - px) * (x - px) + (z - pz) * (z - pz)
            if best[0] is None or d2 < best[0]:
                best = (d2, e["name"], px, pz)
    if best[0] is None:
        return 0.0, "none", None
    facing = math.degrees(math.atan2(best[2] - x, -(best[3] - z)))
    facing = (facing + 360.0) % 360.0
    return round(facing, 1), f"nearest_street:{best[1]}", math.sqrt(best[0])


# --- pack assembly ----------------------------------------------------------

CENSUS_PINNED = {
    # v4 counts — the T-205 bbox north (N 42.0355 → 42.0780) grew the box
    # past the census's own window like the east/south strips did; each entry
    # records the v3 pin and the strip deltas. The census-window rules are
    # untouched; the strips' buildings classify by the census §6 rule
    # (build_buildings — the east guard fires first, so the box's NE-corner
    # growth rides the EAST strip bucket, and the north strip is the
    # CSV-less set west of the v1 east edge).
    "buildings": 10783,         # v3 4960 + north strip 5622 + the east
                                # strip's NE-corner growth 201
    "named_buildings": 682,     # v3 616 + 65 north named + 1 east NE-growth
    "east_strip_buildings": 711,    # v3 510 + 201 NE-corner buildings (the
                                    # north widening grew the box past the
                                    # east strip's own northern tail; the
                                    # east guard still fires first)
    "east_strip_named": 58,     # v3 57 + 1
    "east_strip_semi_tagged": 3,    # unchanged
    "east_strip_procedural": 650,   # v3 450 + 200
    "south_strip_buildings": 713,   # v3 0 — unchanged: the north widening
                                    # cannot touch the south strip (the
                                    # guards are disjoint per building)
    "south_strip_named": 47,
    "south_strip_semi_tagged": 9,
    "south_strip_procedural": 657,
    "north_strip_buildings": 5622,  # v3 0 — the CSV-less set, all north of
                                    # CENSUS_V3_NORTH AND west of the v1
                                    # east edge (guarded per-building; the
                                    # north-Ames residential fabric the
                                    # ticket's What names)
    "north_strip_named": 65,    # §6 rule split of the 5622
    "north_strip_semi_tagged": 27,
    "north_strip_procedural": 5530,
    "lakes": 2,                 # v3 1 — the named-water rule joins Ada
                                # Hayden Lake (way/44802137, 52.1 ha, the
                                # twin-quarry-lobed ring, bank=quarry);
                                # LaVerne predates the rule (relation
                                # 3329428) and its ways are unnamed, so
                                # the rules are disjoint. Arnold Lake
                                # (2.0 ha, named) sits EAST of the core
                                # edge — bbox center −93.6014 > −93.607 —
                                # and stays out.
    "trail_runs": 69,           # v3 0 — the north parks' trails (T-205):
                                # Ada Hayden 5.29 km (cycleway 4.27 + path
                                # 0.84 + footway 0.18), Moore Memorial 2.44,
                                # Inis Grove 1.62; longest single run 1.76
                                # km (the survey's "outside loop 1.9 km"
                                # through the park-ring clip)
    "trail_km": 9.36,
    "trees": 6753,              # v3 6106 + 647 north strip tree nodes
    "rail_at_grade_vehicular": 14,  # §5/§7.11's 9 (Grand, Clark, Kellogg,
                                    #  Duff, Hazel, Brookridge, 9th, 13th,
                                    #  1 service) + the north strip's 5 the
                                    # v3 box never saw: West 190th Street,
                                    #  Bloomington Road, 24th, 20th, 16th
                                    #  (the UP line exits town at grade)
    "venues": 48,               # VENUES.md (14 + 17 + 17) — unchanged
    "venue_tiers": {1: 14, 2: 17, 3: 17},
    "landmarks": 15,            # LANDMARKS §5 top-15 — unchanged
    "parking_lots": 639,        # v3 571 + 68 north strip lots (bbox center
                                # in core); bays stay 31
    "parking_ha": 113.97,       # v3 94.43 + 19.54 north strip ha
    "parking_tailgate_lots": 33,    # §3 Iowa State Center tailgate zone —
                                    # the zone rule is the lat/lon window, not
                                    # the box: the census §3 record (and the
                                    # v1/v2 pack) saw its northern part only;
                                    # the south widening reveals the rest
                                    # (19 → 33)
    "parking_tailgate_ha": 11.9,    # §3 tailgate total, same reveal
                                    # (8.9 → 11.9; the game's stock)
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--distill-commit", default="e486d72",
                    help="provenance stamp only (default: the survey commit "
                         "whose dataset this pack distills); NOT part of the "
                         "byte-identity contract")
    args = ap.parse_args()

    nodes, ways, rels, authored_csv, tagged = load_inputs()

    streets, street_km_census = build_streets(nodes, ways)
    street_km_stored = round(sum(e["km"] for e in streets), 2)

    drivable_km = 0.0
    for wid in sorted(ways):
        w = ways[wid]
        t = w.get("tags") or {}
        if t.get("highway") not in ROAD_CLASSES:
            continue
        for a, b in segs_in_bbox(way_pts(w, nodes)):
            drivable_km += seg_len_m(a, b)

    extra3_km_raw, extra3_by_class = named_highway_extra3_km(nodes, ways)
    extra3_km = round(extra3_km_raw / 1000.0, 1)
    # The extra3 rule re-run over the v4 box (T-205): the v1 census figure
    # was 99.6 km (SUMMARY §3); the east strip added 6.1 (v2 105.7); the
    # south strip added the rest (v3 134.7 — University Boulevard, Mortensen
    # Parkway, South 16th Street, the Vet Med loops); the north strip adds
    # the rest (275.9 — the north residential grid's named ways, whose
    # node-filter rule rejoins its own gaps, folding cycleway/service/
    # pedestrian names in). Band guards against rule drift, not history.
    if not (275.4 <= extra3_km <= 276.4):
        raise SystemExit(f"extra3-rule named-road km {extra3_km} outside the "
                         f"v4 band [275.4, 276.4] (v3 figure 134.7; rule "
                         f"drift — check named_highway_extra3_km)")

    blds = collect_building_set(nodes, ways, rels)
    buildings, missing_csv, strip_n, south_n, north_n = \
        build_buildings(blds, authored_csv)
    named = [b for b in buildings if b["name"]]
    authored_n = sum(1 for b in buildings if b["class"] == "authored")

    water = build_water(nodes, ways, rels)
    rail = build_rail(nodes, ways)
    parks = build_parks(nodes, ways, rels, water)
    trails = build_trails(nodes, ways, parks)
    trees = build_trees(tagged)
    parking = build_parking(nodes, ways, tagged)
    pois = build_pois(nodes, ways, rels, tagged, rail, streets)

    # --- pinned-count guards (the pack IS the census, made load-bearing) ---
    if len(buildings) != CENSUS_PINNED["buildings"]:
        raise SystemExit(f"buildings {len(buildings)} != pinned "
                         f"{CENSUS_PINNED['buildings']}")
    if len(named) != CENSUS_PINNED["named_buildings"]:
        raise SystemExit(f"named buildings {len(named)} != pinned "
                         f"{CENSUS_PINNED['named_buildings']}")
    strip_total = sum(strip_n.values())
    if strip_total != CENSUS_PINNED["east_strip_buildings"] \
            or strip_n.get("authored-named") != CENSUS_PINNED["east_strip_named"] \
            or strip_n.get("semi-tagged") != CENSUS_PINNED["east_strip_semi_tagged"] \
            or strip_n.get("procedural") != CENSUS_PINNED["east_strip_procedural"]:
        raise SystemExit(f"east strip split {strip_n} != pinned "
                         f"{CENSUS_PINNED['east_strip_buildings']} "
                         f"({CENSUS_PINNED['east_strip_named']}/"
                         f"{CENSUS_PINNED['east_strip_semi_tagged']}/"
                         f"{CENSUS_PINNED['east_strip_procedural']})")
    south_total = sum(south_n.values())
    if south_total != CENSUS_PINNED["south_strip_buildings"] \
            or south_n.get("authored-named") != CENSUS_PINNED["south_strip_named"] \
            or south_n.get("semi-tagged") != CENSUS_PINNED["south_strip_semi_tagged"] \
            or south_n.get("procedural") != CENSUS_PINNED["south_strip_procedural"]:
        raise SystemExit(f"south strip split {south_n} != pinned "
                         f"{CENSUS_PINNED['south_strip_buildings']} "
                         f"({CENSUS_PINNED['south_strip_named']}/"
                         f"{CENSUS_PINNED['south_strip_semi_tagged']}/"
                         f"{CENSUS_PINNED['south_strip_procedural']})")
    north_total = sum(north_n.values())
    if north_total != CENSUS_PINNED["north_strip_buildings"] \
            or north_n.get("authored-named") != CENSUS_PINNED["north_strip_named"] \
            or north_n.get("semi-tagged") != CENSUS_PINNED["north_strip_semi_tagged"] \
            or north_n.get("procedural") != CENSUS_PINNED["north_strip_procedural"]:
        raise SystemExit(f"north strip split {north_n} != pinned "
                         f"{CENSUS_PINNED['north_strip_buildings']} "
                         f"({CENSUS_PINNED['north_strip_named']}/"
                         f"{CENSUS_PINNED['north_strip_semi_tagged']}/"
                         f"{CENSUS_PINNED['north_strip_procedural']})")
    lakes = [w for w in water if w.get("kind") == "lake"]
    if len(lakes) != CENSUS_PINNED["lakes"]:
        raise SystemExit(f"lakes {len(lakes)} != pinned "
                         f"{CENSUS_PINNED['lakes']}: "
                         + str([l["name"] for l in lakes]))
    trail_km = round(sum(t["km"] for t in trails), 2)
    if len(trails) != CENSUS_PINNED["trail_runs"] \
            or abs(trail_km - CENSUS_PINNED["trail_km"]) > 0.05:
        raise SystemExit(f"trails {len(trails)} runs / {trail_km} km != pinned "
                         f"{CENSUS_PINNED['trail_runs']} / "
                         f"{CENSUS_PINNED['trail_km']}")
    if len(trees) != CENSUS_PINNED["trees"]:
        raise SystemExit(f"trees {len(trees)} != census {CENSUS_PINNED['trees']}")
    at_grade = [c for c in rail["crossings"] if c["grade"] == "at_grade"]
    if len(at_grade) != CENSUS_PINNED["rail_at_grade_vehicular"]:
        raise SystemExit(f"at-grade vehicular crossings {len(at_grade)} != "
                         f"census {CENSUS_PINNED['rail_at_grade_vehicular']}: "
                         + str([c['road_name'] or c['road_class'] for c in at_grade]))
    tailgate = parking_tailgate(parking)
    if len(parking) != CENSUS_PINNED["parking_lots"]:
        raise SystemExit(f"parking areas {len(parking)} != census "
                         f"{CENSUS_PINNED['parking_lots']}")
    if len(tailgate) != CENSUS_PINNED["parking_tailgate_lots"]:
        raise SystemExit(f"tailgate lots {len(tailgate)} != census "
                         f"{CENSUS_PINNED['parking_tailgate_lots']}")
    parking_ha = sum(e["area_m2"] for e in parking) / 10000.0
    if abs(parking_ha - CENSUS_PINNED["parking_ha"]) > 0.05:
        raise SystemExit(f"parking total {parking_ha:.2f} ha != census "
                         f"{CENSUS_PINNED['parking_ha']} ha")
    venues = [p for p in pois if p["kind"] == "venue"]
    landmarks = [p for p in pois if p["kind"] == "landmark"]
    if len(venues) != CENSUS_PINNED["venues"]:
        raise SystemExit(f"venues {len(venues)} != {CENSUS_PINNED['venues']}")
    for tier, want in CENSUS_PINNED["venue_tiers"].items():
        got = sum(1 for v in venues if v["tier"] == tier)
        if got != want:
            raise SystemExit(f"tier-{tier} venues {got} != {want}")
    if len(landmarks) != CENSUS_PINNED["landmarks"]:
        raise SystemExit(f"landmarks {len(landmarks)} != {CENSUS_PINNED['landmarks']}")
    if missing_csv:
        raise SystemExit(f"buildings missing from authored-buildings.csv: "
                         f"{missing_csv[:5]} ({len(missing_csv)} total)")
    # duplicate building ids would silently corrupt the census join
    ids = [b["id"] for b in buildings]
    if len(set(ids)) != len(ids):
        raise SystemExit("duplicate building ids in pack")

    pack = {
        "meta": {
            "pack": "ames_core",
            "version": 4,
            "schema": "ames_core/v4",
            "attribution": "Map data © OpenStreetMap contributors",
            "license": "ODbL — see docs/references/ames-survey/ODBL-NOTE.md",
            "source_date": "2026-11-08",
            "survey_commits": ["aa73840", "e486d72"],
            "distill_commit": args.distill_commit,
            "distilled_by": "tools/ames_distill.py",
            "core_bbox_wsen": [CORE[0], CORE[1], CORE[2], CORE[3]],
            "core_bbox_east_v1": CENSUS_V1_EAST,
            "core_bbox_south_v2": CENSUS_V2_SOUTH,
            "core_bbox_north_v3": CENSUS_V3_NORTH,
            "bbox_east_note": "v2 (T-203): east edge widened +248 m for "
                              "Bandshell Park + the S Duff corridor context; "
                              "buildings east of core_bbox_east_v1 classify "
                              "by the census §6 rule (build_buildings)",
            "bbox_south_note": "v3 (T-204): south edge widened +1.0 km to "
                               "42.0030 (SUMMARY §3's planned window) for "
                               "Reiman Gardens + the ISU Vet Med campus + "
                               "the south blocks; buildings south of "
                               "core_bbox_south_v2 classify by the census "
                               "§6 rule (build_buildings)",
            "bbox_north_note": "v4 (T-205): north edge widened to 42.0780 "
                               "past the whole Ada Hayden Heritage Park "
                               "(relation 12032468, bbox lat 42.05999.."
                               "42.07618 — the ticket's twin-lakes/trail-"
                               "ring criteria need the park at data "
                               "geometry and walkable; SUMMARY §3's own "
                               "+1.6 km north window (42.0500) stops ~2 km "
                               "short of it), landing the park + Moore "
                               "Memorial + Inis Grove + The Cafe (2616 "
                               "Northridge Pkwy) + the north blocks; "
                               "buildings north of core_bbox_north_v3 "
                               "classify by the census §6 rule. v4 also "
                               "joins named water bodies (>= 1 ha) and the "
                               "north parks' trails (build_water / "
                               "build_trails).",
            "origin": {
                "lon": ORIGIN_LON,
                "lat": ORIGIN_LAT,
                "place": "Lincoln Way x Welch",
                "axes": "+X east, -Z north, Y up (master plan §2)",
            },
            "scale": {
                "equirect_lat": SCALE_LAT,
                "m_per_deg_lat": M_PER_DEG_LAT,
                "m_per_deg_lon": round(M_PER_DEG_LON, 4),
            },
            "facing_convention": "compass degrees, 0 = north (-Z), 90 = east "
                                 "(+X); Godot yaw = -deg_to_rad(facing_deg)",
            "counts": {
                "buildings": len(buildings),
                "named_buildings": len(named),
                "authored_buildings": authored_n,
                "procedural_buildings": len(buildings) - authored_n,
                "buildings_east_strip": sum(strip_n.values()),
                "buildings_east_strip_named": strip_n.get("authored-named", 0),
                "buildings_east_strip_semi_tagged": strip_n.get("semi-tagged", 0),
                "buildings_east_strip_procedural": strip_n.get("procedural", 0),
                "buildings_south_strip": sum(south_n.values()),
                "buildings_south_strip_named": south_n.get("authored-named", 0),
                "buildings_south_strip_semi_tagged": south_n.get("semi-tagged", 0),
                "buildings_south_strip_procedural": south_n.get("procedural", 0),
                "buildings_north_strip": sum(north_n.values()),
                "buildings_north_strip_named": north_n.get("authored-named", 0),
                "buildings_north_strip_semi_tagged": north_n.get("semi-tagged", 0),
                "buildings_north_strip_procedural": north_n.get("procedural", 0),
                "lakes": len(lakes),
                "trail_runs": len(trails),
                "trail_km": trail_km,
                "trees": len(trees),
                "street_entries": len(streets),
                "venues": len(venues),
                "venues_placed": sum(1 for v in venues if v["placed"]),
                "landmarks": len(landmarks),
                "pois": len(pois),
                "rail_crossings_vehicular": len(rail["crossings"]),
                "rail_crossings_at_grade": len(at_grade),
                "parks": len(parks),
                "parking_lots": len(parking),
                "parking_ha": round(parking_ha, 1),
                "parking_tailgate_lots": len(tailgate),
                "parking_tailgate_ha": round(
                    sum(e["area_m2"] for e in tailgate) / 10000.0, 1),
                "parking_bays": sum(1 for e in parking
                                    if e["kind"] in ("street_side", "lane")),
            },
            "street_km": {
                "named_drivable_in_core": street_km_stored,
                "named_drivable_in_core_census_rule": round(street_km_census / 1000.0, 2),
                "drivable_in_core_all": round(drivable_km / 1000.0, 2),
                "method": "census §4: segment midpoints inside the core bbox; "
                          "named drivable classes only. This is the rule the "
                          "streets[] graph pins (clean per-way polyline runs "
                          "with class/width semantics).",
                "named_highway_in_core_extra3_km": extra3_km,
                "named_km_by_class_extra3": {
                    k: round(v / 1000.0, 2)
                    for k, v in sorted(extra3_by_class.items(), key=lambda kv: -kv[1])
                },
                "method_extra3": "SUMMARY §3's '99.6 km of named street': "
                                 "extra3.py §5 — every way with a highway tag "
                                 "and a name, NODES filtered to the core bbox, "
                                 "haversine over the consecutive survivors (a "
                                 "survey statistic, not the streets[] graph). "
                                 "Re-runnable: python -I "
                                 "docs/references/ames-survey/osm/scripts/extra3.py "
                                 "docs/references/ames-survey/osm/ames_merged.json "
                                 "docs/references/ames-survey/osm/raw",
            },
            "unplaced_pois": [p["id"] for p in pois if not p["placed"]],
        },
        "streets": streets,
        "buildings": buildings,
        "pois": pois,
        "water": water,
        "rail": rail,
        "parks": parks,
        "trails": trails,
        "parking": parking,
        "trees": trees,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(pack, f, ensure_ascii=False, indent=1)
        f.write("\n")

    print(f"wrote {OUT} ({os.path.getsize(OUT) / 1e6:.2f} MB)")
    print(f"buildings {len(buildings)} (named {len(named)}, authored "
          f"{authored_n}; east strip {sum(strip_n.values())} = "
          f"{strip_n.get('authored-named', 0)} named / "
          f"{strip_n.get('semi-tagged', 0)} semi / "
          f"{strip_n.get('procedural', 0)} procedural; south strip "
          f"{sum(south_n.values())} = "
          f"{south_n.get('authored-named', 0)} named / "
          f"{south_n.get('semi-tagged', 0)} semi / "
          f"{south_n.get('procedural', 0)} procedural; north strip "
          f"{sum(north_n.values())} = "
          f"{north_n.get('authored-named', 0)} named / "
          f"{north_n.get('semi-tagged', 0)} semi / "
          f"{north_n.get('procedural', 0)} procedural)")
    print(f"trees {len(trees)}; street entries {len(streets)} "
          f"(named drivable in-core {street_km_stored} km, census rule "
          f"{street_km_census / 1000.0:.2f} km, all drivable "
          f"{drivable_km / 1000.0:.2f} km; extra3 rule {extra3_km} km)")
    print(f"extra3 per-class km: " + ", ".join(
        f"{k} {v / 1000.0:.2f}" for k, v in sorted(extra3_by_class.items(),
                                                   key=lambda kv: -kv[1])))
    print(f"rail: main line {rail['in_core_km']} km in core, crossings "
          f"{len(rail['crossings'])} vehicular "
          f"({len(at_grade)} at-grade: "
          f"{', '.join(c['road_name'] or c['road_class'] for c in at_grade)})")
    print(f"pois {len(pois)} (venues {len(venues)} "
          f"[placed {sum(1 for v in venues if v['placed'])}], landmarks "
          f"{len(landmarks)} [placed {sum(1 for l in landmarks if l['placed'])}]); "
          f"unplaced: {', '.join(pack['meta']['unplaced_pois'])}")
    print(f"water {len(water)} (lakes {len(lakes)}: "
          f"{', '.join(l['name'] for l in lakes)}); parks {len(parks)}; "
          f"trails {len(trails)} runs / {trail_km} km")
    return 0


if __name__ == "__main__":
    sys.exit(main())
