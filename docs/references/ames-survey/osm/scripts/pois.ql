/* Ames IA points/areas of interest: ISU campus, stadiums, parks, landmarks,
   retail/commercial landuse (Campustown, downtown), place nodes.
   bbox = south 42.00, west -93.69, north 42.08, east -93.56 */
[out:json][timeout:180];
(
  nwr["amenity"~"^(university|college)$"](42.00,-93.69,42.08,-93.56);
  nwr["name"~"campanile",i](42.00,-93.69,42.08,-93.56);
  nwr["name"~"Jack Trice",i](42.00,-93.69,42.08,-93.56);
  nwr["name"~"Hilton",i](42.00,-93.69,42.08,-93.56);
  nwr["name"~"Reiman",i](42.00,-93.69,42.08,-93.56);
  nwr["name"~"LaVerne",i](42.00,-93.69,42.08,-93.56);
  nwr["leisure"="park"](42.00,-93.69,42.08,-93.56);
  nwr["name"~"Ada Hayden",i](42.00,-93.69,42.08,-93.56);
  nwr["name"~"Inis Grove",i](42.00,-93.69,42.08,-93.56);
  nwr["name"~"Brookside",i](42.00,-93.69,42.08,-93.56);
  nwr["name"~"Moore",i](42.00,-93.69,42.08,-93.56);
  nwr["leisure"~"^(stadium|sports_centre|track|pitch)$"]["name"](42.00,-93.69,42.08,-93.56);
  nwr["landuse"~"^(retail|commercial)$"](42.00,-93.69,42.08,-93.56);
  node["place"](42.00,-93.69,42.08,-93.56);
);
out geom;
