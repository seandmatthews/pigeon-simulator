/* Ames IA street inventory: named roads, main public classes.
   bbox = south 42.00, west -93.69, north 42.08, east -93.56 */
[out:json][timeout:180];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential)$"]["name"](42.00,-93.69,42.08,-93.56);
);
out geom;
