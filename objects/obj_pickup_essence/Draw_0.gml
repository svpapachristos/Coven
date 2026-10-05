var _yoff = sin(degtorad(bob_t)) * 2;
var _s = min(3 + sqrt(value), 9); //merged orbs look bigger
draw_set_color(make_color_rgb(150, 230, 255));
draw_set_alpha(0.35);
draw_circle(x, y + _yoff, _s * 2, false);
draw_set_alpha(1);
draw_circle(x, y + _yoff, _s, false);
draw_set_color(c_white);
draw_circle(x, y + _yoff, _s * 0.4, false);