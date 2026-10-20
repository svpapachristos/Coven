# The Hex Visual Bible
What the Hexweaver's hex looks like, when, and why. Read this before touching anything that draws her magic.
Born Oct 18, 2026, after twelve lookdev rounds taught us what was actually wrong.

## The one rule: the hex is LIGHT, not paint
Every part of the hex adds up into one **brightness**, and the brightness picks the color. It is drawn as light: a see-through
tint over whatever is behind it, plus added glow. Nothing is a solid shape, not even the white-hot heart (that's just a lot of light).

Why: rounds 1-12 built each ingredient as a shape painted in flat colors (ink). Dark blue ink on green grass reads as scribbles, and
an evenly colored line reads as thread, not a strand of light. Lit the same way light behaves, the same shapes read as a living orb.

## The ingredients (Sophia's names)
| Ingredient | Color | Job |
|---|---|---|
| **Core / Spark** | white-hot, lilac | The heart: a small soft hot point with embers. Reads almost solid (an abundance of light, not a shape) |
| **Body** | hex blue | The mist hugging the core, with dust drifting through it: most of the orb's volume. Never a cloud |
| **Glow** | blue-violet | Where light overlaps and builds up (body + strands + veil + dust adding together): the contained eldritch energy |
| **Smoke / Edge** | dark violet | The only part that isn't light: a broken dark rim and drifting dark patches. Gives the orb its shape |
| **Strands, Veil** | the ramp | Soft filaments of light orbiting the core; thin see-through haze with holes |
| **Pour** (new, Oct 20) | glow -> smoke, fading as it falls | Hex spilling DOWN out of a glowing veil around her hand (and later from under her body) to the ground, like soft smoke drifting down off a ledge: it pours with momentum but stays almost floaty, haze, never water, streams or lines. Overflow's signature (the Wanda reference below). Pairs with a charged knot held in her palm |

## What makes Wanda's chaos magic work (our north star, translated)
1. **It's light.** It brightens what it's in front of; her hands glow from it.
2. **Brighter = whiter.** Our ramp: dark violet (smoke) -> blue-violet (glow) -> blue (core) -> lilac (spark) -> white-hot.
3. **No hard edges.** Even strands are glowing filaments with a soft halo.
4. **Mostly haze.** The truly bright parts are tiny: the heart and a few embers popping inside it.
5. **It never sits still.** Flicker, churn, energy pushing outward.

## Hard rules
- **Judge in game, at real size.** Zoomed previews lie: detail that reads at 4x is noise at 1x. The rig is for building, the game decides.
- **Design for what survives at 1x:** a bright heart, a moving silhouette, color and glow. Texture is a bonus, never the point.
- **Pixel art without dither:** a few flat brightness steps, drawn on a 2-pixel grid (`HEX_ORB_PX`; K/L keys tune it live).
- **Palette is locked:** Coven violet-blue (smoke 14,0,86 / glow 41,7,175 / core 57,17,243 / spark 222,190,255). Don't retune unprompted.
- **The source stays in her hand.** The orb never flies to the cursor. What reaches into the world is her hex itself, flowing as
  motes, and it gathers where it arrives. The hex is a system of ways to manipulate her magic, not a controllable ball.
- **No outlines, no clean discs, no spirals, no hard lightning.** (Every one of these failed in lookdev.)

## The hex speaks differently depending on what it's doing
| What the hex is doing | Its look | Status |
|---|---|---|
| **Idle orb in her hand** (her habit: she IS hex, it's like breathing) | Wanda's chaos ball: a small soft orb of light, white-hot heart, embers, faint wisps and veils of light | Built (sh_hex_orb, light model) |
| **Stance** (Space) | The orb wakes: more strands, more movement; her hex swirls around her body | Built; needs to read more distinct from idle |
| **Charging** (hold left click) | Same family as the idle orb, gathering power. Its real look is still open | Placeholder (softer strands) |
| **Reaching / moving** (motes) | Puffs and wisps of light drifting through space, flowing like a river, never snapping (Skyrim illusion spells) | Built: drawn as one stream of hex light (`hex_flow_draw`, the orb shader in flow mode). **No white-hot core in motion** (that only exists where hex is concentrated: her orbs); blue and lilac with sparkles |
| **Telekinesis** (lift, hold, throw) | Hex cupping the object from underneath (the cup: the levitation itself), edges lit from below. **No tether, ever** (decided Oct 20) | Cup built (5b); polish in step 11 |
| **Overflow** (E in the stance) | A charged knot in her palm inside a glowing veil, and the **Pour** spilling down from that veil (and from under her body) into a glowing pool on the ground; eyes glowing. BOTH hands: overflow puts the wand away (decided Oct 20), so the second hand glows once 5d and the wandless sprites land | Placeholder: palm flare + hover + shadow (5c, plays well; the flare barely reads). Step 11. (`spr_shadow` already exists for the ground) |
| **Blast / explosion** | Tendrils and strands of light lashing outward in the burst | Not built |

## Reference: Wanda floating over the battlefield (Endgame), added Oct 20
Sophia's reference clip for overflow, telekinesis and the hex as a whole. (Her colors are scarlet; ours stay the locked
violet-blue. Read every "red" below as our ramp: anything scarlet or red in a reference ALWAYS translates to our hex
blue-violet, by Sophia's decision. It is never a palette question.) What the frame teaches:
1. **The hex is the scene's light source.** The ground under her and the scrap she holds are lit FROM the magic: a glowing
   pool on the floor beneath her, underlit debris. The world around it is muted grey-blue, so the one magic hue owns the frame.
2. **The hands are small and fierce.** Each palm is a tight white-hot point with a colored halo, arms low and spread. The
   source is never a big ball; brightness, not size, says "power".
3. **Overflow pours DOWN off her body.** A veil of colored haze falls from her (her dress, her legs) into the glowing pool on
   the ground. That's how the float reads: not a gap and a shadow but light spilling from her to the floor.
   (5c's placeholder dark shadow should become this glow pool in step 11.)
4. **Held things glow along their edges and cracks.** Each chunk she lifts is rimmed and lit from inside its seams, hanging in
   loose clusters on both sides of her. No tethers anywhere: nothing connects her hands to the scrap. The world reacts.
5. **One hue, many intensities.** White-hot (palms) -> saturated color (halos, edges) -> deep, dark haze (the veil and air),
   with scattered embers drifting. It's the same brightness-picks-the-color rule as ours.
6. **Symmetry and stillness.** She is calm and centered while everything around her churns. Her body barely moves; the magic does.
7. **Eyes glow in her hex color** (our blue-violet; not visible at this size, but part of the look she wants).

## To-do list (polish, not blockers)
- Charged orb: its own look (not flame licks, not yarn).
- Stance: clearly different from idle (a cast pose sprite would help most: an art ask).
- Light spilling onto her hand and sprite near the orb.
- Blast: tendrils lashing out on impact.
- Recolor her drawn hex (curse visuals) to the violet-blue palette.
- Fewer bars, more world: let the hex itself show how much she has (the hand orb already shrinks as her reserve empties),
  then retire the placeholder hex bar on the HUD.

## Where things live
- Shader: `shaders/sh_hex_orb` (the light model; header comment lists every part).
- Drawing and sizes: `scr_hex_wisp` (`hex_orb_draw`, `hex_wisp_att`, K/L/O/P keys), `obj_player` Draw.
- Motion (Motes 2.0): `obj_player` Step + `hex_flow_to` in Create. Lift/stir: `obj_env_parent` (`hex_gather`).
- History: `hex-wisp.md` (this folder), and the Coven project doc `claude/hex-hand-orb-lookdev.md` (rounds 8-12).
