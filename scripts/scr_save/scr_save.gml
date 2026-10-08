//one save file for everything permanent: essence, unlocks, settings, lifetime stats, most recent loadout
#macro SAVE_FILE "coven_save.json"

function scr_save_defaults() {
	return {
		version: 1,
		essence: 0,
		//saved by name not list position, so reordering the dbs doesnt break the saves
		unlocked: { witch: ["Necromancer"], wand: ["Witches Wand"], familiar: ["Munin", "Salem"] },
		loadout:  { witch: "Necromancer", wand: "Witches Wand", familiar: "Munin" },
		settings: { screen_shake: 1, damage_numbers: 1, master_volume: 1 },
		stats:	  { runs: 0, best_time: 0, total_kills: 0 }
	};
}

function scr_save_load() {
	var _def = scr_save_defaults();
	global.save = _def;
	if (!file_exists(SAVE_FILE)) { scr_save_write(); return; }
	try {
		var _buf = buffer_load(SAVE_FILE);
		var _text = buffer_read(_buf, buffer_string);
		buffer_delete(_buf);
		global.save = scr_save_merge(_def, json_parse(_text));
	} catch (_err) {
		show_debug_message("Save file unreadable, starting fresh: " + string(_err));
		global.save = _def;
	}
}

//keep everything the file has and fill anything the game added since the save
function scr_save_merge(_def, _data) {
	var _keys = variable_struct_get_names(_def);
	for (var i = 0; i < array_length(_keys); i++) {
		var _k = _keys[i];
		if (!struct_exists(_data, _k)) _data[$ _k] = _def[$ _k];
		else if (is_struct(_def[$ _k]) && is_struct(_data[$ _k])) _data[$ _k] = scr_save_merge(_def[$ _k], _data[$ _k]);
	}
	return _data;
}

function scr_save_write() {
	var _text = json_stringify(global.save);
	var _buf = buffer_create(string_byte_length(_text) + 1, buffer_fixed, 1);
	buffer_write(_buf, buffer_string, _text);
	buffer_save(_buf, SAVE_FILE);
	buffer_delete(_buf);
}

//Unlocks ---------------------

function scr_station_key(_step) {
	var _keys = ["witch", "wand", "familiar"];
	return _keys[_step];
}

function scr_is_unlocked(_step, _index) {
	var _db = scr_select_db(_step);
	var _name = _db[_index].name;
	var _list = global.save.unlocked[$ scr_station_key(_step)];
	return scr_array_has(_list, _name);
}
// an entry can set its own cost: field, otherwise it uses the default for its station
function scr_unlock_cost(_step, _index) {
	var _db = scr_select_db(_step);
	var _e = _db[_index];
	if (struct_exists(_e, "cost")) return _e.cost;
	var _defaults = [300, 200, 100];
	return _defaults[_step];
}
// true if it's (now) unlocked, false if you can't afford it
function scr_try_unlock(_step, _index) {
	if (scr_is_unlocked(_step, _index)) return true;
	var _cost = scr_unlock_cost(_step, _index);
	if (global.save.essence < _cost) return false;
	global.save.essence -= _cost;
	var _db = scr_select_db(_step);
	var _e = _db[_index];
	var _list = global.save.unlocked[$ scr_station_key(_step)];
	array_push(_list, _e.name);
	scr_save_write();
	global.toast = { text: "UNLOCKED", sub: _e.name, color: make_color_rgb(200, 150, 255), timer: game_get_speed(gamespeed_fps) * 3 };
	return true;
}

// -----loadout---------
//turns the saved names into list positions, falling back to first unlocked pick

function scr_loadout_from_save() {
	var _l = { witch: 0, wand: 0, familiar: 0 };
	for (var s = 0; s < 3; s++) {
		var _key = scr_station_key(s), _db = scr_select_db(s);
		var _found = -1, _first = -1;
		for (var i = 0; i < array_length(_db); i++) {
			if (!scr_is_unlocked(s, i)) continue;
			if (_first == -1) _first = i;
			if (_db[i].name == global.save.loadout[$ _key]) { _found = i; break; }
		}
		_l[$ _key] = (_found != -1) ? _found : max(_first, 0);
	}
	return _l;
}

function scr_save_loadout() {
	for (var s = 0; s < 3; s++) {
		var _key = scr_station_key(s);
		var _db = scr_select_db(s);
		var _index = global.loadout[$ _key];
		var _entry = _db[_index];
		global.save.loadout[$ _key] = _entry.name;
	}
	scr_save_write();
}

//-----essence----
//a trickle from kills during the run
function scr_essence_on_kill(_enemy) {
	if (_enemy.is_boss)		 global.run_essence += 50;
	else if(_enemy.is_elite) global.run_essence += 10;
	else					 global.run_essence += 0.04; // about 1 essence per 25 kills
}

// what the run is worth at the end on top of the trickle
function scr_essence_payout() {
	var _bonus = floor(global.run_time / 60 * 5); // 5 per minute survived
	if (global.game_state == "VICTORY") _bonus += 50;
	return _bonus;
}

//banks the runs essence once, win or lose
function scr_essence_bank_run() {
	if (global.run_banked) return;
	global.run_banked = true;
	global.run_payout = scr_essence_payout();
	global.run_total = floor(global.run_essence) + global.run_payout;
	global.save.essence += global.run_total;
	global.save.stats.runs++;
	global.save.stats.total_kills += global.kill_count;
	global.save.stats.best_time = max(global.save.stats.best_time, global.run_time);
	scr_save_write();
}





