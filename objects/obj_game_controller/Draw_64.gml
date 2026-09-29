if (quit_confirm) {
	draw_text(500, 140, "Quit? Press Q again to confirm, or any other key to cancel");
}
if (global.game_state == "START") {
    draw_text(display_get_gui_width() / 2.15, display_get_gui_height() /2.15, "COVEN");
    draw_text(display_get_gui_width() / 2.15, display_get_gui_height() /2, "Press Enter to begin");
}
if (global.game_state == "PAUSED") {
	draw_text(270, 140, "PAUSED. Q to Quit");

}

if (global.game_state == "DEAD") {
	draw_text(270, 180, "YOU DIED");
	draw_text(270, 200, "YOU FELLED " + string(global.kill_count) + " ENEMIES.");
	draw_text(270, 250, "PRESS ENTER TO RESTART");

}