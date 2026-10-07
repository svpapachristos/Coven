if (scr_freeze_if_paused()) exit;


var _list = ds_list_create();
var _n = collision_circle_list(x, y, sep_radius, obj_enemy_parent, false, true, _list, false);

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

// knockback slides the enemy and fades out
x += knock_x; y += knock_y;
knock_x *= 0.8; knock_y *= 0.8;

//tints the enemy ember orange or icy blue if burned or chilled
image_blend = (burn_timer > 0) ? make_color_rgb(255, 170, 110) : ((chill_timer > 0) ? make_colour_rgb(150, 220, 255) : c_white);