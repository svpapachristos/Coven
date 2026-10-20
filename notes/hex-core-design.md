# Hex core design: the structure of the Hexweaver's hex
Oct 19, 2026. Agreed with Sophia before step 3. **Every hex pass gets checked against this file.**
Goal: as the game's complexity grows, the code's complexity doesn't have to get muddy.
(Plan and order: `hex-foundation-plan.md`. Bugs and history: `hex-system-audit.md`.)

## One hex body per caster
All of a caster's hex lives in ONE struct, the **hex body**, owned by the caster (obj_player holds it as `hex`).
Nothing about it is tied to obj_player, so another witch, a familiar or an enemy can own one and get the whole system.

| Part | What it is |
|---|---|
| `max`, `hand` | her total hex, and how much is in her hand right now |
| `parcels[]` | her hex out in the world (0.25 each) |
| `anchors[]` | every place hex is gathering |
| `tune` | every tuning number, with a comment (her tuned values are copied over exactly) |
| `owner` | whose hex it is (a shot's hex knows whose hand to fly home to) |

## Her hand is the body's home, not an anchor
An anchor is somewhere hex goes TO; her hand is where hex comes FROM and goes back to. Anchors are made, fill, move with
what they're attached to, and are released; the hand does none of that. As an anchor it would need an exception in
every anchor function ("release... unless it's the hand"). As home, hex is always in exactly one of three places:

**THE LEDGER: hand + parcels + anchor pools = max.** (Like a bank account and envelopes of cash: envelopes come and go,
the account is where money starts and where leftovers return.)

## Parcels
`{ x, y, vx, vy, s (its own pace), ph (its own phase), st, wait, hot, amt, a (its anchor, or none) }`
| st | What it does |
|---|---|
| flow | travels to its anchor through drifting currents (the river) |
| gather | arrived: churns around its anchor (pooling under a held thing) |
| home | waits its own moment, drifts, then is drawn back to her palm (catching up even while she walks) |
A **burst** is home parcels launched with an outward kick (a shot ending, later the slam), not a separate state.

## Anchors
```
anchor = {
  kind,      "knot" | "hold" | "orb" | "shot" (a label, for the look and debugging)
  x, y,      where it is (updated from its attachment every frame)
  attach,    what it rides on: an instance (rock, enemy, shot) or noone (a free anchor the move positions itself, like the knot)
  want,      how much hex it asks for
  at, out,   hex gathered on it / flowing to it (counted from ITS OWN parcels only)
  pool,      hex held inside it directly, not as parcels (a charging orb, a shot in flight)
  r,         arrival radius / how wide its parcels churn
  focus,     frames held in place (the knot, step 6)
}
```
Two ways hex sits on an anchor: **gathered parcels** (the river flowed in: reach, hold) or a **pool** (fed straight from
her palm: charge; or carried: a shot). The charging orb BECOMES the shot: on release its anchor re-attaches to the new
shot instance, pool and all; when the shot ends the anchor releases its pool as burst parcels.

## Layer 1: the core (`scr_hex_core`). The ONLY code that changes amounts, parcels or anchors
| Function | Job |
|---|---|
| `hex_body_create(owner, max)` | build a body |
| `hex_core_set_max(body, max)` | max hex changes (items, H key); the difference lands in her hand |
| `hex_anchor_make(body, kind, x, y, want, r)` | a new anchor |
| `hex_anchor_move(anchor, x, y)` | put a free anchor somewhere (the move steers the knot this way) |
| `hex_anchor_attach(body, anchor, inst)` | ride on an instance, or noone to come free; reshapes its parcels around it |
| `hex_core_release_all(body)` | let go of everything except shots in flight (they end on their own) |
| `hex_core_pour(body, anchor, from_x, from_y)` | hand → parcels flowing to the anchor, until at + out reaches want |
| `hex_core_feed(body, anchor, rate)` | hand → the anchor's pool directly (charging) |
| `hex_anchor_release(body, anchor, how, vx, vy)` | "home": its parcels drift home · "burst": its pool blasts out as parcels · "melt": its pool goes straight back to her hand |
| `hex_core_step(body, hand_x, hand_y, move_x, move_y)` | once a frame: anchors follow their attachments, parcels flow / gather / go home, counts update |
| `hex_core_audit(body)` | the ledger check: prints the exact difference the frame hex is lost or duplicated (runs while F1 debug HUD is on) |

## Layer 2: moves (`scr_hex_moves`). Behavior, built only from core calls
Moves take the body plus what the player WANTS as plain arguments (aim point, button states). They never read input,
never touch obj_player's variables, never edit parcels directly. So AI, a familiar or a replay can call the same moves.
| Move | Built from |
|---|---|
| `hex_move_reach(body, aim_x, aim_y)` (each frame) | a knot anchor following the aim; pick the target; pour; lift when paid; steer what's held |
| `hex_move_reach_end(body)` | throw what's held; release its anchor home |
| `hex_move_charge(body, x, y)` (each frame) | an orb anchor in front of her hand, fed from her palm |
| `hex_move_charge_end(body, dir)` | ≥ 2 hex: create the shot, re-attach the orb to it. Less: melt |
| `hex_move_blast(body, x, y, dir)` | a small shot with a 4-hex pool |
| `hex_move_let_go(body)` | release every anchor |

## Layer 3: the look (`scr_hex_look` + `sh_hex_orb`). Reads only
Ingredients (core/spark, body, glow, smoke/edge, strands, veil, sparks) are shader functions; recipes (hand orb, river,
knot, charge, scoop, shot, burst) combine them. The look reads the body and never changes it; its own eased visual
numbers live in their own struct.

## obj_player's whole job
Read `scr_input` → call moves → `hex_core_step(hex, ...)` → Draw asks the look to draw `hex`.

## The rules
1. Only `scr_hex_core` touches parcels, anchors or amounts.
2. Moves get intent as arguments; they never read input or obj_player.
3. The look only reads.
4. No bare numbers in logic: every number lives in `tune` with a comment.
5. Names say the layer: `hex_core_*`, `hex_anchor_*`, `hex_move_*`, `hex_look_*`.
6. The ledger must balance. If the audit fires, it's a bug, fixed before anything else.
7. Future-proofing first: never read a key or the mouse outside `scr_input`.

## THE REACH MODEL: flow, claim, overflow (decided Oct 20, before step 5)
Inspiration: Wanda rising over the battlefield in Endgame. Everything pours out of HER (hands, body, eyes); the scrap
lifts because it's caught in her overflow, not because anything connects her to it. The source is her; the world reacts.
**No tether**: nothing ever draws a line from her palm to what she holds (decided before, confirmed here).

**1. FLOW: hex pours from her for as long as she reaches.** Holding secondary = she is pouring. Hex leaves her palm at a
steady RATE (not a set lump) and goes wherever she steers: the river's HEAD (an anchor) follows the cursor, and the hex
eddies and drifts around it with no target needed. This is the "play with magic in the environment" fantasy, and a rate
removes the stop-start lumps. The longer she pours, the more of her hex is out. Let go: anything unclaimed unravels home.

**2. THE RESERVE: she can pour everything except an emergency reserve.** Flow never takes her last `reserve` hex (a
forward-thinking witch keeps a backup). So her palm never reads as empty: a small core of hex always burns there, like
Wanda's hands mid-cast. The reserve CAN be spent on a palm blast (and a charge), never on the flow.

**3. CLAIM: things are lifted by the hex that reaches them.** Liftable things the HEAD touches (or the one nearest the
cursor when she starts pouring) are claimed: hex arriving there STICKS to that thing (its own anchor, attached to it)
instead of flowing on. When its cost has stuck (rock 8 x weight, enemy 14), it lifts. The hex holding it sits ON the
object (an aura cupping it), so no tether and no orbiting blob; anything beyond the cost flows on with the head.
- **Claims happen only at the head, never along the river's body.** (m21's failure: enemies between her and the
  target stole her hex. This rule is what prevents it.)
