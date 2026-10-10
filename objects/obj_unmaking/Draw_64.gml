// the clean frame: on the cast's first frame the doomed, she and her familiar were hidden and the Unmaking drew
// nothing, so the screen holds just the bare world. photograph it: that's the ground that breaks away.
// a flash covers the one frame where the world stood empty
if (clean_pending) {
	clean_pending = false;
	var _aw = surface_get_width(application_surface), _ah = surface_get_height(application_surface);
	snap = surface_create(_aw, _ah);
	surface_set_target(snap);
	draw_clear_alpha(c_black, 1);
	draw_surface(application_surface, 0, 0);          // drawn on the graphics card: fast, unlike making a sprite
	surface_reset_target();
	snap_x  = camera_get_view_x(view_camera[0]);   // exactly where the camera was for this photograph
	snap_y  = camera_get_view_y(view_camera[0]);
	draw_set_color(make_color_rgb(240, 225, 255));
	draw_set_alpha(1);
	draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
}