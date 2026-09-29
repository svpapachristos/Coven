if (global.game_state != "PLAYING") {
	alarm[1] = 1;
	exit;
}
speed = 0;
alarm[0] = game_get_speed(gamespeed_fps) * 1; 