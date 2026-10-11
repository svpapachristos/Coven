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
// the Big Bang's first instant: the whole screen washes white, then fades into the afterglow (Draw)
if (variable_global_exists("hex_bang") && is_struct(global.hex_bang)) {
	var _bt = global.hex_bang.t / game_get_speed(gamespeed_fps);
	if (_bt < 1.4) {
		draw_set_color(make_color_rgb(255, 250, 240));
		draw_set_alpha((_bt < 0.25) ? 1 : sqr(1 - (_bt - 0.25) / 1.15));
		draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
		draw_set_alpha(1);
	}
}
// paused while sitting in her universe
var _hhud = variable_global_exists("hex_hide_hud") && global.hex_hide_hud;
if (gaze && gaze_paused && !_hhud) {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_halign(fa_center); draw_set_valign(fa_middle);
	draw_set_alpha(0.85);
	draw_set_color(make_color_rgb(230, 215, 255));
	draw_text(_gw / 2, _gh * 0.12, "PAUSED");
	draw_set_alpha(0.55);
	draw_text(_gw / 2, _gh * 0.12 + 24, "Esc / P to resume  -  G to leave");
	draw_set_alpha(1);
	draw_set_halign(fa_left); draw_set_valign(fa_top);
}

// debug readout while sitting in her universe (hidden with H): what age her universe is in, and how full it is
if (gaze && !_hhud) {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	var _ae  = variable_global_exists("hex_aeon") ? global.hex_aeon : { phase: "dawn", n: 0 };
	var _sm  = scr_hex_find_smbh();
	var _ml  = (!is_undefined(_sm) && variable_struct_exists(_sm, "meal")) ? string(floor(_sm.meal)) + "/" + string(HEX_QUASAR_MEAL) : "-";
	var _nf  = variable_global_exists("hex_flow") ? array_length(global.hex_flow) : 0;
	var _txt = "aeon " + string(_ae.n) + ": " + _ae.phase + "   |   holes " + string(array_length(global.hex_holes))
	         + "   |   gas " + string(array_length(global.hex_haze)) + " (" + string(_nf) + " flying)   |   meal " + _ml
	         + "\nV giant  B birth  N +1 min  M rush holes  K next age  H hide HUD  P pause  G leave";
	draw_set_halign(fa_right); draw_set_valign(fa_bottom);
	draw_set_alpha(0.7);
	draw_set_color(make_color_rgb(220, 205, 255));
	draw_text(_gw - 16, _gh - 12, _txt);
	draw_set_alpha(1);
	draw_set_halign(fa_left); draw_set_valign(fa_top);
}
