var _stage = scr_corruption_stage();
if (_stage > 0) {
	var _pulse = 0.85 + 0.15 * sin(current_time / 180);
	draw_set_color(make_color_rgb(190, 70, 255));
	draw_set_alpha(0.12 * _stage * _pulse);
	draw_circle(x, y, (14 + _stage * 7) * _pulse, false);
	draw_set_alpha(1);
	draw_set_color(c_white);
}
draw_self();