- **Her total hex is her carrying capacity:** sweep the head across a crowd and each enemy claims its 14 as the flow
  passes; 32 hex holds two enemies, not three. Clean single targeting = start pouring with the cursor on the thing.
- Throw / slam then act on everything she's holding at once (step 8).

**4. OVERFLOW: she can devote hex to herself, on a toggle.** When she has enough, she can TOGGLE overflow on: a fixed
chunk of her hex is committed to her own body (an anchor attached to HER, holding a locked pool). Hex pours off her
hands and eyes, she rises off the ground and moves faster. Toggle off and it returns to her hand. A bargain: power now,
less to cast with. (Starts as a toggle because that's the fun one to play with; could later become an Ascension unlock
or a permanent run upgrade.) Needs a new scr_input action ("overflow"), key to be chosen.

**The knot fits inside the flow:** the head IS the knot. When she holds the head still, it gathers and its `focus`
builds (the future ground ability: a ground tear / rune); when she moves on, it simply flows on (it never slides along as
a ball).

**Why it fits the structure:** it's all anchors. The head = an anchor following the cursor; a claim = an anchor attached
to a thing; overflow = an anchor attached to her. The ledger still reads: hand + flowing + claimed + devoted = max. No new
plumbing, only new moves (plus a pour-by-rate in the core).

## Step 3 in three passes (each one plays exactly the same)
- **3a core:** `scr_hex_core` (body, parcels, anchors, audit); obj_player's existing move code calls core functions.
  (Built Oct 19. Verified by porting old and new to Python: 420 frames of reach / lift / hold / throw / charge / fire /
  burst / palm blast / let go matched exactly, ledger at 32 throughout. Her tuning now lives in ONE struct passed to
  `hex_body_create` in obj_player's Create.)
  Keeps the m20 latch bugs on purpose (fixed in step 5), so any difference you feel is a refactor mistake. Input part 2
  rides in this commit. *Clip:* reach, lift, throw, charge, fire, palm blast; F1 audit stays quiet.
- **3b moves:** the move code moves into `scr_hex_moves`; obj_player shrinks to input → moves.
- **3c look:** hex drawing into `scr_hex_look` (may fold into step 4, which rewrites the drawing anyway).
