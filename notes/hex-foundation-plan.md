# Hex foundation plan: how we build the Hexweaver's hex from here
Oct 19, 2026. The work structure for the hex, agreed with Sophia after the full audit (`hex-system-audit.md`).
**Start every hex session by reading this file.** It is the guardrail that keeps the code from getting muddy again.

## The goal
A hex system so cleanly structured that it can become endlessly intricate: its **plumbing** (how hex moves), its
**behavior** (what she can do with it) and its **visual ingredients** (how it looks) are separate, reusable pieces that plug
into each other. Every new spell, combo or witch should be built *from* these pieces, never as a one-off inside obj_player.

## The rules (read before every change)
0. **Future-proofing comes first, every time we write code** (Sophia, Oct 19). Controller and mobile are long-term
   goals: build systems that won't need rewriting when they arrive. Gameplay never reads a key, button or the mouse
   directly; it asks `scr_input` what the player wants.
1. **One change per pass, one clip, one commit.** If something feels off, fix only that before adding anything.
2. **Foundation steps change nothing you can see.** Their test is "plays exactly like before". If it looks different, it's a bug.
3. **Every feature must be expressible in the three layers below.** If it isn't, the layers need a new piece first, on its
   own commit, before the feature.
4. **Nothing new goes in obj_player** except calls into the hex scripts.
5. **New ideas mid-step go in the Parking lot** (bottom of this file), not into the code.
6. **Her tuned numbers are sacred.** Never overwrite them: stage fresh, diff, merge.
7. Every diff comes with a short "what to check in the diff" and a GitHub Desktop commit message (Summary + Description).

---

## The three layers

### Layer 1: the hex core (plumbing). Script: `scr_hex_core`
**The amount.** Her hex is one amount (`hex_max`), always somewhere: in her hand, in parcels, or gathered on an anchor.
Nothing pops in or vanishes. (Already true in m20; keep it.)

**Parcels.** Small bits of hex (0.25 each). A parcel only ever does one of four things:
| State | What it does |
|---|---|
| **flow** | travels to its anchor through drifting currents (the river) |
| **gather** | has arrived: churns around its anchor (pooling under a held thing) |
| **home** | waits its own moment, drifts, then is drawn back to her palm |
| **burst** | flung outward (an explosion, a slam), slows, then turns into home |

