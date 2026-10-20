var cam = view_camera[0];
var cam_w = camera_get_view_width(cam);
var cam_h = camera_get_view_height(cam);

//Only update the look-ahead while playing, so we arent drifting around during pause
if (global.game_state == "PLAYING") {
	var _tx = 0, _ty = 0;
	// during a real hold of her curse (not a tap) the camera settles, so the world under the cursor holds still while
	// she steers. it lingers a moment after she lets go, so tapping E never makes the camera flick back and forth
	if (hex.mv.active && hex.mv.tap > 10) cam_hex_settle = cam_hex_linger;
	else cam_hex_settle = max(0, cam_hex_settle - 1);
	if (cam_hex_settle <= 0) {
		var _aim = input_aim();   // the camera leans toward where she's aiming (scr_input)
		var _mx = (_aim[0] - camera_get_view_x(cam)) - cam_w / 2;
		var _my = (_aim[1] - camera_get_view_y(cam)) - cam_h / 2;
		_tx = clamp(_mx * cam_look_strength, -cam_look_max, cam_look_max);
		_ty = clamp(_my * cam_look_strength, -cam_look_max, cam_look_max);
	}
	var _smooth = cam_look_smooth;
	
	cam_offset_x = lerp(cam_offset_x, _tx, _smooth);
	cam_offset_y = lerp(cam_offset_y, _ty, _smooth);
}

var target_x = x - cam_w / 2 + cam_offset_x;
var target_y = y - cam_h / 2 + cam_offset_y;


// blend between the room-clamped spot and the free spot, so it glides instead of snapping
var _cx = clamp(target_x, 0, room_width - cam_w);
var _cy = clamp(target_y, 0, room_height - cam_h);

// screen shake as a rumble: the camera rides a few overlapping waves instead of jumping to a new random spot every frame
// (the random jumps read as the whole world teleporting, measured in Sophia's merger clips). big moments still hit hard
var _sh = global.shake * global.settings.screen_shake;
var _st = current_time / 1000;
var _sx = sin(_st * 29.3) * 0.55 + sin(_st * 17.9 + 1.7) * 0.3 + sin(_st * 47.1 + 4.1) * 0.15;
var _sy = sin(_st * 25.7 + 0.6) * 0.55 + sin(_st * 13.3 + 2.9) * 0.3 + sin(_st * 41.9 + 5.3) * 0.15;
camera_set_view_pos(cam, _cx + _sx * _sh, _cy + _sy * _sh);
global.shake = max(0, global.shake * 0.93 - 0.15);                      // eases out instead of dropping in a straight line
	

// ---- her hex (scr_hex_moves): pin a held enemy after it has tried to move, and fly thrown enemies into the horde ----
hex_move_end_step(hex);
