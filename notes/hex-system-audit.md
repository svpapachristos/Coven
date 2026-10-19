# Hex system audit: the Hexweaver's living hex, front to back
Oct 19, 2026. A full read of the code to see what the hex actually is right now, before building anything else on it.

**Which code this describes:** m20, the last commit ("Scoop telekinesis, spark-to-bloom charge, brighter parcels", Oct 18
~9:40pm). The m21 pass (multi-lift + slam) is still uncommitted in the working files; section 7 lists the few parts of it worth
keeping. Line numbers below are m20's.

Files the hex lives in: `obj_player` Create / Step / End Step (Step_2) / Draw, `scr_hex_wisp`, `sh_hex_orb`, `obj_hex_shot`,
`obj_env_parent` (+ `obj_env_rock`), and it touches `obj_enemy_parent`, `scr_damage_enemy`, `HUD`.

---

## 1. The whole thing in one picture

```
 INPUT (Space held = stance)          THE HEX (one amount, hex_max = 32)          WHAT IT DOES
 ─────────────────────────           ───────────────────────────────────        ──────────────
 tap Space ────────────────────────► hand ──(4 hex)──► obj_hex_shot ──────────► palm blast, burst
 Space + hold Right click ─────────► hand ──parcels──► the KNOT near cursor ──► lift a rock / an enemy
        release Right ─────────────►                    held thing ──────────► throw it
 Space + hold Left click ──────────► hand ──────────► charging orb ───────────► release: orb shot, burst
 let go of Space ──────────────────► everything out ──► parcels drift HOME ────► back in hand
                                       ▲                                      │
                                       └────────── shots burst into parcels ──┘

 DRAWN BY: hand orb (shader mode 0) · river of parcels (mode 4, hex_field_draw) · knot (mode 0) · charge (mode 7)
           · scoop around a held thing (mode 5) · rock lit from below (mode 6) · shots in flight (mode 0)
```

The core idea is sound and it's the right spine: **her hex is one amount that is always somewhere** (hand, parcels in the
world, charging orb, inside a shot), and every visual reads where it actually is. That part works. The muddiness is in how the
reach decides *what* it's going for, and in what happens to an enemy once it's "held".

---

## 2. The plumbing: where her hex lives

| Variable | What it is | Notes |
|---|---|---|
| `hex_max` | her total hex (32, + `max_hex` stat, + H key) | |
| `hex_hand_amt` | hex in her hand right now | the HUD bar shows this |
| `hex_par[]` | **parcels**: her hex out in the world, 0.25 each | `{x, y, vx, vy, s, ph, st, wait, hot, amt}` |
| `hex_out`, `hex_at` | sums of parcels flowing out (st 0) and gathered (st 1) | recounted every Step |
| `hex_orb_amt` | hex in the charging orb | |
| `obj_hex_shot.hex_amt` | hex riding in a shot | becomes parcels when it ends |
| `hex_hx, hex_hy` | "where the hex is": the cursor while reaching, in front of her hand while charging, her hand otherwise | |
| `hex_gx, hex_gy` | **the knot**: where reaching parcels actually go. Trails the cursor (lerp 0.15) | |
| `hex_held`, `hex_kind`, `hex_cost` | the one thing she's holding ("env" or "enemy") and what it cost | |
| `hex_thrown[]` | enemies currently flying after a throw | moved in End Step |
| `hex_mode` | "", "grab" (right click) or "charge" (left click) | first button pressed wins |

**Parcel states:** `st 0` flowing out (steers to its target through drifting noise currents) → `st 1` gathered (orbits the knot
or the held thing, pooling a little under it) → `st 2` going home (waits `0..hex_home_spread` frames, drifts, then is pulled
back to her palm, faster as it nears; lands within 6px and adds back to her hand).

**Her tuned numbers:** flow 9, return 20, turn 0.13, curl 0.85, fan 0.425, home spread 35, pour 2 parcels/frame (0.5 hex/frame).

