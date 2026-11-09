# Ames Survey — Venue Inventory (bars, restaurants, coffee, late-night food)

Date-stamped: **2026-11-08**. Scope: the *dated* operating inventory of the venues ISU
students name first — for the owner's test "an alum flies to where they know Welch Ave
Station will be, and finds a building that's recognizably their favorite bar."

**Method:** every venue's operating status was re-verified for 2025–2026 via web search
(official sites, Discover Ames / Downtown Ames directories, Ames Regional Economic
Alliance event lists, Ames City Council liquor-license minutes, Iowa State Daily, Ames
Tribune, Yelp/Google snippets). Positions and building footprints were cross-checked
against the sibling lane's OSM extract (`../osm/raw/ames_merged.json`, pulled 2026-11-08)
— building centers and footprint sizes below labeled "OSM" are computed from that file,
not guessed. Emotional anchors are cross-linked to `../community/REDDIT-RESONANCE.md`
(quotes are verbatim from that lane's Arctic Shift archive; threads cited by ID).

**Tier shorthand (matches `../landmarks/LANDMARKS.md`):** venues are `business` tier —
trademarked names. Model the building, rename the sign (see each entry's pigeon cue).

---

## 0. Orientation correction — read before modeling the strip

Two geometry facts this lane verified against the OSM extract that other lanes state
backwards. They change the whole fly-through:

1. **Campustown's bar strip is SOUTH of Lincoln Way; central campus is NORTH of it.**
   The Memorial Union building sits at lat 42.0232–42.0242, Lincoln Way runs at
   lat 42.0228, and every Welch Ave venue sits at lat 42.0194–42.0221 (OSM centroids).
   The Ames Historical Society Campustown walking tour calls it "the two-block stretch
   of Welch Avenue **south of** Lincoln Way, lined with bars and eateries." Students
   cross Lincoln Way *southbound* out of campus into Campustown. (`../landmarks/LANDMARKS.md`
   says Campustown "sits just north" — flip it.)
2. **Along Lincoln Way, the cross streets run (west → east): State Ave, … Sheldon,
   Hayward, Welch, Stanton, Lynn, Ash, … University Blvd.** Welch Ave street centerline
   is at lon ≈ −93.6501, Hayward ≈ −93.6517 (west of Welch), Sheldon ≈ −93.6542,
   Stanton ≈ −93.6485 (east of Welch). The block-gap numbers in `../osm/SUMMARY.md` §5
   are correct but its "west→east" label is reversed — the sequence listed there is
   actually east→west. Burnett Ave is downtown-only, as the siblings already agreed.
3. **Welch Ave addresses increase going SOUTH** (100 block at the Lincoln Way end,
   300 block farthest out), odd numbers on the west side, even on the east
   (verified: Cy's Roost #121 west at lon −93.6504; BNC #206 east at −93.6497).

Also dated: **Welch Avenue itself is torn up.** Chamberlain→Hunt closed for full
reconstruction (pavement + century-old utilities, "building face to building face")
announced April 29, 2025; Phase 4 active July 15, 2025; completion targeted 2026
(not yet confirmed as of this writing — https://www.cityofames.org/News-articles/Section-of-Welch-Avenue-Closed-for-Reconstruction,
project scope: https://whks.com/services-projects/streets-and-streetscapes/welch-avenue-campustown-public-improvements).
Fire Station No. 2 (132 Welch) is slated to relocate to a new State Ave site
(same City of Ames news page). A prior Welch streetscape rebuild finished May 2021.

---

## 1. Tier 1 — the must-haves (the first names out of a student's mouth)

Open venues only; the mourned ones live in §5. "OSM" = footprint from the sibling
extract. Night-flow placement from the Reddit decade summary: Welch fills 10 pm–midnight
(Cy's/Mickey's/Paddy's), the late shift 12–2 goes Sips/AJ's/Outlaws
(`../community/REDDIT-RESONANCE.md`, threads c3k55p + 18a4wgv).

### 1.1 Welch Ave Station — bar
- **Location:** 207 Welch Ave, Ste 101 (west side of the 200 block, between Chamberlain
  and Hunt). Pizza Pit occupies Ste 201 above it — one building, two student staples.
- **Signature:** the "safe" Welch pick — pool tables, darts, ~200 capacity, pizza, free
  full drink for your 21st ("get a double White Russian, it's their strongest drink" —
  thread c3k55p, 2019-06). The most-recommended single bar across a decade of threads
  (`../community/REDDIT-RESONANCE.md` #4).
- **Exterior / pigeon cue:** two-story commercial storefront block on the west sidewalk;
  ground-floor bar with wide flat storefront glazing and a big flat block-letter sign
  band; upper-floor pizzeria windows. A pigeon gliding south down Welch reads it as the
  wide-open porch-lit bar mid-block, right where the 200 block opens up (OSM: block
  contains Kum & Go's 11×26 m canopied store at #203 on the SAME west side of the
  block — not opposite; QA fix 2026-11-08 per QA-REPORT item 4 / A-14, ledger V-21).
- **Anchor:** "Go to welch Ave station. Best chill bar to hangout alone on welch Ave."
  — r/iastate, 2025-08 (thread 1mxscpm). Co-host of "Masters on Welch Ave," Apr 12 2025.
- **Status source:** welchave.com/location (own site, hours through 2025);
  https://discoverames.com/business-listing/welch-ave-station

### 1.2 Paddy's Irish Pub — bar (the packed one)
- **Location:** 124–126 Welch Ave, east side of the 100 block, mid-block opposite
  Mickey's (#109). License holder is literally **THE SCENE, LLC, DBA "SIPS and Paddy's
  Irish Pub"** (Ames City Council, July 8 2025) — the old club's LLC runs both floors.
- **Signature:** the room where big campus moments happen — "Paddy's is probably the
  most packed bar in Ames" (thread c3k55p, 2019-06); "I was at Paddys the night VEISHEA
  died. We had just gotten 2 pitchers, cops come in and tell them to stop serving and
  not let anyone leave" (thread 1spv39t, 2026-04). Pool tables + beer pong upstairs.
- **Exterior / pigeon cue:** narrow double-storefront brick block; the pub is the
  SECOND floor — a stair door and handrail at the sidewalk, small upper windows lit
  late; two doors (Paddy's 124, Sips 126) share one facade. Reads as the vertical bar:
  light pouring out of upstairs windows over a dark basement stairwell.
- **Status source:** Facebook (active 2025, hours); liquor license "Sips and Paddy's
  Irish Pub, 126 Welch Avenue," Ames City Council Dec 2025; ISD history
  https://iowastatedaily.com/211113/uncategorized/irish-pub-replaces-welch-avenue-club

### 1.3 Cy's Roost — bar (the ritual bar)
- **Location:** 121 Welch Ave, west side of the 100 block, across the street and one
  door north of Paddy's (OSM footprint 32×12 m — a skinny two-story slot).
- **Signature:** "Ames Staple Since 1977" (@cysroost1977) — the "21 mugs on your 21st"
  bar and Thursday mug night ("Cy's has cover on Thursdays due to their 21 mugs deal,"
  c3k55p); upstairs game room with Mario Kart, patio with bags/cornhole, free popcorn
  and hot dogs.
- **Exterior / pigeon cue:** tall narrow brick building hugging the west sidewalk;
  flat parapet with the Roost sign stacked vertically; upper-floor game-room windows
  glowing over a ground-floor taproom; patio furniture spilling along the sidewalk edge.
- **Anchor:** "Cy Roost - the place for mug night and 21 mugs in your birthday (been
  around for a long time)" — r/iastate, 2023-12 (thread 18a4wgv).
- **Status source:** Class C license renewal (outdoor service) on Ames City Council
  agenda Jan 14 2025; "Masters on Welch Ave" Apr 2025; https://discoverames.com/blog/best-bars-and-nightlife-in-ames

### 1.4 Sips — bar/club (the finisher)
- **Location:** 126 Welch Ave — the BASEMENT of the Paddy's building (same LLC, see 1.2).
- **Signature:** "Sips, the pitch black basement of paddy's. Sticky floor, fog machine
  on the dance floor, EDM nights and pretty dope lights" (c3k55p, 2019-06); skee-ball;
  free tequila shot at 11 pm "Sips O'clock" (ISD 2021 nightlife guide). The 12–2 am
  shift's default destination.
- **Exterior / pigeon cue:** shares 1.2's facade — model ONE building with two doors
  and a below-grade stairwell; the pigeon cue is the basement stair glow and the queue
  on the east sidewalk after midnight.
- **Status source:** Ames City Council Dec 2025 license list (with Paddy's, 126 Welch);
  https://iowastatedaily.com/248829/news/welcome-back-ames-nightlife (Aug 20 2021, layout)

### 1.5 Mickey's Irish Pub — bar
- **Location:** 109 Welch Ave, west side of the 100 block at the Lincoln Way end —
  the first bar you hit coming off campus.
- **Signature:** $1-well Wednesdays; patio plus a basement dance floor; "definitely a
  love it or hate it bar. Kind of a cult classic thing" (c3k55p, 2019-06). Opens early
  on St. Patrick's Day ($3 green beer).
- **Exterior / pigeon cue:** low Irish-pub storefront in the block corner position,
  dark green/black paint scheme typical of the genre, sidewalk patio rail on the west
  side, basement stair signs; faces the Lincoln Way/Welch crosswalk.
- **Status source:** Class C license renewal (outdoor service) at 109 Welch Ave, Ames
  City Council Dec 9 2025 minutes; Tasty Tuesday participant July 15 2025
  (https://discoverames.com — Tasty Tuesdays listing).

### 1.6 AJ's Ultra Lounge — club
- **Location:** 2401 Chamberlain St (OSM 26×12 m) — behind the Lincoln Way frontage,
  one block east of Welch; entrance faces Chamberlain.
- **Signature:** the club: "Walk up the stairs into the pitch black abyss and enter the
  best that Ames has to offer for clubbing... The cherry on top: the patio" (c3k55p,
  2019-06). Three levels, big dance floor, outdoor patio; late-shift venue (12–2).
- **Exterior / pigeon cue:** modest two-story commercial box on the alley-side street;
  the tell is the stair/second-level entry and the rooftop patio edge with string lights
  — from the air the patio is the recognizable part, not the door.
- **Status source:** Class C license renewal at 2401 Chamberlain St (Ames City Council
  agenda, 2025); Tasty Tuesdays in Campustown participant July 2025
  (https://amesalliance.com/upcoming-event/tasty-tuesdays-in-campustown-2025)

### 1.7 Outlaws — country bar
- **Location:** 2522 Chamberlain St (OSM 12×26 m narrow box), west of Welch on the
  Chamberlain back-street line.
- **Signature:** three-level country-rock bar — mellow ground floor, dance floor above,
  live bands, and "The Back 40" patio bar; the other 12–2 am anchor. Co-hosted "Masters
  on Welch Ave" April 2025. (Reddit pairs it with One Night Stand as the country
  pair — 18a4wgv/c3k55p era.)
- **Exterior / pigeon cue:** slim vertical bar box with a big painted-country sign;
  the Back 40 patio reads as a lit fenced yard behind the building — the only green
  glow in that row.
- **Status source:** venue hours/events listings (Wed–Sat 8 pm–2 am) and Tasty Tuesdays
  2025 participation; search snippets 2025 (phone 515-292-9668). Lost its license in
  early 2023, appealed, stayed open — still licensed since.

### 1.8 Café Beaudelaire ("Café B") — bar/restaurant
- **Location:** 2504 Lincoln Way — south side of Lincoln Way at the Welch corner
  (west of the intersection, first building off the strip).
- **Signature:** Brazilian counter food at a bar that wins "best restaurant in town"
  votes — the Bauru sandwich; $1 Long Island birthday ritual (c3k55p). "Cafe Baudelaire
  is the best restaurant in town IMO, try the Bauru" — r/ames, 2026-09 (1wr5jne).
- **Exterior / pigeon cue:** corner counter-joint storefront facing the Welch/Lincoln
  Way crossroads — flat glass front, window service counter, neon-ish signage band.
  From the air it's the lit corner at the head of the Welch strip, opposite the
  Memorial Union axis. (Interpolated ±50 m from OSM-anchored addresses 2546/2544 US
  Bank and 2320 23 Twenty; treat exact quadrant as approximate.)
- **Status source:** cafebeaudelaire.com (Tue–Sun 11–10, closed Mondays);
  Tasty Tuesdays 2025 participant.

### 1.9 Jeff's Pizza Shop — pizza / late-night
- **Location:** 2402 Lincoln Way, south side, just east of Welch near Stanton Ave.
- **Signature:** by-the-slice pizza beloved across decades — free Smotherella sticks
  Tuesdays (190t84, 2013); open till 2:30 am Thu–Sat; runs its own coffee bar
  mornings. "Jeff's Pizza is, and always will be, amazing pizza." — r/IowaCity, 2023-10
  (17eoagz).
- **Exterior / pigeon cue:** storefront strip under the student-apartment frontage;
  big glass slice-shop front with menu boards; late-night line spilling onto the
  Lincoln Way sidewalk is the pigeon's cue that it's the right block.
- **Status source:** jeffspizzashop.com (hours incl. Thu–Sat to 2:30 am, coffee bar
  8 am–4 pm).

### 1.10 Mr. Burrito — Mexican / late-night food
- **Location:** 2508 Lincoln Way — two doors west of Café B, same corner cluster.
- **Signature:** the post-midnight burrito pilgrimage ("post-midnight Mr. Burrito" is
  bucket-list material — thread 911jbh, 2018-07); family-owned, big burritos, late
  hours Wed–Sat to ~2 am.
- **Exterior / pigeon cue:** small glowing storefront next to Café B at the head of
  the strip; hand-painted-style sign; the 2 am crowd queues here and at Jeff's —
  model both as lit islands in a dark block.
- **Status source:** mrburritoia.com (hours); corroborated by Tasty Tuesdays-era
  listings and Superdog's own "across from Pizza Pit / near Mr. Burrito" lore.

### 1.11 Superdog — hot dog cart (late-night food, living landmark)
- **Location:** 208 Welch Ave — the cart parks outside BNC Field House, across from
  Kum & Go (203 Welch), ~20 years on the strip.
- **Signature:** "Ames' longest-operating late-night food stand" — the Superdog, chili
  cheese dog, Veggie Superdog; out till ~2:30 am on busy nights; shows up for 801 Day.
  "Also, Superdog at 2AM." — r/iastate bucket list (911jbh, 2018-07).
- **Exterior / pigeon cue:** a rolling cart with umbrella and steam, parked at the
  east curb mid-200-block — the only moving venue on Welch. Model as a reusable prop
  with a night-shift position.
- **Status source:** amessuperdog.com (merch/menu, active); Instagram @amessuperdog
  posting 801-Day appearances; phone 515-290-6265.

### 1.12 Hickory Park — restaurant institution (changed hands, still open)
- **Location:** 1404 S Duff Ave, hickoryparkbbq.com, (515) 232-8940.
- **Signature:** BBQ + 20 flavors of ice cream sundaes; "Hickory park is where people
  who aren't from Ames go to eat when they come to Ames" (osc33r, 2021-07). Founder
  David Wheelock sold to Bernau Capital Partners effective **Aug 31, 2019** after 49
  years; community consensus since: "Hasn't been the same since it was sold"
  (1o4po9s, 2025-10); "biggest waste of money now" (1wr5jne, 2026-09). Still the
  gameday/visitor default — model it, but the grief is part of the anchor.
- **Exterior / pigeon cue:** freestanding big-box restaurant in a sea of parking along
  S Duff; model a generic large western-style BBQ barn/restaurant with a big roadside
  pylon sign; sundaes = the draw, parking lot = the shape.
- **Status source:** operating through Dec 2025 (events booked, hickoryparkbbq.com);
  sale: https://www.amestrib.com Ames Tribune/DMR coverage Sept 2019 (details in
  `../community/REDDIT-RESONANCE.md` §4).

### 1.13 The Cafe — quality-dinner shrine
- **Location:** 2616 Northridge Pkwy — NORTH Ames near the ISU Research Park's
  Northridge area, NOT south of campus (its sister restaurant Provisions Lot F is at
  2400 N Loop Dr in the SOUTH research park, ~4.5 km away). *(QA fix 2026-11-08 per
  QA-REPORT item 4 / A-15; ledger V-19.)*
- **Signature:** farm-to-table rotations, weekend brunch, boutique bar. "I've
  extensively traveled the U.S. and a good number of countries, and I've _never_ found
  a restaurant as high of quality as The Cafe for anything less than double the
  price." — r/iastate, 2022-04 (tv3uj7).
- **Exterior / pigeon cue:** low modern stand-alone restaurant in the research-park
  greenery — pitched-roof dining room with a patio, surrounded by lawn; nothing like
  the Campustown strip; recognizable as "the nice one in the trees."
- **Status source:** ~4.4/5 rating listings with current hours (March 2025 "highest
  rated breakfast" lists); search-verified 2025.

### 1.14 Great Plains Sauce & Dough Co. — pizza (downtown)
- **Location:** 129 Main St, Ste 101, north side of Main near Duff/Douglas — the
  100 block's EAST end of the historic strip. *(QA fix 2026-11-08 per QA-REPORT
  item 4 / A-16; ledger V-06 — Main numbers increase westward.)*
- **Signature:** Denver-style Thick Wheat crust since 1979; dip the crust in honey —
  "Great Plains Pizza! ... dip the crust in honey, trust me" — r/ames, 2026-07
  (1v0jf10).
- **Exterior / pigeon cue:** classic 2-story downtown brick storefront, painted
  signboard, big pie-shop windows; sits in the continuous Main Street wall of
  1880s–1920s commercial blocks (see §3.2 sequence).
- **Status source:** greatplainspizza.com (Sun–Wed 11–10, Thu–Sat 11–11, "since 1979").

### 1.15 Es Tas — *mourned*; its slot in the heart of the strip
Cross-reference: the December 2024 eviction emptied the most-recent Tier-1 name
(120 Welch original; 216 Stanton flagship). Community anchor: "RIP cheap taco night.
You will be missed." (1h8filz, 2024-12). Full entry in §5.4. The 216 Stanton space
reopened as **The Stan Tap** in 2025 (§2.15).

---

## 2. Tier 2 — well-known (the next names a student gives)

### 2.1 Mother's Pub & Coffee — bar + coffeehouse hybrid
- **Location:** 2900 West St (OSM 17×13 m), the West Street bar-hop's anchor.
- **Signature:** "mother's pub isn't super popular but i'd say it's worth including
  simply bc it's the prettiest bar in town" (18a4wgv, 2023-12). Coffee/lattes by day,
  cocktails by night; trivia Tuesdays 7 pm; open-mic every other Thursday; hosted a
  "Thrift Market" Sept 21 2025. Starter bar of the 8–10 pm shift.
- **Exterior / pigeon cue:** house-scale corner pub on West Street — porch-ish front,
  small sign, string-light patio vibe; reads "neighborhood living room," not "bar box."
- **Status source:** Yelp/Toast/MapQuest listings with 2025 events;
  Facebook "Mother's Pub Page."

### 2.2 Thumbs — dive bar (the insider's pick)
- **Location:** 2816 West St (OSM 6×21 m — one of the skinniest venues in town),
  two doors north of West Street Deli.
- **Signature:** "Thumbs. Only the best know the west street bar hop." (18a4wgv,
  2023-12). $3 Hamm's, "Grape Bombs," Mug Club, happy hour 3–6 pm.
- **Exterior / pigeon cue:** a slot of a bar — 6 m wide facade squeezed between
  row buildings; hand-painted sign; if you model West Street, Thumbs is the door
  almost hidden between the deli and the shops.
- **Status source:** Yelp listing (2816 West St) with current promos; phone
  515-268-1556. UNVERIFIED recency (no 2025-dated event post found) — flag low-risk.

### 2.3 West Street Deli — sandwich shop
- **Location:** 2810 West St, weststreetdeliames.com, (515) 268-4605.
- **Signature:** 25+ years of toasted sandwiches, house-smoked meats, scratch soups;
  celebrated its 25th with Tasty Tuesdays 2025 combos. The noon counterpoint to the
  West Street night strip.
- **Exterior / pigeon cue:** small storefront deli in the same row as Thumbs; chalk
  sandwich boards on the sidewalk are the daytime cue.
- **Status source:** weststreetdeliames.com + daily-special posts June 2025.

### 2.4 BNC Field House — sports bar
- **Location:** 206 Welch Ave, east side of the 200 block (OSM 32×14 m), opposite
  Welch Ave Station; Superdog parks at the curb (#208).
- **Signature:** the game-day screens bar — trivia, karaoke, comedy nights (ISU
  standup club every other Wednesday), Bachelor nights; Classic Burger + wings.
- **Exterior / pigeon cue:** wide low sports-bar storefront, big flat sign band,
  TV-glow windows; model the widest ground-floor frontage in the 200 block's east row.
- **Status source:** bncfieldhouse.com (hours ~4 pm–2 am, 2025 events); ISD 2021
  nightlife guide.

### 2.5 Blue Owl Bar — sports bar (Campustown's new mid-tier room)
- **Location:** 223 Welch Ave, Ste 3, west side of the 200 block in the Welch Crown
  Center building (217 Welch block).
- **Signature:** sports bar with outdoor service license; Tasty Tuesdays July 2025
  participant. (The older "Blue Owl" of 2019 threads — trivia/karaoke era — is a
  predecessor name/venue; treat this as the current bearer.)
- **Exterior / pigeon cue:** suite-level storefront inside a mid-block commercial
  strip; modest sign; patio tables out front under the license.
- **Status source:** Class C license (outdoor service/catering) + Tasty Tuesdays July
  2025 (amesalliance.com); Facebook/Instagram active.

### 2.6 Cornbred Barbecue — BBQ (the local-success-story)
- **Location:** 526 Main St, Ste 106 — in the restored railroad depot at downtown's
  WEST end near Clark/Pearle (opened as a restaurant June 2019 after the food-truck
  run). *(QA fix 2026-11-08 per QA-REPORT item 4 / A-17; ledger V-06.)*
- **Signature:** "cornbred bbq is top tier" (qfjqxd, 2021-10); "Cornbread >>>"
  (1o4po9s, 2025-10). The standing answer to "good BBQ now," i.e., the post-Hickory
  pride pick.
- **Exterior / pigeon cue:** the depot itself is the landmark — a single-story 19th-c.
  rail depot form (long, low, deep eaves, brick) hard by the UP main line at Main's
  west end, with a covered patio. A pigeon flying the rail line finds it instantly.
  *(QA fix 2026-11-08 per QA-REPORT item 4 / A-17.)*
- **Status source:** cornbredbbq.com (Mon–Tue 11–8 etc.); June 2019 opening on record.

### 2.7 Whiskey River — bar & grill (downtown game-day)
- **Location:** 132–134 Main St (official site: 134), south side, 100 block.
- **Signature:** the "old Whiskey River" tribute — dive-bar-style grill, 11 am–2 am
  daily; the 2019/2026 game-day downtown pick in Reddit threads (c3k55p / 1rbbgwr
  eras).
- **Exterior / pigeon cue:** corner-ish downtown storefront with a saloon-style
  signboard; steady day-to-night glow on the south sidewalk.
- **Status source:** whiskeyriveronmain.com (hours, online menu, Halloween 2025
  "Trick or Drink" specials).

### 2.8 London Underground — British pub (downtown)
- **Location:** 212 Main St, south side, 200 block; open since 2006.
- **Signature:** "London Underground for a great dark and welcoming pub" (qfjqxd,
  2021-10) — the no-lights conversation pub, the antithesis of Campustown; live
  music + a "Books & Beverages" club (second Saturdays, as of May 2025).
- **Exterior / pigeon cue:** below-street-level English pub front — dark paint, small
  windows, hanging sign; the darkest doorway on Main. Model the "down" stairs.
- **Status source:** downtownames.org/directory/london-underground + Facebook
  (booking email live 2025).

### 2.9 Time Out — barcade (downtown)
- **Location:** 120 Kellogg Ave (one block south of Main, at Kellogg; OSM 36×19 m).
- **Signature:** retro arcade bar — Galaga/Frogger/pinball/skeeball, karaoke Thu–Sat;
  "check out Timeout bar and arcade on Kellogg... If you like playing some Digdug,
  pinball, or skeeball while having a delicious drink" (1rbbgwr, 2026-02).
  Family-friendly till 7 pm, 21+ after.
- **Exterior / pigeon cue:** low brick storefront set back off Main on Kellogg; the
  rooftop/negative-space sign "TIME OUT" in marquee letters; arcade cabinet silhouettes
  in the front windows.
- **Status source:** downtownames.org/directory/time-out + Facebook (karaoke schedule).

### 2.10 The Mucky Duck Pub — English pub + British foods shop
- **Location:** 3100 S Duff Ave (NOT Main Street — older listings say 1415 Duff).
- **Signature:** "Mucky duck pub - A little slice of England in the center of Iowa"
  (18a4wgv, 2023-12); fish & chips, Saturday biscuits-and-gravy, live music; runs
  amesbritishfoods.com.
- **Exterior / pigeon cue:** suburban pub in a strip/standalone spot on S Duff —
  hanging black-and-gold pub sign, cream facade; the British-market next door is the
  tell.
- **Status source:** themuckyduckpub.com (hours); TripAdvisor reviews Feb 2025.

### 2.11 Torrent Brewing Company — brewery taproom (downtown)
- **Location:** 504 Burnett Ave (downtown N–S street, one block west of Kellogg).
- **Signature:** ~18 taps, board games, fire pit; trivia nights (June 2025 on the
  calendar); parade-day specials. The 2026 Reddit "visiting Ames" era pick
  (1wr5jne).
- **Exterior / pigeon cue:** warehouse-y taproom corner with a big grain-themes mural
  opportunity; fire-pit patio glows in the evening — the only fire glow downtown.
- **Status source:** torrentbrewingco.com + downtownames.org/directory/torrent-brewing-company.

### 2.12 Aunt Maude's — the "fancy dinner" of memory
- **Location:** 547 Main St (moved from its old Fifth Street address; auntmaudes.com).
- **Signature:** the celebratory-dinner name in the senior-farewell list (tv3uj7,
  2022-04); TripAdvisor #3 of 134 Ames restaurants.
- **Exterior / pigeon cue:** white-tablecloth storefront at Main's west end —
  awning, modest brass-and-glass front; the "date night" glow among retail.
  *(QA fix 2026-11-08 per QA-REPORT item 4 / A-18; ledger V-06.)*
- **Status source:** auntmaudes.com + TripAdvisor (active, 4.5/5).

### 2.13 The Grove Cafe — diner (nearly 80 years)
- **Location:** 124 Main St, south side of the 100 block (relocated here from Burnett
  Ave years back).
- **Signature:** breakfast-and-lunch only, the "mysteriously addicting" pancake; open
  6 am; ~80 years running (Ames Tribune profile July 22, 2024).
- **Exterior / pigeon cue:** narrow diner storefront with a striped-awning feel,
  counter window glow at dawn — the sunrise venue, paired with Morning Bell across
  the street.
- **Status source:** https://www.amestrib.com/story/lifestyle/food/2024/07/22/grove-cafe-in-ames-still-going-strong-after-nearly-80-years/74413859007

### 2.14 Provisions Lot F — sister restaurant to The Cafe
- **Location:** 2400 N Loop Dr, ISU Research Park (7,000 sq ft buildout).
- **Signature:** the modern "take people to eat in Ames" default pair with The Cafe —
  "My go to is Provisions and The Cafe now when taking people to eat in Ames"
  (1o4po9s, 2025-10).
- **Exterior / pigeon cue:** big modern barn-glass restaurant in research-park
  landscaping; larger and boxier than The Cafe; big parking field.
- **Status source:** listings/ratings 2025 (search-verified).

### 2.15 The Stan Tap — the successor in Es Tas's room
- **Location:** 216 Stanton Ave (the former Club 8 → Es Tas building).
- **Signature:** neighborhood bar & grill — craft drafts, espresso martinis, bar food,
  daily happy hour; opened 2025 in the ex-Es Tas space ("OPEN TODAY! A warm corner in
  Ames..." — venue Instagram).
- **Exterior / pigeon cue:** reuse the Es Tas box (corner bar building at Stanton &
  Chamberlain-ish); new sign paint. For the game: model the BUILDING as the constant,
  signage changes with eras.
- **Status source:** TownVue/Stumblon listings at 216 Stanton + Instagram announcement
  (2025). UNVERIFIED exact opening month.

### 2.16 Sam's Place — pool hall (the Corner Pocket reborn)
- **Location:** 125 Main St, north side, 100 block — the former Corner Pocket/DG's
  building.
- **Signature:** opened Nov 15 2022 with 14 pool tables, 10 arcade games, NFL/ISU TV
  packages; dive-ish karaoke bar.
- **Exterior / pigeon cue:** classic downtown pool-hall front — dark glass, cue-and-
  ball sign, the widest "game room" glow on that block.
- **Status source:** https://www.amestrib.com/story/news/2022/11/15/sams-place-pool-hall-opens-downtown-ames-corner-pocket/69633706007
  (Note: part of Main was closed Sept 2022 over structural concerns with this same
  building just before opening — Ames Tribune, Sep 28 2022.)

### 2.17 Lost and Found Lounge — cocktail bar above Cy's Roost
- **Location:** 121 Welch Ave, upper floor (shares the Roost address; ISD 2013 listed
  both).
- **Signature:** the shot/cocktail step above the mug bar — "Lost and Found Lounge –
  located above Cy's Roost; more cocktail/shot-focused" (Discover Ames 2024 guide).
- **Exterior / pigeon cue:** same skinny building as Cy's Roost (32×12 m); second
  door + staircase sign. Model as one building, two nightlife signs stacked.
- **Status source:** https://discoverames.com/blog/best-bars-and-nightlife-in-ames
  (April 2024). UNVERIFIED for 2026 — no independent 2025-dated listing found.

---

## 3. Tier 3 — deep lore and texture (the details that sell "real Ames")

### 3.1 Stomping Grounds Cafe — late-hours coffeehouse
- **Location:** 303 Welch Ave, Ste 101/105, west side of the 300 block — the far end
  of the strip. (NOT Main Street.)
- **Signature:** open late (to 11 pm), espresso + crepes, handmade pottery mugs; the
  same room operates as **Bar La Tosca** (beer/wine/spirits) — coffee by day, bar
  license attached.
- **Status source:** sgcafe.netlify.app + phone listings. UNVERIFIED recency — the
  website is a Netlify placeholder; flag for a second source before baking in.
- **Pigeon cue:** the last lit storefront at the quiet south end of Welch.

### 3.2 Clouds — the sky café
- **Location:** Legacy Tower, 119 Stanton Ave — 7th floor (the Reddit lane's "12th
  floor" is wrong per cloudsames.com; Legacy Tower is Campustown's one high-rise,
  OSM 60×38 m).
- **Signature:** European-style cake-and-coffee ~100 ft up with a panorama of campus;
  hours drift (Wed–Sun 10–6, seasonal); the community's own "pigeon's-eye" rec:
  "awesome coffee shop on the 12 level of Legacy Tower with great views of campus"
  (1b5g4de, 2024-03 — floor number theirs, view is real).
- **Status source:** cloudsames.com (fall-hours notices).
- **Pigeon cue:** the tower itself — model the rooftop restaurant glass band; the
  ghost of Legends (closed March 2012) haunts the top floors (§5.6).

### 3.3 Labyrinth Coffee — nonprofit coffee shop
- **Location:** 159 Sheldon Ave (Sheldon is the quiet residential street WEST of
  Hayward; address matches the Collegiate Presbyterian Church block — likely operates
  from/next to it; UNVERIFIED exact suite).
- **Signature:** sustainable coffee/tea/smoothies, community events free for ISU
  students; seasonal break hours ("As Ames slows down, Labyrinth takes a break too").
- **Status source:** listing snippets 2025 (phone 515-232-2310).
- **Pigeon cue:** the gentle one on the street where the noise isn't.

### 3.4 Ichiban Japanese Restaurant — sushi/ramen
- **Location:** 117 Welch Ave, west side of the 100 block (OSM 15×8 m), between
  Mickey's and Cy's Roost.
- **Signature:** sushi + ramen with online carryout; the strip's non-bar dinner option.
  (Occupies the old Fighting Burrito slot — see §5.10.)
- **Status source:** ichibanames.com/Clover ordering page live (hours posted).
- **Pigeon cue:** narrow glowing Japanese-facade slot between bars; red lantern cue.

### 3.5 Blue Fish Poke Bowl — poke
- **Location:** 127 Welch Ave, west side of the 100 block.
- **Signature:** Hawaiian-style poke bowls; Tasty Tuesdays participant; the modern
  Campus-town eatery layer.
- **Status source:** Ames Alliance Tasty Tuesdays listings; MenuGuide listing.
- **Pigeon cue:** bright minimal storefront among the old brick.

### 3.6 Macubana — Cuban (CLOSING as of this snapshot)
- **Location:** 116 Welch Ave, east side of the 100 block (the old Café Mood room;
  OSM 22×16 m), plus a footprint at 2504 Lincoln Way.
- **Signature:** food-truck-turned-brick-and-mortar Cubano sandwiches, mac bowls,
  Saturday breakfast empanadas/beignets; on the senior-farewell list (tv3uj7, 2022-04).
- **Status flag:** September 2026 report says it is preparing to **close the Welch
  brick-and-mortar** — likely truck-only going forward. Include the building, mark
  the tenant as end-of-era.
- **Status source:** search report dated Sept 2026 + StreetFoodFinder/Facebook.

### 3.7 Dogtown University — Cyclones apparel shop
- **Location:** 217 Welch Ave, Ste 101, west side of the 200 block (Welch Crown Center).
- **Signature:** not food — the spirit-wear shop named for **"Dogtown," Campustown's
  original nickname (before "Campustown," circa 1922)**. A perfect lore plaque for the
  strip: pigeons can perch on a "DOG TOWN" ghost sign.
- **Status source:** dogtownu.com; Tasty Tuesdays-era listings.
- **Pigeon cue:** cardinal-and-gold window displays; the name itself is the lore.

### 3.8 Thai Kitchen — Thai
- **Location:** 2410 Chamberlain St (Campustown back street, east of Welch).
- **Signature:** 20+ years of made-to-order Thai; pad thai/curry; Grubhub delivery.
- **Status source:** thaikitchenames.com.
- **Pigeon cue:** modest strip-mall storefront on Chamberlain's student row.

### 3.9 Szechuan House — Chinese
- **Location:** 3605 Lincoln Way (north side, far west of campus near the McFarland/
  McDonald's strip; ~1.4 km west of Welch). *(QA fix 2026-11-08: "3.5 km" → ~1.4 km
  per QA-REPORT item 9 / B-02 — OSM probe: 1.44 km from the Welch/Lincoln Way corner.)*
- **Signature:** 3.8/5 (107 reviews), the west-side sit-down Chinese; catering.
- **Status source:** szechuanhouseames.com; Nov 1 2025 event listing names it.
- **Pigeon cue:** suburban strip storefront with big red-and-gold sign on old
  Lincoln Way.

### 3.10 888 Restaurant — Chinese
- **Location:** 809 Wheeler St, Ste 106 (North Grand area, ~1.5 km north of downtown).
- **Signature:** humble strip-mall traditional Chinese, lunch specials; 2025 health
  inspection Sept 5 (i.e., operating).
- **Status source:** Stacker "highest-rated Chinese" Aug 21 2025; inspection record.
- **Pigeon cue:** strip-mall tile front; "888" pylon.

### 3.11 El Azteca — Mexican (two locations)
- **Location:** Somerset: 2727 Stange Rd; South: 2120 Isaac Newton Dr (moved 2020).
- **Signature:** 2025 Community Choice Awards "Best All Around" + "Best Mexican" in
  Ames; huge plates, homemade margaritas. (The original 13th Street spot is gone.)
- **Status source:** award listings + Aug 2025 reviews (search-verified).
- **Pigeon cue:** family-Mexican strip fronting the Stange Rd corridor.

### 3.12 Carlos Quesadilla — food truck (gameday fixture)
- **Location:** truck; base 806 Stange Rd; sells INSIDE Jack Trice Stadium on
  football gamedays (r/iastate reports).
- **Signature:** ~4.7★ nachos/tacos/carnitas; the gameday smell of Campustown.
- **Status source:** Yelp + Reddit gameday reports (search snippets).
- **Pigeon cue:** a truck prop with a game-day position at the stadium, weekday
  positions near campus.

### 3.13 Iowa State Creamery — student-run ice cream (campus)
- **Location:** Room 2953, Food Sciences Building, 536 Farm House Lane; retail shop
  opened Aug 2020 (original creamery operated 1927–1969).
- **Signature:** scratch ice cream with ISU-tradition flavors; Mon–Fri 12–5 pm;
  scoop schedule on Instagram.
- **Status source:** creamery.iastate.edu/hours (phone 515-294-3612).
- **Pigeon cue:** a small service window on a big brick lab building — treasure, not
  landmark.

### 3.14 Perfect Games — bowling/arcade (the rain-day institution)
- **Location:** 1320 Dickinson Ave (north Ames; NOT S Duff).
- **Signature:** 24 lanes, 2-story laser tag, arcade, food and bar; youth leagues
  running Sept 2025–Mar 2026; $2 games Mon–Wed nights.
- **Status source:** perfectgamesinc.com (league schedule 2025-26).
- **Pigeon cue:** big flat entertainment box with a lit sign row.

### 3.15 Whatcha Smokin' BBQ — the 15-minute pilgrimage (Luther)
- **Location:** 403 Iowa Ave, Luther, IA (off US-17/Hwy 17, ~15 min west of Ames).
- **Signature:** "arrive early... before they sell out" (1v0jf10, 2026-07); BBQ + brew.
- **Status source:** whatchasmokinbbq.com/contact.
- **Pigeon cue:** tiny smokehouse with a big smoker stack in a small-town lot — a
  nice out-of-city fly for the pigeon.

### 3.16 Morning Bell Coffee Roasters — worker-owned roastery
- **Location:** 111 Main St, Ste 101, north side (downtown EAST end, at Duff).
  *(QA fix 2026-11-08 per QA-REPORT item 4 / A-19; ledger V-06.)*
- **Signature:** Iowa's only worker-owned cafe (since ~2023); roasting on-site behind
  the shop; open 7–5 daily. The Grove Cafe's sunrise counterpart across the way.
- **Status source:** morningbellcoffeeroasters.square.site.
- **Pigeon cue:** roaster aroma-vent + burlap sacks out front; clean modern sign in an
  old brick wall.

### 3.17 Cafe Diem — the semester-schedule coffeehouse
- **Location:** 229 Main St (north side; also "The Loft" at 233 Main; Ankeny + DMACC
  branches).
- **Signature:** 7 am–9 pm during fall/spring semesters, **closed summers** — the
  semester rhythm made concrete. (In OSM as of the Nov 2026 extract.)
- **Status source:** cafediem.com (semester-hours note).
- **Pigeon cue:** late-open bookshop-cafe glow; UNVERIFIED whether summer 2026
  closure is permanent or seasonal (site says seasonal).

---

## 4. The Welch Avenue strip as a fly-through (geographic order)

Run the pigeon south out of campus across Lincoln Way, then drift down Welch block by
block. Coordinates = OSM centers; "W/E" = side of Welch; L/W = Lincoln Way side.

**Gate — Lincoln Way & Welch intersection.** The crossroads itself is the anchor:
the 2014 VEISHEA riot tore a stoplight down here (r/iastate 1hthf9w), 801 Day floods
it every August, and "everyone just knew to gather on Welch" (1spv39t). Model the
intersection generously wide — it's the emotional center of the city.

**L/W south frontage at the corner (west of Welch):**
1. **Café Beaudelaire** (2504 L/W) — the lit corner counter (Tier 1).
2. **Mr. Burrito** (2508 L/W) — two doors west, the 2 am burrito (Tier 1).
   *(East of Welch on L/W: 23 Twenty Lincoln (2320) with Blaze Pizza, then The
   Foundry (2300) with Pizza Pit Extreme in its ground floor — the two 2020s student
   towers; then Memorial Lutheran (2228) and St Thomas Aquinas (2210) facing campus,
   then the Greek houses (2112–2136) and Geoffroy/Buchanan toward University Blvd.
   QA fix 2026-11-08: order corrected per QA-REPORT item 4 / A-21 — ledger V-20.)*

**Welch 100 block (Lincoln Way → Chamberlain; ~130 m; the dense bar block):**
- W side: 3. **Mickey's** (109) → 4. **Ichiban** (117) → 5. **Cy's Roost + Lost and
  Found** (121) → 6. **Blue Fish Poke** (127).
- E side: 7. **Macubana** (116, closing) → 8. **[120 vacant — ex-Es Tas]** →
  9. **Portobello Road** boutique (122) → 10. **Paddy's (124) over Sips (126)** →
  11. **Fire Station 2** (132, slated to move to State Ave).

**Chamberlain Street crossings (the back-street bar row, W→E):**
- W of Welch: 12. **AJ's Liquor** (2515), **Chamberlain Lofts** (2519),
  13. **Public House** (2520 — UNVERIFIED tenant), 14. **Outlaws** (2522),
  15. **ex-Little Taipei** (2514, closed Oct 2024), Planned Parenthood (2530).
- E of Welch: 16. **AJ's Ultra Lounge** (2401), 17. **Thai Kitchen** (2410),
  Clock Tower Place (2410).

**Welch 200 block (Chamberlain → Hunt; the big-draw block):**
- W side: 18. **Kum & Go** (203, the beer-run store) → 19. **Welch Ave Station**
  (207, Pizza Pit above) → 20. **Welch Crown Center** (217: **Dogtown University**
  Ste 101; **Blue Owl Bar** Ste 3 at 223).
- E side: 21. **Campustown Court** (204) → 22. **BNC Field House** (206) →
  23. **Superdog cart** (208, curbside).

**Welch 300 block (south of Hunt; the quiet tail):**
- W side: 24. **Stomping Grounds** (303) → Theta Xi house (315).
- E side: apartments (304, Adelante 318).

**Side streets:** Hayward Ave (one block west) is residential today — its venue ghost
is Battle's Bar-B-Q at 112 Hayward (closed 2009, §5.7); the Greek-free quiet street is
part of the bar-hop lore ("only the best know the west street bar hop" — that's WEST
Street, two blocks further west: Mother's 2900, West Street Deli 2810, Thumbs 2816,
1+1 Restaurant & Tea 2814, The Pier 2721). Sheldon Ave (west edge) holds Labyrinth
Coffee (159). Stanton Ave (east) holds **Legacy Tower** (119 — Clouds café, and the
ghost of Legends) and **The Stan Tap** (216).

**Night-flow overlay (from the Reddit decade):** 8–10 pm — Mother's/Thumbs (West St)
and Mickey's patios; 10–12 — Cy's Roost, Mickey's basement, Paddy's; 12–2 — Sips,
AJ's, Outlaws; 2 am — Superdog cart, Mr. Burrito, Jeff's (Thu–Sat). Downtown after:
London Underground, Time Out.

---

## 5. Lincoln Way corridor and downtown Main Street (same treatment, fewer entries)

### 5.1 Lincoln Way corridor (west → east)
West of Campustown the corridor is chain-and-car-lot country with three stops that
matter: **Szechuan House** (3605, Tier 3), **Fareway Meat Market #189** (3720 — a
meat market, NOT the full grocery; the full store is at 619 Burnett Ave,
`../landmarks/LANDMARKS.md` T4; rename the sign in-game), **Hy-Vee**
(3800). *(QA fix 2026-11-08: Fareway address corrected per QA-REPORT item 4 / A-22 —
ledger V-15; 534 S Duff is the Walmart Supercenter.)* At the Campustown gate (W→E on the south side): **Dunkin'** (2650), **U.S.
Bank** (2546), **Mr. Burrito** (2508), **Café Beaudelaire** (2504) — then the Welch
intersection — **23 Twenty Lincoln** (2320) with **Blaze Pizza**, then **The Foundry**
(2300) with **Pizza Pit Extreme** (2306), the campus churches (2228/2210), Greek row
and towers toward University Blvd. *(QA fix 2026-11-08: Foundry/23-Twenty order
corrected per QA-REPORT item 4 / A-21 — ledger V-20.)* North side of L/W in Campustown is dominated by the
Memorial Union frontage and the 2020s redevelopments; **23 Twenty Lincoln replaced
nine buildings demolished in 2014** (Kingland project + Champlin buildings) — the
biggest single Campustown change since VEISHEA's fall.

### 5.2 Downtown Main Street sequence (east → west along Main; N/S side)

*(QA fix 2026-11-08: label reversed per QA-REPORT item 4 / A-20 — ledger V-06:
Main numbers increase westward, so this list as written runs east→west.)*

1. **Morning Bell Coffee** (111 N) → 2. **Mary Jane's** (119 N, NEW 2026 — the
   six-musician "elevated dive bar" that replaced the Angry Irishmen; Ames Tribune,
   March 2026) → 3. **Sportsman Lounge** (123 N, running since at least 2013) →
   4. **The Grove Cafe** (124 S) → 5. **Sam's Place** pool hall (125 N) →
   6. **Great Plains Sauce & Dough** (129 N) → 7. **Whiskey River** (134 S) →
   8. **London Underground** (212 S) → 9. **Cafe Diem** (229 N) → 10. **torrent
   Brewing** (504 Burnett, one block off-corridor) → 11. **Cornbred BBQ** (526 S,
   the depot) → 12. **Aunt Maude's** (547 N).
Off-corridor: **Time Out** (120 Kellogg, one block south of Main). The Saturday
farmers market closes Main — the downtown's other ritual (1wmk7h0, 2026-09).

---

## 6. CLOSED / MISSED — the grief inventory (students mourn closures; that's data)

| Venue | Address | Closed | How we know |
|---|---|---|---|
| **Es Tas Bar & Grill** | 120 Welch Ave (original) + 216 Stanton Ave (flagship, ex-Club 8) | **Evicted Dec 2, 2024** (~$26k/5 months back rent); owners said Jan 2025 it won't reopen | Ames Tribune Jan 7 2025: https://www.amestrib.com/story/news/local/2025/01/07/building-owners-say-es-tas-wont-reopen-in-ames/77171723007 ; r/iastate 1h8filz: "RIP cheap taco night. You will be missed." / "It was my go to. Last bar I was at in college." |
| **Little Taipei** | 2514 Chamberlain St | **Closed permanently Oct 5, 2024** (announced ~Oct 4) | Ames Tribune Oct 4 2024: https://www.amestrib.com/story/news/local/2024/10/04/when-is-little-taipei-asian-restaurant-closing-its-doors-in-ames/75511965007 ; the Szechuan green beans still unmatched ("Missing Ames" thread lyqanp) |
| **People's Bar & Grill** | 2430 Lincoln Way | **May 31, 2007** (open since Aug 1990) | Closure reporting via search (2007); mourned as "Peoples - RIP" as late as 2023 (18a4wgv) and the "replace People's with a music venue" wish (lyqanp, 2021) |
| **DG's Tap House + Corner Pocket** | 125 Main St | **May 2019** (licenses suspended Apr 30, 2019; permanent) | DMR/KCCI/ISD coverage — owner tax/labor violations; "went silent" May 16 2019; Corner Pocket building stayed dark as of 2022 |
| **Olde Main Brewing** | 316 Main St | **May 2019** (same owner) | same coverage |
| **Legends (rooftop)** | Legacy Tower, 119 Stanton | **End of March 2012** (~5,600 sq ft) | Ames Tribune May 2012 (via search); mourned in the 2013 visiting-Ames thread (190t84) |
| **Battle's Bar-B-Q** | 112 Hayward Ave, later 218 Welch Ave | **2009**, after George Battle died (75); sauce lives on via Sauce Slingers (~2023), carried at Ames Hy-Vee; Jimmy's BBQ (Boone) follows the recipe | obituary + closure coverage via search; Reddit: "Battles was good but his kids couldn't figure out the business after George died" and "RIP battles, holy shit" (1o4po9s, 2025-10) |
| **Hickory Park — SOLD (not closed)** | 1404 S Duff | Founder sold to Bernau Capital Partners **effective Aug 31, 2019**; still operating, consensus "never the same" | Ames Tribune/DMR Sept 2019; 1o4po9s + 1wr5jne quotes above |
| **One Night Stand** (country bar) | Welch Ave (listed 121/124 Welch in various records) | Opened Jan 14 2016; **closed by ~2023** (lost license Jan 2023; MapQuest/Yelp CLOSED) | ISD "Country rock bar opens in Campustown" Jan 22 2016; council Jan 2023 |
| **Fighting Burrito** | 2712 Lincoln Way (2004, as "Flying Burrito"), later 117 Welch | **May 2019** after 14 years | closure reporting via search (Reddit 9jfeua-era fans) |
| **The Angry Irishmen** | 119 Main St | **Closed ~2025–26; replaced by Mary Jane's** (six musicians, "elevated dive bar") | Ames Tribune March 2026 (via search); "whatever happens with Irishmen once it's overhauled..." (1rbbgwr, 2026-02) |
| **Wise Guys** | 120 Welch Ave | closed before Es Tas took the room (no closure article found) | ISD opening piece 122142; absent from all 2024–25 listings |
| **Charlie Yoke's** | 2430 Lincoln Way | closed sometime after 2013 (People's old room) | ISD 2013 directory; absent from current listings |
| **Café Mood** | 116 Welch Ave | closed; room is Macubana's now | ISD 2013 directory; OSM 2026 tags the room Macubana |
| **The Scene** | 124–126 Welch Ave | closed; its LLC became Paddy's/Sips | ISD 211113; July 2025 license record (THE SCENE, LLC DBA Sips and Paddy's) |
| **West Towne Pub** | Westown Pkwy | **April 2024** after ~20 years | closure announcement via search |
| **Cocost** | downtown era venue | gone by mid-2010s | named only in the 2013 thread (190t84) — UNVERIFIED details |

Pre-2014 VEISHEA-era losses are mostly *traditions*, not venues: VEISHEA itself (last
held 2014; the riot stoplight died at Lincoln Way & Welch), Ash Bash on Ash Ave, the
cherry pies — see `../community/REDDIT-RESONANCE.md` §3–4. The physical venue layer
that died with it: the roof-raising Paddy's night of April 2014 (quote in §1.2).

---

## 7. Dated snapshot note & unverified flags

**This inventory reflects sources dated no later than 2026-11-08.** Liquor-license
evidence runs to Dec 2025 city-council minutes; event-based evidence (Tasty Tuesdays,
Masters on Welch Ave) to July–Sept 2025; the Macubana closure report is dated Sept
2026; Mary Jane's replacing the Angry Irishmen is dated March 2026. Businesses on the
strip churn fast — re-verify any venue before baking its name into a build.

**UNVERIFIED (could not confirm still operating as of 2026-11-08):**
- **Thumbs** (2816 West St) — listing-verified but no 2025-dated event found.
- **Lost and Found Lounge** (121 Welch, upstairs) — last clear sighting April 2024.
- **Stomping Grounds / Bar La Tosca** (303 Welch) — Netlify placeholder site; needs a
  second source.
- **Public House** (2520 Chamberlain) — OSM-mapped, no independent web presence found.
- **El Maguey** (217 S Duff — on the 2022 farewell list) — Stacker ranked it Jan 2025,
  but Yelp now lists CLOSED; status conflict, do not bake in.
- **Welch Ave reconstruction completion** — phased through 2025–26; not confirmed
  complete as of this writing (cityofames.org/Welch).
- **Labyrinth Coffee** exact suite at 159 Sheldon (church-building adjacency assumed).
- **Cafe Diem summer-closure** — seasonal per its site; confirm not permanent.

**Not counted in tiers but verified near-corridor texture:** Kum & Go (203 Welch),
Portobello Road boutique (122 Welch, since 2012), Fire Station 2 (132 Welch), Legacy
Tower (119 Stanton), Fareway Meat Market (3720 L/W — full store 619 Burnett; 534 S
Duff is Walmart; QA fix 2026-11-08 per QA-REPORT item 4 / A-22, ledger V-15), The
Pier (2721 West St), 1+1
Restaurant & Tea (2814 West St), Freddy's Frozen Custard (Campustown Tasty Tuesdays
participant, 2025).

---

## 8. Source register (per-venue status)

- Official sites: welchave.com/location · cafebeaudelaire.com · jeffspizzashop.com ·
  mrburritoia.com · amessuperdog.com · hickoryparkbbq.com · bncfieldhouse.com ·
  dogtownu.com · thaikitchenames.com · szechuanhouseames.com · weststreetdeliames.com ·
  whiskeyriveronmain.com · themuckyduckpub.com · torrentbrewingco.com ·
  auntmaudes.com · cornbredbbq.com · greatplainspizza.com · cloudsames.com ·
  creamery.iastate.edu/hours · perfectgamesinc.com · whatchasmokinbbq.com/contact ·
  morningbellcoffeeroasters.square.site · cafediem.com · ichibanames.com.
- Directories/events: discoverames.com (business listing + Apr 2024 bars guide) ·
  downtownames.org/directory (London Underground, Time Out, torrent) ·
  amesalliance.com Tasty Tuesdays in Campustown 2025 (July 2025 participant list) ·
  traveliowa.com (Grove Cafe).
- News: Ames Tribune — Es Tas eviction (Jan 7 2025), Little Taipei closing (Oct 4
  2024), Sam's Place opening (Nov 15 2022) + Main St structural closure (Sep 28
  2022), Grove Cafe 80-years profile (Jul 22 2024), Hickory Park sale (Sept 2019),
  Mary Jane's/Angry Irishmen (Mar 2026); Iowa State Daily — 2013 bar directory
  (118161), nightlife guide (248829, Aug 20 2021), Paddy's/The Scene (211113), One
  Night Stand opening (Jan 2016), Wiseguys opening (122142); City of Ames — Welch
  reconstruction (Apr 29 2025), Fire Station 2 relocation.
- City records: Ames City Council liquor-license minutes — Cy's Roost renewal (Jan 14
  2025), Mickey's renewal (Dec 9 2025), Sips & Paddy's at 126 Welch (Dec 2025), THE
  SCENE LLC DBA (Jul 8 2025), AJ's at 2401 Chamberlain, One Night Stand suspension
  (Jan 2023).
- Geometry: all footprints/centers from `../osm/raw/ames_merged.json` (sibling extract,
  2026-11-08); community quotes from `../community/REDDIT-RESONANCE.md` (Arctic Shift
  archive, 2026-11-08).

*Research agent, 2026-11-08. 48 open venues across the three tiers (Tier 1: 14, Tier 2:
17, Tier 3: 17) plus 17 closed/mourned entries in §6 and 8 flags in §7. Slightly over
the 30–45 target by design: the extra Tier-3 entries are the texture venues students
name when they're showing off, not eating.*
