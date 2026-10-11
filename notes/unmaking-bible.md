# The Unmaking: the complete guide
The Hexweaver's ultimate, and the universe terrarium it grows. Every part, how it works, and why. Written Oct 11, ~5am, after the day the universe learned to live, die and be reborn.

**The pillar:** childlike awe, built from real (simplified) astrophysics. Her enemies become dust, the dust becomes nebula, the nebula becomes stars, and the stars live, die and recycle. Every cast is a peek into a living universe that kept evolving while she fought.

---

## 1. The cast: breaking the world open
**Files:** obj_unmaking Create (timeline), Step, Draw (7c entrance), Draw GUI (clean frame).
1. **Clean frame.** On the first frame, the doomed enemies, she and her familiar are hidden, and the Unmaking draws nothing, so Draw GUI can photograph the bare world (`snap`). A flash covers that one empty frame (and fades over the first few, in case the heavy first frame hitches).
2. **Glitch (0.7s).** Reality glitches: windows onto her cosmos slash across the screen.
3. **Stillness (2s).** Time locks and her hex draws itself beneath her.
4. **Tear (0.3s).** A crack runs in from the right edge, under her, and forks.
5. **Gape (0.95s).** The line of light holds and builds.
6. **Shatter.** Impact frame (`hitstop`, kind 1), then BOOM. The photographed world breaks into chunks (slabs and rocks) that drift away for ~2s, revealing her sky behind.
7. **Heavy setup is time-sliced** across the entrance frames (`plan_queue`: 80 bodies per frame, ≤2 new pixel reads per frame), so the cast doesn't freeze.

## 2. Stardust: enemies become a universe
**Files:** Create (dust plans), Step (motes), Draw (stardust stages 1–3).
- **Crumble.** Each doomed enemy stands in full color, then burns away pixel by pixel from the head down. Every pixel becomes a **mote** of its own color.
- **Two fates for a mote:**
  - **Cloud dust** (most of it) drifts like smoke and eases to rest around where its star is forming. It thins into the dark, or stays as **haze** (her nebula).
  - **Star dust** (bright threads) streams into the star and condenses into its color.
- **Protostars.** A cocoon of glowing gas gathers around each forming star.
- **Ignition.** When a body's last thread lands, its star blooms, flaring big then settling to its size.
- **The finale wave.** A wave runs outward through only this cast's newborn stars, so they pop as the new arrivals.
- **Accretion.** Newborn stars attract each other and merge (bigger, heavier, flash). Black holes pull newborns into spirals and swallow them.
- **Budget:** dust_total 3,200 motes across all bodies (each body 2–24). wisp_keep 0.3 of settled dust stays as haze.

## 3. The haze: her nebula
**Files:** scr_hexweaver (haze functions), Step (section 3), Draw (6b).
- **Wisps.** Every piece of lasting gas is a wisp: position in her sky (ox, oy), size, brightness, color, angle, texture cell.
  - **Fields:** ex (exposure), st (stretch), tx (texture fade-in), fr (atlas cell), at (brightness target), u (claimed by a star), tr (caught by a hole), fz (orbit flatness), fl (flying).
  - **scr_hex_wisp_norm** fills in every field's default. Every creator of gas goes through it.
- **Her sky frame.** Wisps and stars store positions unrotated and are drawn rotated by sky_angle. The sky slowly turns.
- **Texture atlas** (256×128, 8 cells): cells 0–3 are billows (warped noise), 4–7 are threads (ridged noise). Energy-normalized so swapping cells doesn't change brightness.
- **Diffusion.** Fresh gas billows out fast while settling, then keeps slowly spreading and thinning (same light, wider).
- **Soot.** Dark wisps (c = −1) are drawn subtractive first: dark lanes with structure.
- **The exposure curve.** Light from overlapping wisps doesn't just add up to white. Each 48px patch glows toward a ceiling (HEX_HAZE_GLOW · (1 − e^(−L/G))). Dim gas stays dim, dense gas glows rich and saturated.
- **Merging between casts.** Every wisp thins (s × 1.06, a × 0.96). Dead wisps are dropped. Crowded wisps merge (≤2 per 36px cell), conserving light (areas add). Big settled gas grows threads. Gas shaped by a star (u) keeps its shape.
- **Cap:** HEX_HAZE_CAP 3000 (ring buffer via scr_hex_haze_add). Shreds, outflow and primordial gas may go up to cap + 800 on purpose; the next merge tidies them.

