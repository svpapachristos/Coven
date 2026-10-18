# The Hex wisp: her curse as living smoke, and the hex orb
Code: `scr_hex_wisp` (script), `sh_hex_orb` (the orb shader), `sh_hex_wisp_flow` and `sh_hex_wisp_draw` (the smoke shaders), called from `obj_player` Draw. Slice 1 (smoke) and 1.1 (the collapse) were built Oct 15 2026; slice 2 (the hex orb) Oct 16.

**Three looks, O cycles them:** the **hex orb** (default, slice 2), the **smoke wisp** (slices 1 and 1.1, kept for comparison) and the **original circles**. The rest of this note describes the smoke look until the orb section below.

## What it is
The motes are still the Hex energy (nothing about gameplay changed). The wisp only changes how they are *drawn*: instead of three flat circles per mote, every mote stamps soft light into a small off-screen "field" picture, a shader drags that light along a swirling current (curl noise) and fades it, and a second shader turns the field into smoke with a bright core. The target look is Wanda and Agatha's: a glowing wisp that flows through the world with an ethereal motion.

## Per frame
1. **Field**: two small surfaces (view / 4, so 640 x 360), swapped every frame.
2. **Flow** (`sh_hex_wisp_flow`): last frame's field is carried along the current and faded. It also scrolls with the camera, so the smoke stays where it was in the world.
3. **Stamp**: each mote that isn't spent (st 2) or inside a shot (st 4) stamps light where it is. Fast motes stamp along their path so streams stay unbroken. Channels: red = smoke, green = core, blue = energy flowing home (state 3), which burns a little brighter and tinted, so Recall is visible.
4. **Draw** (`sh_hex_wisp_draw`): density becomes smoke, then body glow, then core, then an optional white-hot center. Drawn premultiplied, so the smoke keeps its color over bright grass. (Plain additive light washes to white on grass; the old circles did too.)

## The hex orb (slice 2)
The smoke looked like a nebula or a gravity well, not like Wanda's hand magic. The orb replaces it as the default. Designed in a lookdev rig against a still of Wanda's hands (the north star: a small, dense, dark crinkled mass with a hot cracked heart, a ragged edge and a glow), then ported. Round 7 of the lookdev is what ships.
- **What it is:** `sh_hex_orb` computes every pixel from shapes and noise (no surfaces, no smoke field). `hex_orb_draw` draws one square of it around each registered ball (`hex_wisp_att`, the same balls the smoke look uses).
- **Parts, inside out:** a big hot **heart** with crack-holes (the lilac-white tone); a few overlapping soft **clouds** that drift on their own orbits, so the body has dark seams (not one blob, not strands); fine **crinkle** (dark creases, lit ridges); a dark dithered **haze** that fades out like a nebula's edge; a banded violet **glow** that lights the surroundings (alpha 0, so it adds light); twinkling **sparks** of three kinds; and **hex rings** that flare off it when charged. A whisper of hexagon in the outline.
- **Pixel art:** four tones plus the hot tone, ordered and random dither, on the game's world pixel grid (the shader floors the room position).
- **Energy:** each ball has `oE` (0 calm .. 1 wild) and `oR` (core radius, world pixels). The main ball's come from her stance in `obj_player` Draw, eased: at rest in her hand 0.12 (radius shrinks a little as her reserve is spent); stance up 0.35; grab 0.5; holding something 0.55; charging 0.45 to 1.0 with the radius growing 6.5 to 13; a shot in flight 0.9.
- **Palette:** the new default is **Coven violet-blue** (smoke 14,0,86, glow 41,7,175, core 57,17,243, spark 222,190,255, hot 0.30). P cycles it with the older blue, midpoint and lilac.
- **Only the orb look changes these:** the ground-light circle and the charge-heart circle are skipped (the orb has its own); the resting motes aren't drawn (they are inside the orb); the motes that are out in the world still draw as bright thread dots; `obj_hex_shot` skips its two fallback circles whenever the wisp is on.
- **Knobs:** the look is in `sh_hex_orb.fsh` (each part is commented). The numbers to start with: `reach` (clump sizes), `F` weights (how full the body is), the tone thresholds (`Fd >`), `hr` (heart size), `hz` (haze size), the glow `g` (0.55).
- **Not done yet:** no wake behind a shot in flight (the smoke look has one); the orb doesn't react to her movement; the mid-energy look wants a pass; the dark haze reads as a shadow on bright ground at calm.

## The collapse (slice 1.1, smoke look)
The goal look is a ball of wispy magic that is forever collapsing in on itself. Slice 1 let smoke drift away on a random current, so it read as a trail. Now anything that is *a ball of her magic* registers itself every frame with `hex_wisp_att(x, y, radius, strength)`: the ball in her hand, the charging orb (grows with the charge), what she is holding, and any shot in flight (`obj_hex_shot`, which also leaves a short wake). Around each ball:
- **Flow shader**: the random current is calmed and smoke is pulled in along a spiral, then eaten at the middle so it can't pile up.
- **Draw shader**: three spiral arms that turn and slide inward, and a dense core, drawn per screen pixel so they stay smooth.
Up to four balls count at once. Registering is done in `obj_player` Draw, right before `hex_wisp_draw`.

