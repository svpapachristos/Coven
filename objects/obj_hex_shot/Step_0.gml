if (scr_freeze_if_paused()) exit;

x += vx;
y += vy;
life--;
var _end = false;

// it hit an enemy: burst. Full damage to what it hit, less toward the edge of boom_r, and a shove outward
var _e = collision_circle(x, y, 10 * size + 6, obj_enemy_parent, false, true);
if (_e != noone) {
	var _l = ds_list_create();
	collision_circle_list(x, y, boom_r, obj_enemy_parent, false, true, _l, false);
	for (var _i = 0; _i < ds_list_size(_l); _i++) {
		var _o = _l[| _i];
		if (!instance_exists(_o)) continue;
		var _k = (_o == _e) ? 1 : 1 - 0.5 * point_distance(x, y, _o.x, _o.y) / boom_r;
		scr_damage_enemy(_o, round(dmg * _k), make_color_rgb(200, 170, 255));
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

// off the screen, or out of time: it's gone
var _cam = view_camera[0];
var _vx0 = camera_get_view_x(_cam), _vy0 = camera_get_view_y(_cam);
if (x < _vx0 - 32 || y < _vy0 - 32 || x > _vx0 + camera_get_view_width(_cam) + 32 || y > _vy0 + camera_get_view_height(_cam) + 32) _end = true;
if (life <= 0) _end = true;

if (_end) {
	// the hex inside it bursts out from here and flows home to her, bit by bit
	if (!is_undefined(hex_anchor)) {
		hex_anchor_move(hex_anchor, x, y);
		hex_anchor_release(hex_body, hex_anchor, "burst");
		hex_anchor = undefined;
	}
	instance_destroy();
	exit;
}
depth = -y;
