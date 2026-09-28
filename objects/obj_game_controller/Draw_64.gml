if (global.game_state = "PAUSED") {
	draw_text(270, 140, "PAUSED.");

}

if (global.game_state = "DEAD") {
	draw_text(270, 180, "YOU DIED");
	draw_text(270, 200, "YOU FELLED " + string(global.kill_count) + " ENEMIES.");
	draw_text(270, 250, "PRESS ENTER TO RESTART");

}