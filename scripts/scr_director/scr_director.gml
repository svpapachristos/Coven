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
	return instance_create_layer(_x, _y, "Instances", _obj);
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
		