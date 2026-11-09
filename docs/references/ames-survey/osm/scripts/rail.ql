/* Ames IA rail: UP hump yard, main lines, stations
   bbox = south 42.00, west -93.69, north 42.08, east -93.56 */
[out:json][timeout:180];
(
  way["railway"~"^(rail|yard|spur|siding|industrial|disused|abandoned|construction)$"](42.00,-93.69,42.08,-93.56);
  node["railway"~"^(station|halt)$"]["name"](42.00,-93.69,42.08,-93.56);
);
out geom;
