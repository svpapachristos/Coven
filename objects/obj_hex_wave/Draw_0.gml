var _a = (r < max_r) ? 1 : fade / 10;
gpu_push_state();
gpu_set_blendmode(bm_add);

// a faint violet wash inside the wave
draw_set_color(HEX_VIOLET);
draw_set_alpha(0.08 * _a);
draw_circle(x, y, r, false);

//the wave front: two crackling, warbling rings so it reads as chaotic instead of a clean wave
for (var k = 0; k < 2; k++) {
	draw_set_color((k == 0) ? HEX_VIOLET : make_color_rgb(230, 190, 255));
	draw_set_alpha(((k == 0) ? 0.7 : 0.9) * _a);
	draw_primitive_begin(pr_linestrip);
	for (var j = 0; j <= 48; j++) {
		var _ang = j / 48 * 360;
		var _wr = r + sin(j * 1.7 + current_time / 40 + k * 2) * 6 * (k + 1);
		draw_vertex(x + lengthdir_x(_wr, _ang), y + lengthdir_y(_wr, _ang));
	}
	draw_primitive_end();
}
gpu_pop_state();
draw_set_alpha(1);
draw_set_color(c_white);