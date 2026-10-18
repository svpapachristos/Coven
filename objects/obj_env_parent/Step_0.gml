if (scr_freeze_if_paused()) exit;
if (!movable) exit;

x += vx;
y += vy;

// height: magic lifts what it holds off the ground; let go, it falls, lands with a thud and a small bounce
if (grabbed) {
	z = lerp(z, env_hold_z, 0.2);
	vz = 0;
} else if (hex_gather > 0.02 && z <= 4 && vz <= 0) {
	// hex is gathering under it: it stirs and starts to rise a little, before the lift takes hold
	z = lerp(z, 4 * hex_gather, 0.15);
	vz = 0;
} else if (z > 0 || vz > 0) {
	vz -= env_gravity;
	z += vz;
	if (z <= 0) {
		z = 0;
		if (vz < -2) env_land(-vz);
		vz = (vz < -4) ? -vz * 0.3 : 0;   // a hard landing bounces a little; a soft one just settles
	}
}

hex_gather *= 0.85;   // the witch tops this up every frame she's gathering; otherwise it settles back down

// sliding: it keeps most of its speed in the air and drags to a stop on the ground. While held, the witch steers it
if (!grabbed) {
	var _f = (z > 0) ? env_air_drag : env_friction;
	vx *= _f;
	vy *= _f;
}
var _s = point_distance(0, 0, vx, vy);
if (_s > env_max_speed) {
	vx *= env_max_speed / _s;
	vy *= env_max_speed / _s;
	_s = env_max_speed;
}

// moving fast and low enough: it hurts whatever it slams into. Heavier things hit harder
if (hit_cd > 0) hit_cd--;
if (_s > 5 && hit_cd <= 0 && z < 24) {
	var _e = collision_circle(x, y, r + 6, obj_enemy_parent, false, true);
	if (_e != noone) {
		scr_damage_enemy(_e, round(_s * 1.5 * weight), make_color_rgb(150, 110, 255));
		if (instance_exists(_e)) {
			_e.x += vx * 0.5 * weight;   // knocked along the throw
			_e.y += vy * 0.5 * weight;
		}
		vx *= 0.6;
		vy *= 0.6;
		hit_cd = 6;
		global.shake = max(global.shake, 1 + weight);
		repeat (4) part_particles_create(global.ps_sparks, x + random_range(-r, r), y - z + random_range(-r, r), global.pt_dust, 1);
	}
}

depth = -(y + r);
