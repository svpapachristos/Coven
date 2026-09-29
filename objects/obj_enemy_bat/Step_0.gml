//Freeze the Bat when paused or dead
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

//Chase the player continously at a quick speed
direction = point_direction(x, y, obj_player.x, obj_player.y);
speed = bat_move_speed;