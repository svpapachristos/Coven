var cam = view_camera[0];
var cam_w = camera_get_view_width(cam);
var cam_h = camera_get_view_height(cam);

//Only update the look-ahead while playing, so we arent drifting around during pause
if (global.game_state == "PLAYING") {
	var _mx = (mouse_x - camera_get_view_x(cam)) - cam_w / 2;
	var _my = (mouse_y - camera_get_view_y(cam)) - cam_h / 2;
	
	var _tx = clamp(_mx * cam_look_strength, -cam_look_max, cam_look_max);
	var _ty = clamp(_my * cam_look_strength, -cam_look_max, cam_look_max);
	
	cam_offset_x = lerp(cam_offset_x, _tx, cam_look_smooth);
	cam_offset_y = lerp(cam_offset_y, _ty, cam_look_smooth);
}

var target_x = x - cam_w / 2 + cam_offset_x;
var target_y = y - cam_h / 2 + cam_offset_y;

var _sh = global.shake;
camera_set_view_pos(cam,
	clamp(target_x, 0, room_width - cam_w) + random_range(-_sh, _sh),
	clamp(target_y, 0, room_height - cam_h) + random_range(-_sh, _sh));
global.shake = max(0, global.shake - 0.4);
	
