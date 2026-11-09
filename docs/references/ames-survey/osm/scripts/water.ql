/* Ames IA water: rivers, creeks, ponds, lakes (Lake LaVerne etc.)
   bbox = south 42.00, west -93.69, north 42.08, east -93.56 */
[out:json][timeout:180];
(
  way["waterway"](42.00,-93.69,42.08,-93.56);
  way["natural"="water"](42.00,-93.69,42.08,-93.56);
  relation["natural"="water"](42.00,-93.69,42.08,-93.56);
);
out geom;