---

## 3. Every move she has today, front to back

| Move | Input | What the code does | Cost / numbers |
|---|---|---|---|
| **Idle orb** | nothing | The orb sits in her off hand (`hex_hand_pos`, per-sprite table). Shrinks as her hand empties. | — |
| **Stance** | hold Space | `hex_active`. Wand stands down (left/right click now belong to the hex). Hand orb tightens into the erratic "channeling pocket". Camera stops looking ahead after 10 frames. | free |
| **Reach (open ground)** | Space + hold RMB | Parcels pour from her palm toward the knot until `hex_reach_cap` has gathered. The knot draws as a growing orb that kindles a heart once mostly full. | 14 hex parked at the knot (m21 lowered this to 6) |
| **Lift a rock** | reach near a rock | Rock within `hex_grab_r` (64) of the cursor, measured to its edge, is the target. As hex gathers, the rock trembles and rises a little (`hex_gather`). When total gathered ≥ cost, it lifts (`grabbed`, floats to z 14). | 8 × weight |
| **Lift an enemy** | reach near an enemy | Only if **no rock** is in range: the single nearest enemy to the cursor (origin distance), not a boss, not a toad, within 64. Lifts when total gathered ≥ 14. | 14 |
| **Hold + steer** | keep RMB, move mouse | Rock: velocity steered toward the cursor, slower if heavy. Enemy: snapped toward the cursor in End Step (lerp 0.85). Parcels re-gather around the held thing (the scoop). | extra hex beyond the cost makes the scoop stronger |
| **Throw** | release RMB (or Space) | Rock: speed × 1.6 plus a hop (vz), lands with dust/shake, hurts enemies it slides into (speed × 1.5 × weight). Enemy: flies with the cursor's last motion × 1.6, hurts each enemy it passes (4 + 1.5 × speed), takes 8 when it stops. Hex lets go and drifts home. | — |
| **Charge** | Space + hold LMB | Orb forms 30px in front of her hand, filling 0.5/frame from her hand (full at 24 in ~0.8s). Drawn with the spark → crackle → glow → bloom shader (mode 7). | up to 24 |
| **Fire orb** | release LMB | If ≥ 2: `obj_hex_shot` flies at 15px/frame. On first enemy contact it bursts: 10 + 10/hex damage at center, falling off to half at the edge, radius 40 + 5/hex, shoves enemies, shake. Under 2: melts back into her hand. | max 250 dmg, 160 radius |
| **Palm blast** | tap Space (≤ 10 frames) | Small shot from her hand, 16px/frame, 10 damage, radius 40. | 4 hex |
| **Shot ends** | hit / off screen / 10s | Its hex breaks into parcels at that spot that drift home. | hex returns |
| **Let go of Space** | release | Held thing thrown, unfired orb melts back, all parcels head home. | — |

**Combos that exist today:** basically none. Only one mouse button counts per stance press (whichever was pressed first), so
you can't charge while holding, slam a held thing, or reach while charging. Throw-into-horde is the only interaction between moves.

---

## 4. The visual ingredients: what draws each state

| State | Drawn by | Shader mode | Where |
|---|---|---|---|
| Hand orb (idle → channeling) | `hex_wisp_att` → `hex_orb_draw` | 0 (orb), eased by `hex_hand_f` | obj_player Draw L46 |
| River (parcels out / home) | `hex_field_draw`: every parcel splats a soft blob into a camera-sized surface, then the surface is drawn as hex | 4 (field) | scr_hex_wisp L213 |
| Knot (where reach gathers) | orb whose heart kindles past 45% full (`hex_gR`) | 0 | Draw L49-52 |
| Charge | the spark-to-bloom orb (`_kn` = how full) | 7 | Draw L45 |
| Scoop (holding) | cup of hex under/around the held thing (`hex_wR`), stronger when overcommitted | 5 | Draw L56-65 |
| Rock lit from below | rock sprite redrawn with violet underlight (`hex_lit`) | 6 | obj_env_parent Draw |
| Rock stirring | rock trembles and rises a few px (`hex_gather`) | — | obj_env_parent Step/Draw |
| Shot in flight | a wild orb per shot | 0 | Draw L66-68 |
| Burst | arcane spark particles + shake (not hex-colored, not parcels-first) | — | obj_hex_shot Step |
| HUD | violet bar of hand hex (Hexweaver only) | — | HUD Draw_64 |

