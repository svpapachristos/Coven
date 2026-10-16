// How many enemies the director wants alive at a given run time (seconds)
// Keyframes: [time, target]. Early is tense, mid ramps, last stretch is the peak
function scr_director_target(_t){
	static _keys = [[0, 12], [120, 30], [360, 90], [600, 260], [780, 500], [900, 650]];
	for (var i = 1; i < array_length(_keys); i++) {
		if (_t <= _keys[i][0]) {
			var _a = _keys[i - 1], _b = _keys[i];
			return lerp(_a[1], _b[1], (_t - _a[0]) / (_b[0] - _a[0]));
		}
	}
	return _keys[array_length(_keys) - 1][1];
}

/// Picks an enemy entry from spawn table that's in its time window and under its cap
function scr_pick_enemy(_table, _t) {
	var _pool = [];
	for (var i = 0; i < array_length(_table); i++) {
		var _e = _table[i];
		if (_t >= _e.start_time && _t < _e.end_time && instance_number(_e.obj) < _e.cap) array_push(_pool, _e);
	}
	if (array_length(_pool) == 0) return undefined;
	return _pool[irandom(array_length(_pool) - 1)];
}

// Picks a formation by weight, among the ones unlocked by the given point in the run, that fit the spawn budget
function scr_pick_pack(_types, _t, _deficit) {
	var _pool = [], _total = 0;
	for (var i = 0; i < array_length(_types); i++) {
		var _p = _types[i];
		if (_t >= _p.min_time && _deficit >= _p.min) { array_push(_pool, _p); _total += _p.weight; }
	}
	if (array_length(_pool) == 0) return undefined;
	var _r = random(_total);
	for (var i = 0; i < array_length(_pool); i++) {
		_r -= _pool[i].weight;
		if (_r <= 0) return _pool[i];
	}
	return _pool[array_length(_pool) - 1];
}

function scr_spawn_enemy(_obj, _x, _y) {
	if (_x < 0 || _x > room_width || _y < 0 || _y > room_height) return noone;
	var _i = instance_create_layer(_x, _y, "Instances", _obj);
	if (global.endless) with (_i) { max_hp *= 1 + (global.run_time - global.endless_t0) / 180; hp = max_hp; }   // ENDLESS (edit49): +100% health every 3 minutes
	return _i;
}

//Distance from the player to spawn just past the camera view
function scr_spawn_radius() {
	var _cam = view_camera [0];
	return point_distance(0, 0, camera_get_view_width(_cam), camera_get_view_height(_cam)) / 2 + 80;
}

// a single enemy just to have some early game spawning still look nice
function scr_pack_scatter(_obj, _n) {
	if (!instance_exists(obj_player)) return;
	repeat(_n) {
		var _a = random(360);
		var _r = scr_spawn_radius() + random(150); // staggered distances
		scr_spawn_enemy(_obj, obj_player.x + lengthdir_x(_r, _a), obj_player.y + lengthdir_y(_r, _a));
	}
}

// a clump of enemies spawning from one direction
function scr_pack_blob(_obj, _n, _angle = undefined) {
	if (!instance_exists(obj_player)) return;
	if (is_undefined(_angle)) _angle = random(360);
	var _r = scr_spawn_radius();
	var _cx = obj_player.x + lengthdir_x(_r, _angle);
	var _cy = obj_player.y + lengthdir_y(_r, _angle);
	var _spread = 32 * sqrt(_n);
	repeat(_n) {
		var _a = random(360), _d = sqrt(random(1)) * _spread;
		scr_spawn_enemy(_obj, _cx + lengthdir_x(_d, _a), _cy + lengthdir_y(_d, _a));
	}
}

