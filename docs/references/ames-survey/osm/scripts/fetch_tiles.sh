#!/usr/bin/env bash
# Fetch the whole Ames survey bbox from the OSM API 0.6 map.json endpoint,
# tile by tile (the Overpass mirrors are unreachable from this network).
set -u
OSM="/c/Users/matth/Documents/pigeon-simulator/docs/references/ames-survey/osm"
RAW="$OSM/raw"
mkdir -p "$RAW"
UA="PigeonSimResearch/1.0 (one-off OSM extract for a local game-design survey; polite scripted use)"

python -I "$OSM/scripts/make_tiles.py" 42.00 -93.69 42.08 -93.56 0.025 0.012 | tr -d '\r' > "$RAW/_tilelist.txt"

ok=0
: > "$RAW/_failed_tiles.txt"
while read -r name S W N E; do
  out="$RAW/tile_${name}.json"
  code=$(curl -sS --max-time 120 -H "User-Agent: $UA" \
    -o "$out" -w "%{http_code}" \
    "https://api.openstreetmap.org/api/0.6/map.json?bbox=$W,$S,$E,$N")
  if [ "$code" = "200" ] && grep -q '"elements"' "$out"; then
    ok=$((ok+1))
    echo "$name OK $(stat -c%s "$out") bytes"
  else
    echo "$name $S $W $N $E" >> "$RAW/_failed_tiles.txt"
    echo "$name FAILED http=$code"
    rm -f "$out"
  fi
  sleep 0.4
done < "$RAW/_tilelist.txt"
echo "DONE ok=$ok failed=$(wc -l < "$RAW/_failed_tiles.txt")"
