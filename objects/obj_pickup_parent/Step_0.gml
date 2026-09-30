if (global.game_state != "PLAYING") exit;

life--;
if (life<= 0) { instance_destroy(); exit; }
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