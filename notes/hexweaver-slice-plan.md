# Coven: vertical slice plan (living doc)

Updated Oct 10, 2026. Keep this next to the code so the big picture and the polish list never get lost.

## The goal (macro)
A **15-minute vertical slice** for Sophia's resume. The bar is "feels industry-standard".
Heavy focus: **the Hexweaver** and **the Witches Wand**.

Slice checklist, roughly in order:
1. **Hexweaver kit, complete and polished**: Q (the Unmaking), E (Hex), primary fire.
2. **Witches Wand**: arcane beam startup channel (light gathering before it fires), slight turn-speed cap for weight.
3. **Everyday combat feel**: hit feedback and enemy reactions. Seen 100x per run, so it matters as much as the ult.
4. **One act, start to boss**, playable in about 15 minutes.
5. **Economy pass**: essence vs unlock costs, the level-up flood, thrall balance.
6. **Sound**: later.

## Where the Unmaking is now
Design pillars: **Diavolo's time erasure** (reality glitches, the ground rips, the world falls away in slabs) plus **Gojo's Unlimited Void** (you've crossed the universe into her domain). Dio's big sphere is saved for a possible World tarot.

Entrance beats (Create, top):
| Beat | Length | What happens |
|---|---|---|
| Lock | 1.3s | Clean photo of the bare world (flash), world drained violet-grey, hex sigil draws itself under her |
| Glitch | 0.3s | Diagonal bars that are windows onto her nebula, one near-white frame |
| Still | 1.0s | Total stillness, no shake |
| Tear | 0.275s | Crack runs in from the right edge, under her, forks behind her |
| Gape | 1.0s | The ground hangs open, cosmos visible in the crack |
| Break | slab_len 2.2s | Three chunks (above, below, wedge) drift off, earthy undersides |
| Stardust | birth_at = break start + 0.8 x slab_len | Frogs and enemies, left standing in her universe, become stars |

How it works: the doomed, she and her familiar are hidden for one frame so the **bare world** can be photographed (Draw GUI). That photo is the ground that breaks. The horde is drawn live on top, frozen grey, until birth_at. Toads now have sprites (spr_hex_toad, spr_hex_toad_hop), so they take the full sprite path (grey shader, then starlit windows).

**Done Oct 10: glitch-first opening.** The desaturated first frame felt empty: a filter isn't an event. New order: cast flash, then the glitch at once over the frozen world still in full colour; on the glitch's near-white frame the world comes back drained ("what just happened?", the JoJo time-skip beat); the hex sigil draws itself during a longer stillness (1.6s), then the crack. Code: lock_len = 0, still_len 1.6s, `_drained` switches desat/dark, hex `_hp` counts from still_at.

## Bugs to fix
- Fixed Oct 10: the horde and a second copy of her rode away on the breaking chunks, and looked like they shifted when they turned into windows. Cause: `if (clean_pending) exit;` had gone missing from the top of obj_unmaking Draw, so the Unmaking drew them into the photo itself. Fix: put the line back as line 2.
- Oct 10: the glitch bars' nebula tint was `merge_color(_gc, 0.8, 0.3)`, which mixes toward a near-black colour (0.8 isn't a colour). Replaced by a two-depth nebula, dark edges, a cyan channel-split sliver and pinprick stars.
- Magic missiles target frogs (on cast and on retarget). Fix given Oct 9: skip obj_toad in scr_magic_missile and in obj_magic_missile's retarget.
- The arcane beam shows damage numbers on frogs without hurting them (scr_damage_enemy ignores toads, but the beam spawns its numbers first). Fix given Oct 9: skip hex < 0 at the top of the beam's enemy loop.
- Done: magic missiles have a lifetime (3s, obj_magic_missile Create/Step).

## Micro polish queue (next up, in order)
**Entrance first pass (finish these, then the starfield):**
Done Oct 10: glitch-first opening, darker/redder detailed bars, ground cliffs (600px banded strata wall drawn as one strip per column, bottomless while gaping, rigid slabs, smooth torn underside), light from below, chunks drawn top to bottom, pop-then-accelerate exit, frog window jump fixed.
1. Rubble lumps torn from the cliff undersides that fall into the cosmos (code given Oct 10: `rocks` in Create, drawn inside the chunk loop after each wall). Plus more pebbles (grit 40 to 90).
2. Dust burst along the crack as it runs.
3. Impact on the break: a hit-frame/flash with the shake.
4. Sigil pass: light pool on the ground, a leading spark tracing its lines, and the overload (it flickers and splits right before the crack).
5. Cleanup: remove leftover debug messages; optionally draw the glitch bars and sigil above the frozen horde.
**Then the starfield ("best power fantasy"):**
- Stardust and window polish, black hole coalescence as a visible gathering, the return rebuilt as the entrance in reverse, black hole pacing (impact frame can land off-screen), camera language.

