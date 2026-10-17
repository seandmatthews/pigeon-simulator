# CREDITS

Every third-party asset in this repository is listed here.

All audio below is CC0 (public domain). The game-ready files are lightly edited
derivatives of the sources (trimmed, level-normalized; the ambience beds were
made into seamless loops with a head-tail crossfade; the edits are noted per
row) — CC0 permits modification, no attribution required, given anyway.

| Asset | Source | License |
| ----- | ------ | ------- |
| assets/third-party/opengameart/flap_whoosh.ogg | "Swishes Sound Pack" (swish-7) by artisticdude — https://opengameart.org/content/swishes-sound-pack (trimmed, peak-normalized) | CC0 |
| assets/third-party/opengameart/wing_effort.ogg | "Swishes Sound Pack" (swish-4) by artisticdude — https://opengameart.org/content/swishes-sound-pack (trimmed, normalized, pitched down ~30%) | CC0 |
| assets/third-party/opengameart/splat.ogg | "Squish Sounds Effects" (squishsplat_impact) by EZduzziteh — https://opengameart.org/content/squish-sounds-effects (trimmed, peak-normalized) | CC0 |
| assets/third-party/opengameart/tourist_yelp.ogg | "Girly Scream" (wscream_2), performed by Mariel Carmona Varo, recorded/edited by Ferk — https://opengameart.org/content/girly-scream (CC0 chosen from the dual license offered; resampled to 44.1 kHz, trimmed, normalized) | CC0 |
| assets/third-party/opengameart/tourist_panic.ogg | "High pitch scream sounds(2)" (high_pitch_scream) by pauliuw — https://opengameart.org/content/high-pitch-scream-sounds2 (trimmed, normalized, pitched down slightly) | CC0 |
| assets/third-party/opengameart/car_horn.ogg | "Bicycle Horn" (bicycle-horn-1) by AntumDeluge — https://opengameart.org/content/bicycle-horn (trimmed, peak-normalized) | CC0 |
| assets/third-party/opengameart/traffic_murmur_loop.ogg | "High traffic road sounds" ("gatve Varniu") by IgnasD — https://opengameart.org/content/high-traffic-road-sounds (made into a seamless 60 s loop with a 3 s head-tail crossfade, RMS-normalized) | CC0 |
| assets/third-party/opengameart/distant_chatter_loop.ogg | "Crowd Shouting/Speaking Ambience" (crowd_shouting) by StarNinjas — https://opengameart.org/content/crowd-shoutingspeaking-ambience (made into a seamless 27 s loop with a 2.5 s head-tail crossfade, RMS-normalized) | CC0 |
| assets/third-party/kenney/bread_peck.ogg | "Impact Sounds" (impactSoft_medium_000) by Kenney — https://kenney.nl/assets/impact-sounds (pitched up ~25%, trimmed, peak-normalized) | CC0 |

## Models (T-124)

The game scenes never reference these packs directly: `tools/bake_people_cars.gd`
derives the flat-tinted part meshes under `assets/generated/models/` from them
(skeleton-posed + skinned at Universal Animation Library clip frames for the
people; colormap color-role split for the car). The derived meshes carry the
source pack, pose clip and license as metadata.

| Asset | Source | License |
| ----- | ------ | ------- |
| assets/third-party/quaternius/base_character.glb | "Universal Base Characters Kit" by Quaternius — https://quaternius.itch.io/universal-base-characters (rigged character with the Universal Animation Library clips; imported MESH-ONLY — `animation/import=false`, the death clips are banned by T-124 and ship nowhere). See LICENSE.txt in the same folder. | CC0 |
| assets/third-party/kenney/carkit/sedan.glb + Textures/colormap.png | "Car Kit" (3.1) by Kenney — https://kenney.nl/assets/car-kit (sedan variant + shared colormap; LICENSE.txt alongside) | CC0 |

## Generated in-house (T-123)

Synthesized from scratch by `tools/gen_sfx.py` (sines + shaped noise, no
recordings involved) — these are the project's own work, no license
restrictions at all.

| Asset | What |
| ----- | ---- |
| assets/generated/coo_idle.wav | Grounded idle coo (two soft hoots) |
| assets/generated/coo_waddle.wav | Waddling coo (single hoot) |
| assets/generated/coo_smug.wav | Post-splat smug coo (rising three hoots) |
| assets/generated/splat_2.wav | Splat variant (wet, low thump) |
| assets/generated/splat_3.wav | Splat variant (sharp, bright) |
| assets/generated/stinger_win.wav | Victory stinger (major arpeggio) |
| assets/generated/stinger_lose.wav | Starvation sting (descending minor) |
