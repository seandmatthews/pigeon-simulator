# Ames Survey — Reddit Community Resonance Report

Date-stamped: **2026-11-08**.
Scope: what r/IowaState, r/ames, r/Iowa (and a few adjacent subreddits) say they
*love, miss, mourn and ritualize* about Ames, Iowa — the emotional-weight layer
for rebuilding the game's city as real Ames.

**Method:** WebSearch for thread discovery (`site:reddit.com r/IowaState ...`
families: bars, restaurants, "things I miss", hidden gems, campanile/tradition,
Welch Ave, Hickory Park, VEISHEA, tailgating, nature spots). Reddit's own
endpoints (www, old, api, redlib mirrors) all serve bot-block pages from this
network, so thread contents were pulled from the **Arctic Shift public archive**
(`arctic-shift.photon-reddit.com`, post + full comment trees; raw JSON cached in
`_cache/`, fetch helper `_fetch.py`). 45 threads were fetched and read; a
handful of r/CFB wiki/guide pages could not be fetched and are cited as
**search-snippet only** where used. Quote text is verbatim from the archive
except that line breaks became spaces and archive mojibake (`Æ`, `╢`) was
normalized to `'` / punctuation. Everything marked *single-source* rests on one
comment or one thread — treat as color, not fact.

**Grounding from the sibling lanes** (not re-verified here, trusted): Campustown's
N–S streets are **Welch, Hayward and Sheldon Avenues** (Burnett Ave is downtown);
Lake LaVerne is ~2.8 ac; the Campanile is 33.5 m with 50 bells; Jack Trice holds
~61,500; the rail line is UP's Clinton Subdivision (ex-C&NW), a 70 mph through
main passing 44 m from Main×Duff. See `../landmarks/LANDMARKS.md` and
`../osm/SUMMARY.md`.

---

## 1. Ranked resonance table

