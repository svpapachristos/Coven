var cam = view_camera[0];
var cam_w = camera_get_view_width(cam);
var cam_h = camera_get_view_height(cam);

var target_x = x - cam_w / 2;
var target_y = y - cam_h / 2;

camera_set_view_pos(cam,
	clamp(target_x, 0, room_width - cam_w),
	clamp(target_y, 0, room_height - cam_h));