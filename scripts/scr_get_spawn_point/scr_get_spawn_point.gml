//Returns a random [X, Y] that is just outside of the cameras view, or und if it cant find a spot
function scr_get_spawn_point(_extra_min = 32, _extra_max = 200){
	if (!instance_exists(obj_player)) return undefined;
	var _cam = view_camera[0];
	var _vw = camera_get_view_width(_cam);
	var _vh = camera_get_view_height(_cam);
	var _base = point_distance(0, 0, _vw, _vh) / 2;
	repeat (10) {
		var _a = random(360);
		var _r = _base + random_range(_extra_min, _extra_max);
		var _sx = obj_player.x + lengthdir_x(_r, _a);
		var _sy = obj_player.y + lengthdir_y(_r, _a);
		if (_sx >= 0 && _sx <= room_width && _sy >= 0 && _sy <= room_height) {
			return [_sx, _sy];
		}
	}
	return undefined; // for when youre sitting in a corner fighting for your life
	//allow me to spin on it a little further

}