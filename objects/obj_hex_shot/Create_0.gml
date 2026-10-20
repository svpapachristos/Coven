// A shot of the Hexweaver's hex: the charged orb (hold left click in her stance) and the palm blast (tap E).
// It flies straight until it hits an enemy or leaves the screen, bursts, and the hex riding in it flows back to her.
// obj_player sets these right after creating it.
vx = 0;               // speed, pixels per frame
vy = 0;
dmg = 20;             // damage at the center of the burst
boom_r = 40;          // burst radius
size = 1;             // how big it draws (a bigger knot of hex is a bigger shot)
hex_body = undefined; // whose hex this is (a hex body, scr_hex_core) ...
hex_anchor = undefined; // ...and the anchor carrying it: its pool is the hex riding in this shot (it bursts home when the shot ends)
life = 600;           // safety: a shot that somehow never leaves the screen ends after this many frames
