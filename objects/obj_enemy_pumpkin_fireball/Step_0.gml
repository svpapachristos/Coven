if (global.game_state != "PLAYING") {
	speed = 0;
	exit;
}

if (x < 0 || x > room_width || y < 0 || y > room_height) {
    instance_destroy();
}