//hide the hude while game is paused (can remove if thats how we feel
var _controller = instance_find(obj_game_controller, 0);

if (global.game_state == "MENU" 
	|| global.game_state == "HUB" 
	|| global.game_state == "STATION"
	|| (global.game_state == "PAUSED"
		&& _controller != noone
		&& _controller.pause_return == "HUB")) {
	exit;
}

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
draw_set_font(-1);

//Act 1 Boss HP Bar
if (instance_exists(obj_boss_act1)) {
	var _b = instance_find(obj_boss_act1, 0);
	var _bw = _gw * 0.5;
	scr_draw_bar((_gw - _bw) / 2, _gh - 70, _bw, 16, _b.hp / _b.max_hp, c_red);
	draw_set_halign(fa_center);
	draw_text(_gw / 2, _gh - 94, _b.boss_name);
	draw_set_halign(fa_left);
}

var _bw = _gw * 0.4;
scr_draw_bar((_gw - _bw) / 2, 12, _bw, 10, global.souls / global.souls_to_next, make_color_rgb(150, 230, 255));
draw_set_halign(fa_center);
draw_text(_gw / 2, 26, "Lvl " + string(global.level));
draw_set_halign(fa_left);

//HP/Mana Bars, Top left for now

if (instance_exists(obj_player)) {
	var _p = obj_player;
	scr_draw_bar(16, 16, 200, 16, _p.hp / _p.max_hp, c_red,
		string(ceil(_p.hp)) + " / " + string(_p.max_hp));
	var _inf = (scr_stat("infinite_mana", 0) > 0);
	var _mana_col = _inf ? merge_color(c_navy, c_fuchsia, 0.5 + 0.5 * sin(current_time / 300)) : c_aqua;
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
	
	var _cs = scr_corruption_stage();
	scr_draw_bar(16, 104, 200, 8, global.corruption / CORRUPTION_MAX,
	merge_color(make_color_rgb(200, 180, 255), make_color_rgb(180, 30, 120), global.corruption / CORRUPTION_MAX),
	scr_corruption_stage_name(_cs));
	
}


//Run info, Top Right for now
var _t = floor(global.run_time);
var _time = string(_t div 60) + ":" + ((_t mod 60 < 10) ? "0" : "") + string(_t mod 60);
draw_set_halign(fa_right);
draw_text(_gw - 16, 16, _time);
draw_text(_gw - 16, 34, "Kills: " + string(global.kill_count));
draw_set_halign(fa_left);

// Item Pickup
if (!is_undefined(global.toast)) {
	var _i = global.toast;
	draw_set_alpha(clamp(_i.timer / 30, 0, 1)); //fades in its last half second
	draw_set_halign(fa_center);
	draw_set_color(_i.color);
	draw_text_transformed(_gw / 2, 60, _i.text, 2, 2, 0);
	draw_set_color(c_ltgray);
	draw_text(_gw / 2, 92, _i.sub);
	draw_set_halign(fa_left);
	draw_set_color(c_white);
	draw_set_alpha(1);
}



//ITEMMSS, Bottom left for now, will eventually display as sprites instead of text
var _counts = global.item_counts;
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
	draw_text(16, 200, "Enemies Alive: " + string(instance_number(obj_enemy_parent)));
	draw_text(16, 217, "FPS: " + string(fps));
	draw_text(16, 234, "Target: " + string(floor(scr_director_target(global.run_time))) + " Alive: " + string(instance_number(obj_enemy_parent)));
	if (instance_exists(obj_player)) draw_text(16, 183, "iframes: " + string(obj_player.iframes));
}