## 4. The peek: the cast is a window into time
**Files:** Create (peek block, section 2.2), Step.
- **Away time.** The seconds since she last looked (`global.hex_last_peek`) are cosmic time that passed while she fought.
- **Births from density.** Her gas collapses where it's densest (a patch's glow ≥ HEX_COLLAPSE_L). The number of births scales with how much gas there is (dense skies drain themselves), up to HEX_PEEK_BIRTHS per cast.
- **Aging.** Every star ages by the away time. Due deaths are shown during the peek.
- **Holes drift** together, and the galaxy turns, by the away time too.

## 5. Nurseries: how stars are born
**Files:** scr_hex_nursery_at, Step and Draw (6c).
1. **Gathering.** All free gas within 80px is claimed. Too little gas → no birth.
2. **Bok globule.** A dark knot with a lit rim.
3. **Infall.** Matter spirals in Keplerian orbits (faster and faster as it closes in).
4. **Herbig-Haro jets.** The young star fires jets from its poles: an hourglass beam, bow shocks, a dark lane, and a dimmer far side. Bead types: **knots** (roman-candle pulses), **aerosol spray** (fine specks drifting to mist), **wide wind** (puffs). The axis precesses.
5. **Ignition.** The star catches, blows its cocoon away, and lights up the gas around it.
6. **The garden trim.** The leftover gas splits: some swallowed, some ejected 30–90px as pinkish jet streaks, some kept as the star's pocket. Jet streaks slowly loosen (st −0.002 per frame) and rejoin the garden.
- **The tidal limit:** no births within 7r of a black hole (its pull tears clouds apart faster than they can collapse: the Roche limit).
- **No births during the quasar or the twilight.**

## 6. A star's life
**Files:** scr_hexweaver (life, death), Step (2.2), Draw (section 7).
- **Mass sets everything** (scr_hex_star_color: red dwarf → sun-like → blue giant, softened toward white by HEX_STAR_SOFTEN).
  - **Red dwarfs** (m < 6) live forever.
  - **Sun-like stars** (6–24) live HEX_SUN_LIFE · (10/m)^1.2 seconds. In their last 30% they swell into **red giants** (bigger, orange-red).
  - **Giants** (m ≥ 24) die soonest.
- **Sun-like death:** throbs three times, then puffs off a **planetary nebula** (a lumpy, oval ring of red hydrogen and teal oxygen) and leaves a **white dwarf** (tiny, white-hot, mass × 0.3). The ring settles into haze: food for new stars.
- **Giant death:** fast white-blue pulses, then either:
  - **A black hole,** if massive enough (HEX_COLLAPSE_MASS 100, or 15 with F10), allowed (tier ≥ 4 or debug) and there's room (spacing, max holes), or
  - **A supernova:** an impact frame, a flash, 90 filaments, then a remnant of 48 thread wisps in oxygen teal, sulfur and iron gold, and hydrogen red. It leaves a **neutron star**, drawn as a **pulsar** with sweeping beams.
- **The newborn halo** marks this cast's new stars.

