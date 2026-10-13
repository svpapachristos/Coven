# The Hex: the Hexweaver's mark
What every part of her sigil means. Code: `scr_draw_hex_sigil` in scr_menu (title screen, the ult's ground circle, and any future hex effect).

Built like a real ceremonial magic circle from the old grimoires: protective rings of script on the outside, a star of power inside, and the heart at the center. Read from the outside in.

| Layer | What it is | What it means |
|---|---|---|
| Double outer ring | Two rings with a spark racing around them | The boundary of the circle: in ceremonial magic, the line between the working and the world. The spark is the circle "live" |
| The inscription | A band of witch's script, read clockwise, with a slow wave of light passing over it as if spoken | **"AS ABOVE SO BELOW"**: the Hermetic maxim from the Emerald Tablet. What happens in the heavens mirrors what happens on earth. Her pocket universe above, her battles below; every star in it was one of her kills. A larger dot marks where it begins and ends |
| Seven-pointed star {7/2} | The witch's star (also the faery or elven star), inside a faint heptagon | Seven: the old sacred number of the heavens. Turns slowly one way |
| Seven seals | A small circle at each point, each holding a classical planet's symbol: Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn | The seven "wandering stars" of old astrology, one per point: the classical occult correspondence of the heptagram. Kept upright so they read |
| Beaded ring | A ring of small points | The threshold between the heavens (the star) and the self (the pentagram) |
| Pentagram | Five points in a circle, turning the opposite way | The witch's own sign: the four elements (earth, air, fire, water) crowned by spirit |
| Triple moon | Waxing crescent, full moon, waning crescent, always upright | The heart of witchcraft: the triple goddess (maiden, mother, crone), birth, life and death. Also her universe's own cycle: dawn, galaxy, twilight |

**Colors:** deep glow (150, 30, 190), magenta-violet line (220, 90, 255), pinkish-white core (255, 225, 250). Three lines at the top of the function, open to Sophia's palette.

## The Coven script (our witches' alphabet, for now)
- Every letter has one fixed glyph, built from a stem or a sweeping curve, a curl or hook, and sometimes a tail or a dot, chosen by a hash of the letter itself. The same letter always looks the same, so the band truly spells its words.
- Spaces are small dots; a larger hollow dot marks the start and end of the inscription.
- The inscription is one line, `#macro HEX_SIGIL_TEXT` in scr_menu. Change it and the hex says something else. Ideas: the Latin "QUOD EST SUPERIUS EST SICUT QUOD INFERIUS" (the same maxim, longer), or later her universe's pet name.
- **Planned:** swap these glyphs for the real Theban alphabet (the historical "witches' alphabet", public domain), given a letter reference. Only the glyph drawing changes; the inscription stays.
