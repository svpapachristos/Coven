//causes the enemy to freeze in place during pauses

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