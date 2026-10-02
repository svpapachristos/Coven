if (global.game_state == "MENU") {
	scr_draw_menu("COVEN", menu_options, menu_index);
}
if (global.game_state == "SELECT") {
	var _titles = ["Choose Your Witch", "Choose Your Wand", "Choose Your Familiar"];
	var _opts = scr_select_options(select_step);
	scr_draw_menu(_titles[select_step], _opts, select_index);
	
	var _db = scr_select_db(select_step);
	var _cx = display_get_gui_width() / 2;
	var _y = display_get_gui_height() / 2 + array_length(_opts) * 28 + 24;
	draw_set_halign(fa_center);
	draw_set_color(c_ltgray);
	draw_text(_cx, _y, _db[select_index].desc);
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

