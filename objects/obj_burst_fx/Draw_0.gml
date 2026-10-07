var _t = 1 - life / life_max; // 0 at the start, 1 at the end
var _r = radius * (1 - power(1 - _t, 3)); // bursts out fast then eases
var _a = 1 - _t;

gpu_set_blendmode(bm_add);
draw_set_color(color);

//a soft flash filling the circle
draw_set_alpha(0.18 * _a)
draw_circle(x, y, _r, false);

//the bright expanding (a few concentric lines so its thick)
draw_set_alpha(0.9 * _a);
for (var i = 0; i < 3; i++) draw_circle(x, y, _r - i * 3, true);

//rays flying outward with the ring mushroom cloud style
draw_set_alpha(0.7 * _a);
for (var _k = 0; _k < 12; _k++) {
	var _ang = _k * 30 + _t * 40;
	draw_line_width(x + lengthdir_x(_r * 0.7, _ang), y + lengthdir_y(_r * 0.7, _ang),
					x + lengthdir_x(_r, _ang),		 y + lengthdir_y(_r, _ang), 3 * _a + 1);
					
}

gpu_set_blendmode(bm_normal);
draw_set_alpha(1);
draw_set_color(c_white);