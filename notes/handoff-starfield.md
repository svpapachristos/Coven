# Handoff: the Hexweaver's star system (Coven)

Written Oct 10, 2026, at the end of the entrance chat. Read this first, then `notes/hexweaver-slice-plan.md` (the living plan: macro goals, polish queue, parked ideas, gotchas).

## Who and how
- Sophia is building **Coven**, a GameMaker (GML) witch roguelite, as a **15-minute vertical slice** for her resume. The bar is "feels industry-standard". Heavy focus: the Hexweaver class and the Witches Wand.
- **Sophia types every line herself, for practice.** Give her the full code, the why, and exactly where it goes (file, event, and the line to paste above or replace). Prefer whole replacement blocks over scattered edits; she gets lost when edits are spread out.
- Claude **reads** her live project folder (`C:\Users\Sophia\Documents\GitHub\Coven`) and does not write code into it. The one exception is the notes files, which Claude keeps updated.
- She sends **short clips** (mp4). Step through them frame by frame (ffmpeg contact sheets, then zoom) before answering. Read the saved files to check her implementation; if a file looks unchanged, she probably hasn't pressed Ctrl+S in that event tab.
- Art is drawn by her girlfriend: **no AI art**. Code-drawn effects and art briefs are fine.
- She has great instincts. When she pushes back ("are you sure?", "looks like they're flipping"), take it seriously; she has been right several times.

## Where things stand
- **The entrance is done (first pass).** Cast flash, then the glitch over the colour world, then a white frame that drains it grey, then the hex sigil draws itself, then a streak of light races along the crack, then a short hold, then the ground's impact frame, then BOOM (shake 48), then 600px banded cliffs rip apart as rigid slabs, rubble is flung, and rays blast out. The full beat list is in the plan file.
- **Now: the star system.** Sophia's vision (in her words): make "spaghettify into stardust" and the star system "a smol little (massive) star and gravity system, so a player can come for the roguelite mechanics and stay because their favourite class turns the game into a space simulator with stars made of your enemies."

## How the star system works today (code map)
- `objects/obj_unmaking`: the ult. Create (timing, doomed list, star planning, tear and chunks, rocks), Step (t, hitstop and impact frames, shakes, black hole ageing, finale pulse, accretion), Draw (the sky layers, her stars, black holes, the entrance, the frozen horde, windows streaking into stars, ignitions, the impact frame), Draw GUI (the clean photo), Clean Up.
  - Key timing: `birth_at` (the stardust starts), `seize_len`/`seize_end` (the horde fills with light, then starts travelling), `rise_end`, `cascade_len` (stars ignite nearest-first), `finale_at` (the ring pulse), `duration`.
  - Windows: in Draw, "stages 1 and 2", the `sh_starlit` shader turns each body into a window onto her cosmos; `draw_sprite_pos` stretches it head-first into its star (corners use `sprite_get_xoffset`, NOT `sprite_xoffset`).