## Keys (in a run)
| Key | What |
|---|---|
| **O** | next look: hex orb, smoke wisp, original circles (exactly as before, for comparison) |
| **P** | next palette: Coven violet-blue, blue, midpoint, lilac (original). The look and palette name and core color show above her for 2 seconds |

## Palettes
All in `hex_wisp_state()`. `core` is the identity color; the other tiers are built around it.
| Tier | lilac (original) | midpoint | blue |
|---|---|---|---|
| smoke | 60, 30, 120 | 40, 15, 111 | **19, 0, 101** |
| glow | 110, 70, 200 | 76, 39, 188 | **41, 7, 175** |
| core | 200, 175, 255 | **129, 96, 249** | **57, 17, 243** |
| spark (thread dots, return tint) | 200, 175, 255 | 190, 178, 254 | 180, 180, 252 |
| hot (how white the brightest part burns) | 0 | 0.15 | 0.30 |

The midpoint is computed in code from the other two, so retuning either one moves it. The lilac column is exactly what the circles used before. The blue palette values above are Sophia's selected colors for the Wanda-inspired pixel-art pass.

## Wanda-inspired pixel-art target (Oct 16)
The target is a pixel-art rendition of Wanda's hand magic, adapted to the witch's off-hand and the chosen blue-violet palette. Read the source as energy wrapping and following the hand, with bright knots, uneven branching filaments, dark gaps, and a smoky edge. Do not turn it into a detached orb with broad orbital rings. The exact in-game shape is not implemented yet. Blue colors chosen by Sophia: core RGB(57, 17, 243), glow RGB(41, 7, 175), smoke RGB(19, 0, 101).

## Knobs (`k` struct in `hex_wisp_state`)
`flow` (how strongly the wandering current moves things), `decay` (trail length), `cell` (size of the biggest swirl), and for the collapse: `pull` (how fast smoke falls in), `swirl` (how tightly it spirals), `eat` (what the middle swallows), `arms` (arm brightness, 0 = none), `ball` (core density), `spin` (how fast the arms turn), the three stamp sizes, how much smoke and core each mote stamps at rest vs in stance, `home_amt` (how strongly the return stream reads), `gain`, `bright`, `add`, `detail`. Everything about the look is in that one struct.

## How later effects join
Anything that should be part of the same smoke stamps into the field with `hex_wisp_stamp` during `hex_wisp_draw`'s stamp pass (the orb in flight and the palm blast are next: they are `obj_hex_shot`, drawn as two circles today). Keep the contract small: position, velocity, how much, and which channel.

## Known limits of slice 1
- Not run in GameMaker when written (slice 1.1 included); it was checked by running the exact shader text in a WebGL test rig and reading the code twice. First thing to do: press O and P in a run, and check the surfaces survive alt-tab.
- Shots and the held thing collapse like the hand ball, but they are not made of motes (the motes inside a shot are hidden), and `obj_hex_shot` draws its own two circles only when the wisp is off.
- Mana is still a separate bar for the wand's alt (the brief says one reserve).

## Round 12 look + Motes 2.0 (Oct 18, 2026)
The full lookdev history (rounds 8-12, the five ingredients, Sophia's notes) is in the Coven project doc `claude/hex-hand-orb-lookdev.md`.

**sh_hex_orb is now the round 11/12 hybrid**, drawn in 2-pixel steps (`HEX_ORB_PX` in scr_hex_wisp) and about 50% bigger (sizes in obj_player Draw):
core (a 2x2 cluster warbling hot white / lilac / blue, fixed size), strands (1 magic pixel thick, orbiting, far side dimmer, sparkles),
shade (drifting dark patches on the underside, never an outline), body (ghostly shifting gas), veil (see-through haze with holes),
and the **overflow** (flame-like licks straining outward) only on a ball that is holding something (`hex_wisp_att(..., _oF = 1)`).
No light ring. The charged orb's real look is still open ("round 13").

**Motes 2.0** (obj_player Step, helpers in Create): motes out in the world no longer spring to their target. `hex_flow_to` steers each
one at a steady pace (`hex_flow_speed` 7, `hex_return_speed` 9, `hex_flow_turn` 0.18) with a gentle weave, so the hex flows like a river.
Once there they churn (soft pull, low speed cap). Held things: the swirl flattens into a pool underneath. While holding, every third
mote is the **tether**, streaming palm to object and back (the binding). Before the lift, `hex_gather` on the env object makes it
tremble and rise a little as hex arrives. Motes draw as a puff with a fading 2-segment wisp behind it (`t1x/t1y/t2x/t2y`).
