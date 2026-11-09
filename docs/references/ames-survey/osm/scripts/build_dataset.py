"""Merge the per-tile OSM API dumps into one dataset.

Usage: python -I build_dataset.py <raw_dir> <out_json> W S E N
- nodes: id -> [lon, lat]
- ways:  id -> {"tags": {...}, "nodes": [ids...]}   (full ref list kept even if
  some refs lie outside the survey bbox; geometry is truncated to the bbox later)
- relations: id -> {"tags": {...}, "members": [...]}

Ways/relations identical across tiles are merged (keeping the richest copy).
"""
import json
import os
import sys

raw_dir, out_path = sys.argv[1], sys.argv[2]
W, S, E, N = (float(x) for x in sys.argv[3:7])

nodes = {}
ways = {}
rels = {}

files = sorted(f for f in os.listdir(raw_dir) if f.startswith("tile_") and f.endswith(".json"))
for fname in files:
    with open(os.path.join(raw_dir, fname), encoding="utf-8") as fh:
        d = json.load(fh)
    for e in d.get("elements", []):
        t = e["type"]
        if t == "node":
            nodes[e["id"]] = [e["lon"], e["lat"]]
        elif t == "way":
            cur = ways.get(e["id"])
            refs = e.get("nodes", [])
            if cur is None:
                ways[e["id"]] = {"tags": e.get("tags", {}), "nodes": refs}
            elif len(refs) > len(cur["nodes"]):
                cur["nodes"] = refs
                cur["tags"] = e.get("tags", {})
        elif t == "relation":
            cur = rels.get(e["id"])
            mem = e.get("members", [])
            if cur is None:
                rels[e["id"]] = {"tags": e.get("tags", {}), "members": mem}
            elif len(mem) > len(cur["members"]):
                cur["members"] = mem
                cur["tags"] = e.get("tags", {})

out = {
    "source": "OpenStreetMap via api.openstreetmap.org /api/0.6/map.json tile sweep",
    "bbox_WSEN": [W, S, E, N],
    "n_nodes": len(nodes),
    "n_ways": len(ways),
    "n_relations": len(rels),
    "nodes": {str(k): v for k, v in nodes.items()},
    "ways": {str(k): v for k, v in ways.items()},
    "relations": {str(k): v for k, v in rels.items()},
}
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump(out, fh, ensure_ascii=False)
print(f"merged {len(files)} tiles: {len(nodes)} nodes, {len(ways)} ways, {len(rels)} relations -> {out_path}")
