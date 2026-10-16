# The Hex wisp: her curse as living smoke
Code: `scr_hex_wisp` (script), `sh_hex_wisp_flow` and `sh_hex_wisp_draw` (shaders), called from `obj_player` Draw. First slice built Oct 15 2026; slice 1.1 (the collapse) the same day.

## What it is
The motes are still the Hex energy (nothing about gameplay changed). The wisp only changes how they are *drawn*: instead of three flat circles per mote, every mote stamps soft light into a small off-screen "field" picture, a shader drags that light along a swirling current (curl noise) and fades it, and a second shader turns the field into smoke with a bright core. The target look is Wanda and Agatha's: a glowing wisp that flows through the world with an ethereal motion.

## Per frame
1. **Field**: two small surfaces (view / 4, so 640 x 360), swapped every frame.
2. **Flow** (`sh_hex_wisp_flow`): last frame's field is carried along the current and faded. It also scrolls with the camera, so the smoke stays where it was in the world.
3. **Stamp**: each mote that isn't spent (st 2) or inside a shot (st 4) stamps light where it is. Fast motes stamp along their path so streams stay unbroken. Channels: red = smoke, green = core, blue = energy flowing home (state 3), which burns a little brighter and tinted, so Recall is visible.
4. **Draw** (`sh_hex_wisp_draw`): density becomes smoke, then body glow, then core, then an optional white-hot center. Drawn premultiplied, so the smoke keeps its color over bright grass. (Plain additive light washes to white on grass; the old circles did too.)

## The collapse (slice 1.1)
The goal look is a ball of wispy magic that is forever collapsing in on itself. Slice 1 let smoke drift away on a random current, so it read as a trail. Now anything that is *a ball of her magic* registers itself every frame with `hex_wisp_att(x, y, radius, strength)`: the ball in her hand, the charging orb (grows with the charge), what she is holding, and any shot in flight (`obj_env_rock` with `is_bolt`, which also leaves a short wake). Around each ball:
- **Flow shader**: the random current is calmed and smoke is pulled in along a spiral, then eaten at the middle so it can't pile up.
- **Draw shader**: three spiral arms that turn and slide inward, and a dense core, drawn per screen pixel so they stay smooth.
Up to four balls count at once. Registering is done in `obj_player` Draw, right before `hex_wisp_draw`.

## Keys (in a run)
| Key | What |
|---|---|
| **O** | wisp on / off. Off draws the original circles exactly as before, for comparison |
| **P** | next palette: blue, midpoint, lilac (original). The name and core color show above her for 2 seconds |

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
Anything that should be part of the same smoke stamps into the field with `hex_wisp_stamp` during `hex_wisp_draw`'s stamp pass (the orb in flight and the palm blast are next: they are `obj_env_rock` with `is_bolt`, drawn as two circles today). Keep the contract small: position, velocity, how much, and which channel.

## Known limits of slice 1
- Not run in GameMaker when written (slice 1.1 included); it was checked by running the exact shader text in a WebGL test rig and reading the code twice. First thing to do: press O and P in a run, and check the surfaces survive alt-tab.
- Shots and the held thing collapse like the hand ball, but they are not made of motes (the motes inside a shot are hidden), and `obj_env_rock` still draws its own two circles on top of the wisp for now.
- Mana is still a separate bar for the wand's alt (the brief says one reserve).
