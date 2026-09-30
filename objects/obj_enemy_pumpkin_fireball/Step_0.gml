if (global.game_state != "PLAYING") {
	if (speed != 0) {
		saved_speed = speed;
		speed = 0;
	}
	exit;
}
if (speed == 0 && saved_speed != 0) {
	speed = saved_speed;
	saved_speed = 0;
}

life -= 1;
if (life <= 0) {
	instance_destroy();
}

if (x < 0 || x > room_width || y < 0 || y > room_height) {
    instance_destroy();
}