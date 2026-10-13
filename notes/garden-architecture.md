# The garden's architecture: what is real, what is legacy, what is dead
The map to check every change against. Written Oct 12, 1am, after an audit of scr_hexweaver (2,429 lines), obj_unmaking Step (856) and Draw (1,291).
Update it whenever a system moves between columns.

## DECISION (Oct 12, 10:47pm): the universe simulation is DORMANT
The garden works and loops (dawn → galaxy → quasar → twilight → crunch → bang, conserved matter). We stop building it here: for a ~10 s ult, a full background universe is overbuilt. What happens now:
- **Keep it in the game as is.** Your sky remembers every enemy you unmade; each cast feeds it and shows it. There's no background simulation between casts, and the run-universe restructure is cancelled.
- **Next:** optimize the ult version, and polish the cast segment itself (enemies → their dust in place → stars kindling from it → smooth color settle). This is what the player feels.
- **Later:** a stargazer in the hub as a quiet pocket-universe view. Split the simulation into its own tech-demo repo on GitHub (a future session).
- **Parked ideas:** a stardust collector as a meta resource for crafting; "cultivate a universe from seeds" (a whole game of its own); a remnant of each run drifting into the hub universe.
- **Scope guard (Sophia):** if a feature starts growing into its own project again, stop and put the effort into making the practical parts of the game breathtaking with code (the Elementalist first). A Hexweaver polish pass is always welcome.

## The north star
A self-sustaining universe garden built bottom-up on the real ingredients astrophysics codes use, so it is both genuinely physical and visually stunning. When something looks wrong, look for faked math; real physics usually fixes the look.

