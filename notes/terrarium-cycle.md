# The terrarium cycle: how her universe lives forever
Written Oct 11, ~4:30am. The goal: a sky that never runs down and never stops changing, with every piece feeding the next, all of it real astrophysics (simplified). Wallpaper-forever.

## The rule
Every object either **makes** something, **eats** something, or **turns one thing into another**. Matter only changes form. Nothing is a dead end except on purpose and briefly, and even the dead ends (black holes) give back eventually.

## The flows (✅ built · 🟡 foundation built tonight · ⬜ planned)
**Sources of fresh gas**
- ✅ Her kills → stardust → nebula.
- ⬜ **Cosmic web inflow:** thin streams of fresh gas drift in from the edges of her sky (real galaxies are fed this way). A second source, so the sky lives even without casts. Slow, faint, blue-white primordial gas.
- ⬜ **New aeon:** a dead supermassive's evaporation becomes fresh gas (see the aeon loop).

**Gas → stars**
- ✅ Dense gas collapses into stars (density nurseries), with jets as the garden trim.
- ⬜ **Triggered births:** shockwaves from supernovae and black-hole jets compress gas into new nurseries (real: triggered star formation).
- ✅ The tidal limit: no births within 7r of a hole.

**Stars → gas (and remnants)**
- ✅ Sun-like stars → red giant → planetary nebula (gas back) + white dwarf.
- ✅ Giants → supernova (gas back) + neutron star or pulsar, or → black hole.
- ⬜ **Stellar winds:** giants slowly shed gas their whole lives (Wolf-Rayet bubbles).
- ⬜ **Binaries:** a white dwarf eats its partner → novae (small gas puffs) → Type Ia supernova (the white dwarf destroyed, ALL of it back to gas). This is the recycler for white dwarfs, which otherwise pile up forever.
- ⬜ **Kilonova:** two neutron stars merge → flash + ripple + gas back. The recycler for neutron stars.

**Black holes: eat, give back, merge**
- ✅ They feed on gas (tidal shredding, a disk that brightens while feeding) and carve quiet cavities (quenching).
- ⬜ **Feedback jets:** while feeding hard, a hole fires faint polar jets that carry ~10% of what it eats far out into the garden as hot gas; where they land, nurseries can ignite. Holes become mixers: eat the inner garden, seed the outer one.
- 🟡 **Migration:** holes sink toward each other (dynamical friction). Also during her fights.
- 🟡 **Merging:** two that meet spiral together (an inspiral: the gap closes as (time left)^¼, the orbit speeds up into a chirp), ringing gravitational waves through the whole sky, then become one (5% of the mass leaves as the waves). The photon ring blazes and the biggest ripple rolls out.
- 🟡 **Supermassive:** after 2 mergers (3 holes) a hole is supermassive: bigger (up to 160px radius), with a 700px reach and a huge disk. HEX_MAX_HOLES stays 3, but merging frees room, so new holes keep forming and keep feeding it.

