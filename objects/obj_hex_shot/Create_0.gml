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
// NEEDLES (her evolved left click in overflow): small homing shards. 0 / noone for every other shot
needle = false;       // drawn as a needle of hex light instead of a ball of her magic (the orb shader draws only a few at a time)
homing = 0;           // how hard it turns toward its target each frame (0..1; 0 = flies straight)
seek_r = 0;           // how far it looks for an enemy to home in on (pixels)
target = noone;       // the enemy it's homing in on
shake_k = 1;          // how much its burst shakes the screen (x the usual; needles are 0: a spray would rattle the camera)
// (a needle's look: one see-through diamond along its flight, tip _f ahead of it, tail _t behind, half-width _w at its
// widest point (_mx, _my). Draw layers several of these, dark to bright)
needle_shard = function(_ux, _uy, _nx, _ny, _mx, _my, _f, _t, _w) {
	draw_triangle(x + _ux * _f, y + _uy * _f, _mx + _nx * _w, _my + _ny * _w, _mx - _nx * _w, _my - _ny * _w, false);
	draw_triangle(x - _ux * _t, y - _uy * _t, _mx + _nx * _w, _my + _ny * _w, _mx - _nx * _w, _my - _ny * _w, false);
}