Ranked by emotional resonance: how often the spot recurs across independent
threads, and how strongly people attach to it (return-pilgrimage language,
ritual language, grief when it's gone). "Type" is for the game build.

| # | Spot | Type | Why people love it | Representative quote (thread, date) |
|---|------|------|--------------------|--------------------------------------|
| 1 | **The Campanile** | campus landmark | THE icon of the college; the midnight-kiss rite of passage; the quarter-hour chimes scored people's whole undergrad | "wandering with no destination, hearing the campanile chime the quarter hours, talking and laughing with friends - golden hours, warmly remembered." — r/iastate, 2026-04 (https://www.reddit.com/r/iastate/comments/1spv39t/whats_the_most_iowa_state_thing_thats_ever) |
| 2 | **Welch Ave (the strip)** | street / nightlife district | Campustown's bar spine (Welch/Hayward/Sheldon are the N–S runs); the place the town *gathers* — big news nights, game nights, VEISHEA | "Also Bin Laden was killed my freshmen year... everyone just knew to gather on Welch. So I guess in general just rallying on Welch." — r/iastate, 2026-04 (https://www.reddit.com/r/iastate/comments/1spv39t/whats_the_most_iowa_state_thing_thats_ever) |
| 3 | **Lake LaVerne (incl. swans Lancelot & Elaine)** | campus water | The postcard pond by the MU; the swans are campus royalty (and famously two females); love-through-teasing nickname "Lake Latrine"; the three-laps marriage folklore | "So are Lancelot and Elaine just never coming back?... They were so iconic to ISU's campus :(" — r/iastate, 2025-08 (https://www.reddit.com/r/iastate/comments/1n51i2i/so_are_lancelot_and_elaine_just_never_coming_back) |
| 4 | **Welch Ave Station** | bar | The most-recommended single bar across a decade of threads; chill, pool/foosball, free 21st-birthday drink; the "safe" Welch pick alumni still name | "Go to welch Ave station. Best chill bar to hangout alone on welch Ave." — r/iastate, 2025-08 (https://www.reddit.com/r/iastate/comments/1mxscpm/are_any_campus_bars_good_to_go_to_alone) |
| 5 | **Paddy's Irish Pub** | bar | The most packed bar in Ames; the room where big campus moments *happen* (see the VEISHEA quote below); double-decker with club Sips in the basement | "Paddy's is probably the most packed bar in Ames." — r/iastate, 2019-06 (https://www.reddit.com/r/iastate/comments/c3k55p/how_are_the_bars_in_ames) |
| 6 | **Jack Trice Stadium** | stadium | Gameday is the town's biggest ritual; tailgating culture grown by decades of losing football; field-storming memories; Jack Trice's story as moral center | "As a life long Cyclones fan I can tell you our tailgating scene is probably the best in the Big 12. Historically we've been bad in football so we fans developed a great tailgating tradition." — r/cyclONEnation, 2024-10 (https://www.reddit.com/r/cyclONEnation/comments/1g3u145/first_trip_to_jacktrice) |
| 7 | **Hickory Park (S Duff)** | restaurant institution | The town's love-hate monument: every visitor and gameday tradition routes through it, every local has a grumble; sold 2019, "never the same since" | "Hickory park is where people who aren't from Ames go to eat when they come to Ames." — r/iastate, 2021-07 (https://www.reddit.com/r/iastate/comments/osc33r/best_restaurants_in_ames) |
| 8 | **Cy's Roost** | bar | The birthday-ritual bar: "21 mugs" for your 21st; mug night; decades old | "Cy Roost - the place for mug night and 21 mugs in your birthday (been around for a long time)" — r/iastate, 2023-12 (https://www.reddit.com/r/iastate/comments/18a4wgv/iowa_state_bars) |
| 9 | **Central Campus (the lawn)** | campus landscape | The huge green everyone loves in every season; moonlit picnics; aimless coin-flip walks; the "most beautiful campus" pride | "On warm weekend evenings, some friends and I used to go on 'random walks' around campus... The only rules were to stay on the campus proper - no crossing Lincoln Way." — r/iastate, 2026-04 (https://www.reddit.com/r/iastate/comments/1spv39t/whats_the_most_iowa_state_thing_thats_ever) |
| 10 | **The Cafe** | restaurant | Locals' genuine quality pride; the "you don't know how lucky we are" spot | "I've extensively traveled the U.S. and a good number of countries, and I've _never_ found a restaurant as high of quality as The Cafe for anything less than double the price." — r/iastate, 2022-04 (https://www.reddit.com/r/iastate/comments/tv3uj7/places_to_visit_in_ames_before_leaving) |
| 11 | **Cafe Beaudelaire ("Cafe B")** | bar/restaurant | Brazilian burgers at the corner counter; birthday Long Island ritual; keeps winning "best restaurant in town" votes from locals | "Cafe Baudelaire is the best restaurant in town IMO, try the Bauru" — r/ames, 2026-09 (https://www.reddit.com/r/ames/comments/1wr5jne/visiting_ames) |
| 12 | **Memorial Union** (Great Hall, fountain, M-Shop) | campus building | The front door of campus; the fountain is a character in student stories; the M-Shop is the town's last small music venue | "With DG's recently closed, the M-Shop is the only real venue around now afaik" — r/iastate, 2021-03 (https://www.reddit.com/r/iastate/comments/lyqanp/missing_ames) |
| 13 | **Jeff's Pizza** | restaurant | The pizza people carry for years; free Smotherella sticks Tuesdays; caps-lock loyalty | "Going back to Ames feels like an (empty) home. Some things feels the same (Jeff's Pizza is, and always will be, amazing pizza.)" — r/IowaCity, 2023-10 (https://www.reddit.com/r/IowaCity/comments/17eoagz/the_iowa_city_blues) |
| 14 | **Es Tas** (evicted 2024) | bar/restaurant (mourned) | Best bar food + taco night; the most recent genuine bar-grief in Campustown | "RIP cheap taco night. You will be missed." — r/iastate, 2024-12 (https://www.reddit.com/r/iastate/comments/1h8filz/es_tas_was_evicted_from_its_campustown_building) |
| 15 | **Campustown on 801 Day** | neighborhood-as-event | The Saturday-before-classes all-day party, starting 8:01 AM; the new students' shared first-week memory; now heavily policed | "801 Day is a party throughout Campustown starting at 8:01 AM the Saturday before classes." — r/iastate, 2020-08 (https://www.reddit.com/r/iastate/comments/i9ufu9/this_one_goes_out_to_all_the_frat_brossorority) |
| 16 | **Cornbred BBQ** | restaurant | The local food-truck success story people are proud of; the answer to "where's good BBQ now" | "cornbred bbq is top tier" — r/iastate, 2021-10 (https://www.reddit.com/r/iastate/comments/qfjqxd/first_time_visiting); "Cornbread >>>" — r/iastate, 2025-10 (https://www.reddit.com/r/iastate/comments/1o4po9s/hickory_park_sucks) |
| 17 | **Great Plains Sauce & Dough** | restaurant | The Denver-style Thick Wheat crust; dip the crust in honey; the only pizza some alums still crave | "Great Plains Pizza! ... dip the crust in honey, trust me" — r/ames, 2026-07 (https://www.reddit.com/r/ames/comments/1v0jf10/favorite_restaurants) |
| 18 | **CyRide** | transit | The bus system is part of the town's identity — friendly, free-ish, legendary; packed campus routes and the "free tuition if hit" dark joke | "Cyride seems so friendly compared to the bus systems other places." — r/iastate, 2021-03 (https://www.reddit.com/r/iastate/comments/lyqanp/missing_ames) |
| 19 | **Ada Hayden Heritage Park** | nature | The sunset walk; the dock; the bike loop; the town's favorite outdoor hour | "Ada Hayden park during sunsets is a must" — r/ames, 2024-03 (https://www.reddit.com/r/ames/comments/1b5g4de/things_to_do_and_hidden_gems_in_ames) |
| 20 | **The tailgate lots (Iowa State Center)** | event space | Where the town actually socializes on fall Saturdays; visitors get adopted; arrive 5–6 hours early | "If you're coming up from DSM on Saturday, make sure you get up there EARLY, like 5-6 hours before kickoff." — r/cyclONEnation, 2024-10 (https://www.reddit.com/r/cyclONEnation/comments/1g3u145/first_trip_to_jacktrice) |
| 21 | **Mucky Duck Pub** | restaurant | The English pub; fish & chips; Saturday biscuits-and-gravy claim | "Mucky duck pub - A little slice of England in the center of Iowa" — r/iastate, 2023-12 (https://www.reddit.com/r/iastate/comments/18a4wgv/iowa_state_bars) |
| 22 | **AJ's Ultra Lounge** | bar | The club; "cheap drinks and bad decisions"; the patio everyone names | "Walk up the stairs into the pitch black abyss and enter the best that Ames has to offer for clubbing... The cherry on top: the patio." — r/iastate, 2019-06 (https://www.reddit.com/r/iastate/comments/c3k55p/how_are_the_bars_in_ames) |
| 23 | **Mickey's** | bar | Cult-classic midrange bar with a dance-floor basement and a deck; love-it-or-hate-it by its own fans' admission | "Mickeys has a chill up stairs and a dance floor/pole basement... definitely a love it or hate it bar. Kind of a cult classic thing." — r/iastate, 2019-06 (https://www.reddit.com/r/iastate/comments/c3k55p/how_are_the_bars_in_ames) |
| 24 | **Mother's Pub** | bar | "Prettiest bar in town"; bar + coffee shop hybrid; starter bar of the 8–10pm shift | "mother's pub isn't super popular but i'd say it's worth including simply bc it's the prettiest bar in town" — r/iastate, 2023-12 (https://www.reddit.com/r/iastate/comments/18a4wgv/iowa_state_bars) |
| 25 | **Thumbs** | bar | The tiny engineers' bar on West Street; the insider's pick | "Thumbs. Only the best know the west street bar hop." — r/iastate, 2023-12 (https://www.reddit.com/r/iastate/comments/18a4wgv/iowa_state_bars) |
| 26 | **Sips** | bar | Paddy's pitch-black basement dance room; the "finisher"; sticky-floor legend | "Sips, the pitch black basement of paddy's. Sticky floor, fog machine on the dance floor, EDM nights and pretty dope lights." — r/iastate, 2019-06 (https://www.reddit.com/r/iastate/comments/c3k55p/how_are_the_bars_in_ames) |
| 27 | **Mr. Burrito & Superdog (late-night)** | late-night food | The post-midnight bucket-list meals; the 2 AM cart | "Serious answer... like the typical campaniling or post-midnight Mr. Burrito" (OP prompt) + "Also, Superdog at 2AM." — r/iastate, 2018-07 (https://www.reddit.com/r/iastate/comments/911jbh/what_should_be_on_any_iowa_staters_bucket_list) |
| 28 | **The zodiac (Memorial Union Gold Star Hall floor — NOT a Curtiss–Beardshear sidewalk; QA fix 2026-11-08 per QA-REPORT item 9 / A-23 — the Curtiss–Beardshear pairing is the streak run, TRADITIONS §9.5)** | campus superstition | Don't step on it or you flunk your next exam; alums still refuse to step | "I graduated 15 years ago and occasionally get back to campus. But still can't bring myself to step on it." — r/iastate, 2018-07 (https://www.reddit.com/r/iastate/comments/911jbh/what_should_be_on_any_iowa_staters_bucket_list) |
| 29 | **Parks Library** | campus building | The Stacks (and the "sex in Stacks" legend); the special-collections vault; the rumor of a secret live-in apartment | "Visit the special collections vault in the Parks Library... Also, Superdog at 2AM." — r/iastate, 2018-07 (https://www.reddit.com/r/iastate/comments/911jbh/what_should_be_on_any_iowa_staters_bucket_list) |
| 30 | **Marston Water Tower** | landmark | Campus lore generator: the bicycle somebody chained to the top catwalk | "One day a bicycle appeared, chained to the catwalk at the top of the water tower." — r/iastate, 2021-03 (https://www.reddit.com/r/iastate/comments/lxqeld/iowa_state_university_official_iceberg_any) |
| 31 | **London Underground** | downtown bar | The dark conversation pub downtown; the "no TVs" antithesis of Campustown | "London Underground for a great dark and welcoming pub" — r/iastate, 2021-10 (https://www.reddit.com/r/iastate/comments/qfjqxd/first_time_visiting) |
| 32 | **Time Out** | downtown barcade | Bar + 80s/90s arcade + karaoke + "butter beer"; the quirky downtown night | "check out Timeout bar and arcade on Kellogg... If you like playing some Digdug, pinball, or skeeball while having a delicious drink" — r/ames, 2026-02 (https://www.reddit.com/r/ames/comments/1rbbgwr/places_to_check_out) |
| 33 | **Downtown Main Street** | district | Saturday farmers market, local shops, Dog-Eared Books, public art; the non-student half of town life | "downtown farmers market Saturday morning." — r/ames, 2026-09 (https://www.reddit.com/r/ames/comments/1wmk7h0/must_dos_in_ames) |
| 34 | **Munn Woods / Pammel Woods / ISU Arboretum** | quiet nature trio | The townies' and nature-lovers' quiet pockets right at the campus edge | "Love to see Munn Woods on the list. Really an underappreciated little pocket of beauty in town." — r/ames, 2024-03 (https://www.reddit.com/r/ames/comments/1b5g4de/things_to_do_and_hidden_gems_in_ames) |
| 35 | **The albino squirrel (campus)** | living landmark | Spotting it is a blessing; people have framed photos; it shows up in job-interview stories | "Observe the albino squirrel and receive its blessing." — r/iastate, 2018-07 (https://www.reddit.com/r/iastate/comments/911jbh/what_should_be_on_any_iowa_staters_bucket_list) |
| 36 | **Reiman Gardens** | garden | The south-gate gardens; butterfly wing; the date/parents visit | "Reiman Gardens, Ada Hayden, bowling at Perfect Games..." — r/iastate, 2018-07 (https://www.reddit.com/r/iastate/comments/8zaonu/date_ideas) |
| 37 | **High Trestle Trail bridge (Madrid, ~25 min SW)** | nearby pilgrimage | The region's signature outing — 13-story former rail trestle, blue light rings, go at sunset | "Go at sunset. It's an old train trestle that crosses a river. The bridge is 13 stories from the river below." — r/Iowa, 2024-05 (https://www.reddit.com/r/Iowa/comments/1cnx5yz/vacationing_in_iowa_soon) |
| 38 | **Ledges State Park (Boone, ~20 min W)** | nearby escape | The default "get out of the flat" hike; overlooks and a creek | "Ledges State Park in Boone County is a gem." — r/iastate, 2025-06 (https://www.reddit.com/r/iastate/comments/1lbe6y3/what_is_there_onaround_campus_in_ames_for_nature) |

B-grade mentions that recur but with thinner evidence (each *single-source* or
spread across rec lists only): Iowa State Creamery (student-run ice cream,
2026-07), Fareway's bakery "cronut" ("a cronut from Fareway (trust me)",
r/ames 2026-07), The Grove Cafe ("tiny diner w/ famous pancakes", cash-only,
2026-07), The Spice / Thai Kitchen (Thai, 2021/2026), Aunt Maude's (the "fancy"
Ames dinner, 2022-07), West Street Deli (2022-04), Stomping Grounds & Provisions
Lot F (2022/2026), 888 & Szechuan House (Chinese, 2026-07), Outlaws/One Night
Stand (country bar pair, 2019-06), Blue Owl (trivia/karaoke, 2019-06),
Whiskey River (game-day downtown, 2019/2026), Angry Irishman (dive, 2019-06,
overhaul 2026-02), Cy's statuary ("take a picture with all of the Cy's around
town. I think there's about 30", r/iastate 2022-04,
https://www.reddit.com/r/iastate/comments/tv3uj7/places_to_visit_in_ames_before_leaving),
Clouds coffee on the 12th floor of Legacy Tower per the commenter ("great views of
campus", r/ames 2024-03 — floor number is the commenter's error: 7th floor per
cloudsames.com / ledger V-16; QA fix 2026-11-08 per QA-REPORT item 9 / A-24), Perfect
Games (bowling/mini-golf, 2018/2024),torrent Brewing
(2026-09), Dog-Eared Books (2024-03), Whatcha Smokin' in Luther (the 15-min BBQ
pilgrimage, 2021–2026). Hilton Coliseum / "Hilton Magic" barely appears in the
threads I mined (the r/CFB wiki covers it — snippet-only); physical detail for
Hilton is already in `../landmarks/LANDMARKS.md`.

---

## 2. Verbatim gold

Short direct quotes that best capture what these places MEAN. Attribution =
thread + month (UTC from the archive). Drinking/riot material is noted where
colorful; all are from public threads.

1. "I was at Paddys the night VEISHEA died. We had just gotten 2 pitchers, cops
   come in and tell them to stop serving and not let anyone leave." —
   u/kc_cyclone, r/iastate "What's the most Iowa State thing...", 2026-04
   (https://www.reddit.com/r/iastate/comments/1spv39t/whats_the_most_iowa_state_thing_thats_ever)
2. "...everyone just knew to gather on Welch. So I guess in general just
   rallying on Welch." — u/kc_cyclone, same thread, 2026-04.
3. "wandering with no destination, hearing the campanile chime the quarter
   hours, talking and laughing with friends - golden hours, warmly remembered."
   — u/incog46, same thread, 2026-04.
4. "Ames misses you more." — u/pacmain1, r/iastate "Missing Ames", 2021-03
   (https://www.reddit.com/r/iastate/comments/lyqanp/missing_ames)
5. "It was a weird mix, small town with a full bus system and thousands of
   international students." — u/tomorrowdog, same thread, 2021-03.
6. "ISU took away the only reason there was: VEISHEA. Until that comes back, I
   honestly don't think I can justify a visit." — u/ornryactor, same thread,
   2021-03. (Same commenter: "I desperately need to get my old go-to meal of
   Szechuan Green Beans from Little Taipei, because somehow... I still can't
   find almost any restaurants that make this.")
7. "It really is like New York City, but without the urine." — u/cynical_robot,
   same thread, 2021-03.
8. "I hadn't really realized how great of a town it was until leaving and
   raising my kids elsewhere." — u/sammiller0, same thread, 2021-03.
9. "Going back to Ames feels like an (empty) home. Some things feels the same
   (Jeff's Pizza is, and always will be, amazing pizza.) but things are amiss
   (The friends were the furniture that tied the room together.)" —
   u/OiM8IDC, r/IowaCity "The Iowa City blues", 2023-10
   (https://www.reddit.com/r/IowaCity/comments/17eoagz/the_iowa_city_blues)
10. "For the love of god don't go to hickory park. Eat something good" —
    u/baileygrease, r/iastate "First Time Visiting", 2021-10
    (https://www.reddit.com/r/iastate/comments/qfjqxd/first_time_visiting)
11. "Hickory park is where people who aren't from Ames go to eat when they come
    to Ames." — u/brokeballerbrand, r/iastate "Best restaurants in Ames?",
    2021-07 (https://www.reddit.com/r/iastate/comments/osc33r/best_restaurants_in_ames)
12. "Hickory Park is just a novelty for Ames, similar to the antiques grandma
    keeps in the cabinet." — u/acetrainerarcadia, r/iastate "Hickory Park sold",
    2019-09 (https://www.reddit.com/r/iastate/comments/d0fbk0/hickory_park_sold)
13. "RIP cheap taco night. You will be missed." — u/asimons81, r/iastate "Es Tas
    was evicted...", 2024-12
    (https://www.reddit.com/r/iastate/comments/1h8filz/es_tas_was_evicted_from_its_campustown_building)
14. "I graduated 15 years ago and occasionally get back to campus. But still
    can't bring myself to step on it [the MU Gold Star Hall zodiac]." —
    u/charliebrown331, r/iastate bucket-list thread, 2018-07
    (https://www.reddit.com/r/iastate/comments/911jbh/what_should_be_on_any_iowa_staters_bucket_list)
    *(QA fix 2026-11-08: editorial bracket corrected per QA-REPORT item 9 / A-23 —
    the zodiac is the MU Gold Star Hall floor, not a Curtiss–Beardshear sidewalk.)*
15. "Observe the albino squirrel and receive its blessing." — u/Justlegos,
    same thread, 2018-07. (His follow-up: saw it before a Physics 222 final he
    thought he'd missed, "somehow I received a 89%" and keeps "a framed photo
    of him.")
16. "I joke that VEISHEA was the best 12 days of my life that I can't remember.
    (3 days times 4 years)" — u/Use_this_1, r/Iowa "What led up to the end of
    Iowa State's Veishea?", 2024-04
    (https://www.reddit.com/r/Iowa/comments/1bzw3bs/what_led_up_to_the_end_of_iowa_states_veishea)
17. "our tailgating scene is probably the best in the Big 12. Historically
    we've been bad in football so we fans developed a great tailgating
    tradition." — u/whirlybirds7, r/cyclONEnation "First trip to Jack-Trice!",
    2024-10 (https://www.reddit.com/r/cyclONEnation/comments/1g3u145/first_trip_to_jacktrice)
18. "The complete lack of bars has really made tailgating THE thing over
    several decades." — u/DreadtheSnoFro, same thread, 2024-10.
19. "Bar hop on Welch Ave after the game for some fun times. Win or lose,
    we'll boose." — u/Andjhostet, r/iastate "First Time Visiting", 2021-10
    (https://www.reddit.com/r/iastate/comments/qfjqxd/first_time_visiting)
20. "1990 graduate. Lived all over but came back to Ames to retire. Enjoying
    every minute of it." — u/OldGenXr67, r/iastate "Four Seasons fountain and
    the campanile to bless your timeline", 2026-05
    (https://www.reddit.com/r/iastate/comments/1t3tmz1/)
21. "I will on my life defend it as the best town to live in. Great small town
    vibes with lots of bigger town amenities... Honestly I miss it sometimes."
    — u/Embarrassed_Sink_541, r/ames "Living in Ames?", 2026-04
    (https://www.reddit.com/r/ames/comments/1sfelsl/living_in_ames)
22. "I make a point of going to Ames exclusive places" (a graduating senior's
    farewell list: Mucky Duck, Aunt Maude's, Cafe B, West Street Deli,
    Provisions, The Cafe, Great Plains, Rico's, El Maguey, Macubana, Cornbred)
    — u/madid99, r/iastate "Places to visit in Ames before leaving", 2022-04
    (https://www.reddit.com/r/iastate/comments/tv3uj7/places_to_visit_in_ames_before_leaving)

---

## 3. Traditions & rituals tied to places

Rituals are what make a spot matter; each has a place the game can stage.

- **Campaniling** — become a true Iowa Stater by kissing someone under the
  Campanile as the bells strike midnight. Stated as fact by multiple threads:
  "Tradition says that you become a true Iowa Stater when you kiss someone
  under the campanile at the stroke of midnight" (r/iastate date-ideas thread,
  2022-07, https://www.reddit.com/r/iastate/comments/w7qsln/date_night_ideas);
  bucket-listed in 2018 (911jbh above); a freshman-lore thread lists it first
  (r/iastate, 2020-08, https://www.reddit.com/r/iastate/comments/ifjobz/i_am_very_out_of_the_loop_with_isu_loretradition).
- **Mass Campaniling at Homecoming** — fireworks on Central Campus at midnight
  Friday of Homecoming week, thousands kissing under the tower at once:
  "Fireworks get shot off on central campus at midnight Friday of HC for mass
  campaniling... Most people just watch the fireworks." — r/iastate, 2025-10
  (https://www.reddit.com/r/iastate/comments/1ob3ebs/prospective_student_and_dad_looking_for)
- **Don't step on the zodiac** (the bronze zodiac in the Memorial Union's Gold Star
  Hall floor — QA fix 2026-11-08: "the zodiac walk between Curtiss and Beardshear"
  corrected per QA-REPORT item 9 / A-23; the Curtiss–Beardshear pairing is the
  streak run, a different ritual — TRADITIONS §9.5)
  — step on it and you fail your next exam. Freshman-lore thread, 2020-08
  (ifjobz above); bucket-list thread, 2018-07 (911jbh); even the incoming-
  freshman advice thread repeats it ("Ummm avoiding the zodiac is very much a
  tradition", r/iastate, 2021-08,
  https://www.reddit.com/r/iastate/comments/oxsuxn/to_incoming_freshman).
  One commenter jokes the counter-ritual exists: "Thanking the bus driver
  guarantees 1 grade letter improvement on your next test (Cannot reverse
  zodiac)" (ifjobz, 2020-08).
- **The albino squirrel blessing** — sighting it before an exam is lucky;
  people keep framed photos of it (911jbh, 2018-07; also "I saw the albino
  squirrel during an interview on campus and was offered the job at the end",
  r/iastate 2026-04, 1spv39t).
- **Walk around Lake LaVerne three times** (in silence, with your sweetheart)
  and you'll marry them / be together forever. Known as folklore by students
  ("I recommend walking around Lake Laverne in silence three times. Everyone
  knows that folklore." — r/iastate date-ideas thread, 2018-07,
  https://www.reddit.com/r/iastate/comments/8zaonu/date_ideas; another: "four
  years here and I had never heard about it until my girlfriend brought it up").
  Also documented by ISU press (search snippet only, not fetched).
- **21 mugs at Cy's Roost** — drink 21 mugs on your 21st birthday; Thursday
  mug night draws a cover charge: "Cy's has cover on Thursdays due to their 21
  mugs deal." — r/iastate, 2019-06 (c3k55p).
- **Birthday drinks at Cafe B / Welch Ave Station** — "$1 Long Island Iced
  Teas" at Cafe B; "Welch has a full free drink for your 21st (get a double
  White Russian, it's their strongest drink)." — r/iastate, 2019-06 (c3k55p).
- **Post-midnight Mr. Burrito & Superdog at 2 AM** — the late-night food
  pilgrimage is itself a bucket-list item (911jbh, 2018-07).
- **801 Day** — the Saturday before fall classes, Greeks (barred from drinking
  during recruitment until 8:01 AM) and everyone else day-drink across
  Campustown from 8:01 AM; the first-week shared ordeal. "A Serious Warning for
  Freshman - 801 Day" (r/iastate, 2022-08,
  https://www.reddit.com/r/iastate/comments/wr4aai/a_serious_warning_for_freshman_801_day);
  police-in-Bags-on-roofs lore in same thread; origin story in the
  recruitment-ends thread (r/iastate, 2018-07, 911jbh comment by u/shodrey).
- **Football Saturdays**: Spirit Walk — the band plays at the Alumni Center
  ~90 minutes before kickoff and marches with the team through the tailgating
  lots to the stadium (r/cyclONEnation, 2024-10, 1g3u145); tailgates start
  5–6 hours early; visitors get "adopted" into tents (the CyHawk autistic-son
  tent story in that thread is the "Iowa nice" distillation).
- **Storming the field** — a career memory for alums: "Stormed the field in
  2011 when we beat 10-0 OSU, then ranked #2, in double overtime. Ripped my
  pants tumbling over the wall." (r/iastate, 2026-04, 1spv39t); "We beat
  Nebraska in 2002 and I rushed the field... climbed the goal post... until I
  fell off" (same thread).
- **VEISHEA's ghost** — the dead spring festival is still the reference point
  for every large gathering ("Imagine what we could have been doing today if
  VEISHEA were still with us", r/iastate, 2019-04,
  https://www.reddit.com/r/iastate/comments/batqx1/imagine_what_we_could_have_been_doing_today_if).
  Its rituals survive only in memory: cherry pies ("I just wanted them cherry
  pies dammit!", 2019-04), the parade, the concerts (Childish Gambino, John
  Oliver, Amy Schumer — r/Iowa 2024-04, 1bzw3bs), Ash Bash on Ash Ave ("the
  Greeks basically fenced off a couple blocks of Ash and had over 100 kegs",
  r/iastate, 2024-10, 1gdrdse — colorful: it was a wall-to-wall beer party).
- **The Beardshear–Curtiss run** — the midnight homecoming-week streak between
  the two halls (colorful: nudity): "the tradition is to run from Curtis to
  Beardshear without any clothes on. I believe traditionally at midnight during
  homecoming week" (r/iastate, 2020-08, ifjobz); "the naked run from the dorms
  to the campanile" (r/iastate, 2025-01,
  https://www.reddit.com/r/iastate/comments/1hthf9w/whats_the_craziest_thing_youve_seen_experienced).
- **Six-pack for December grads** — "You give a free 6 pack to people you know
  who graduated the semester before" (r/iastate, 2020-08, ifjobz).
- **Photo with every Cy statue** — "take a picture with all of the Cy's around
  town. I think there's about 30" (r/iastate, 2022-04, tv3uj7).
- **Kaleidoquiz** — KURE's 26-hour town-wide scavenger/quiz, a whole-weekend
  legend ("Winning KQ is still one of my most triumphant memories from my
  entire undergrad", r/iastate, 2018-07, 911jbh).
- **Saturday farmers market on Main Street** — the recurring must-do for town
  and gown alike (r/ames, 2026-09, 1wmk7h0; r/iastate, 2018-07, 911jbh).

---

## 4. Trends & changes (a dated snapshot)

### Mourned / closed (they name names)
- **VEISHEA** — last held 2014; killed by the April 2014 riot (light poles,
  stoplight torn down at Lincoln Way & Welch, cars flipped: r/iastate, 2025-01,
  1hthf9w; r/Iowa 2024-04, 1bzw3bs; r/news 2014 thread,
  https://www.reddit.com/r/news/comments/22l74t/riot_breaks_out_at_iowa_state_campus_during).
  Ten years on, r/Iowa still argues about it (2024-04, 1bzw3bs) and students
  still debate revivals (r/iastate, 2024-10, 1gdrdse: "Really think there's a
  missed opportunity not bringing Veisha back" — top replies: no; also the
  permanent-resident paradox: "The city of Ames wants almost nothing to do
  with a 'spark'").
- **Es Tas** — evicted from its Campustown building Dec 2024 over back rent;
  taco night mourned (r/iastate, 2024-12, 1h8filz; "It was my go to. Last bar I
  was at in college. It meant a lot to me.").
- **People's (downtown)** — "Peoples - RIP" in the bar-collage thread (r/iastate,
  2023-12, 18a4wgv); a 2021 commenter: "We could really use a music venue there
  to replace People's" (r/iastate, 2021-03, lyqanp). Closure date not pinned —
  *single-source*.
- **DG's Taphouse / Corner Pocket** — "these just closed" (r/iastate, 2019-06,
  c3k55p).
- **Legends (Legacy Tower rooftop)** — "Legends closed last year..." (r/iastate,
  2013-02, https://www.reddit.com/r/iastate/comments/190t84/visiting_ames_looking_for_advice_bars_restaurants).
- **Battles BBQ** — the beloved ex-rival: "Battles was good but his kids
  couldn't figure out the business after George died" and "RIP battles, holy
  shit." (r/iastate, 2025-10, 1o4po9s). *Closure date not pinned; single-thread.*
- **Hickory Park sold** — founder David Wheelock to Bernau Capital Partners,
  effective Aug 31, 2019 after 49 years (Ames Tribune quote quoted in-thread;
  r/iastate, 2019-09, d0fbk0). The thread is also where owner stories surface —
  former staff describe a hostile workplace (colorful: "Bye David, you sexist
  old fuck" is the OP's opening line). Post-sale decline is now community
  consensus: "Hasn't been the same since it was sold" (2025-10), "biggest waste
  of money now" (r/ames, 2026-09, 1wr5jne).
- **Little Taipei** — an alum has been unable to replace its Szechuan Green
  Beans for years; closure itself not stated in-thread (*unverified*).
- **Campustown generification** — "I'm kind of horrified at how campus town
  looks now. There's been so much new development on the buildings that line up
  on Lincoln way, it looks ... generic." (r/iastate, 2021-03, lyqanp) and "Kind
  of wish Campustown had some personality to it again" (same thread).
- **CyTown skepticism** — the new stadium-adjacent development reads to some as
  "an athletics enclave for diehard sports fans and no one else" (r/iastate,
  2024-10, 1gdrdse).
- **801 crackdown** — "It's most recently visible in the strangling on 801 day
  with a massive increase in fines for house parties on that specific weekend"
  (r/iastate, 2024-10, 1gdrdse).
- **The swans** — one swan died around 2022 and the other was removed; as of
  Aug–Sep 2025 none introduced; university plans lake restoration first
  (dredging is the 2024–28 project in `../landmarks/LANDMARKS.md`; thread:
  r/iastate, 2025-08, 1n51i2i, citing
  https://www.inside.iastate.edu/article/2024/04/25/laverne).
- **Mother's reputational fall** — "Used to go to Mother's but Captain is
  creepy and has had serious assault allegations against him and I won't go
  anymore" (r/iastate, 2019-06, c3k55p). *Allegation only, single-source.*
- **Angry Irishman changing hands** — "whatever happens with Irishmen once it's
  overhauled by the chill people buying it" (r/ames, 2026-02, 1rbbgwr).

### Recent openings / things people are excited about (dated by thread)
- **Cornbred BBQ** — food truck turned restaurant, already "top tier" by 2021
  (qfjqxd) and the standing answer to "good BBQ" (2025–2026 threads).
- **Whatcha Smokin' (Luther)** — the 15-minute BBQ pilgrimage, repeated from
  2024 to 2026 ("arrive early... before they sell out", r/ames, 2026-07, 1v0jf10).
- **Jeff's Pizza** — already beloved in 2013 ("free Smotherella sticks" on
  Tuesdays, r/iastate, 2013-02, 190t84) and still the alums' constant (2023-10).
- **The Cafe / Provisions Lot F** — the modern "take people to eat in Ames"
  default pair (r/iastate, 2025-10, 1o4po9s: "My go to is Provisions and The
  Cafe now when taking people to eat in Ames").
- **Iowa State Creamery** — student-run ice cream, flagged to visitors in 2026
  (r/ames, 2026-07, 1v0jf10).
- **Time Out barcade** — the 80s/90s-nostalgia night (r/ames, 2026-02, 1rbbgwr).
- **Downtown small business wave** — Dog-Eared Books, Mayhem Comics, Octagon
  Arts Center, vinyl shops (r/ames & r/iastate, 2024-03, 1b5g4de / 1b5g6q6).
- **Ames History Museum** — "newly expanded and renovated" (r/ames, 2024-11
  comment in 1b5g4de).
- **The stadium pedestrian bridge** — "Check out The Bridge on East side of the
  stadium, it's new and leads out to a large RV lot for tailgating" (r/cyclONEnation,
  2024-10, 1g3u145).
- **Clouds coffee, Legacy Tower 12th floor** — "awesome coffee shop on the 12
  level of Legacy Tower with great views of campus" (r/ames, 2024-03, 1b5g4de).
  The "12 level" is the commenter's error — the café is on the **7th floor**
  (cloudsames.com; ledger V-16; QA fix 2026-11-08 per QA-REPORT item 9 / A-24).
  For a pigeon game this is the community's own "pigeon's-eye" recommendation.

---

## 5. Thread manifest (all fetched 2026-11-08 via Arctic Shift; raw JSON in `_cache/`)

| Thread | Sub | Date | Title / note |
|---|---|---|---|
| 1spv39t | r/iastate | 2026-04 | Most Iowa State thing (Paddy's/VEISHEA, Welch rally, field storming) |
| 18a4wgv | r/iastate | 2023-12 | Iowa State Bars (bar inventory w/ loyalty notes) |
| c3k55p | r/iastate | 2019-06 | How are the bars in Ames (the definitive bar-by-hour breakdown) |
| 1mxscpm | r/iastate | 2025-08 | Campus bars good to go to alone |
| tt8i2y | r/iastate | 2022-03 | Downtown vs Campustown nightlife geography |
| qfjqxd | r/iastate | 2021-10 | First Time Visiting (food/bar recs, Hickory Park split) |
| 190t84 | r/iastate | 2013-02 | Visiting Ames advice (era snapshot: Legends alive, Cocost) |
| lyqanp | r/iastate | 2021-03 | Missing Ames (alum nostalgia; VEISHEA-as-reason; Little Taipei) |
| 9jfeua | r/iastate | 2018-09 | Unpopular opinions (Hickory Park, Fighting Burrito, AJ's) |
| 1qeppd5 | r/ames | 2026-01 | New to the Area - Places to eat |
| 1v0jf10 | r/ames | 2026-07 | Favorite Restaurants? (Fareway cronut, Grove, Hickory joke) |
| osc33r | r/iastate | 2021-07 | Best restaurants in Ames? (Hickory thesis line) |
| 1b5g4de | r/ames | 2024-03 | Things to do and hidden gems (Ada Hayden sunsets, Munn Woods, Clouds) |
| tv3uj7 | r/iastate | 2022-04 | Places to visit before leaving (senior farewell list; Cy statues) |
| 1lbe6y3 | r/iastate | 2025-06 | Nature spots (Pammel/Reactor/Munn woods; Lake Latrine; Arboretum) |
| 1e6ljtw | r/iastate | 2024-07 | Things to do in Ames |
| 1wr5jne | r/ames | 2026-09 | Visiting Ames (2-day itinerary) |
| 1wmk7h0 | r/ames | 2026-09 | Must dos in Ames (kayak the Skunk; "Kiss your girl under the Campenille") |
| 1rbbgwr | r/ames | 2026-02 | Places to check out (Time Out; Angry Irishman overhaul) |
| 1sfelsl | r/ames | 2026-04 | Living in Ames? (best-town defense) |
| 1tfp5h9 | r/ames | 2026-05 | Is Ames Right For Me? (CyRide, walkability, library) |
| 1n51i2i | r/iastate | 2025-08 | Lancelot & Elaine never coming back? |
| 8dz49q | r/iastate | 2018-04 | Swans building a nest (two-females fact + Inside Iowa State cite) |
| 8zaonu | r/iastate | 2018-07 | Date ideas (LaVerne three-laps folklore) |
| w7qsln | r/iastate | 2022-07 | Date Night Ideas (campaniling as date) |
| 1o4po9s | r/iastate | 2025-10 | Hickory Park Sucks (173-score pile-on; Battles RIP) |
| d0fbk0 | r/iastate | 2019-09 | Hickory Park sold (Ames Tribune text quoted in thread) |
| 1h8filz | r/iastate | 2024-12 | Es Tas evicted |
| 1bzw3bs | r/Iowa | 2024-04 | What led up to the end of VEISHEA (10 years) |
| 9hr79i | r/iastate | 2018-09 | VEISHEA history ("Big if true") |
| 1gdrdse | r/iastate | 2024-10 | Bring VEISHEA back? (Ash Bash; 801 fines; CyTown) |
| batqx1 | r/iastate | 2019-04 | Imagine VEISHEA still existed (riot geography; cherry pies) |
| 1g3u145 | r/cyclONEnation | 2024-10 | First trip to Jack Trice (tailgating guide; Spirit Walk) |
| 1hthf9w | r/iastate | 2025-01 | Craziest thing on campus (2014 riot eyewitness) |
| lxqeld | r/iastate | 2021-03 | ISU iceberg (Marston bike; Parks apartment; Cyride legend) |
| wr4aai | r/iastate | 2022-08 | 801 Day warning |
| ifjobz | r/iastate | 2020-08 | ISU lore/tradition (zodiac, streak run, steam tunnels) |
| 911jbh | r/iastate | 2018-07 | Iowa Stater bucket list |
| 1ob3ebs | r/iastate | 2025-10 | Homecoming recos (mass campaniling, Yell Like Hell) |
| oxsuxn | r/iastate | 2021-08 | To incoming freshman |
| 17eoagz | r/IowaCity | 2023-10 | Iowa City blues ("Going back to Ames feels like an empty home") |
| 1t3tmz1 | r/iastate | 2026-05 | Fountain+campanile timeline blessing (1990 grad retires to Ames) |
| kf2c8 | r/iastate | 2011-09 | Love school / hate Ames (2011 era snapshot) |
| 1cnx5yz | r/Iowa | 2024-05 | Vacationing in Iowa (Ada Hayden sunset, High Trestle) |
| 1bhr07d | r/Iowa | 2024-03 | You'll never have it so easy (Iowa-wide, light Ames use) |

Search-snippet-only sources (not fetched; used sparingly and marked inline):
r/CFB Iowa State wiki (Spirit Walk wording,
https://www.reddit.com/r/CFB/wiki/iowastate); r/CFB mass-campaniling threads
(https://www.reddit.com/r/CFB/comments/2kpoqj/whats_homecoming_like_at_your_school,
https://www.reddit.com/r/CFB/comments/2ywd1e/rcfb_what_is_your_favorite_urban_legend_about);
r/news 2014 VEISHEA riot
(https://www.reddit.com/r/news/comments/22l74t/riot_breaks_out_at_iowa_state_campus_during);
r/iastate 801-Day origin posts (i9ufu9, p8sslu, ia97lg — IDs from search,
contents consistent with fetched 801 threads).

### Coverage gaps & caveats
- Every quote is one comment at one moment; sample skews toward people who post
  (students + recently-departed alums), and toward 2018–2026 because that's
  where the subreddit's volume is. The 2011–2013 threads are the oldest usable
  windows I found.
- The r/CFB-style "Hilton Magic" lore barely surfaced in r/iastate threads —
  absence of evidence, not evidence of absence.
- Older names I could not pin to threads (noted so nobody treats them as
  verified): Little Taipei's closure date, People's closure date, Battles BBQ
  closure date.
- Lane overlap: physical/dimension claims in this file are NOT re-verified —
  use `../landmarks/LANDMARKS.md` for dimensions and `../osm/SUMMARY.md` for
  geometry. Community sentiment only.

*Research agent, 2026-11-08.*
