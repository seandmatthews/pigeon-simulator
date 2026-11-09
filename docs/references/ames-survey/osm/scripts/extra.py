"""Ad-hoc analysis for the Ames survey: rail-yard extent, Lake LaVerne area,
city extents, campus-core buildings, downtown street bearings, Squaw naming check.

Usage: python -I extra.py <merged_json>
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyze import (Data, load, to_xy, hav, seg_stats, bbox_of, bbox_dims_m,
                     shoelace_m2, centroid, ORIGIN, LAT_M, LON_M,
                     spine_segs, first_cross, street_groups, orient_of)

data = Data(load(sys.argv[1]))

# ---------- 1. rail density grid (find the hump yard) ----------
CELL = 250.0
cells = {}
rail_ways = []
for wid, w in data.ways.items():
    t = w.get("tags", {})
    if t.get("railway") in ("rail", "yard", "spur", "siding", "industrial"):
        pts = data.way_pts(wid)
        if len(pts) >= 2:
            ln, _, _, _ = seg_stats(pts)
            rail_ways.append((wid, t, pts, ln))
for wid, t, pts, ln in rail_ways:
    for i in range(len(pts) - 1):
        xa, ya = to_xy(*pts[i])
        xb, yb = to_xy(*pts[i + 1])
        cx, cy = (xa + xb) / 2, (ya + yb) / 2
        seg = math.hypot(xb - xa, yb - ya)
        key = (int(cx // CELL), int(cy // CELL))
        cells[key] = cells.get(key, 0.0) + seg

top = sorted(cells.items(), key=lambda kv: -kv[1])[:28]
print("== top rail-density cells (250 m grid, track-meters per cell):")
for (ix, iy), ln in top:
    lon = ORIGIN[0] + (ix + 0.5) * CELL / LON_M
    lat = ORIGIN[1] + (iy + 0.5) * CELL / LAT_M
    print(f"  cell ({ix:4d},{iy:4d}) {ln:7.0f} m  center ({lon:.5f},{lat:.5f})")

# cluster: bbox of cells with >= 1000 track-m that lie within 2.5 km of the
# densest cell (candidate yard)
if top:
    bx, by = top[0][0]
    yard_cells = [k for k, v in cells.items() if v >= 1000.0 and abs(k[0] - bx) <= 12 and abs(k[1] - by) <= 12]
    xs = [k[0] for k in yard_cells]
    ys = [k[1] for k in yard_cells]
    if xs:
        w_lon0 = ORIGIN[0] + min(xs) * CELL / LON_M
        w_lon1 = ORIGIN[0] + (max(xs) + 1) * CELL / LON_M
        w_lat0 = ORIGIN[1] + min(ys) * CELL / LAT_M
        w_lat1 = ORIGIN[1] + (max(ys) + 1) * CELL / LAT_M
        print(f"yard zone approx lon {w_lon0:.4f}..{w_lon1:.4f} lat {w_lat0:.4f}..{w_lat1:.4f}")
        tot = 0.0
        nw = 0
        for wid, t, pts, ln in rail_ways:
            c = centroid(pts)
            if w_lon0 <= c[0] <= w_lon1 and w_lat0 <= c[1] <= w_lat1:
                tot += ln
                nw += 1
        print(f"rail ways with centroid in yard zone: {nw}, total track {tot:.0f} m")

# ---------- 2. Lake LaVerne outer ring ----------
print("\n== Lake LaVerne members:")
for rid, r in data.rels.items():
    t = r.get("tags", {})
    if t.get("name") in ("Lake LaVerne", "Lake Laverne"):
        print("  relation", rid, t)
        for m in r.get("members", []):
            if m.get("type") != "way":
                continue
            pts = data.way_pts(m.get("ref"))
            if len(pts) < 4:
                continue
            closed = hav(pts[0], pts[-1]) < 5.0
            bb = bbox_of(pts)
            w_m, h_m = bbox_dims_m(bb)
            line = f"  way {m.get('ref')} role={m.get('role')} pts={len(pts)} closed={closed} bbox {w_m:.0f}x{h_m:.0f} m"
            if closed:
                line += f" area ~{shoelace_m2(pts)/10000:.2f} ha"
            print(line)

# ---------- 3. extents ----------
groups, _ = street_groups(data)
allpts = [p for g in groups.values() for p in g["pts"]]
bb = bbox_of(allpts)
w_m, h_m = bbox_dims_m(bb)
print(f"\n== extent of named roads: lon {bb[0]:.4f}..{bb[2]:.4f} lat {bb[1]:.4f}..{bb[3]:.4f} ({w_m:.0f} x {h_m:.0f} m)")
allnode_bb = bbox_of(list(data.nodes.values()))
print(f"   all nodes:             lon {allnode_bb[0]:.4f}..{allnode_bb[2]:.4f} lat {allnode_bb[1]:.4f}..{allnode_bb[3]:.4f}")

# ---------- 4. Squaw naming check ----------
squaw = 0
for wid, w in data.ways.items():
    nm = w.get("tags", {}).get("name", "")
    if "squaw" in nm.lower():
        squaw += 1
print(f"\nways named containing 'squaw': {squaw}")

# ---------- 5. downtown bearings ----------
def bearing_in(name, latmin, latmax):
    dx = dy = 0.0
    n = 0
    for wid, w in data.ways.items():
        t = w.get("tags", {})
        if t.get("name") != name:
            continue
        pts = data.way_pts(wid)
        pts = [p for p in pts if latmin <= p[1] <= latmax]
        for i in range(len(pts) - 1):
            xa, ya = to_xy(*pts[i])
            xb, yb = to_xy(*pts[i + 1])
            dx += xb - xa
            dy += yb - ya
            n += 1
    if n == 0:
        return None
    brg = (math.degrees(math.atan2(dx, dy)) + 360.0) % 360.0  # 0=N, 90=E
    return brg, n

print("\n== street bearings (0=N, 90=E):")
for nm, lo, hi in [("Main Street", 42.024, 42.026), ("5th Street", 42.024, 42.028),
                   ("6th Street", 42.026, 42.030), ("Duff Avenue", 42.020, 42.040),
                   ("Douglas Avenue", 42.020, 42.040), ("Burnett Avenue", 42.020, 42.046),
                   ("Kellogg Avenue", 42.020, 42.040), ("Clark Avenue", 42.020, 42.040),
                   ("Grand Avenue", 42.020, 42.040), ("Lincoln Way", 42.022, 42.024),
                   ("Welch Avenue", 42.015, 42.024), ("Hayward Avenue", 42.015, 42.024),
                   ("Sheldon Avenue", 42.020, 42.026), ("State Avenue", 42.018, 42.028),
                   ("Stange Road", 42.030, 42.070), ("Mortensen Road", 42.010, 42.017),
                   ("University Boulevard", 42.005, 42.030)]:
    r = bearing_in(nm, lo, hi)
    if r:
        print(f"  {nm:22s} bearing {r[0]:6.1f} deg  ({r[1]} segs in lat {lo}..{hi})")

# ---------- 6. campus-core buildings ----------
uni_bb = None
for rid, r in data.rels.items():
    if r.get("tags", {}).get("amenity") == "university" and "Iowa State" in r.get("tags", {}).get("name", ""):
        pts = data.rel_pts(rid)
        uni_bb = bbox_of(pts)
        print(f"\n== ISU relation {rid}: bbox lon {uni_bb[0]:.4f}..{uni_bb[2]:.4f} lat {uni_bb[1]:.4f}..{uni_bb[3]:.4f}",
              f"dims {tuple(round(v) for v in bbox_dims_m(uni_bb))}")
if uni_bb:
    bpts = []
    nb = 0
    for wid, w in data.ways.items():
        t = w.get("tags", {})
        if "building" in t:
            pts = data.way_pts(wid)
            if len(pts) >= 4:
                c = centroid(pts)
                if uni_bb[0] <= c[0] <= uni_bb[2] and uni_bb[1] <= c[1] <= uni_bb[3]:
                    nb += 1
                    bpts.extend(pts)
    bb = bbox_of(bpts)
    print(f"buildings with centroid inside campus polygon bbox: {nb}; "
          f"combined bbox lon {bb[0]:.4f}..{bb[2]:.4f} lat {bb[1]:.4f}..{bb[3]:.4f} "
          f"dims {tuple(round(v) for v in bbox_dims_m(bb))}")
    # dense core: buildings within lat 42.012..42.036, lon -93.660..-93.620
    core = [p for p in bpts if 42.012 <= p[1] <= 42.036 and -93.660 <= p[0] <= -93.620]
    bb2 = bbox_of(core)
    print(f"of those, in the 42.012..42.036 x -93.660..-93.620 window: "
          f"bbox lon {bb2[0]:.4f}..{bb2[2]:.4f} lat {bb2[1]:.4f}..{bb2[3]:.4f} "
          f"dims {tuple(round(v) for v in bbox_dims_m(bb2))}")

# ---------- 7. main-line pass near downtown ----------
groups2, _ = street_groups(data)
md = first_cross(data, groups2, "Main Street", "Duff Avenue")
print(f"\nMain Street x Duff Avenue (downtown center): ({md[0]:.5f},{md[1]:.5f})")
best = (1e9, None)
for wid, t, pts, ln in rail_ways:
    if t.get("name") != "UP Clinton Subdivision":
        continue
    for i in range(len(pts) - 1):
        # point-segment distance in planar meters
        px, py = to_xy(*md)
        xa, ya = to_xy(*pts[i])
        xb, yb = to_xy(*pts[i + 1])
        vx, vy = xb - xa, yb - ya
        L2 = vx * vx + vy * vy
        if L2 == 0:
            continue
        tt = max(0.0, min(1.0, ((px - xa) * vx + (py - ya) * vy) / L2))
        qx, qy = xa + tt * vx, ya + tt * vy
        d = math.hypot(px - qx, py - qy)
        if d < best[0]:
            best = (d, pts[i] if tt < 0.5 else pts[i + 1])
print(f"UP Clinton Sub main line closest approach to downtown center: {best[0]:.0f} m "
      f"at ({best[1][0]:.5f},{best[1][1]:.5f})")
# main line bearing through town
dx = dy = 0.0
for wid, t, pts, ln in rail_ways:
    if t.get("name") != "UP Clinton Subdivision":
        continue
    pts = [p for p in pts if 42.015 <= p[1] <= 42.040 and -93.64 <= p[0] <= -93.58]
    for i in range(len(pts) - 1):
        xa, ya = to_xy(*pts[i])
        xb, yb = to_xy(*pts[i + 1])
        dx += xb - xa
        dy += yb - ya
brg = (math.degrees(math.atan2(dx, dy)) + 360) % 360
print(f"UP main line bearing through town (lat 42.015..42.040): {brg:.1f} deg (0=N)")
