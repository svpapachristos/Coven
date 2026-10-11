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
// auto loot (Options, on by default): souls and items fly straight to her from anywhere, speeding up as they come.
// health orbs stay put, so healing is still a choice of when to grab it
if (global.settings.auto_loot == 1 && pickup_type != "HEALTH") {
	magnet_range = 99999;
	magnet_speed = min(16 * WORLD_SCALE, (3 * WORLD_SCALE) + age * 0.06);
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