## The scale and the clock
1 sky pixel = 10 parsecs (the garden is ~30,000 pc across, the size of the Milky Way's disk). At full speed 1 real second = 1 million years. Every speed is derived from a measured real value (scr_hex_kms), never tuned by eye: rotation 220 km/s, gas dispersion 10 km/s, photoionized gas 20 km/s.

## The rules (so it never gets muddy again)
1. **One owner per quantity.** Gas lives only in the fluid. Stars live only in `global.hex_stars`. Black holes live only in `global.hex_holes`. Nothing else may create, move or delete them.
2. **Things move because of a force.** Gravity, pressure, rotation, a shockwave. No scripted motion of physical things.
3. **New physics replaces old code, then the old code is deleted** in the same pass. Nothing half-alive.
4. **Test the physics alone** (the isolation switch, below) before judging a change.
5. **One owner of the sky at a time.** During a cast the choreography owns the screen and the physics waits; in G the physics owns everything.

## The spine: the new physics (keep and build on)
| Layer | Where | What it is |
|---|---|---|
| Gas | `sh_hex_fluid_p` modes 10/11, `scr_hex_fluid_update` §3 | Compressible, self-gravitating, isothermal gas; finite volume (mass exact); Rusanov + MUSCL; SSP-RK2 time steps; Jeans pressure floor; outflow-only edges |
| Gravity | `sh_hex_fluid_p` mode 5, `scr_hex_fluid_update` §2 | Thin-disk gravity (1/d², softened by the disk's thickness) summed tree-style from a mass pyramid on a 128² grid; real G; isolated; gas + every cluster + every hole; read back so clusters and holes feel it too |
| Galaxy | `sh_hex_fluid_p` mode 11 | Dark matter halo (flat rotation curve); new gas poured in already orbiting |
| Heating | `sh_hex_fluid_p` `cs2At` | Photoionization: gas lit by hot stars gets ~5× the sound speed |
| Light | `scr_hex_fluid_light`, `sh_hex_fluid` modes 1 and 2 | Starlight map; emission lines (H-alpha, [OIII], [SII]) from ionization, kill colors as a tint; reflection (bluer); dust extinction per color (reddening); Strömgren bubbles; radiative transfer (I = S(1 − e^−τ)) |
| Stars from gas | `scr_hex_fluid_sinks`, `scr_hex_sink_make` | Kennicutt-Schmidt law at the 480 pc scale, stochastic cluster complexes (~900,000 suns), outside holes' Roche reach; each weighs exactly the gas taken |
| Star clusters | `scr_hex_pops_update`, `scr_hex_pop_*` | Each star is a cluster with a real population: color and light fade by age (Bruzual & Charlot), ionizing light for ~3.5 Myr (Starburst99), real Strömgren radius, gas handed back by age (Leitner & Kravtsov 2011), brightest members die as supernova flashes, old clusters merge as they dissolve |
| Feedback | `scr_hex_feedback_map`, `sh_hex_fluid_p` mode 11 | Superbubbles (Weaver 1977, blowout Mac Low & McCray 1988): pressure map from each cluster's supernova energy; the gas feels −∇P |
| Orbits | `scr_hex_orbits` | Leapfrog in the halo: stars and holes move with the gas |
| Plumbing | tiers (Y), read-back, F1 fluid line, L, I arrows | Not physics; the tools |

## Legacy still running that LEAKS into the physics (the muddiness)
| # | System | Where | How it leaks | Replaced by |
|---|---|---|---|---|
| 1 | ~~**Ledger thinning**~~ DELETED 2:40am | `scr_hex_fluid_update` §4 (`_fl.keep`) | When old code deletes wisps, the fluid is faded *everywhere*. Global, not physical | Step 2 (gas consumed locally where stars form) |
| 2 | ~~**Wisp star births**~~ DELETED 2:40am (timed G births, the peek's births, `scr_hex_find_nursery`; B now drops a gas cloud. Only the aeon's first light still calls `scr_hex_nursery_at`: goes with #7) | `scr_hex_nursery_at`, `scr_hex_find_nursery`, `scr_hex_haze_expose`, Step "births (peek)", "G-mode living" | Stars are built from wisps that rode the gas into knots. Made the surprise black hole | Step 2 (sink particles: stars from dense, bound gas) |
| 3 | ~~**Star accretion → holes**~~ DELETED 2:40am | `scr_hex_accrete` (after the finale) | Stars merge into each other and collapse at mass 100: a scripted path to black holes | Step 2/3 (massive stars die as holes by their own mass) |
| 4 | **Galaxy turn** | `scr_hex_galaxy_turn` | Rotates stars AND wisps around the supermassive by script, fighting the halo's real rotation of the gas | Step 4 (stars orbit in the gravity field, leapfrog) |
| 5 | **Holes eat wisps** (no longer leaks: the ledger is gone; delete with the wisp cleanup) | Step "feeding + outflow", aeon §quasar (`_w.f *= 0.9` near holes) | Wisps fade near holes, so the ledger fades gas everywhere (#1) | Gas core already swallows gas at holes; delete with #1 |
| 6 | **Scripted hole motion and mergers** | `scr_hex_holes_migrate`, Step "mergers" | Holes slide by script; their gravity drags gas along | Step 4 (holes are bodies in the gravity field) |
| 7 | **The aeon director** | `scr_hex_aeon_step` (317 lines) | Quasar wind moves wisps, twilight fades wisps (→ #1), crunch pulls wisps, cosmic inflow adds wisps at the edges (fine: real inflow) | After step 4: ages read from the physics state instead of a script |
| 8 | **Shockwave strengths** | `scr_hex_fluid_kick` callers (supernova 1.1, PISN 1.6, shells 0.4, quasar 0.7, outflow, Big Bang 3) | Intended pushes, but sized for the old smoke | Step 3 (energy/momentum from real feedback) |
| 9 | **Ledger upkeep** (no longer leaks; delete with the wisp cleanup) | haze cap 3,000, `scr_hex_haze_merge`, dead-gas sweep, `scr_hex_matter_take` | Each removes wisps, so feeds #1 | Retire with the ledger (step 2) |
| 10 | **Whole-sky spin** | `sky_angle += spin…` (Step) | Rotates the whole view: the old way to make the galaxy turn, now on top of real rotation | Remove once real rotation reads well |

## Every influence on the garden (audit, 3:05am). Re-check this list whenever something new touches gas, stars or holes
**The gas (the fluid) changes only by:**
| Influence | Where | Status |
|---|---|---|
| Its own physics: flux, pressure (+ Jeans floor), thin-disk self-gravity of gas + clusters + holes (real G), halo, photoionization heating, outflow edge | `sh_hex_fluid_p` | ✅ physics |
| Superbubbles (cluster supernova pressure) | `scr_hex_feedback_map` → mode 11 | ✅ physics |
| Star formation removes gas (Kennicutt-Schmidt law) | `scr_hex_fluid_sinks` | ✅ physics |
| A new run empties the gas and the universe's clocks | `scr_hex_universe_reset` (obj_game_controller Create) | ✅ |
| Clusters hand gas back (into their shells, then winds) | `scr_hex_pops_update` → pour | ✅ physics |
| Black holes swallow gas: Bondi (×100) capped at Eddington, 90% grows the hole | per-hole rate `eat` → shader u_holes.z; measured at read-back | 🟡 physics (edit41) |
| Black hole light pushes the gas (AGN feedback, 5% of 0.1·Ṁc²) | scr_hex_feedback_map, a cluster-equivalent Weaver bubble | 🟡 physics (edit41) |
| New gas from wisps, poured once, then the wisp is spent (rule 1) | pour in `scr_hex_fluid_update` | ✅ |
| ↳ wisp sources: her kills (the cast) | Step stardust | ✅ intended: her food |
| ↳ cosmic inflow, the Big Bang | aeon | 🟡 lore, rebuild with #7 |
| ↳ legacy single-star deaths (supernova shell, planetary ring), hole-birth fallback ring, tidal disruption stream | Step | 🟡 her cast stars' deaths; amounts not tied to mass yet |
| Shockwave kicks: quasar wind 0.7, Big Bang 3 | aeon | 🟡 #7/#8 |
| ~~Legacy single-star supernova kicks (kpc-wide)~~ | `scr_hex_flow_kick` | removed 3:05am |
| ~~Hole outflow puffs and bursts, hole shredding~~ (made gas from nothing / doubled it) | Step feeding | inert since rule 1 (no wisps reach holes); delete with the wisp cleanup |
| ~~Wisp merging~~ (could double poured gas) | `scr_hex_haze_merge` | fixed by rule 1 |
| B cloud, X cluster | debug | ✅ |
| Restore after the graphics card drops textures | `scr_hex_fluid_backup` | ✅ |

**Stars:** clusters (born, aged, lose mass, merge when old, orbit in the halo + the gas's own gravity) ✅ physics. Her cast stars ARE clusters now (born at the cast, emerging from their dust) ✅. Only V's debug giant still uses the legacy single-star death. Aeon crunch pulls/deletes stars, tidal disruption removes one 🟡 #7. Galaxy turn gated (#4).
**Holes:** born from legacy collapse 🟡; orbit in the halo + gas gravity ✅; grow by swallowed gas ✅; merge when they meet (the inspiral itself is scripted: below the grid) ✅; migration gated (#6).
**The view:** sky spin gated (#10).

## Visual only (no effect on the physics; keep, restyle later)
Cast choreography (tear, stardust motes, protostar bodies, threads, finale pulse); star drawing; black hole drawing and the lens shader; supernova and ring visuals; jets and knots; infall; tidal disruption visuals; Inspect labels; title cards; the backdrop nebula image and deep field; the faint filament texture on the gas.

## Dead or fallback-only (candidates to delete; verify each while cleaning)
- `scr_hex_fluid_vel` (unused)
- The CPU currents: `scr_hex_flow_init / kick / sample`, the CPU branch of `scr_hex_flow_step`, `HEX_FLOW_*` (only run if the fluid is off)
- Wisp sprite drawing: `scr_hex_wisp_sprite`, `scr_hex_draw_wisp`, the wisp loop in Draw, `HEX_FLUID_WISP` (only when the fluid is off)
- J key (fluid off = falls back to all of the above). Decision: require the GPU fluid and delete the fallback, or keep a minimal one
- `_fl.ink` remnants; old comments describing the smoke solver
- The nursery machinery in Step and Draw (`nurseries`, `jbeads`, `infall`, jets): now only fed by the aeon's first light (#7)
- The ledger's leftover fields (`_fl.W`, `Wp`, `nw`, `passes`, `cal`, `c`, `keep`) and `HEX_STAR_KEEP`, `HEX_POCKET_KEEP`
- Before a real build: restore `_covers` and `HEX_BIRTH_EVERY` ~20, gate debug keys, remove PERF probes

## What a fresh run loads with (defaults)
Fluid ON at HYPERMAX; gravity, halo, heating on; ripples on; Inspect off; fluid visible. **Plus every legacy system in the table above.** So a test today shows physics + legacy mixed.

## Progress
- 4:55pm (Oct 12): item 2 built: her cast stars are young clusters (same physics), clusters emerge from their dust color, her spell lights the gas during the cast and fades after. The legacy route to black holes is gone until item 4.
- 4:30pm (Oct 12): containment: offline, bubbles don't spread the disk; fixed the velocity read-back (mass-weighted, 7x finer) that was handing new clusters wrong speeds. F1 shows gas and cluster radii.
- 2:45pm (Oct 12): Hubble look verified. Faint gas glow now follows young clusters' ultraviolet (not the star count). Whole universe state resets per run. Clearer G pause.
- 2:30pm (Oct 12): visual pass: gas colors from its light (emission lines, bluer reflection), reddening dust lanes, new gas poured as tidal streams; pours capped and batched (the post-cast hitch).
- 2:15pm (Oct 12): real gravity verified in game (a turning spiral that holds its size). Star formation moved to the Kennicutt-Schmidt law (it nearly stopped under real gravity). New runs start empty. Parked: inheriting a faint remnant of the last universe.
- 1:50pm (Oct 12): REAL GRAVITY built: thin-disk potential (tree sum over a mass pyramid), real G, isolated; clusters and holes feel it. HEX_GRAV is now derived, not tuned; HEX_GRAV_ITER, HEX_GRAV_SCREEN, the periodic wrap and the mean removal are deleted.
- 1:15pm (Oct 12): diagnosed the central collapse: our gravity is 2D (1/r), a real disk's is 1/r^2; and clusters don't feel the gas. Offline proof: grav_compare.png. Fix pending discussion.
- 3:05am: AUDIT + fixes. Fullscreen wiped the gas (textures lost, wisps re-poured, momentum gone → collapse → 200-million-sun clusters → bright discs of returned gas): now a 2 s backup restores it. Star formation follows the free-fall law (2% per free-fall time; clusters 90 thousand to 10 million suns). Rule 1 enforced: wisps are spent once poured (soot too, as dust). Holes swallow measured gas and grow. Legacy single-star kicks removed. Returned gas joins the bubble's shell. X reports on screen.
- 2:40am: STEP 3 built. Stars are star clusters with real populations; superbubbles push the gas; clusters hand gas back (metal-colored). Legacy #1, #2, #3 deleted. Debug: B drops a gas cloud, X turns the gas at the mouse into a young giant cluster. Offline: feedback carves bubbles and filaments, mass exact (fb1.png vs fb0.png).
- 1:10am: isolation switch built (O, on by default).
- 1:30am: step 2 built (scr_hex_fluid_sinks). Legacy #2, #3 gated; #1 off under O. Delete #1, #2, #3, #5, #9 once confirmed in game.
- 1:20am (Oct 12): orbits built early (scr_hex_orbits, leapfrog in the halo): stars and holes travel with the gas. Retires #4 and #10 once confirmed.
- 2:20am: square fix verified in game. New gas is poured in as orbit-sheared streaks. Next: delete legacy #1, #2, #3, #5, #9 (step 2 confirmed), then step 3 feedback (gas returned by dying stars: without it the garden eventually turns all its gas into stars and stops).
- 2:15am: fixed the square-stamp bug (spr_soft's alpha is solid; alpha-based passes now use scr_hex_soft_alpha) and set a physical speed limit.
- 2:00am: during a cast the physics is held; it runs in G (ownership boundary).
- 1:50am: real scale and clock; square simulation area; gravity calibrated (0.00002); F1 mass budget; T speed toggle.

- Oct 12, edit41: black holes from physics (seed at Dawn, Bondi–Eddington feeding, AGN bubble, quasar from feeding rate ≥ 1.8e5 suns/Myr). Still scripted: the quasar's 16 s length, twilight, crunch, bang (step 2, the life cycle). `meal` still written by the legacy wisp feeding in obj_unmaking Step (audit).

- Oct 12, edit42: the life cycle from physics (closed Friedmann universe, conserved baryons with a reservoir and cold-flow inflow, ages from state). Legacy left for the audit: the crunch still moves wisps; scr_hex_matter_take and the ledger; the Inspect "quasar wind front" label; the bang palette only tints new gas; old wisp/haze systems.
- Bug (Sophia, Oct 12): item pickup toasts freeze on screen if you enter the stargazer while one is showing. The run keeps going underneath. Moot once the stargazer moves to the hub, but fix the toast timer.

## Parked polish (after the full loop works)
- **FIRST after the loop closes (Sophia, Oct 12 6:30pm): the cast → stargazer transition, a "working + slight polish" pass.** (1) enemies being unmade should become their dust in place, gradually, handing over to the sim gas; (2) the cast's newborn clusters read as thousands of identical orange motes evenly sprinkled (polka dots, screenshot 6:30pm), and the cloud streaks over them look like brush strokes, not gas; (3) the color story from cast to settled garden (orange birth → blue, glows de-lighting) must read as one smooth change. Also: F10 (easy black holes) is dead under the new physics; V giant and first-star holes don't feed (cut or give them the physics); more holes should come from satellite galaxies falling in, each with its own seed (life cycle step).
- The cast: each enemy turns into its own dust cloud in place, gradually, which then hands over to the simulated gas (now: dissolves to nothing, then clouds pop in as they settle).
- A new run inheriting a faint remnant of the last universe.
- The tiny garden stats screen next to the timescale button.

## The recenter plan
0. **Isolation switch** (debug key O): turns off legacy leaks 1, 2, 4, 5, 7's wisp effects and 10, so tests show the physics alone.
1. ~~**Step 2: stars from gas**~~ done; #1, #2, #3 deleted (#5, #9 harmless now, go with the wisp cleanup).
2. **Step 3: feedback**: built 2:40am (clusters, superbubbles, gas returned). Next: retire #8's guesses (the old supernova pushes).
3. **Step 4: bodies in the gravity field** (leapfrog). Retire #4, #6, #10.
4. **Ages from physics**: rebuild #7 to read the universe's state.
5. **Delete the dead list** as each fallback becomes unnecessary.