## Gameplay changes (small, any time)
- **Killing a hexed enemy turns it into a fresh frog** instead of destroying it (frogs are fun). Fix given Oct 9 in scr_damage_enemy: if hex > 0 and it can be toaded, scr_hex_toadify and skip the kill rewards (the frog pays them out when it pops, so nothing counts twice).
- Frogs get slightly stacky when a whole horde is hexed: a touch more separation (they're harmless, so only a little). Knob: sep_radius in obj_toad Create (parent default 44).
- Necromancer ult (Danse Macabre) charge cost scales with level so it can't be spammed.

## Parked ideas (don't lose these)
- **A whole-run cosmology (long term):** small enemies don't become stars outright. They become **stardust**, and dust gathers into stars over many casts. Stars feed each other and collapse, so the **3 black holes take roughly a whole run** to form. In **endless mode**, the 3 holes can merge into a **supermassive black hole**: the final, final power-fantasy ult (Gojo / "Supermassive Black Hole"). Builds on what already exists: stars merging (accretion) and collapsing at HEX_COLLAPSE_MASS.
- **Hollow Purple** energy for the arcane beam.
- **Runes** in the Hexweaver's kit, especially the E (code or art).
- **Katana ZERO** as the feel benchmark: pixel art plus satisfying mechanics and animation.
- Dio-style sphere / colour pulse for a **World tarot**.
- A cast pose or cut-in (the hex sigil stands in for now).
- Hexweaver tuning: tier thresholds (maybe 100 / 400 / 1200), the 80-kill charge cost, a tier glow per ascension.

## How we work
- Sophia types every line herself for practice: full code plus the why, and exactly where it goes.
- Claude reads the live project folder (Documents\GitHub\Coven) instead of .rar uploads. Save (Ctrl+S) before asking for a check.
- Short clips, one question per clip. Claude steps through frames.
- Art is drawn by her girlfriend. No AI art. Code-drawn effects and art briefs are fine.

## Gotchas learned the hard way
- Chained access straight off a function's return value crashes the compiler (`scr_x()[i].name`). Use temp variables.
- `frac()` of a negative number is negative: wrap in `abs()` when hashing.
- A `var` only exists from its line onward. "Not set before reading" usually means a line got deleted or moved.
- "Add under this line" can match two identical lines (the heart block landed in the impact frame). Check which one.
- Old lines left in place after a block moves silently override the new values (duplicate timing lines, twice).
- **Shader comments: no apostrophes.** Curly quotes from copy-paste break the Windows shader compiler with a "line past the end" error.
- Shapes drawn with draw_ellipse / draw_circle are invisible through a texture shader. Give things sprites, or draw them without the shader.
- A sprite's origin matters when flipping: a top-left origin makes a flipped sprite jump sideways.
- Additive drawing can't darken. Mixing a colour with its own negative passes through grey: cut, don't fade.
- `merge_color(a, b, amount)` takes two COLOURS. A number like 0.8 counts as an almost-black colour, not an alpha.
- The clean-frame `if (clean_pending) exit;` must stay at the top of obj_unmaking Draw (and Step). Without it, anything the Unmaking draws gets photographed into the breaking ground.
- **`sprite_xoffset` / `sprite_yoffset` (instance variables) already include image_xscale/yscale, sign included.** For the asset's raw origin use `sprite_get_xoffset(spr)` / `sprite_get_yoffset(spr)`. Mixing them up caused the frog jump-and-flip when windows start stretching (Oct 10).
- **One draw_primitive_begin/end batch holds only about 1000 vertices.** Anything past that is silently dropped (the cliff wall cut off at the fork). Start a fresh batch per column or per strip.
- `call_later` callbacks (and method functions) can't see the caller's local variables.
- **Renaming an asset in GameMaker renames every call to it, project-wide.** Renaming the stray `scr_hash` script to `scr_mirror01` turned all ~40 `scr_hash(` calls into `scr_mirror01(` (Oct 10). Delete stray assets instead of renaming them, and never give a script asset the same name as a function.