**Anchors.** An anchor is any place hex can gather. This is the new core idea. Each anchor has:
| Field | Meaning |
|---|---|
| `x, y` | where it is (follows what it's attached to) |
| `attach` | what it rides on: nothing (a fixed spot), the cursor, her hand, an enemy, a rock, a shot |
| `want` | how much hex it asks for (a lift's cost, the reach amount, a charge cap) |
| `at`, `out` | hex gathered on it / on its way to it (counted from its own parcels only) |
| `r` | how close a parcel must get to count as arrived, and how wide it churns |
| `focus` | frames it has been held in place (see the knot, below) |
| `look` | which recipe draws it (Layer 3) |

Every parcel belongs to exactly one anchor (or is going home). **Latching = a parcel assigned to an anchor attached to the
target**: it flows to *that thing*, wherever it moves, and only hex gathered *on it* counts.

Core functions (names may change, the jobs don't): make an anchor, move it, release it (its parcels go home or burst), pour
from her hand into an anchor, update all parcels, count each anchor's `at` / `out`.

### Layer 2: moves (behavior). Script: `scr_hex_moves`
Each move is a small function that only creates, moves and releases anchors. Combos are moves calling moves.
| Move | In anchor terms |
|---|---|
| **Reach** (Space + RMB) | an anchor on the cursor's spot or on the target under it; pour into it |
| **Lift** | the reach anchor is attached to a rock or enemy and its `at` reaches `want`: the thing is held |
| **Hold / steer** | the held thing follows the cursor; its anchor follows the thing |
| **Throw** | release the anchor with the thing's motion; parcels go home |
| **Charge** (Space + LMB) | an anchor in front of her hand fed straight from her palm |
| **Fire** | the charge anchor becomes a shot (a moving anchor) |
| **Burst** | a shot ends: its anchor releases as burst parcels |
| **Palm blast** (tap Space) | a small shot straight from her hand |
| **Let go** (release Space) | every anchor releases; parcels go home |

**The knot (Sophia's spec, Oct 19).** When she reaches into open ground, her hex gathers into an orb at that spot. This orb is
a placeholder for a future ground ability (a ground tear or rune placement) that will only trigger when she *focuses* hex on
one spot long enough. So the knot is an anchor fixed to a **ground spot**, not dragged around with the cursor:
- She holds the reach on the spot: the anchor's `focus` counts up and the orb forms.
- She moves the reach away before the focus threshold: the orb **dissolves back into parcels** that flow out of it and
  stream on to wherever she's reaching now, as one river. It never slides along as a ball.
- Later: focus reaches the threshold and the ground ability fires. (Not built now; the threshold just exists.)
Purpose today: pre-emptive polish so playing with the magic (swirling it around) feels good.

### Layer 3: the look (visual ingredients). Shader `sh_hex_orb` + script `scr_hex_look`
**Ingredients** are reusable shader functions (Sophia's names, from the visual bible):
core / spark (white-hot, lilac) · body (hex blue mist with dust) · glow (blue-violet where light overlaps) · smoke / edge
(dark violet rim and patches) · strands · veil · sparks.
**Recipes** combine ingredients with settings, one per thing that's drawn:
| Recipe | What it draws |
|---|---|
| hand orb | idle → channeling (eased) |
| river | all parcels, as one body |
| knot | an anchor gathering on open ground |
| charge | spark → crackle → glow → bloom |
| scoop | hex cupping a held thing (+ lit from below) |
| shot | an orb in flight |
| burst | the blast (not built yet) |

**The river needs layers** (the "sandy" look in the Oct 19 clip: faint dark scratches, every parcel its own speck, no light).
Cause: the sand bug (each parcel paints at about 1/3 strength, so only the darkest step ever shows) plus a single thin layer.
Target stack, bottom to top: a wide soft low-res **glow** pass (volume) → the **body** → **light** where it runs thick → **sparks**.
The sand fix alone is not enough (m21 proved it).

**File layout when done:** `scr_hex_core` (amount, parcels, anchors) · `scr_hex_moves` (the verbs) · `scr_hex_look` (recipes,
draw calls) · `sh_hex_orb` (ingredients + recipe modes only, no dead modes) · `obj_player` (input → moves, nothing else).
Another witch can reuse the core and swap the look (e.g. the Elementalist's nature magic).

---

## The order (check off as we go)
Today's finish line: **steps 1-3** (a clean base and the anchor foundation). Step 4 if there's energy.

- [x] **1. Keepers commit.** Re-apply from m21: grab range 80, reach amount 6, the sand fix (solid blob + texture filter,
      streak cap, brighter current dots), facing where she casts. **Not** the charge snap flash or light spill (they mishmashed).
      *Done when:* plays like m20 with those four differences. *Clip:* reach + lift a rock.
- [x] **2. The hex is the Hexweaver's.** Gate the Space stance and the test rocks to her; every other witch gets her E back.
      *Done when:* Necromancer's E raises the fallen again; Hexweaver unchanged. *Clip:* none needed (quick check).
- [ ] **2b. Parcels catch up to her (bug, found in the step 1 clip).** Going home, a parcel's top speed near her hand is capped
      at about half its distance + 1 px/frame, but she walks 7.5 px/frame: within ~13px it can never close the gap, so
      stragglers trail behind until she stops (the HUD bar never refills). Fix: add her own movement to that cap, and land
      within ~14px instead of 6. Own commit, before step 3, so the anchor rebuild copies correct behavior.
      Second layer (Sophia's call): diagonal walking normalized (it was ~41% faster: 10.6 vs 7.5 px/frame), done as the
      first piece of an input layer: new script `scr_input` (`input_move()`, `input_moving()`); every WASD read in obj_player
      goes through it, so a controller or touch controls plug in one place.
      *Clip:* reach, let go, and keep walking: the bar fills back to full.
- [x] **Input layer, part 2** (done Oct 19, rides in the step 3 commit): every gameplay read of the mouse or a button goes
      through `scr_input`: actions (`input_check/pressed/released("stance" | "primary" | "secondary" | "ability" |
      "ultimate" | "interact")`) defined in one bindings table, and `input_aim()` for where she's aiming. Step 3 is written
      against these from the start: **the hex never reads the mouse or a key directly.**
- [ ] **3. Anchors (the foundation)**, designed in `hex-core-design.md` (read it first). Three passes, each "plays exactly
      the same", each its own commit:
  - [x] **3a core:** `scr_hex_core` (hex body, parcels, anchors, ledger audit); obj_player's move code calls core
        functions. Input part 2 rides in this commit. *Clip:* reach, lift, throw, charge, fire, palm blast; F1 audit quiet.
  - [ ] **3b moves:** move code into `scr_hex_moves`; obj_player shrinks to input → moves. (Written Oct 19: move state is
        `hex.mv`; obj_player builds an intent from scr_input and calls `hex_move_update`; End Step calls `hex_move_end_step`.)
  - [ ] **3c look:** hex drawing into `scr_hex_look` (may fold into step 4).
- [x] **4. A readable river.** (First pass Oct 19: glow layer + light where it runs thick, `river` knobs in scr_hex_wisp.
      Sophia: "a slightly less fuzzy mess of specks"; real polish waits for the behavior fixes and step 11.) Minimal layered field (glow pass + body + light). Not the full visual pass: just enough that a
      clip shows where the hex goes. *Clip:* reach into open ground and let go.
- [ ] **5. The reach model: flow, claim, overflow** (designed in `hex-core-design.md`, "THE REACH MODEL"). Fixes the
      step 4 clip problems: globs instead of controlled magic, hex pouring in lumps (stop, then more), extra hex orbiting
      a lifted target. **No tether** (decided). Passes, each its own commit and clip:
  - [ ] **5·0 cooldowns:** a cooldown system for every hex move (`hex.mv.cd`, `hex_move_ready` / `hex_move_cool`, lengths
        as `<name>_cd` in her tuning). First user: the palm blast (tap Space, `blast_cd` 30). A quick tap of left click in
        the stance no longer fires a mini orb (orbs need `charge_min` 6 to fire); that tap is free for a future move.
        Bare numbers moved into tuning: `charge_min`, `tap_frames`.
  - [ ] **5a flow + reserve:** secondary pours hex at a steady rate to a head that follows the cursor, until only her
        reserve (`reserve: 4`, one emergency palm blast) is left; let go and it unravels home. No targets yet. *Clip:* pour, swirl the cursor, let go.
  - [ ] **5b claim:** the head claims what it touches (or what's under the cursor at the start); hex sticks to it, lifts
        it at its cost, no orbiting blob; extra flows on. *Clip:* reach onto a moving enemy in a crowd; lift a rock.
  - [ ] **5c overflow toggle:** E while in the stance (the existing `ability` action, read as a context action) toggles a devoted chunk of hex onto herself: she rises and
        moves faster (placeholder look: her palm flaring + a hover). *Clip:* toggle on, walk, cast, toggle off.
- [ ] **6. The knot's focus:** the head held still builds `focus` (the threshold for the future ground ability exists,
      nothing fires yet). (The dissolve-into-flow part is now just how the flow works.)
- [ ] **7. Held means held.** A held/thrown enemy: no AI, no contact damage, lifted off the ground (z), stunned on landing;
      throw strength from the hold's motion. *Clip:* hold an enemy past her, throw it into the horde.
- [ ] **8. Combos, one at a time:** multi-lift (several anchors) → overflow into a second target → slam (LMB while holding).
- [ ] **9. Charge channeling phase** (the veil forming around the disk) as a recipe change.
- [ ] **10. Cleanup commit:** delete the smoke-wisp look and its 2 shaders, shader modes 1-3, old circles, O/P/K/L keys in
      normal play; update `hex-visual-bible.md` ("Where things live" is stale).
- [ ] **11. Visual pass** with clips: river, blast look, enemy underlight.
Then **hex control is done for the Act 1 slice** and we return to the slice list (enemy variety, the level, the boss).

## Reference
- **m21** (the reverted multi-lift + slam pass): kept in `notes/m21-reference/` as plain text, never compiled. Steps 5 and
  8 borrow from it: per-parcel targets and per-target counting (good), the slam (good). Do **not** bring back its two
  auto-spreading rules (parcels catching enemies mid-flight; auto-retarget after a lift) except on purpose in step 8.
- Bugs and line numbers: `hex-system-audit.md`. Look rules: `hex-visual-bible.md`.

## Parking lot (ideas that came up mid-work; not now)
- A quick tap of left click in the stance is free for a new move (it used to fire a mini orb that looked like a palm blast)
- Input layer, part 3: menu navigation (Escape, arrows, Enter, clicking menu items in scr_menu / obj_game_controller)
  through `scr_input`. Debug keys stay on the keyboard on purpose
- The charge's "crackling spark flowing into the orb" (m21 tried it; redo as a recipe in step 9 or 11)
- The future ground ability the knot is a placeholder for (ground tear / rune placement)
- Curse hook: the living hex applying the curse (toads, ripening)
- Earth rip, Agatha-style spiral-in return, blast cooldown/power rebalance, curse veins, enemy underlight
- Not hex: `scr_stat("attack_speeed")` typo in player_attack (attack-speed items do nothing); check `max_hex` in scr_known_stats
