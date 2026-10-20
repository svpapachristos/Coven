// With the hex look on (scr_hex_wisp), obj_player draws every shot as a ball of her magic, so there's nothing to do here.
// These circles are the look with it off (O cycles to "old circles").
if (needle) {
	// a NEEDLE: hex light in the shape of a glass needle (placeholder until the visual pass). Built like her returning hex:
	// a soft dark smoke body so it reads on any ground, then light layered on top (brighter = whiter): a faint glow, the
	// hex-blue body of light, and a brighter lilac heart toward the tip. No hard lines: every layer is see-through light.
	// A diamond along its flight: pointed at the tip, widest near the front, tapering to the tail
	var _sp = max(0.01, point_distance(0, 0, vx, vy)), _ux = vx / _sp, _uy = vy / _sp, _nx = -_uy, _ny = _ux;
	var _L = 18, _W = 4;   // the shard's length and half-width (pixels)
	var _mx = x - _ux * _L * 0.3, _my = y - _uy * _L * 0.3;   // its widest point
	// smoke: the part that isn't light, soft, so the shard holds its shape on the grass
	draw_set_color(make_color_rgb(14, 0, 86));
	draw_set_alpha(0.3); needle_shard(_ux, _uy, _nx, _ny, _mx, _my, 6, _L + 4, _W + 3);
	draw_set_alpha(0.45); needle_shard(_ux, _uy, _nx, _ny, _mx, _my, 4, _L + 2, _W + 1.5);
	gpu_set_blendmode(bm_add);
	// glow: where the light builds up around it
	draw_set_color(make_color_rgb(41, 7, 175));
	draw_set_alpha(0.35); needle_shard(_ux, _uy, _nx, _ny, _mx, _my, 5, _L + 3, _W + 2.5);
	// the body of light: hex blue
	draw_set_color(make_color_rgb(57, 17, 243));
	draw_set_alpha(0.7); needle_shard(_ux, _uy, _nx, _ny, _mx, _my, 2, _L, _W);
	// its heart: brighter (lilac) and slimmer toward the tip, where the glass catches the light
	draw_set_color(make_color_rgb(222, 190, 255));
	draw_set_alpha(0.55); needle_shard(_ux, _uy, _nx, _ny, _mx, _my, 1, _L * 0.6, _W * 0.45);
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	draw_set_color(c_white);
	exit;
}
if (hex_wisp_state().on) exit;
gpu_set_blendmode(bm_add);
draw_set_color(make_color_rgb(90, 50, 170));
draw_set_alpha(0.35);
draw_circle(x, y, 12 * size, false);
draw_set_color(make_color_rgb(200, 170, 255));
draw_set_alpha(0.9);
draw_circle(x, y, 4 * size, false);
gpu_set_blendmode(bm_normal);
draw_set_alpha(1);
draw_set_color(c_white);
