"""Final details: yard bbox from service=yard ways, station nodes, derived distances.

Usage: python -I extra3.py <merged_json> <raw_dir>
"""
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyze import (Data, load, to_xy, hav, seg_stats, bbox_of, bbox_dims_m,
                     shoelace_m2, centroid, ORIGIN, LAT_M, LON_M)

data = Data(load(sys.argv[1]))
raw_dir = sys.argv[2]

# 1. yard combined bbox + total yard track
yard_pts, yard_len = [], 0.0
for wid, w in data.ways.items():
    t = w.get("tags", {})
    if t.get("railway") == "rail" and t.get("service") == "yard":
        pts = data.way_pts(wid)
        ln, _, _, _ = seg_stats(pts)
        yard_pts.extend(pts)
        yard_len += ln
bb = bbox_of(yard_pts)
w_m, h_m = bbox_dims_m(bb)
c = centroid(yard_pts)
print(f"YARD (service=yard ways): {w_m:.0f} m E-W x {h_m:.0f} m N-S, center ({c[0]:.5f},{c[1]:.5f}), "
      f"lon {bb[0]:.5f}..{bb[2]:.5f} lat {bb[1]:.5f}..{bb[3]:.5f}, track {yard_len:.0f} m in ways")

# 2. station-ish nodes in tiles
print("\n== station nodes:")
for path in sorted(glob.glob(os.path.join(raw_dir, "tile_*.json"))):
    with open(path, encoding="utf-8") as fh:
        d = json.load(fh)
    for e in d.get("elements", []):
        if e["type"] == "node" and e.get("tags"):
            t = e["tags"]
            if t.get("railway") in ("station", "halt") or t.get("public_transport") == "station" \
               or t.get("historic") == "railway_station":
                print(f"  node {e['id']} ({e['lon']:.5f},{e['lat']:.5f}) {t}")

# 3. derived distances (planar)
def dist_m(a, b):
    pa, pb = to_xy(*a), to_xy(*b)
    return math.hypot(pa[0] - pb[0], pa[1] - pb[1])

main_duff = (-93.61043, 42.02516)
campanile = (-93.64604, 42.02543)      # Campanile building way centroid
lincoln_welch = (-93.65014, 42.02276)  # Lincoln Way x Welch Ave crossing
stadium = (-93.63576, 42.01401)        # Jack Trice Stadium relation centroid
lake = (-93.64802, 42.02357)           # Lake LaVerne centroid
campus_c = (-93.64745, 42.02428)       # ISU relation bbox center
print("\n== derived distances:")
for a_name, a, b_name, b in [
        ("downtown Main x Duff", main_duff, "Campanile", campanile),
        ("downtown Main x Duff", main_duff, "Lincoln x Welch (Campustown)", lincoln_welch),
        ("downtown Main x Duff", main_duff, "ISU bbox center", campus_c),
        ("Campanile", campanile, "Jack Trice Stadium", stadium),
        ("Campanile", campanile, "Lake LaVerne", lake),
        ("Lincoln x Welch", lincoln_welch, "Jack Trice Stadium", stadium)]:
    print(f"  {a_name:24s} -> {b_name:28s} {dist_m(a,b):7.0f} m")

# 4. Lincoln Way corridor width check: Lincoln Way lat vs Main St lat
print(f"\nLincoln Way lat 42.0229 vs Main Street lat 42.0251: separation "
      f"{(42.0251-42.0229)*LAT_M:.0f} m")
# 5. total named-road length inside the core window
core_named = 0.0
for wid, w in data.ways.items():
    t = w.get("tags", {})
    if "highway" in t and t.get("name"):
        pts = data.way_pts(wid)
        pts = [p for p in pts if 42.0120 <= p[1] <= 42.0355 and -93.6590 <= p[0] <= -93.6100]
        for i in range(len(pts) - 1):
            core_named += hav(pts[i], pts[i + 1])
print(f"named-road length inside proposed core window: {core_named/1000:.1f} km")