**Not drawn by anything:** a held *enemy* is never lit or lifted off the ground (no z), so a held enemy reads as "dragged",
not "lifted". The blast has no look of its own yet (the bible lists it as not built).

---

## 5. What's broken in code (most important first)

### A. The reach doesn't latch onto the thing, it latches onto a point near the cursor (the core bug)
1. **Parcels go to the knot, not the target.** Every reaching parcel steers to `hex_gx/gy` (Step L213, L235-242), a point that
   trails the cursor. The target is only used to decide *when* to lift. So the hex pools in the air near the cursor while the
   enemy walks out from under it.
2. **"Enough gathered" is counted anywhere, not on the target.** The lift fires when `hex_at` (all gathered parcels, wherever
   they are) ≥ cost (L128). With reach cap 14 and enemy cost 14, hovering open ground fills the knot, then sweeping onto any
   enemy lifts it **instantly**: the hex never travelled to it.
3. **The target is re-picked every frame.** No lock. As the cursor or the horde moves, the target flickers between enemies,
   rocks and nothing, and `hex_need` flips between the cost and the reach cap, so the pour starts and stops.
4. **Rocks always beat enemies.** Any rock edge within 64px wins (L117), even if an enemy is right under the cursor.
5. **Only one enemy is considered.** `instance_nearest` (L120): if the nearest is a boss or a toad, nothing lifts, even with a
   valid enemy beside it. And enemies are measured to their origin while rocks are measured to their edge.

### B. A "held" enemy is still fighting you
6. **Its AI keeps running.** It still sets its own `speed` toward her every frame; End Step pulls it back 85% of the way, so it
   jitters and creeps toward her (Step_2 L43-46). Separation pushes it around too.
7. **It still deals contact damage.** Nothing turns off `Collision_obj_player`, so steering a held enemy past her hurts her.
8. **Thrown enemies walk while flying.** Same cause: their own movement runs alongside the throw. No stun when they land.
9. **Throw strength comes from cursor speed of the last frame** (`hex_hvx`), so a release while the mouse is still is a drop.

### C. The hex stance isn't the Hexweaver's, it's everyone's
10. **Every witch has the hex.** The Space stance runs for any witch (Step L71), and Create spawns 6 rocks for any witch.
11. **Every witch lost her E.** The old E call is commented out for all witches (Step L16-21), so the Necromancer's Raise the
    Fallen (and every placeholder E) does nothing right now. The witch DB still says the Hexweaver's E is `scr_curse_wave`.

### D. The two hex systems don't know about each other
12. **The living hex never curses anything.** The curse system (`scr_curse`: ripening, toads, tiers, Toadstone) only runs from
    Q (Polymorph). The parcel hex has no curse hook at all. Not a bug for the slice, but it's the biggest "what is her hex
    *for*" gap: today it lifts and explodes, it doesn't hex.

### E. Smaller code issues
13. The "sand" bug (faint-alpha blob) is still in m20's `hex_field_draw`; the fix only exists in uncommitted m21.
14. `hex_reach` is 4000 (no real range limit) and `hex_charge` / `hex_orb_n` are counters nothing important reads.
15. `max_hex` isn't in `scr_known_stats`. Check whether that list gates stats; if it does, a max-hex item would silently do nothing.
16. Found along the way, not hex: `scr_stat("attack_speeed", 1)` in `player_attack` is misspelled, so attack-speed items do nothing.