- `scripts/scr_hexweaver`: the macros (`HEX_COLLAPSE_MASS 150`, `HEX_MAX_HOLES 3`, `HEX_HOLE_SPACING`, `HEX_HOLE_MIN_DIST`, `HEX_GATHER` 1.5s, `HEX_STAR_SOFTEN`), plus `scr_hex_plan_star` (decides each enemy's star, sharing stars when crowded, using a 20px grid), `scr_unmake` (ignites), `scr_hex_accrete` (newborn stars pull and merge after the finale), `scr_hex_hole_radius`/`scr_hex_hole_room`/`scr_hex_draw_hole`, `scr_draw_star_flare`, `scr_hex_star_colour`, the nebula and sky art builders, and `scr_hex_return`.
- Data: `global.hex_stars` holds structs with `ox, oy` (offset from her, in sky coordinates that turn with `sky_angle`), `s` (size), `ph` (colour phase) and mass. `global.hex_holes` holds black holes with `ox, oy, age`. Stars past `new_from` are this cast's newborns.
- Shaders: `sh_starlit` (windows), `sh_timestop` (the grey frozen world).

## Read of the last starfield clip (Oct 10, 4:30am)
Works well: the finale ring (newborn stars popping in sequence around her) and the black hole impact frames.
What holds it back, in the recommended order:
1. **The horde becoming stars is muddy.** Dark window shards with thin outlines tumble over a bright, busy nebula, so it reads as debris, not starlight. It should get **brighter** as the horde dies.
2. **Dead air and an invisible gathering.** About 1.5s of nothing after the finale, then a collapse whose gathering is barely visible (one star dims). The stars should visibly spiral in while the sky dims ("wait, is that doing what I think it's doing?").
3. **The nebula competes** with the stars and holes. Dim it during the key moments.
4. **Black holes read small.** Give them presence: lensing, an accretion swirl, nearby stars bending around them.

**Open question for Sophia** (asked, not yet answered): when a body becomes a star, should it
- (a) **turn to light**: flood white-violet from the feet up, then streak in as a bright comet (Claude's pick), or
- (b) **stay a window, but bright**: brighter cosmos inside and a hard glowing edge, then a bright streak?

Her new framing ("spaghettify into stardust", a gravity system) suggests a third take worth offering: **spaghettification**. Bodies stretch into long glowing threads pulled toward their star, the way matter stretches falling into a black hole. The existing head-races-ahead/feet-lag stretch is already halfway there.

## Bigger ideas to keep in view (from the plan's parked list)
- **The whole-run cosmology**: enemies become stardust, dust gathers into stars over many casts, stars feed and collapse, about 3 black holes per run, and in endless mode the holes merge into a **supermassive black hole** (the final power fantasy).
- Gravity as a real system: stars pulling on each other between casts, orbits, holes bending light and stars. Note this is a 15-minute slice, so scope each step to something that reads in one cast.

## Gotchas that bit us (full list in the plan)
- `sprite_xoffset` already includes `image_xscale` (sign too). Use `sprite_get_xoffset()` for the raw origin.
- One `draw_primitive_begin`/`end` batch holds about 1000 vertices; anything past that is silently dropped.
- `merge_color(a, b, amt)` takes two colours. A number like 0.8 counts as near-black.
- A reused `var` name silently overwrites the old value (`_open` almost broke the sky ring). Ctrl+F before naming.
- No apostrophes in shader comments: curly quotes break the Windows shader compiler.
- Keep `if (clean_pending) exit;` at the top of obj_unmaking Draw and Step, or the photo bakes everything in.

## Oct 10 (afternoon): starfield overhaul, clip read + plan
Clip: the ult from the stardust onward (24s). Sophia's notes, each confirmed frame by frame:
1. **One-frame swap, grey to nebula windows.** Cause: the grey frozen draw stops at `birth_at` and the starlit path starts with `_fill = 1` hard-coded (Draw, "stages 1 and 2"), so the shader's rising fill never animates. Her call: the doomed don't need to be desaturated. They're her ingredients coming with her, so they keep their colour against the drained world.
2. **Bodies "vwoosh" to their spots.** Every body leaves at the same moment (`seize_end`) on a straight eased line, with no particles and no gravity.
3. **Stars near her go dark right after they're born.** Cause: the resting star core is `_ss * 0.6 / 15` of a 15px dot, so its radius is under a pixel, and the twinkle dips to 0.2. After the 18-frame ignition flare it almost vanishes. It only comes back when it twinkles up, or when it merges past s 2.5 and gets the flare path.
4. **Black holes:** cool, but each one should be a breathtaking spectacle ("wait, that star collapsed... it's gathering more and more... is it becoming a-" BOOM). Only one forms at a time without F10, so a long build is fine. Wants Interstellar / NASA-style lensing.

No-regret fixes given (before the overhaul): the doomed keep their colour (Draw, the frozen-horde block: desat 0, tint 1, dark 0), and resting stars get a minimum crisp core plus a twinkle that never goes dark.

Cleanup spotted: Create lines ~217-243 hold a stray copy of Draw code (the break flash, which uses `_vx` and `t - shatter_at`). It only survives because `_bf` is negative at t = 0, so delete it. Step lines 18-19 set `hitstop = 10` twice. The black hole "time drags" never worked, because `_slow` is always 1.

**The plan (proposed, waiting on her picks):**
- **Step 1, Stardust.** Bodies crumble pixel by pixel (new `sh_crumble`: blocky per-texel noise, head first, a white-violet burning edge) in a ripple outward from her. Each body sheds motes (about 3000 total, split per enemy). Motes fall like ash for a beat, then get swept into a galaxy-wide swirl around her (tangential pull) and spiral into their planned star. Star plans get `ph` at planning, so motes already carry their star's colour. A protostar glow grows at each plan as dust lands. When an enemy's last mote lands, its `unmake_at = t`, so `scr_unmake` fires: that's the ignition "catch". The finale triggers when the motes are gone, not on a fixed timer. Draw motes in two passes (all glows, then all cores), since `spr_glow` and `spr_dot` sit on different texture pages and alternating them breaks batching.
- **Step 2, Living sky.** Visible orbits and drift between casts, and the nebula dims during key moments.
- **Step 3, The collapse as a five-act spectacle:** (A) unstable: a heavy star swells red and pulses while time drags (wire `_slow`); (B) it pulls: nearby stars drift in on spiral tracks, dust streams form a growing disk, the sky and nebula dim, the star shrinks and turns blue-white; (C) implosion: all light sucked inward, then a near-black beat; (D) the existing impact frame and BOOM with a supernova shell; (E) reveal: the shell's debris falls back and forms the disk over about 2s.
- **Step 4, Real lensing.** Render the sky layers into `sky_surf`, then draw each hole's area through `sh_lens` (point-mass thin lens: sample at r - Re^2/r, black inside the shadow). Background stars and nebula smear into Einstein-ring arcs. Keep the far-side disk arc over the top and under the bottom (Gargantua), plus Doppler beaming.
- **Step 5, Supermassive (F10 / endless).** Holes inspiral, gravitational-wave ripples run through the lens shader, they merge, and the bigger hole gets a bigger ring.
- Design note: **save spaghettification for things falling into a black hole** (stars torn into streams, as in tidal disruption), so it never shares a look with the enemy crumble.
References shown: Infinity War snap dust, NASA SVS black hole accretion disk visualization (Schnittman), Interstellar's Gargantua, NASA tidal disruption illustrations.

## Oct 10 (afternoon): cliff ends showing during the rumble (fix given)
Clip: during the BOOM shake (48), the left end of the top chunk and its cliff slid into view (a vertical cut with the void behind it), and a seam showed at the right edge. Cause: the ground only reached 80px past the screen, and the world_surf texture margin is just 64 surface px, so the outer columns sampled past the photo. Fix: `_pad = 400` on every side, `tear_n` scaled to keep the column width the same, the fork's spread divided by the visible columns (`_vis`), branches clamped inside the ground, chunk pivots kept at the old 80px anchors (the wedge's grow would otherwise swing its tip over her), rocks and grit picked from visible columns only (`_vc0`), ground UVs mirrored past the photo's edge (`scr_mirror01`), and the ground drawn one batch per row (the top chunk would pass the ~1000-vertex limit). Also deleted the stray Draw code in Create (the break's pale frame); it had never run.
