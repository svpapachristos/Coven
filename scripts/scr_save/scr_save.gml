// save slots for each playthrough, plus one settings file shared by all of them
#macro SAVE_SLOTS 3
#macro SETTINGS_FILE "coven_settings.json"
#macro OLD_SAVE_FILE "coven_save.json" // the single save from before slots existed

function scr_slot_file(_slot) { return "coven_slot_" + string(_slot) + ".json"; }

function scr_save_defaults() {
	return {
		version: 1,
		essence: 0,
		// saved by name, not list position, so reordering a db never scrambles a save
		unlocked: { witch: ["Necromancer"], wand: ["Witches Wand"], familiar: ["Munin", "Salem"] },
		loadout:  { witch: "Necromancer", wand: "Witches Wand", familiar: "Munin" },
		stats:    { runs: 0, best_time: 0, total_kills: 0 }
	};
}


// ---- reading and writing files ----
// read any json file into a struct, or undefined if it's missing or broken
function scr_json_read(_file) {
	if (!file_exists(_file)) return undefined;
	try {
		var _buf  = buffer_load(_file);
		var _text = buffer_read(_buf, buffer_string);
		buffer_delete(_buf);
		return json_parse(_text);
	} catch (_err) {
		show_debug_message("Couldn't read " + _file + ": " + string(_err));
		return undefined;
	}
}

function scr_json_write(_file, _data) {
	var _text = json_stringify(_data);
	var _buf  = buffer_create(string_byte_length(_text) + 1, buffer_fixed, 1);
	buffer_write(_buf, buffer_string, _text);
	buffer_save(_buf, _file);
	buffer_delete(_buf);
}

// keep everything the file has, and fill in anything the game added since that save was made
function scr_save_merge(_def, _data) {
	var _keys = variable_struct_get_names(_def);
	for (var i = 0; i < array_length(_keys); i++) {
		var _k = _keys[i];
		if (!struct_exists(_data, _k)) _data[$ _k] = _def[$ _k];
		else if (is_struct(_def[$ _k]) && is_struct(_data[$ _k])) _data[$ _k] = scr_save_merge(_def[$ _k], _data[$ _k]);
	}
	return _data;
}


// ---- save slots ----
// loads a slot (starting fresh if it's empty) and makes it the active playthrough
function scr_save_load(_slot) {
	global.save_slot = _slot;
	var _def  = scr_save_defaults();
	var _data = scr_json_read(scr_slot_file(_slot));
	if (is_undefined(_data) && _slot == 1) _data = scr_json_read(OLD_SAVE_FILE); // carry the pre-slots save into slot 1
	global.save = is_undefined(_data) ? _def : scr_save_merge(_def, _data);
	scr_save_write();

	// this playthrough's loadout
	global.loadout = scr_loadout_from_save();
	scr_apply_loadout();
	scr_spawn_familiar();
}

function scr_save_write() {
	if (global.save_slot < 1) return; // no slot picked yet, don't write the placeholder
	scr_json_write(scr_slot_file(global.save_slot), global.save);
}

// one line per slot for the slot picker
function scr_slot_labels() {
	var _out = [];
	for (var s = 1; s <= SAVE_SLOTS; s++) {
		var _data = scr_json_read(scr_slot_file(s));
		if (is_undefined(_data) && s == 1) _data = scr_json_read(OLD_SAVE_FILE);
		if (is_undefined(_data)) {
			array_push(_out, "Slot " + string(s) + "   -   Empty");
			continue;
		}
		var _ess  = struct_exists(_data, "essence") ? _data.essence : 0;
		var _runs = 0;
		if (struct_exists(_data, "stats")) {
			var _stats = _data.stats;
			if (struct_exists(_stats, "runs")) _runs = _stats.runs;
		}
		array_push(_out, "Slot " + string(s) + "   -   " + string(_ess) + " essence, " + string(_runs) + " runs");
	}
	array_push(_out, "Back");
	return _out;
}

function scr_slot_delete(_slot) {
	var _file = scr_slot_file(_slot);
	if (file_exists(_file)) file_delete(_file);
	if (_slot == 1 && file_exists(OLD_SAVE_FILE)) file_delete(OLD_SAVE_FILE);
}


// ---- settings, shared by every slot ----
function scr_settings_defaults() {
	return { screen_shake: 1, damage_numbers: 1, master_volume: 1 };
}

function scr_settings_load() {
	var _def  = scr_settings_defaults();
	var _data = scr_json_read(SETTINGS_FILE);
	global.settings = is_undefined(_data) ? _def : scr_save_merge(_def, _data);
	scr_settings_apply();
}

function scr_settings_write() {
	scr_json_write(SETTINGS_FILE, global.settings);
	scr_settings_apply();
}

function scr_settings_apply() {
	audio_master_gain(global.settings.master_volume);
}

// the options menu: each row is a label and the setting it changes. add a row here to add an option
function scr_options_rows() {
	return [
		{ label: "Screen Shake",   key: "screen_shake" },
		{ label: "Damage Numbers", key: "damage_numbers" },
		{ label: "Master Volume",  key: "master_volume" }
	];
}

function scr_options_labels() {
	var _rows = scr_options_rows();
	var _out = [];
	for (var i = 0; i < array_length(_rows); i++) {
		var _row = _rows[i];
		var _key = _row.key;
		array_push(_out, _row.label + ":   " + string(round(global.settings[$ _key] * 100)) + "%");
	}
	array_push(_out, "Back");
	return _out;
}

// nudge a setting by a step, keeping it between 0 and 100%
function scr_setting_step(_key, _step, _wrap) {
	var _v = round((global.settings[$ _key] + _step) * 10) / 10;
	if (_wrap && _v > 1) _v = 0;
	global.settings[$ _key] = clamp(_v, 0, 1);
	scr_settings_write();
}


// ---- unlocks ----
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


// ---- loadout ----
// turns the saved names back into list positions, falling back to the first unlocked pick
function scr_loadout_from_save() {
	var _l = { witch: 0, wand: 0, familiar: 0 };
	for (var s = 0; s < 3; s++) {
		var _key = scr_station_key(s);
		var _db = scr_select_db(s);
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


// ---- essence ----
// a trickle from kills during the run
function scr_essence_on_kill(_enemy) {
	if (_enemy.is_boss)       global.run_essence += 50;
	else if (_enemy.is_elite) global.run_essence += 10;
	else                      global.run_essence += 0.04; // about 1 essence per 25 kills
}

// what the run is worth at the end, on top of the trickle
function scr_essence_payout() {
	var _bonus = floor(global.run_time / 60 * 5); // 5 per minute survived
	if (global.game_state == "VICTORY") _bonus += 50;
	return _bonus;
}

// banks the run's essence once, win or lose
function scr_essence_bank_run() {
	if (global.run_banked) return;
	global.run_banked = true;
	global.run_payout = scr_essence_payout();
	global.run_total  = floor(global.run_essence) + global.run_payout;
	global.save.essence += global.run_total;
	global.save.stats.runs++;
	global.save.stats.total_kills += global.kill_count;
	global.save.stats.best_time = max(global.save.stats.best_time, global.run_time);
	scr_save_write();
}