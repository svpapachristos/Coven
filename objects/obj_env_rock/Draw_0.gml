// A curse bolt draws as a glowing knot of her magic.
if (is_bolt) {
	if (hex_wisp_state().on) exit;   // with the Hex wisp on (scr_hex_wisp), obj_player draws a shot as a ball of her magic; the circles below are the wisp-off look
	var _yo = 0;
	if (is_lob) {
		// arc: it rises and falls on the way there, with its light pooled on the ground below
		var _p = min(1, lob_t / lob_dur);
		_yo = -sin(_p * pi) * (30 + point_distance(lob_x0, lob_y0, lob_tx, lob_ty) * 0.25);
		gpu_set_blendmode(bm_add);
		draw_set_color(make_color_rgb(70, 40, 140));
		draw_set_alpha(0.25);
		draw_circle(x, y, 10 * bolt_size, false);
		gpu_set_blendmode(bm_normal);
	}
	var _y = y + _yo;
	gpu_set_blendmode(bm_add);
	draw_set_color(make_color_rgb(90, 50, 170));
	draw_set_alpha(0.35);
	draw_circle(x, _y, 12 * bolt_size, false);
	draw_set_color(make_color_rgb(200, 170, 255));
	draw_set_alpha(0.9);
	draw_circle(x, _y, 4 * bolt_size, false);
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	draw_set_color(c_white);
	exit;
}
// Placeholder rock until the real sprite exists.
// light stone with a dark outline and a highlight, so it reads on dark ground
draw_set_color(make_color_rgb(30, 28, 36));
draw_circle(x, y, r + 1, false);
draw_set_color(make_color_rgb(150, 145, 160));
draw_circle(x, y, r, false);
draw_set_color(make_color_rgb(200, 196, 210));
draw_circle(x - r * 0.3, y - r * 0.3, r * 0.35, false);
if (grabbed) {
	// violet ring while a witch's curse holds it
	draw_set_color(make_color_rgb(150, 110, 255));
	draw_circle(x, y, r + 3, true);
}
draw_set_color(c_white);