// A wall of enemies sweeping in from one side
function scr_pack_line(_obj, _n) {
	if (!instance_exists(obj_player)) return;
	var _a = random(360), _r = scr_spawn_radius();
	var _cx = obj_player.x + lengthdir_x(_r, _a);
	var _cy = obj_player.y + lengthdir_y(_r, _a);
	for (var i = 0; i < _n; i++) {
		var _o = (1 - (_n - 1) / 2) * 56;
		scr_spawn_enemy(_obj, _cx + lengthdir_x(_o, _a + 90), _cy + lengthdir_y(_o, _a + 90));
	}
}

// clumps from opposite sides
function scr_pack_pincer(_obj, _n) {
	var _a = random(360);
	scr_pack_blob(_obj, ceil(_n / 2), _a);
	scr_pack_blob(_obj, floor(_n / 2), _a + 100);
}

// a ring that closes in on the player from every direction
function scr_pack_ring(_obj, _n) {
	if (!instance_exists(obj_player)) return;
	var _r = scr_spawn_radius(), _off = random(360);
	for (var i = 0; i < _n; i++) {
		var _a = _off + i * 360 / _n;
		scr_spawn_enemy(_obj, obj_player.x + lengthdir_x(_r, _a), obj_player.y + lengthdir_y(_r, _a));
	}
}
		
		
// makes recolored copies of a sprite by turning every pixel's hue (saturation and brightness stay, so the shading is identical).
// done once at startup. each copy is a real sprite, so everything that draws or reads it (its own draw and later effects,
// its dust colors) just works. _from: the sprite's own hue now (0-255). _hues: the hues to recolor it to
function scr_make_hue_variants(_spr, _from, _hues) {
	var _out = [];
	var _w  = sprite_get_width(_spr), _h = sprite_get_height(_spr), _nf = sprite_get_number(_spr);
	var _xo = sprite_get_xoffset(_spr), _yo = sprite_get_yoffset(_spr);
	var _surf = surface_create(_w, _h);
	var _buf  = buffer_create(_w * _h * 4, buffer_fixed, 1);
	for (var v = 0; v < array_length(_hues); v++) {
		var _shift = _hues[v] - _from;
		var _new = -1;
		for (var f = 0; f < _nf; f++) {
			// copy the frame exactly (blending off, so see-through edges come across untouched)
			surface_set_target(_surf);
			draw_clear_alpha(c_black, 0);
			gpu_set_blendenable(false);
			draw_sprite_ext(_spr, f, _xo, _yo, 1, 1, 0, c_white, 1);
			gpu_set_blendenable(true);
			surface_reset_target();
			buffer_get_surface(_buf, _surf, 0);
			// turn each solid pixel's hue (a surface stores each pixel as blue, green, red, alpha)
			for (var i = 0; i < _w * _h; i++) {
				var _o = i * 4;
				if (buffer_peek(_buf, _o + 3, buffer_u8) == 0) continue;
				var _c  = make_color_rgb(buffer_peek(_buf, _o + 2, buffer_u8), buffer_peek(_buf, _o + 1, buffer_u8), buffer_peek(_buf, _o, buffer_u8));
				var _nc = make_color_hsv((color_get_hue(_c) + _shift + 256) mod 256, color_get_saturation(_c), color_get_value(_c));
				buffer_poke(_buf, _o,     buffer_u8, color_get_blue(_nc));
				buffer_poke(_buf, _o + 1, buffer_u8, color_get_green(_nc));
				buffer_poke(_buf, _o + 2, buffer_u8, color_get_red(_nc));
			}
			buffer_set_surface(_buf, _surf, 0);
			if (f == 0) _new = sprite_create_from_surface(_surf, 0, 0, _w, _h, false, false, _xo, _yo);
			else sprite_add_from_surface(_new, _surf, 0, 0, _w, _h, false, false);
		}
		sprite_set_speed(_new, sprite_get_speed(_spr), sprite_get_speed_type(_spr));   // animates like the original
		array_push(_out, _new);
	}
	surface_free(_surf);
	buffer_delete(_buf);
	return _out;
}		
