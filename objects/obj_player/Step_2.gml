var cam = view_camera[0];
var cam_w = camera_get_view_width(cam);
var cam_h = camera_get_view_height(cam);

//Only update the look-ahead while playing, so we arent drifting around during pause
if (global.game_state == "PLAYING") {
	var _tx = 0, _ty = 0;
	// during the Unmaking she's the still centre of her universe, so the look-ahead lets go and the camera settles onto her
	if (!instance_exists(obj_unmaking)) {
		var _mx = (mouse_x - camera_get_view_x(cam)) - cam_w / 2;
		var _my = (mouse_y - camera_get_view_y(cam)) - cam_h / 2;
		_tx = clamp(_mx * cam_look_strength, -cam_look_max, cam_look_max);
		_ty = clamp(_my * cam_look_strength, -cam_look_max, cam_look_max);
	}
	var _smooth = instance_exists(obj_unmaking) ? 0.08 : cam_look_smooth; // a slow, deliberate glide into place
	if (instance_exists(obj_unmaking) && obj_unmaking.t < obj_unmaking.shatter_at) _smooth = 0; // time has stopped, and so has the look-ahead
	
	cam_offset_x = lerp(cam_offset_x, _tx, _smooth);
	cam_offset_y = lerp(cam_offset_y, _ty, _smooth);
}

// during the Unmaking the camera may go past the edge of the room, so she stays at the centre of her universe
// even near a wall. it only lets go once the void has fully opened, and glides back before the world returns
var _want_free = 0;
if (instance_exists(obj_unmaking)) {
	with (obj_unmaking) {
		var _fps = game_get_speed(gamespeed_fps);
		_want_free = (t > shatter_at && t < duration - _fps * 0.9) ? 1 : 0;
	}
}
cam_free = lerp(cam_free, _want_free, 0.12);

var target_x = x - cam_w / 2 + cam_offset_x;
var target_y = y - cam_h / 2 + cam_offset_y;


// blend between the room-clamped spot and the free spot, so it glides instead of snapping
var _cx = lerp(clamp(target_x, 0, room_width - cam_w), target_x, cam_free);
var _cy = lerp(clamp(target_y, 0, room_height - cam_h), target_y, cam_free);

var _sh = global.shake * global.settings.screen_shake;
camera_set_view_pos(cam, _cx + random_range(-_sh, _sh), _cy + random_range(-_sh, _sh));
global.shake = max(0, global.shake - 0.4);
	
