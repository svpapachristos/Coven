scr_necro_draw_fallen();
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

// The living curse: soft plum glow (smoke) + bright lilac cores (threads), drawn as added light.
gpu_set_blendmode(bm_add);
if (hex_active) {
	var _knot = (hex_mode == "charge") ? clamp(hex_orb_n / hex_charge_cap, 0, 1) : 0; // how full the charging orb is
	// her magic lights the ground under it
	draw_set_color(make_color_rgb(70, 40, 140));
	draw_set_alpha(0.22 + 0.05 * sin(current_time / 120) + 0.2 * _knot);
	draw_circle(hex_hx, hex_hy + 4, 22 + 10 * _knot, false);
	if (_knot > 0) {
		// the knot's bright heart as it charges
		draw_set_color(make_color_rgb(200, 170, 255));
		draw_set_alpha(0.5 * _knot);
		draw_circle(hex_hx, hex_hy, (2 + 9 * _knot) * (1 + 0.2 * sin(hex_charge * 0.5)), false);
	}
}
if (!hex_active) {
	// the ball's soft glow in her hand
	draw_set_color(make_color_rgb(80, 45, 160));
	draw_set_alpha(0.14 + 0.04 * sin(current_time / 150));
	draw_circle(hex_hx, hex_hy, 14, false);
}
// brightness: these stack additively, so keep each layer faint (lower = dimmer, higher = brighter)
var _sa = hex_active ? 0.06 : 0.035;  // smoke
var _ga = hex_active ? 0.12 : 0.07;   // glow
var _ca = hex_active ? 0.85 : 0.55;   // core
for (var _i = 0; _i < array_length(hex_motes); _i++) {
	var _m = hex_motes[_i];
	if (_m.st == 2 || _m.st == 4) continue; // spent curse, or curse inside a shot, isn't drawn here
	var _dim = (_m.st == 3) ? 0.6 : 1;  // curse flowing home is a little fainter
	// smoke: wide, faint, overlapping so neighbors merge into one cloud
	draw_set_color(make_color_rgb(60, 30, 120));
	draw_set_alpha(_sa * _dim);
	draw_circle(_m.x, _m.y, 14, false);
	// glow
	draw_set_color(make_color_rgb(110, 70, 200));
	draw_set_alpha(_ga * _dim);
	draw_circle(_m.x, _m.y, 6, false);
	// thread: the bright core
	draw_set_color(make_color_rgb(200, 175, 255));
	draw_set_alpha(_ca * _dim);
	draw_rectangle(_m.x - 1, _m.y - 1, _m.x + 1, _m.y + 1, false);
}
gpu_set_blendmode(bm_normal);
draw_set_alpha(1);
draw_set_color(c_white);

// her curse energy, under her feet, only while it isn't full
var _avail = hex_available();
if (_avail < array_length(hex_motes)) {
	var _bw = 40, _bx = x - _bw / 2, _by = bbox_bottom + 6;
	draw_set_color(make_color_rgb(30, 20, 50));
	draw_rectangle(_bx - 1, _by - 1, _bx + _bw + 1, _by + 4, false);
	draw_set_color(make_color_rgb(170, 130, 255));
	draw_rectangle(_bx, _by, _bx + _bw * _avail / array_length(hex_motes), _by + 3, false);
	draw_set_color(c_white);
}