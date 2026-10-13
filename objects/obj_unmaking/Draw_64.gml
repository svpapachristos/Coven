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
// keep the flash up for the cast's first few frames too, fading out: if that first heavy frame hitches, the bare world never shows
else if (t < 4) {
	draw_set_color(make_color_rgb(240, 225, 255));
	draw_set_alpha(1 - t / 4);
	draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
	draw_set_alpha(1);
}
// the end of the universe: as the crunch finishes, everything goes black, the whole screen, her included. where did the game go?
if (variable_global_exists("hex_mood") && global.hex_mood.dark > 0.003) {
	draw_set_color(c_black);
	draw_set_alpha(min(1, global.hex_mood.dark));
	draw_rectangle(-4, -4, display_get_gui_width() + 4, display_get_gui_height() + 4, false);
	draw_set_alpha(1);
}
// in the void: a single pinprick of light, trembling, swelling... then one frame of nothing at all
if (variable_global_exists("hex_aeon") && global.hex_aeon.phase == "void" && instance_exists(obj_player)) {
	var _vsm = scr_hex_find_smbh();
	var _vt = global.hex_aeon.t, _vlen = game_get_speed(gamespeed_fps) * 1.1;
	if (!is_undefined(_vsm) && _vt > _vlen * 0.25 && _vt < _vlen - 2) {
		var _cam = view_camera[0];
		var _vd = point_distance(0, 0, _vsm.ox, _vsm.oy), _va = point_direction(0, 0, _vsm.ox, _vsm.oy) + sky_angle;
		var _gx = (obj_player.x + lengthdir_x(_vd, _va) - camera_get_view_x(_cam)) / camera_get_view_width(_cam) * display_get_gui_width();
		var _gy = (obj_player.y + lengthdir_y(_vd, _va) - camera_get_view_y(_cam)) / camera_get_view_height(_cam) * display_get_gui_height();
		var _vk2 = (_vt - _vlen * 0.25) / (_vlen * 0.75);
		draw_set_color(c_white);
		draw_set_alpha(0.25 + 0.75 * _vk2);
		draw_circle(_gx + random_range(-1, 1) * _vk2, _gy + random_range(-1, 1) * _vk2, 1 + 2.5 * _vk2 * _vk2, false);
		draw_set_alpha(1);
	}
}
// the Big Bang's first instant (after the impact frame): a punch of pure white, gone in half a second, revealing the fog (Draw)
if (hitstop <= 0 && variable_global_exists("hex_bang") && is_struct(global.hex_bang)) {
	var _bt = global.hex_bang.t / game_get_speed(gamespeed_fps);
	if (_bt < 0.12) {                                                      // the white covers everything for an instant; the cooling glow is in Draw
		draw_set_color(make_color_rgb(255, 250, 240));
		draw_set_alpha(1);
		draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
		draw_set_alpha(1);
	}
}
// paused while sitting in her universe: unmistakable, even with the HUD hidden (H). the sky dims, and a large label sits in the middle
// (it used to be a small line at the top, under the item and age title cards, so pausing was easy to miss)
var _hhud = variable_global_exists("hex_hide_hud") && global.hex_hide_hud;
if (gaze && gaze_paused) {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_color(c_black); draw_set_alpha(0.35);
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_halign(fa_center); draw_set_valign(fa_middle);
	draw_set_alpha(0.95);
	draw_set_color(make_color_rgb(230, 215, 255));
	draw_text_transformed(_gw / 2, _gh / 2 - 60, "PAUSED", 3, 3, 0);
	draw_set_alpha(0.75);
	draw_text(_gw / 2, _gh / 2 - 15, "Esc / P to resume  -  G to leave");
	draw_set_alpha(1);
	draw_set_halign(fa_left); draw_set_valign(fa_top);
}

// (the G-mode readout lives in HUD's Draw GUI now)
