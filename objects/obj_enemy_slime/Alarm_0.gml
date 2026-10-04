if (global.game_state != "PLAYING") {
	alarm[0] = 1;
	if (speed != 0) {
		saved_speed = speed;
		speed = 0;
	}
	exit
} else if (variable_instance_exists(id, "saved_speed") && saved_speed != 0) {
	speed = saved_speed;
	saved_speed = 0;
}
//A Dashy-ier movement
var _dir = point_direction(x, y, obj_player.x, obj_player.y);
direction = _dir;
speed = 10 * SPEED_SCALE * speed_mult; //dash speed
alarm[1] = game_get_speed(gamespeed_fps) * 0.8; //dash length