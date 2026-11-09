"""Generate the OSM API tile list for the Ames survey bbox.

Usage: python -I make_tiles.py S W N E DLON DLAT
Prints lines: name S W N E   (bbox order for the API call is W,S,E,N)
"""
import sys

S, W, N, E = float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
DLON, DLAT = float(sys.argv[5]), float(sys.argv[6])

lat = S
r = 0
while lat < N - 1e-9:
    lat2 = min(lat + DLAT, N)
    lon = W
    c = 0
    while lon < E - 1e-9:
        lon2 = min(lon + DLON, E)
        print(f"r{r:02d}c{c:02d} {lat:.4f} {lon:.4f} {lat2:.4f} {lon2:.4f}")
        lon = lon2
        c += 1
    lat = lat2
    r += 1
