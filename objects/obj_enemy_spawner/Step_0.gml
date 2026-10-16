if (global.game_state != "PLAYING") exit;
if (event_index < array_length(run_events) && global.run_time >= run_events[event_index].t) {
	if (scr_run_event(run_events[event_index])) event_index++;
}

director_timer--;
if (director_timer > 0) exit;
director_timer = 15; // about 4 times a second 

var _goal = min(scr_director_target(global.run_time), max_enemy_count);
// ENDLESS (edit49): the horde keeps growing past the act's peak, +50% every 5 minutes, up to the cap, and an elite every 2 minutes
if (global.endless) {
	var _et = global.run_time - global.endless_t0;
	_goal = min(scr_director_target(99999) * (1 + _et / 600), max_enemy_count);
	if (!variable_instance_exists(id, "endless_elite")) endless_elite = 60;
	if (_et >= endless_elite) {
		endless_elite += 120;
		scr_spawn_elite(obj_enemy_zombie, 20 * (1 + _et / 180), 2.5, "");
	}
}
if (instance_exists(obj_boss_act1)) _goal *= 0.4;
var _deficit = _goal - instance_number(obj_enemy_parent);
if (_deficit < 1) exit;

var _entry = scr_pick_enemy(spawn_table, global.run_time);
if (is_undefined(_entry)) exit;
var _pack = scr_pick_pack(pack_types, global.run_time, _deficit);
if (is_undefined(_pack)) exit;

var _n = min(irandom_range(_pack.min, _pack.max), _deficit, _entry.cap - instance_number(_entry.obj));
if (_n >= 1) _pack.fn(_entry.obj, _n);
