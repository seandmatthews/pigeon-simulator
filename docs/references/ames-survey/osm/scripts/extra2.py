"""Follow-up details: squaw-named ways, Lake LaVerne ring area, yard way tags.

Usage: python -I extra2.py <merged_json>
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyze import (Data, load, to_xy, hav, seg_stats, bbox_of, bbox_dims_m,
                     shoelace_m2, centroid, ORIGIN, LAT_M, LON_M)

data = Data(load(sys.argv[1]))

print("== ways with 'squaw' in any tag value:")
for wid, w in data.ways.items():
    t = w.get("tags", {})
    if any("squaw" in str(v).lower() for v in t.values()):
        pts = data.way_pts(wid)
        ln, _, _, _ = seg_stats(pts)
        bb = bbox_of(pts) if pts else None
        print(f"  way {wid} name={t.get('name')!r} other={ {k:v for k,v in t.items() if k!='name'} } "
              f"len {ln:.0f} m bbox lon {bb[0]:.4f}..{bb[2]:.4f} lat {bb[1]:.4f}..{bb[3]:.4f}")

print("\n== Lake LaVerne ring assembly:")
outers = []
for rid, r in data.rels.items():
    if r.get("tags", {}).get("name") == "Lake LaVerne":
        for m in r.get("members", []):
            if m.get("type") == "way" and m.get("role") == "outer":
                pts = data.way_pts(m.get("ref"))
                outers.append((m.get("ref"), pts))
for ref, pts in outers:
    print(f"  outer {ref}: start {pts[0]}, end {pts[-1]}, n={len(pts)}")
# try to chain them
if len(outers) == 2:
    (a_id, a), (b_id, b) = outers
    pairs = [(a, b), (b, a)]
    best = None
    for p, q in pairs:
        for flip in (False, True):
            qq = q[::-1] if flip else q
            d_end_start = hav(p[-1], qq[0])
            d_start_end = hav(p[0], qq[-1])
            if best is None or d_end_start + d_start_end < best[0]:
                best = (d_end_start + d_start_end, p, qq, flip)
    gap1 = hav(best[1][-1], best[2][0])
    gap2 = hav(best[2][-1], best[1][0])
    ring = best[1] + best[2]
    closed = gap1 < 10 and gap2 < 10
    print(f"  chain gaps: {gap1:.1f} m, {gap2:.1f} m -> closed={closed}")
    if True:
        area = shoelace_m2(ring)
        bb = bbox_of(ring)
        w_m, h_m = bbox_dims_m(bb)
        print(f"  combined ring: bbox {w_m:.0f} x {h_m:.0f} m, area ~{area:.0f} m2 = {area/10000:.2f} ha "
              f"({area/4046.86:.2f} acres)")

print("\n== rail ways with centroid in yard zone (lon -93.60..-93.55, lat 42.024..42.033):")
for wid, w in data.ways.items():
    t = w.get("tags", {})
    if t.get("railway") not in ("rail", "yard", "spur", "siding", "industrial"):
        continue
    pts = data.way_pts(wid)
    if len(pts) < 2:
        continue
    c = centroid(pts)
    if -93.60 <= c[0] <= -93.55 and 42.024 <= c[1] <= 42.033:
        ln, _, _, _ = seg_stats(pts)
        bb = bbox_of(pts)
        w_m, h_m = bbox_dims_m(bb)
        print(f"  way {wid} len {ln:6.0f} m bbox {w_m:6.0f}x{h_m:5.0f} m tags={ {k:v for k,v in t.items() if k!='railway'} } railway={t.get('railway')}")

print("\n== distinct service/railway tag combos on all rail ways:")
from collections import Counter
cnt = Counter()
for wid, w in data.ways.items():
    t = w.get("tags", {})
    if "railway" in t:
        cnt[(t.get("railway"), t.get("service", "-"))] += 1
for k, v in cnt.most_common():
    print(f"  {k}: {v}")
