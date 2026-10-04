label = "Station";
interact_range = 32 * WORLD_SCALE;
near = (global.game_state == "HUB")
	&& point_distance(x, y, obj_player.x, obj_player.y) < interact_range;