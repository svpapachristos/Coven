if (scr_freeze_if_paused()) exit;
if (!instance_exists(obj_player)) exit;

// climbing out of the grave: a slow, deliberate claw-out normally, but mid-frenzy the dead burst straight up
if (rise < 1) { rise = min(1, rise + ((global.necro_frenzy > 0) ? 0.12 : 0.018)); exit; }

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
	var _gap = body_radius + target.body_radius;
	_gx = target.x + lengthdir_x(_gap, _side);
	_gy = target.y + lengthdir_y(_gap, _side);
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
body_radius = (bbox_right - bbox_left) * 0.45;
var _cx = (bbox_left + bbox_right) / 2, _cy = (bbox_top + bbox_bottom) / 2;
var _list = ds_list_create();
var _n = collision_circle_list(_cx, _cy, body_radius * 2 + 4, obj_thrall, false, true, _list, false);
var _lim = min(_n, 8);
for (var i = 0; i < _lim; i++) {
	var _o = _list[| i];
	var _ox = (_o.bbox_left + _o.bbox_right) / 2, _oy = (_o.bbox_top + _o.bbox_bottom) / 2;
	var _od = point_distance(_cx, _cy, _ox, _oy);
	var _min = body_radius + _o.body_radius;
	if (_od >= _min) continue;
	var _push = (_od < 0.01) ? irandom(359) : point_direction(_ox, _oy, _cx, _cy);
	var _amt = (_min - _od) * 0.5; // each takes half the radius so they bounce off each other
	x += lengthdir_x(_amt, _push);
	y += lengthdir_y(_amt, _push);
}
ds_list_destroy(_list);

// make way for your queen! the witch should be able to walk right through her horde instead of floating ontop of them
	var _pcx = (_p.bbox_left + _p.bbox_right) / 2, _pcy = (_p.bbox_top + _p.bbox_bottom) / 2;
	var _mcx = (bbox_left + bbox_right) / 2,	   _mcy = (bbox_top + bbox_bottom) / 2;
	var _pd = point_distance(_mcx, _mcy, _pcx, _pcy);
	var _pmin = _p.body_radius + body_radius + 10;
	if (_pd < _pmin) {
		var _pa = (_pd < 0.01) ? irandom(359) : point_direction(_pcx, _pcy, _mcx, _mcy);
		var _amt = (_pmin - _pd) * 0.6;
		x += lengthdir_x(_amt, _pa);
		y += lengthdir_y(_amt, _pa);
}



// bite! the target bites back based on how dangerous it is
hit_cd--;
var _tcx = instance_exists(target) ? (target.bbox_left + target.bbox_right) / 2 : 0;
var _tcy = instance_exists(target) ? (target.bbox_top + target.bbox_bottom) / 2 : 0;
if (instance_exists(target) && hit_cd <= 0
	&& point_distance((bbox_left + bbox_right) / 2, (bbox_top + bbox_bottom) / 2, _tcx, _tcy) <= body_radius + target.body_radius + 8) {
	hit_cd = game_get_speed(gamespeed_fps) * (_frenzy ? 0.3 : 0.5);
	var _dmg  = scr_stat("thrall_damage", 12 + 2 * global.level) * (_frenzy ? 2 : 1);
	//every thrall should only be able to fight for a limited time so you arent just summoning dudes to play the game for you
	// equal to the share of the enemies health it took, scaled by how dangerous the enemy is
	var _fights = scr_stat("thrall_fights", 1);
	var _danger = clamp(target.contact_damage / 20, 0.5, 2) * sqrt(target.max_hp / 200);
	var _taken = min(_dmg, target.hp) / target.max_hp;
	hp -= max_hp * (_taken / _fights) * _danger;
	
	// every number shows with a small army, fewer as it grows so hundreds of thralls don't flood the screen
	var _show = random(1) < clamp(30 / instance_number(obj_thrall), 0.1, 1);
	scr_damage_enemy(target, _dmg, make_color_rgb(170, 140, 255), _show);
}

if (hp <= 0) {
	part_particles_create(global.ps_sparks, x, y, global.pt_aura, 4);
	instance_destroy();
}
depth = -bbox_bottom; // no one will stand on each other anymore

