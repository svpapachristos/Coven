// A shot of the Hexweaver's hex: the charged orb (hold left click in her stance) and the palm blast (tap E).
// It flies straight until it hits an enemy or leaves the screen, bursts, and the motes riding in it flow back to her.
// obj_player sets these right after creating it.
vx = 0;               // speed, pixels per frame
vy = 0;
dmg = 20;             // damage at the center of the burst
boom_r = 40;          // burst radius
size = 1;             // how big it draws (a bigger knot of hex is a bigger shot)
mote_n = 0;           // how many of her motes ride in this shot
life = 600;           // safety: a shot that somehow never leaves the screen ends after this many frames
