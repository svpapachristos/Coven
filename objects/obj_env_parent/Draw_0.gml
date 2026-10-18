// its shadow stays on the ground and shrinks and fades as it rises; the thing itself is drawn z pixels up
var _lift = clamp(z / 40, 0, 1);
draw_set_color(c_black);
draw_set_alpha(0.3 * (1 - 0.6 * _lift));
var _sw = r * (1.1 - 0.4 * _lift), _sh = r * (0.45 - 0.15 * _lift);
draw_ellipse(x - _sw, y + r * 0.6 - _sh, x + _sw, y + r * 0.6 + _sh, false);
draw_set_alpha(1);
draw_set_color(c_white);

if (sprite_index != -1) {
	draw_sprite_ext(sprite_index, image_index, x, y - z, image_xscale, image_yscale, image_angle, image_blend, image_alpha);
} else {
	// no art yet: a placeholder circle the size of its footprint
	draw_set_color(make_color_rgb(150, 145, 160));
	draw_circle(x, y - z, r, false);
	draw_set_color(c_white);
}
