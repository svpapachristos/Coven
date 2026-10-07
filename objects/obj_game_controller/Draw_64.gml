if (global.game_state == "MENU") {
	scr_draw_menu("COVEN", menu_options, menu_index);
}
if (global.game_state == "STATION") {
	var _titles = ["Choose Your Witch", "Choose Your Wand", "Choose Your Familiar"];
	var _opts = scr_select_options(station_step);
	scr_draw_menu(_titles[station_step], _opts, station_index);
	
	var _db = scr_select_db(station_step);
	var _cx = display_get_gui_width() / 2;
	var _y = display_get_gui_height() / 2 + array_length(_opts) * 28 + 24;
	draw_set_halign(fa_center);
	draw_set_color(c_ltgray);
	draw_text(_cx, _y, _db[station_index].desc);
	draw_set_color(c_dkgray);
	draw_text(_cx, _y + 28, "Esc / Right Click to go Back");
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

if (global.game_state == "PAUSED") {
	draw_set_alpha(0.55);
	draw_set_color(c_black);
	draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
	draw_set_alpha(1);
	draw_set_color(c_white);
	scr_draw_menu("PAUSED", pause_options, pause_index);
}

if (global.game_state == "LEVELUP") {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_alpha(0.65);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_gw / 2, _gh * 0.12, "LEVEL " + string(global.level), 3, 2, 0);
	
	var _n = array_length(levelup_choices);
	for (var i = 0; i < _n; i++) {
		var _r = scr_card_rect(i, _n);
		var _it = global.item_db[$ levelup_choices[i]];
		var _col = scr_rarity_color(_it.rarity);
		var _sel = (i == levelup_index);
		var _cx = (_r.x1 + _r.x2) / 2;
		
		draw_set_color(c_black);
		draw_set_alpha(0.85);
		draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, false);
		draw_set_alpha(1);
		draw_set_color(_sel ? c_white : _col);
		draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, true);
		if (_sel) draw_rectangle(_r.x1 + 2, _r.y1 + 2, _r.x2 - 2, _r.y2 - 2, true);
		
		draw_set_color(_col);
		draw_text_transformed(_cx, _r.y1 + 30, _it.name, 2, 2, 0);
		draw_set_color(c_gray);
		draw_text(_cx, _r.y1 + 70, string_upper(_it.rarity));
		draw_set_color(c_white);
		draw_text_ext(_cx, _r.y1 + 120, _it.desc, 22, _r.x2 - _r.x1 - 40);
		draw_set_color(c_dkgray);
		draw_text(_cx, _r.y2 - 30, "[" + string(i + 1) + "]");
	}
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}
if (global.game_state == "DEAD") {
	var _gui_w = display_get_gui_width();
	var _gui_h = display_get_gui_height();
	var _cx = _gui_w / 2;
	var _cy = _gui_h / 2;
	
	var _total_seconds = floor(global.run_time);
	var _hours = _total_seconds div 3600;
	var _minutes = (_total_seconds mod 3600) div 60;
	var _seconds = _total_seconds mod 60;
	
	var _time_text = "";
	
	if (_hours > 0) {
		_time_text += string(_hours)
			+ ((_hours == 1) ? " hour " : " hours ");
	}
	
	if (_minutes > 0 || _hours > 0) {
		_time_text += string(_minutes)
			+ ((_minutes == 1) ? " minute " : " minutes ");
	}
	
	_time_text += string(_seconds)
		+ ((_seconds == 1) ? " second" : " seconds");
		
	draw_set_alpha(0.75);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gui_w, _gui_h, false);
	draw_set_alpha(1);
	
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_cx, _cy - 155, "RUN OVER", 2, 2, 0);
	draw_text(_cx, _cy - 85, "Time Survived: " + _time_text);
	draw_text(_cx, _cy - 55,
		"Enemies Defeated: " + string(global.kill_count));
		
	draw_set_halign(fa_left);
	scr_draw_menu("", end_options, end_index);
}

if (global.game_state == "VICTORY") {
	scr_draw_menu("ACT COMPLETE", victory_options, victory_index);
	var _cx = display_get_gui_width() / 2;
	var _y = display_get_gui_height() / 2 + array_length(victory_options) * 28 + 30;
	var _t = floor(global.run_time);
	draw_set_halign(fa_center);
	draw_text(_cx, _y, "Time  " + string(_t div 60) + ":" + ((_t mod 60 < 10) ? "0" : "") + string(_t mod 60));
	draw_text(_cx, _y + 22, "Enemies felled  " + string(global.kill_count));
	draw_text(_cx, _y + 44, "Level  " + string(global.level));
	var _path = (global.corruption < 25) ? "RADIANT" : ((global.corruption < 75) ? "WAVERING" : "CONSUMED");
	draw_set_color((global.corruption < 25) ? make_color_rgb(255, 235, 150) : ((global.corruption < 75) ? c_white : make_color_rgb(200, 70, 160)));
	draw_text(_cx, _y + 66, "Path " + _path);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

if (quit_confirm) {
	var _gui_w = display_get_gui_width();
	var _gui_h = display_get_gui_height();
	var _cx = _gui_w / 2;
	var _cy = _gui_h / 2;
	
	//Dim the game and menu behind the dialog.
	draw_set_alpha(0.7);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gui_w, _gui_h, false);
	draw_set_alpha(1);
	
	//Draw the confirmation panel
	draw_set_color(c_dkgray);
	draw_rectangle(_cx - 230, _cy - 125, _cx + 230, + _cy + 125, false);
	draw_set_color(c_white);
	draw_rectangle(_cx - 230, _cy - 125, _cx + 230, + _cy + 125, true);
	
	// Reuse the existing menu drawing and click targets
	scr_draw_menu( 
		"ARE YOU SURE?",
		quit_confirm_options,
		quit_confirm_index,
		_cy + 5
	);
}


if (global.game_state == "HUB") {
	draw_text(16, 16, "Reagents: " + string(global.reagents));
}

if (global.game_state == "SPREAD") {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_alpha(0.7);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_gw / 2, _gh * 0.1, (spread_mode == "reading") ? "THE READING" : "THE CAULDRON", 3, 3, 0);
	draw_text(_gw / 2, _gh * 0.1 + 60, (spread_mode == "reading")
		? "Click a card to turn it. Reversed: stronger, but it costs Corruption.  R to redraw, Esc to close."
		: "Click a card to reroll it (1 reagent).  Reagents: " + string(global.reagents));

	var _n = array_length(global.spread);
	var _foot = ["Elite I - 4:00", "Elite II - 8:00", "Elite III - 11:00"];
	if (_n == 0) draw_text(_gw / 2, _gh / 2, "Draw a reading first.");
	for (var i = 0; i < _n; i++) {
		scr_draw_card(scr_card_rect(i, _n), scr_spread_card_id(i), i == spread_index,
			_foot[i] + (global.spread_rev[i] ? "  [REVERSED]" : ""));
	}
	draw_set_halign(fa_left);
}