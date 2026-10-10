if (scr_freeze_if_paused()) exit;

// being unmade: frozen, rising toward its place in her sky, then igniting on its cue
if (unmaking > 0) {
	speed_mult = 0;
	speed = 0;
	if (!instance_exists(obj_unmaking)) { scr_unmake(id); exit; } // the realm closed early: finish at once
	unmaking = clamp(obj_unmaking.t / unmake_at, 0.001, 1);      // 0 at the cast, 1 at its ignition
	if (obj_unmaking.t >= unmake_at) scr_unmake(id);
	exit;
}

var _list = ds_list_create();
var _n = collision_circle_list(x, y, sep_radius, obj_enemy_parent, false, true, _list, object_index == obj_toad);

var _lim = min(_n, 8)
for (var i = 0; i < _lim; i++) {
	var _o = _list[| i];
	var _d = point_distance(x, y, _o.x, _o.y);
	if (_d >= sep_radius) continue; //bbox touched the circle but not too close
	// exactly stacked? picked a random direction so they can split
	var _push = (_d < 0.01) ? irandom(359) : point_direction(_o.x, _o.y, x, y);
	var _amt = min((sep_radius - _d) * sep_strength, 3);
	
	x += lengthdir_x(_amt, _push);
	y += lengthdir_y(_amt, _push);
}
ds_list_destroy(_list);

// the witch is solid: get pushed out to the edge of her instead of standing inside her
body_radius = (bbox_right - bbox_left) * 0.45;
if (instance_exists(obj_player)) {
	var _p   = obj_player;
	var _cx  = (bbox_left + bbox_right) / 2,       _cy  = (bbox_top + bbox_bottom) / 2;
	var _pcx = (_p.bbox_left + _p.bbox_right) / 2, _pcy = (_p.bbox_top + _p.bbox_bottom) / 2;
	var _pd  = point_distance(_cx, _cy, _pcx, _pcy);
	var _min = _p.body_radius + body_radius;
	if (_pd < _min) {
		var _pa = (_pd < 0.01) ? irandom(359) : point_direction(_pcx, _pcy, _cx, _cy);
		x += lengthdir_x(_min - _pd, _pa);
		y += lengthdir_y(_min - _pd, _pa);
	}
}

// thralls are solid too: the army forms a wall as the hord as to go around or through your forces
if (instance_exists(obj_thrall)) {
	var _ecx = (bbox_left + bbox_right) / 2, _ecy = (bbox_top + bbox_bottom) / 2;
	var _tl = ds_list_create();
	var _tn = collision_circle_list(_ecx, _ecy, body_radius * 2 + 4, obj_thrall, false, true, _tl, false);
	var _tlim = min(_tn, 6);
	for (var i = 0; i < _tlim; i++) {
		var _t = _tl[| i];
		if (_t.rise < 1) continue; //still climbing, not a solid object yet
		var _tcx = (_t.bbox_left + _t.bbox_right) / 2, _tcy = (_t.bbox_top + _t.bbox_bottom) / 2;
		var _td = point_distance(_ecx, _ecy, _tcx, _tcy);
		var _tmin = body_radius + _t.body_radius;
		if (_td >= _tmin) continue;
		var _ta = (_td < 0.01) ? irandom(359) : point_direction(_tcx, _tcy, _ecx, _ecy);
		var _amt = (_tmin - _td) * 0.8; // enemies give more than thralls do, so your wall will push through an enemy block
		x += lengthdir_x(_amt, _ta);
		y += lengthdir_y(_amt, _ta);
	}
	ds_list_destroy(_tl);
}



// statuses
if (burn_timer > 0) {
	burn_timer--;
	burn_tick--;
	if (burn_tick <= 0) {
		burn_tick = game_get_speed(gamespeed_fps) / 2; // twice a second
		scr_damage_enemy(id, burn_dps / 2, make_color_rgb(255, 140, 40), irandom(2) == 0);
		if (hp <= 0) exit; //if the enemy gets a bit crispy (the burn killing the enemy)
	}
} else {
	burn_dps = 0;
}

if (chill_timer > 0) {
	chill_timer--;
	speed_mult = 1 - chill_slow;
} else {
	speed_mult = 1;
}

if (stun_timer > 0) { stun_timer--; speed_mult = 0; }

//hexweavers hex: the curse ripens on its own until the enemy is fully hexed
if (hex > 0 && hex < 1) hex = min(1, hex + 1 / (game_get_speed(gamespeed_fps) * scr_hex_ripen_time()));
if (hex >= 1 && scr_hex_can_toad(id)) { scr_hex_toadify(id); exit; }

// knockback slides the enemy and fades out
x += knock_x; y += knock_y;
knock_x *= 0.8; knock_y *= 0.8;

//tints the enemy ember orange or icy blue if burned or chilled
image_blend = (burn_timer > 0) ? make_color_rgb(255, 170, 110) : ((chill_timer > 0) ? make_colour_rgb(150, 220, 255) : c_white);

//tints the enemy hex violet when hexed
if (hex > 0) image_blend = merge_color(image_blend, HEX_VIOLET, 0.35 + 0.5 * hex);
