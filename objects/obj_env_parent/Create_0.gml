// The parent of everything that lives in the world: rocks now, and later trees, tombstones, grass, barrels...
// A child calls event_inherited() at the top of its Create, then sets its own numbers below. It gets sliding,
// being lifted by magic, weight, falling and landing, hitting enemies, a shadow and depth sorting for free.

// ---- what it is (children set these) ----
material = "none";    // what it's made of, for the substance rules later (fire burns wood, frost cracks stone...)
r = 10;               // its footprint: a circle this many pixels out from its middle (hits, grabbing, the shadow)
movable = true;       // false for things rooted in the ground (a tree): it never slides or lifts
liftable = true;      // whether a witch's magic can pick it up
weight = 1;           // 1 = a rock. Heavier things cost more hex to lift, swing slower, and hit harder

// ---- how it moves ----
vx = 0;               // sliding speed along the ground
vy = 0;
z = 0;                // how high it is off the ground (0 = resting on it). It's drawn this far up from its shadow
vz = 0;               // how fast it's rising (+) or falling (-)
grabbed = false;      // true while a witch's magic is holding it
hit_cd = 0;           // frames before it can hit an enemy again

// ---- tuning (shared by every child unless it changes them) ----
env_hold_z = 14;      // how high magic lifts it while held
env_gravity = 0.55;   // how fast it falls once let go
env_friction = 0.88;  // how much sliding speed it keeps each frame on the ground (lower = stops sooner)
env_air_drag = 0.99;  // ...and while it's in the air
env_max_speed = 24;   // so a wild flick can't send it to orbit

// it landed hard (_impact = how fast it was falling): dust, a little shake, and a short bounce
env_land = function(_impact) {
	var _n = round(3 + _impact * 1.5 * weight);
	repeat (_n) {
		part_particles_create(global.ps_sparks, x + random_range(-r, r), y + random_range(-2, 4), global.pt_dust, 1);
	}
	global.shake = max(global.shake, min(4, _impact * 0.25 * weight));
}

depth = -(y + r);
