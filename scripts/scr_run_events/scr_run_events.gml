function scr_spawn_elite(_obj, _hp_mult, _size, _drop_type) {
	var _p = scr_get_spawn_point();
	if (is_undefined(_p)) return noone;
	var _e = instance_create_layer(_p[0], _p[1], "Instances", _obj);
	_e.max_hp *= _hp_mult;
	_e.hp = _e.max_hp;
	_e.image_xscale = _size;
	_e.image_yscale = _size;
	_e.sep_radius *= _size;
	_e.contact_damage *= 1.5;
	_e.soul_value *= 15;
	_e.is_elite = true;
	_e.elite_drop = _drop_type;
	return _e;
}

/// Returns true once the event has actually happened (so a failed spawn gets retried)
function scr_run_event(_ev) {
	switch (_ev.kind) {
		case "elite":
			return scr_spawn_elite(_ev.obj, _ev.hp_mult, _ev.size, _ev.drop) != noone;
		case "boss":
			var _p = scr_get_spawn_point();
			if (is_undefined(_p)) return false;
			instance_create_layer(_p[0], _p[1], "Instances", obj_boss_act1);
			global.toast = { text: "THE SHROOM-MOTHER", sub: (global.corruption >= 50) ? "She can taste what you are becoming..." : "Something large is coming.", color: c_red, timer: game_get_speed(gamespeed_fps) * 3 };
			return true;
	}
	return true;
}