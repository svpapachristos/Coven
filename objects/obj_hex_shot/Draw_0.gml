// With the hex look on (scr_hex_wisp), obj_player draws every shot as a ball of her magic, so there's nothing to do here.
// These circles are the look with it off (O cycles to "old circles").
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