## 7. Black holes
**Files:** scr_hex_draw_hole, Step (aging, feeding, outflow), Draw (7b + shader uniforms), sh_hex_lens.
### Formation: implosion with a payoff
1. **The inhale** (HEX_GATHER 1.5s). Three rings of light contract onto the giant, 28 streaks pour inward, the rest of the sky dims, and space visibly bends around it (lens strength grows to full). The star swells, reddens, and is crushed to a point.
2. **The vanish:** the impact frame.
3. **The beams:** twin hair-thin gamma-ray beams from the poles across the whole screen (0.7s, flickering), plus a 0.15s core flash.
4. **The ripple:** a wave of bent space rolls outward (1500px over 1.4s).
5. **The ignition:** the photon ring lights first (a flare ×3 settling to 1), then the disk builds over 2.5s.
6. **Fallback:** 28 warm wisps (the dead star's outer layers) ring the new hole at 2.6–4.4r and spiral in to build the first disk. The sky's light seeps back over 1s.
### Feeding
- **Reach:** min(300, 7r) (700 for a supermassive). The pull fades in smoothly from the edge, so far gas just drifts and keeps its shape.
- **Caught (within 4.5r):** it stops spreading, leaves a trail, gets torn, stretched and heated.
- **Tidal shredding:** a big cloud (s > 11) tears into three soft pieces at 0.58 size (same total light), spread radially. The inner ones orbit faster, so the cloud shears into a curved arm.
- **Orbits flatten into the disk** (fz 1 → 0.12, Bardeen-Petterson alignment). Gas orbits faster (Kepler) and falls faster the closer it gets. It turns smoothly to follow its orbit and stretches gently (≤ 2.2).
- **Trails:** positions are remembered every 4 frames, and each trail segment is one soft stamp stretched across its gap, so streaks are unbroken.
- **Heat:** its own color far out, orange inside the reach, white-gold inside 2.5r.
- **Into the disk:** inside 3r, the gas dissolves into the disk (2% per frame). Swallowed at 1.3r.
- **Feed:** gas lost to the disk adds to the hole's feed (decays × 0.995 per frame). **A starving hole is dim and quiet; a feeding hole blazes.**
### The heart: holes give back
- **Most gas that reaches a disk never crosses the horizon.** It's blown back out. A small hole throws out 35%, a supermassive 90% (real: our galaxy's black hole swallows well under 1% of the gas that comes its way).
- **Outflow:** up to 3 wisps per frame fly out of the poles (±9°) as hot blue-white gas. A supermassive also blows a ±60° wind. They slow down (× 0.985 per frame), cool to violet, and settle far away, where density births can turn them into stars (real: jets trigger star birth).
- **Faint polar jets** are drawn while a hole feeds hard.
### What makes it look like Interstellar (sh_hex_lens, per pixel)
- **Shadow:** pure black inside r.
- **Lensing** (softened point-lens equation): the sky behind bends into a bright compressed ring around the shadow. No razor-thin Einstein ring, so no spikes.
- **The brim:** the far half of the disk, seen by light bent over the hole, wraps over the top. A thinner mirrored image wraps under the bottom.
- **The disk** (nearly edge-on, SQ 0.12):
  - turbulent clumps and filaments sheared along their orbits (two flow copies on a 7s cycle so the shear never winds into stripes), fine streaks, and two orbiting hot spots
  - Doppler beaming (approaching side brighter and bluer, receding dimmer and redder) and temperature colors (white-gold → orange → her violet)
  - gravitational redshift dims and reddens the inner edge
- **Smoky envelope:** cooler, wispy gas puffed above and below the disk.
- **Layered photon ring:** three nested hairlines (light that looped the hole 1, 2, 3 times), brighter on the approaching side.
- **Glare:** a soft halo and a streak along the disk.

## 8. Mergers, the supermassive, the galaxy
**Files:** scr_hexweaver (migrate, size, galaxy turn, clearance), Step (dance block, star tearing).
- **Migration:** holes sink toward each other's center of mass (dynamical friction), the lighter one moving more. It happens during fights too.
- **Clearance:** holes keep ≥ max(250, 3.2 · size) away from her, easing out.
- **The inspiral:** two holes within 2.4 × (combined size) start spiraling. The gap closes as (time left)^¼, and the orbit speeds up into a chirp (5s). Gravitational-wave ripples ring at twice the orbital rhythm, growing stronger.
- **The merge:** they become one (5% of the mass leaves as the waves), the photon ring blazes, the biggest ripple rolls out, and the screen shakes.
- **The supermassive:** gen ≥ 2 (three holes merged into one). Size × (1 + 0.45 · gen), up to 160px, with a 700px reach and a huge disk. Merging frees hole slots, so new holes keep forming and feeding it.
- **The galaxy:** once a supermassive exists, everything turns around it: stars, gas and other holes. Flat rotation curve (solid inside 300px, slower outside), so gas shears into spiral arms.
- **Tidal disruption:** every 12–22s, the supermassive tears apart its nearest star: a flash, a 22-wisp arc stretched along its orbit (half flung outward, half spiraling in), the disk flares, and half the star's mass is swallowed.

