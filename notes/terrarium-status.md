# Terrarium status and the plan to stick the landing
Written Oct 11, ~6:30am, at the end of the big build night. This cross-references the guide (unmaking-bible.md) and the cycle plan (terrarium-cycle.md) against what the clips actually show, and sets the plan for the next sessions.

## What the latest clips show (6:25am clip, 63s)
✅ **Working:** births and jets, deaths (rings, supernovae, pulsars), hole formation, the shader black hole look (shadow, brim, disk, photon ring), feeding, merges, the supermassive with smaller holes orbiting it, the galaxy turning, the crunch's opening (the gas ring collapsing inward is beautiful), Hide HUD, the debug readout, the dead-gas sweep, auto loot.
⚠️ **Broken or unclear:**
- **The crunch's end:** blocky rectangles as the horizon swells. Cause: the lens θE scales with the crunch swell, so the lens magnifies sky_a texels into big blocks. The void black and the bang aren't confirmed in G mode yet (clips ended early, were duplicates, or were in casts).
- **Springing lensing:** partly fixed (smoothed size, no ringdown in the lens). Remaining suspects: holes moving fast (migration, galaxy turn), new holes ramping their lens, and a wide lens reach (fade from 4θE to 9θE).
- **Too many holes** churning (V spam plus max 3 with merges freeing slots) clutters the sky.
- **The quasar** isn't readable yet. Stars are hard to read against everything else.
- **Gas** still a bit wonky when being vacuumed or thrown out (acceptable for a first pass).
- **FPS** is OK but getting expensive. Sophia's clue: lag is worse when spawned slimes are bunched up (enemy-vs-enemy proximity checks scaling with crowding).

## The structural problem
About 15 systems were built in one night. Each one sets visual values directly (sizes, brightness, lens strength, phase switches), so transitions snap or spring, and fixes interact in unexpected ways. "Smoothing" needs a shared layer, not individual patches.

## The plan
1. **Walkthrough first:** every process explained in plain words (especially the quasar, outflow, aeon machine and shader), so Sophia owns the system again before more changes. Update unmaking-bible.md as we go.
2. **The aeon director:** one global struct of eased "mood" values (sky brightness, lens scale, backdrop alpha, disk spin rate, darkness, gas brightness, shake). Phases set targets, and the director eases toward them every frame. Every system reads from it.
3. **The crunch as a scripted cinematic** on top of the director: inhale → rush → darkness → void (guaranteed full black, HUD hidden) → bang → afterglow → first light. Decouple the horizon swell from the lens (cap θE at its pre-crunch size, and cap magnification).
4. **Calm lensing:** eased per-hole lens strength, a cap on total displacement, a narrower reach, smooth ramps when holes form or merge, and lens positions eased while holes move.
5. **Hole population:** a soft cap and fewer, more meaningful holes. The supermassive eats stragglers; new holes only when the garden has earned them.
6. **One gas lifecycle:** settled → caught → flying → settled, with eased transitions in stretch, brightness and color, never instant switches.
7. **Optimization:** profile (the probes), a spatial grid for enemy separation and collisions, culling for off-screen haze, shader LOD (simplified disk for small or far holes), and fewer per-frame full-haze passes (stagger them across frames).
8. **Extras, once it's solid:** Hawking-point seeding and the run signature (the universe stays "hers"), special stars (tinted dwarfs and giants, convection spots), supernova polish (shock breakout, cooling colors, light echo, filament remnant, triggered births), varied planetary nebula shapes, cosmic web inflow, a dark matter halo (seen only through weak lensing; the flat rotation curve is its real evidence), the Stargazer station, binaries and Type Ia, kilonovae, click-to-zoom on a black hole, the timelapse.

## The finish line: "a living garden"
- [ ] Runs unattended in G mode (H on) for 30+ minutes, through at least 2 full aeons, with no bugs or crashes.
- [ ] Never empty, never clogged: the gas and star budgets stay stable across aeons.
- [ ] Every phase is readable at a glance (galaxy, quasar, twilight, crunch, void, bang, dawn).
- [ ] Every transition is smooth: no snapping, springing or popping.
- [ ] A steady 60 FPS on Sophia's machine.
- [ ] Physics-first: every behavior has a real-science explanation written in the guide.
Then: the Arcane Wand's Deadlock-level pass, then the Hex, then back to the rest of the game's spine.
