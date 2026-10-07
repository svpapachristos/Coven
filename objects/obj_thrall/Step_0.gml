if (scr_freeze_if_paused()) exit;
if (!instance_exists(obj_player)) exit;

// climbing out of the grave
if (rise < 1) { rise = min(1, rise + 0.07); exit; }

var _p = obj_player;
var _frenzy = (global.necro_frenzy > 0);
var _spd = scr_stat("thrall_speed", 4.5) * (_frenzy ? 1.6 : 1);

// fell way behind? catch back up to the witch
if (point_distance(x, y, _p.x, _p.y) > 1200) {
	x = _p.x + random_range(-80, 80);
	y = _p.y + random_range(-80, 80);
}

// target died? think again right away instead of standing around
if (target != noone && !instance_exists(target)) { target = noone; retarget = 0; }

retarget--;
if (retarget <= 0) {
	retarget = 20;
	pick_target();
}

var _gx, _gy;
if (instance_exists(target)) {
	// take a spot on the edge of the target, on our own side of it, so a swarm surrounds instead of stacking
	var _side = point_direction(target.x, target.y, x, y);
	_gx = target.x + lengthdir_x(reach - 6, _side);
	_gy = target.y + lengthdir_y(reach - 6, _side);
} else {
	// nothing to bite: swirl around the witch like a cloud of the dead
	var _a = orbit + current_time / 40;
	_gx = _p.x + lengthdir_x(orbit_r, _a);
	_gy = _p.y + lengthdir_y(orbit_r, _a);
}

var _d = point_distance(x, y, _gx, _gy);
if (_d > 1) {
	var _dir = point_direction(x, y, _gx, _gy);
	x += lengthdir_x(min(_spd, _d), _dir);
	y += lengthdir_y(min(_spd, _d), _dir);
	if (abs(lengthdir_x(1, _dir)) > 0.2) flip = sign(lengthdir_x(1, _dir));
}

// personal space: shove apart from other thralls so the army spreads into a crowd
var _list = ds_list_create();
var _n = collision_circle_list(x, y, sep_radius, obj_thrall, false, true, _list, false);
var _lim = min(_n, 6);
for (var i = 0; i < _lim; i++) {
	var _o = _list[| i];
	var _od = point_distance(x, y, _o.x, _o.y);
	if (_od >= sep_radius) continue;
	var _push = (_od < 0.01) ? irandom(359) : point_direction(_o.x, _o.y, x, y);
	var _amt = min((sep_radius - _od) * 0.5, 2.5);
	x += lengthdir_x(_amt, _push);
	y += lengthdir_y(_amt, _push);
}
ds_list_destroy(_list);

// bite! the target bites back based on how dangerous it is
hit_cd--;
if (instance_exists(target) && point_distance(x, y, target.x, target.y) <= reach + 4 && hit_cd <= 0) {
	hit_cd = game_get_speed(gamespeed_fps) * (_frenzy ? 0.3 : 0.5);
	var _dmg  = scr_stat("thrall_damage", 12 + 2 * global.level) * (_frenzy ? 2 : 1);
	var _bite = target.contact_damage * 0.15; // read it before the hit, the target might die
	// every number shows with a small army, fewer as it grows so hundreds of thralls don't flood the screen
	var _show = random(1) < clamp(30 / instance_number(obj_thrall), 0.1, 1);
	scr_damage_enemy(target, _dmg, make_color_rgb(170, 140, 255), _show);
	hp -= _bite;
}

if (hp <= 0) {
	part_particles_create(global.ps_sparks, x, y, global.pt_aura, 4);
	instance_destroy();
}