## 9. The aeon: death and rebirth
**File:** scr_hex_aeon_step.
1. **Galaxy:** the supermassive feeds. When its meal reaches HEX_QUASAR_MEAL (300) →
2. **Quasar (10s):** the disk outshines everything, relativistic jets cross the screen, and its wind blows the galaxy's gas outward, heated blue-white. No births.
3. **Twilight (45s):** no births, the gas dims, and stars age 4× faster toward their ends (giants, rings, embers).
4. **Evaporation (14s):** Hawking radiation. The supermassive shrinks away, its disk fades, and it burns hotter and brighter.
5. **The Big Bang → dawn:** the last of the old universe becomes the next one's beginning (Penrose's conformal cyclic cosmology). The screen washes white. 408 clouds of primordial gas (12 clumps, the next of 4 palettes) rush outward from the singularity and coast to rest. The sky glows with the cooling afterglow of creation (the cosmic microwave background, orange → deep red → dark over 7s). Every old hole is gone, old gas fades to a memory, and in G mode the old stars are gone too. The first stars of the new aeon ignite in the clumps.

## 10. Sitting in her universe (G)
- **G** (in a run) opens her sky without a cast: no horde, the world frozen, the sky living. A warp opens over 0.6s and closes over 0.5s, with streaks.
- **Living:** a second of watching is a second of cosmic time. Stars age, deaths play out, and density births happen every HEX_BIRTH_EVERY seconds.
- **Esc or P pauses** (G still leaves).

## 11. Rendering
- **The sky** (sections 2–7) draws into `sky_a`, a 16-bit float surface that can hold light brighter than white, in world coordinates (camera_apply).
- **sh_hex_lens** copies it into `sky_b`, bending light around holes, adding ripples, and drawing each hole's shadow, disk, brim, rings and glare.
- **Holes' CPU parts** (inhale, beams, jets, quasar, Hawking glow) draw into `sky_b`.
- **sh_hex_tone** puts `sky_b` on screen through a camera curve: untouched below a brightness knee of 0.7, rolling off smoothly above it, with overbright colors bleaching toward white. Nothing clips flat.
- **Fallback:** if the shaders are missing or fail to compile, everything draws straight to the screen the old way.

## 12. Debug keys
| Key | Where | Does |
|---|---|---|
| G | in a run | sit in her universe |
| F10 | anywhere | debug holes (collapse mass 15, ignores tier) |
| V | in the Unmaking | a dying 40-mass giant at the mouse |
| B | in the Unmaking | a birth at the mouse |
| N | in the Unmaking | a minute of cosmic time |
| M | in the Unmaking | black holes rush together (toggle) |
| K | with a supermassive | skip to the next age of the aeon |
| Insert / F6 | in a run | full ult / +50 unmade |

## 13. Tuning knobs (scr_hexweaver macros)
HEX_HAZE_CAP 3000 · HEX_BIRTH_EVERY 5 (testing; restore to ~20) · HEX_PEEK_BIRTHS 4 · HEX_MASS_SUN_MIN 6 · HEX_MASS_GIANT 24 · HEX_SUN_LIFE 240 · HEX_HAZE_GLOW 0.6 · HEX_GAS_REF 20 · HEX_COLLAPSE_L 0.45 · HEX_COLLAPSE_MASS 100 · HEX_MAX_HOLES 3 · HEX_HOLE_SPACING 500 · HEX_HOLE_MIN_DIST 250 · HEX_GATHER 1.5s · HEX_SMBH_GEN 2 · HEX_QUASAR_MEAL 300 · HEX_STAR_SOFTEN 0.225.

## 14. Before a real build
- Restore `_covers` to [0.87, 0.73, 0.62, 0.55], and HEX_BIRTH_EVERY to ~20.
- Gate the debug keys (G, V, B, N, M, K, F10).
- Remove the PERF PROBE lines.
- Known: one sighting of a hole stuck on the supermassive (unreproduced).

## 15. Still to build (see terrarium-cycle.md)
Cosmic web inflow · binaries, novae and Type Ia · kilonovae · spiral density waves · the timelapse in G · special stars (tinted dwarfs and giants, convection spots) · supernova polish (shock breakout, cooling colors, light echo, filament remnant, triggered births) · varied planetary nebula shapes · click-to-zoom on a black hole · the stargazing station in the hub · the GPU haze for performance.
