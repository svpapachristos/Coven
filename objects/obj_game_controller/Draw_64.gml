if (global.game_state == "MENU") {
	scr_draw_menu("COVEN", menu_options, menu_index);
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
	draw_text(270, 180, "YOU DIED");
	draw_text(270, 200, "YOU FELLED " + string(global.kill_count) + " ENEMIES.");
	draw_text(270, 250, "PRESS ENTER TO RESTART");
}

if (quit_confirm) {
	draw_set_halign(fa_center);
	draw_text(display_get_gui_width() / 2, display_get_gui_height() / 2 + 140, "Quit? Press Q Again to Quit. Press any Other Key to cancel");
	draw_set_halign(fa_left);
}