---

## 6. Dead weight (the "muddy" part): safe to delete in one cleanup commit
- **The smoke-wisp look:** `hex_wisp_draw`, `hex_wisp_stamp`, the `k` knobs, and two whole shaders (`sh_hex_wisp_flow`,
  `sh_hex_wisp_draw`). It's fed an empty mote list now, so it draws nothing but shot wakes. ~200 lines of GML plus 2 shaders.
- **Shader modes 1-3** in `sh_hex_orb` (old mote flow, hex flame, curve river) and their uniforms (`u_rv`, `u_rv2`, `u_n`,
  `u_motes`, `u_hollow`): ~135 lines.
- **The "old circles" look:** the `!_orb` / `!_wisp` branches in obj_player Draw and obj_hex_shot Draw.
- **Debug keys bound in normal play:** O (switch looks), P (palette), K, L. Pressing O mid-run swaps her magic to placeholder
  circles. Keep J and H if you still use them, behind a debug flag.
- **Stale notes:** `hex-visual-bible.md` "Where things live" points at `hex_flow_draw`, `hex_flow_to` and motes, which no
  longer exist (it's parcels + `hex_field_draw` now).

---

## 7. m21: what to throw away and what to keep
m21 rebuilt holding as a list, gave parcels their own target, and added a slam, all at once, and it played "super backwards".
Revert it, but carry these over by hand (they're small and were good):
- **The sand fix** in `hex_field_draw` (solid blob alpha + texture filter on), the streak-length cap, and the brighter current dots.
- **Tuning:** `hex_grab_r` 80, `hex_reach_cap` 6. These live in Create, so a plain Discard loses them.
- **Facing:** she faces where she's casting while walking another way (one line in `update_facing_sprite`).
- **Shader:** the sparkle tweak in the field and the "snap" flash at the start of a charge.
- Kept in my backup for reference later: the multi-lift structure and the slam. The ideas were right; doing them in one pass wasn't.

---

## 8. What only the game can tell us (clips to take, ~10s each)
Code can't show feel. These are the checks that decide what's "broken in game":
1. **Reach onto a moving enemy** in a crowd: does the hex visibly travel to it and grab *it*, or pool beside it?
2. **Hold an enemy and steer it past her:** jitter? does she take damage?
3. **Throw an enemy into the horde:** does it read as a throw (arc, impact) or a slide?
4. **Lift and throw a rock:** the one path that already works end to end; the reference for how enemy lifts should feel.
5. **Charge and fire** at a group: burst readability.
6. **Reach into open ground, then let go:** does the river read as one body going out and coming home?

---

## 9. Suggested order (one change per pass, one clip each)
1. **Clean base:** revert m21, re-apply the keepers from section 7. Commit.
2. **The hex belongs to the Hexweaver:** gate the stance and the rocks to her, give every other witch her E back. Small, safe.
3. **Fix the latch (A1-A5):** the reach locks onto one target when it starts, parcels flow to *that thing*, the lift counts only
   hex gathered *on it*, and targets are picked by what's nearest the cursor, rock or enemy. This is the heart of the ability.
4. **Make "held" mean held (B6-B9):** a held/thrown enemy stops its own AI and contact damage, is lifted off the ground like a
   rock (z), and is briefly stunned when it lands. Throw strength from the hold's motion, not one frame of mouse.
5. **Combos, one at a time:** multi-lift as a list (no visible change), then overflow spreads to a second target, then the slam
   (LMB while holding). This is where the "chaos magic that adapts" starts.
6. **Charge channeling phase** (the veil forming around the disk).
7. **Cleanup commit** (section 6) + update the visual bible.
8. **Visual pass with clips:** the river as one body, the blast's own look, an enemy's underlight.
Then call hex control done for the Act 1 slice. Parked: curse hook into the living hex (D12), earth rip, Agatha spiral return.
