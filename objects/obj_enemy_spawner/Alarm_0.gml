if (global.game_state != "PLAYING") {
	alarm[0] = 1;
	exit;
}

alarm[0] = game_get_speed(gamespeed_fps) * 2; // Resets the spawner to a default, preventing some possible future bugs/crashes

//overall enemy cap
if (instance_number(obj_enemy_parent) >= max_enemy_count) exit;

//building a pool of enemies, unlocked based on length of the run, each with their own individual cap

var _pool = [];
for (var i = 0; i < array_length(spawn_table); i++) {
	var _e = spawn_table[i];
	var _time_ok = global.run_time >= _e.start_time && global.run_time < _e.end_time;
	var _under_cap = instance_number(_e.obj) < _e.cap;
	if (_time_ok && _under_cap) array_push(_pool, _e.obj);
}

//spawns random, eligible enemies from the pool,
if (array_length(_pool) > 0) {
	var _p = scr_get_spawn_point();
	if (!is_undefined(_p)) {
	instance_create_layer(_p[0], _p[1], "Instances", _pool[irandom(array_length(_pool) -1)]);
	}
}

