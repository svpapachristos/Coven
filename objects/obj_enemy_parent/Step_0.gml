if (scr_freeze_if_paused()) exit;

// keep your distance from the crowd: check only the crowd grid's buckets around you (obj_game_controller builds it each frame),
// at most 8 pushes and 24 looks, so a packed horde costs the same as a loose one
// (each enemy keeps its distance every other frame, half on even frames and half on odd, with double the push: half the cost,
// and at 60 frames a second the crowd still spreads just as smoothly)
if (variable_global_exists("sep_head") && variable_global_exists("sep_frame") && ((global.sep_frame + real(id)) mod 2 == 0)) {
	var _head = global.sep_head;
	var _gx = floor(x / SEP_CELL), _gy = floor(y / SEP_CELL);
	var _pushes = 0, _looks = 0;
	for (var _cx = _gx - 1; _cx <= _gx + 1 && _pushes < 6 && _looks < 16; _cx++) {
		for (var _cy = _gy - 1; _cy <= _gy + 1 && _pushes < 6 && _looks < 16; _cy++) {
			var _o = _head[((_cx * 73856093) ^ (_cy * 19349663)) & (SEP_BUCKETS - 1)];
			while (_o != noone && _pushes < 6 && _looks < 16) {
				if (_o != id && instance_exists(_o)) {
					_looks++;
					var _dx = x - _o.x, _dy = y - _o.y;
					if (abs(_dx) < sep_radius && abs(_dy) < sep_radius) {
						var _d = sqrt(_dx * _dx + _dy * _dy);
						if (_d < sep_radius) {
							// exactly stacked? pick a random direction so they can split
							var _push = (_d < 0.01) ? irandom(359) : point_direction(_o.x, _o.y, x, y);
							var _amt = min((sep_radius - _d) * sep_strength * 2, 6);
							x += lengthdir_x(_amt, _push);
							y += lengthdir_y(_amt, _push);
							_pushes++;
						}
					}
				}
				_o = instance_exists(_o) ? _o.sep_next : noone;
			}
		}
	}
}

// the witch is solid: get pushed out to the edge of her instead of standing inside her
body_radius = (bbox_right - bbox_left) * 0.45;
if (instance_exists(obj_player) && abs(x - obj_player.x) < 96 && abs(y - obj_player.y) < 96) {   // (only worth the math when it's close)
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

//hexweavers curse: the curse ripens on its own until the enemy is fully hexed
if (curse > 0 && curse < 1) curse = min(1, curse + 1 / (game_get_speed(gamespeed_fps) * scr_curse_ripen_time()));
if (curse >= 1 && scr_curse_can_toad(id)) { scr_curse_toadify(id); exit; }

// knockback slides the enemy and fades out
x += knock_x; y += knock_y;
knock_x *= 0.8; knock_y *= 0.8;

//tints the enemy ember orange or icy blue if burned or chilled
image_blend = (burn_timer > 0) ? make_color_rgb(255, 170, 110) : ((chill_timer > 0) ? make_color_rgb(150, 220, 255) : c_white);

//tints the enemy curse violet when hexed
if (curse > 0) image_blend = merge_color(image_blend, CURSE_VIOLET, 0.35 + 0.5 * curse);