**The galaxy**
- 🟡 Once a supermassive exists, everything turns around it: stars, gas, other holes. Flat rotation curve (solid inside 300px, ever slower outside), so the gas shears into spiral arms over minutes. Also during her fights.
- ⬜ **Spiral density waves:** gently nudge gas into 2 arms so the spiral reads clearly (real galaxies' arms are waves of compression).
- ⬜ **Galactic bar** (maybe): a central bar that funnels gas to the center.

## The aeon loop (the forever)
1. **Dawn:** gas from her kills (and the cosmic web) → nurseries → young blue stars. Busy, colorful.
2. **Summer:** stars live, die, recycle. Holes form, feed, drift together, merge.
3. **The galaxy:** the supermassive anchors everything; spiral arms form.
4. ⬜ **Quasar:** when a lot of gas reaches the supermassive at once, it ignites: a blazing disk, relativistic jets spanning the screen, outshining everything. The peak spectacle.
5. ⬜ **Quenching:** the quasar's power blows the remaining gas out of the galaxy (real: why big galaxies go "red and dead"). Births stop.
6. ⬜ **Twilight:** no new stars. Old stars age out into red giants, white dwarfs, and slowly dimming embers. Warm, dim, quiet, melancholy.
7. ⬜ **Evaporation:** the supermassive shrinks by Hawking radiation (real, just compressed time). It gets hotter and brighter as it shrinks, and ends in one final flash.
8. ⬜ **New aeon:** the flash becomes fresh primordial gas: a new nebula, new nurseries. Back to 1. Backbone: Penrose's conformal cyclic cosmology (a dead universe of evaporated black holes becomes the next Big Bang).
Each aeon varies (gas palette, spiral arm count, where the supermassive sits), so it never repeats. The timelapse in G makes a full aeon watchable in minutes.

## Balance knobs (so it never stalls or explodes)
- Gas budget: HEX_HAZE_CAP, merge thinning, nursery rates scale with gas (dense skies drain themselves).
- Remnant pile-up: binaries/Type Ia and kilonovae recycle white dwarfs and neutron stars; cap their counts.
- Holes: max 3 at once; mergers free room. The supermassive grows by merging and feeding; quasar feedback stops runaway growth.
- Aeon length: twilight starts when gas stays below a threshold for a while after a quasar; evaporation length is set so a full aeon is about 10–15 minutes in timelapse.

## Debug keys (gaze: F10 then G)
- **V:** a dying 40-mass giant at the mouse (with F10, it collapses into a hole).
- **M:** holes rush together, toggles (merge testing).
- **K:** skip to the next age of the aeon (galaxy → quasar → twilight → evaporation → dawn).
- **B:** a birth at the mouse. **N:** a minute of cosmic time.

## Build order from here
1. Test the foundation (mergers, supermassive, galaxy turn).
2. Feedback jets + triggered births (closes the hole → garden loop).
3. Binaries / Type Ia + kilonova (closes the remnant loop).
4. Quasar → quench → twilight → evaporation → new aeon (closes the forever loop).
5. Cosmic web inflow, spiral density waves.
6. Timelapse in G.
7. Then back to the Deadlock polish on the black hole itself.

## The supermassive as the garden's heart (Sophia's idea, Oct 11 ~4am, science-checked)
Sophia: the supermassive is the big switch that closes the loop and shakes things up. It scrambles the garden to keep it moving, and sheds roughly what went into it, so the garden can shrink and grow forever, with no two gardens ever the same.
**Science check:**
- ✅ Stirring: AGN feedback. A feeding supermassive's winds and jets heat gas and push it across the galaxy.
- ✅ Scrambling stars: **hypervelocity stars** (stars flung out at huge speed; some are leaving our galaxy) and **tidal disruption events** (a star torn apart: about half swallowed, the rest flung out as a glowing stream).
- ✅ Never the same twice: it's a chaotic system, so tiny differences grow.
- 🔁 Reframe: swallowed matter can't leave (until Hawking evaporation). But **most gas that falls toward a supermassive never crosses the horizon.** It's heated in the disk and blown back out by winds and jets (Sgr A* swallows well under 1% of the gas available to it). The honest version: **it takes in a lot, keeps a little, flings most of it back out.** What it keeps returns at the aeon's end.
**Design:**
- Gas reaching the supermassive's disk is split: ~5–10% swallowed (grows it), the rest launched outward along jets and winds as hot gas that lands far across the sky and seeds nurseries.
- Stars drifting within a few r: torn apart into a stream (TDE), or slingshot outward (hypervelocity). Both stir the garden.
- Quasar episodes are the big shove: they clear the center and push gas to the rim, so the garden shrinks in one place and grows in another.
- Everything it kept comes back as the next aeon's nebula (evaporation).
Goes into build step 2 (feedback jets) as the supermassive's main job.


## Status, Oct 11 ~5am
🟡 Built (first pass): the heart (polar outflow, keep 35% small / 90% supermassive), tidal disruption events, the full aeon machine (quasar → twilight → evaporation → dawn with new palettes). Still to come: cosmic web inflow, binaries/Type Ia, kilonovae, spiral density waves, the timelapse, and tuning every number from clips.
