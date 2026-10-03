//hide the hude while game is paused (can remove if thats how we feel)
if (global.game_state == "MENU") exit;

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
draw_set_font(-1);

//HP/Mana Bars, Top left for now

if (instance_exists(obj_player)) {
	var _p = obj_player;
	scr_draw_bar(16, 16, 200, 16, _p.hp / _p.max_hp, c_red,
		string(ceil(_p.hp)) + " / " + string(_p.max_hp));
	var _inf = (scr_stat("infinite_mana", 0) > 0);
	var _mana_col = _inf ? merge_color(c_aqua, c_fuchsia, 0.5 + 0.5 * sin(current_time / 300)) : c_aqua;
	scr_draw_bar(16, 40, 200, 10, _inf ? 1 : _p.mana / _p.max_mana, _mana_col,
		_inf ? "" : string(floor(_p.mana)) + " / " + string(_p.max_mana));
if (_inf) scr_draw_infinity(236, 45, 10, _mana_col);

if (!is_undefined(_p.witch)) {
	var _cd_max = max(1, game_get_speed(gamespeed_fps) * scr_stat("ability_cooldown", _p.witch.ability.cooldown));
	scr_draw_bar(16, 60, 200, 8, 1 - _p.ability_cd / _cd_max, c_lime,
		_p.witch.ability.name + ((_p.ability_cd <= 0) ? " [E]" : ""));

	var _ready = (_p.ultimate_charge >= _p.ultimate_charge_max);
	var _ult_col = _ready ? merge_color(c_fuchsia, c_white, 0.5 + 0.5 * sin(current_time / 120)) : c_purple;
	scr_draw_bar(16, 80, 200, 8, _p.ultimate_charge / _p.ultimate_charge_max, _ult_col,
		_p.witch.ultimate.name + (_ready ? " [Q]" : ""));
}
}


//Run info, Top Right for now
var _t = floor(global.run_time);
var _time = string(_t div 60) + ":" + ((_t mod 60 < 10) ? "0" : "") + string(_t mod 60);
draw_set_halign(fa_right);
draw_text(_gw - 16, 16, _time);
draw_text(_gw - 16, 34, "Kills: " + string(global.kill_count));
draw_set_halign(fa_left);

//ITEMMSS, Bottom left for now
var _counts = scr_item_counts();
var _ids = variable_struct_get_names(_counts);
for (var i = 0; i < array_length(_ids); i++) {
	var _it = global.item_db[$ _ids[i]];
	draw_set_color(scr_rarity_color(_it.rarity));
	draw_text(16, _gh - 24 - i * 16,
		_it.name + ((_counts[$ _ids[i]] > 1) ? " x" + string(_counts[$ _ids[i]]) : ""));
}
draw_set_color(c_white);

//debug (f1)
if (global.debug_hud) {
	draw_text(16, 78, "Enemies Alive: " + string(instance_number(obj_enemy_parent)));
	draw_text(16, 110, "FPS: " + string(fps));
	draw_text(16, 126, "Target: " + string(floor(scr_director_target(global.run_time))) + " Alive: " + string(instance_number(obj_enemy_parent)));
	if (instance_exists(obj_player)) draw_text(16, 94, "iframes: " + string(obj_player.iframes));
}