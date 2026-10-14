if (scr_freeze_if_paused()) exit;

// A lobbed ball of hex: arcs over everything to where she aimed, then bursts.
if (is_lob) {
	lob_t++;
	var _p = min(1, lob_t / lob_dur);
	x = lerp(lob_x0, lob_tx, _p);
	y = lerp(lob_y0, lob_ty, _p);
	if (_p >= 1) {
		var _l = ds_list_create();
		collision_circle_list(x, y, boom_r, obj_enemy_parent, false, true, _l, false);
		for (var _i = 0; _i < ds_list_size(_l); _i++) {
			var _o = _l[| _i];
			if (!instance_exists(_o)) continue;
			// full damage at the center, half at the edge, and a shove outward
			var _k = 1 - 0.5 * point_distance(x, y, _o.x, _o.y) / boom_r;
			scr_damage_enemy(_o, round(bolt_dmg * _k), make_color_rgb(200, 170, 255));
			if (instance_exists(_o)) {
				var _a = point_direction(x, y, _o.x, _o.y);
				_o.x += lengthdir_x(24 * _k, _a);
				_o.y += lengthdir_y(24 * _k, _a);
			}
		}
		ds_list_destroy(_l);
		repeat (round(10 + boom_r / 6)) {
			var _a = random(360), _d = random(boom_r);
			part_particles_create(global.ps_sparks, x + lengthdir_x(_d, _a), y + lengthdir_y(_d, _a), global.pt_arcane, 1);
		}
		global.shake = max(global.shake, 2 + boom_r / 40);
		instance_destroy();
		exit;
	}
	depth = -y;
	exit;
}

// A hex shot: flies straight until it hits an enemy or leaves the screen. On a hit it bursts: full damage at the
// center, less toward the edge of boom_r, a shove outward. Either way, the motes inside flow back to her.
if (is_bolt) {
	x += vx;
	y += vy;
	life--;
	var _end = false;
	var _e = collision_circle(x, y, 10 * bolt_size + 6, obj_enemy_parent, false, true);
	if (_e != noone) {
		var _l = ds_list_create();
		collision_circle_list(x, y, boom_r, obj_enemy_parent, false, true, _l, false);
		for (var _i = 0; _i < ds_list_size(_l); _i++) {
			var _o = _l[| _i];
			if (!instance_exists(_o)) continue;
			var _k = (_o == _e) ? 1 : 1 - 0.5 * point_distance(x, y, _o.x, _o.y) / boom_r;
			scr_damage_enemy(_o, round(bolt_dmg * _k), make_color_rgb(200, 170, 255));
			if (instance_exists(_o)) {
				var _a = point_direction(x, y, _o.x, _o.y);
				_o.x += lengthdir_x(20 * _k, _a);
				_o.y += lengthdir_y(20 * _k, _a);
			}
		}
		ds_list_destroy(_l);
		repeat (round(6 + boom_r / 8)) {
			var _a = random(360), _d = random(boom_r);
			part_particles_create(global.ps_sparks, x + lengthdir_x(_d, _a), y + lengthdir_y(_d, _a), global.pt_arcane, 1);
		}
		global.shake = max(global.shake, 1 + boom_r / 50);
		_end = true;
	}
	// off the screen: it's gone
	var _cam = view_camera[0];
	var _vx0 = camera_get_view_x(_cam), _vy0 = camera_get_view_y(_cam);
	if (x < _vx0 - 32 || y < _vy0 - 32 || x > _vx0 + camera_get_view_width(_cam) + 32 || y > _vy0 + camera_get_view_height(_cam) + 32) _end = true;
	if (life <= 0) _end = true;
	if (_end) {
		var _n = mote_n, _ex = x, _ey = y;
		if (_n > 0 && instance_exists(obj_player)) with (obj_player) hex_return(_n, _ex, _ey);
		instance_destroy();
		exit;
	}
	depth = -y;
	exit;
}

x += vx;
y += vy;

// Loose rocks slide to a stop; held rocks are steered by whoever holds them.
if (!grabbed) {
	vx *= 0.94;
	vy *= 0.94;
}

// Speed cap so a wild flick can't send it to orbit.
var _s = point_distance(0, 0, vx, vy);
if (_s > 24) {
	vx *= 24 / _s;
	vy *= 24 / _s;
	_s = 24;
}

// Moving fast enough: it hurts whatever it slams into.
if (hit_cd > 0) hit_cd--;
if (_s > 5 && hit_cd <= 0) {
	var _e = collision_circle(x, y, r + 6, obj_enemy_parent, false, true);
	if (_e != noone) {
		scr_damage_enemy(_e, round(_s * 1.5), make_color_rgb(150, 110, 255));
		if (instance_exists(_e)) {
			_e.x += vx * 0.5; // knock it along the throw
			_e.y += vy * 0.5;
		}
		vx *= 0.6;
		vy *= 0.6;
		hit_cd = 6;
	}
}

depth = -(y + r);
