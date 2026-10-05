if (global.game_state != "PLAYING") exit;

age++;
if (expires) {
	life--;
	if (life <= 0) { instance_destroy(); exit; }
} else if (age > game_get_speed(gamespeed_fps) * 8) {
	//items that dont expire will magnetize after ~8 seconds)
	magnet_range = 99999;
	magnet_speed = (2.5 * WORLD_SCALE) + (age - game_get_speed(gamespeed_fps) * 8) * 0.03;
}
bob_t += 4;

if (instance_exists(obj_player)) {
	var _d = point_distance(x, y, obj_player.x, obj_player.y);
	
	if (_d < magnet_range) {
		var _dir = point_direction(x, y, obj_player.x, obj_player.y);
		x += lengthdir_x(magnet_speed, _dir);
		y += lengthdir_y(magnet_speed, _dir);
	}
	
	if (_d < pickup_range) {
		scr_apply_pickup(id, obj_player);
		instance_destroy();
	}
}