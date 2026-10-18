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

// The living curse. O cycles three looks (scr_hex_wisp): the hex orb (default: a small crackling cloud of hex energy per ball of her
// magic), the smoke wisp (light carried along a swirling current), and the original soft circles, kept so they can be compared.
// P cycles the palette. The bright threads (the motes that are out in the world) are drawn here as added light in every look.
var _ws = hex_wisp_state();
var _wisp = _ws.on;
var _wp = hex_wisp_pal();
var _orb = (_ws.mode == 0);   // the hex orb look (otherwise the smoke wisp)
if (_wisp) {
	// the balls of her magic: where her curse is (in her hand, the charging orb, what she holds), and any shot in flight.
	// for the orb each one also carries a core radius (world pixels) and an energy (0 calm .. 1 wild); her stance sets the main ball's
	var _kn = (hex_mode == "charge") ? clamp(hex_orb_n / hex_charge_cap, 0, 1) : 0;
	var _af = hex_available() / array_length(hex_motes);          // how full her reserve is: a spent reserve is a smaller ball
	// (sizes went up ~50% with the round 12 look: the magic is drawn in 2-pixel steps, and at the old size it read tiny)
	var _tR = 9 * (0.65 + 0.35 * _af), _tE = 0.12;                  // at rest in her hand: small and calm
	if (hex_active) {
		if (hex_mode == "charge") { _tR = 9.5 + 6.5 * _kn; _tE = 0.45 + 0.55 * _kn; }
		else { _tR = 9.5; _tE = 0.35; }                             // stance up: the source in her hand, awake
	}
	_ws.eE += (_tE - _ws.eE) * 0.12;                                // eased, so a change of stance swells instead of snapping
	_ws.eR += (_tR - _ws.eR) * 0.2;
	// THE SOURCE stays in her hand. The orb never flies to the cursor: what reaches out into the world is her hex itself,
	// flowing as motes, and it gathers where it arrives. (Charging is the exception: the knot forms just in front of her hand.)
	var _hp = hex_hand_pos();
	if (hex_mode == "charge") hex_wisp_att(hex_hx, hex_hy, 11 + 20 * _kn, 0.65 + 0.35 * _kn, 0, 0, false, _ws.eR, _ws.eE, 0, 0.6);   // softer strands while charging (the charged orb's own look is still on the bible's to-do list)
	else hex_wisp_att(_hp[0], _hp[1], 15, 0.75, 0, 0, false, _ws.eR, _ws.eE);
	if (hex_active && hex_held != noone) {
		// what she holds is wrapped in her hex, straining against it (the overflow)
		hex_wisp_att(hex_held.x, hex_held.y - ((hex_kind == "env") ? hex_held.z : 0), ((hex_kind == "env") ? hex_held.r : 22) + 8, 0.6, 0, 0, false, 11, 0.55, 1);
	} else if (hex_active && hex_mode == "grab") {
		// reaching: hex gathers where it arrives, growing as more of it gets there
		var _g = clamp(hex_arrived / 14, 0, 1);
		if (_g > 0.05) hex_wisp_att(hex_hx, hex_hy, 15, 0.6, 0, 0, false, 4 + 7 * _g, 0.3 + 0.3 * _g);
	}
	with (obj_hex_shot) {
		hex_wisp_att(x, y, 11 * size, 0.95, vx, vy, true, max(6, 7 * size), 0.9);   // a shot in flight is wild
	}
	if (_orb) hex_orb_draw();
	else hex_wisp_draw(hex_motes, hex_active);
}
gpu_set_blendmode(bm_add);
if (hex_active && !_orb) {   // (the orb has its own glow and heart)
	var _knot = (hex_mode == "charge") ? clamp(hex_orb_n / hex_charge_cap, 0, 1) : 0; // how full the charging orb is
	// her magic lights the ground under it
	draw_set_color(_wisp ? hex_wisp_col(_wp.glow, 0.64) : make_color_rgb(70, 40, 140));
	draw_set_alpha(0.22 + 0.05 * sin(current_time / 120) + 0.2 * _knot);
	draw_circle(hex_hx, hex_hy + 4, 22 + 10 * _knot, false);
	if (_knot > 0) {
		// the knot's bright heart as it charges
		draw_set_color(_wisp ? hex_wisp_col(_wp.spark) : make_color_rgb(200, 170, 255));
		draw_set_alpha(0.5 * _knot);
		draw_circle(hex_hx, hex_hy, (2 + 9 * _knot) * (1 + 0.2 * sin(hex_charge * 0.5)), false);
	}
}
if (!hex_active && !_wisp) {
	// the ball's soft glow in her hand (the wisp draws its own)
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
	if (_orb && _m.st == 0) continue;       // at rest they are inside the orb
	var _dim = (_m.st == 3) ? 0.6 : 1;  // curse flowing home is a little fainter
	if (!_wisp) {
		// smoke: wide, faint, overlapping so neighbors merge into one cloud
		draw_set_color(make_color_rgb(60, 30, 120));
		draw_set_alpha(_sa * _dim);
		draw_circle(_m.x, _m.y, 14, false);
		// glow
		draw_set_color(make_color_rgb(110, 70, 200));
		draw_set_alpha(_ga * _dim);
		draw_circle(_m.x, _m.y, 6, false);
	}
	if (_orb) {
		// MOTES 2.0 look: each mote out in the world is a little puff of hex with a wisp trailing behind it,
		// drawn on the magic's 2-pixel grid. A stream of them reads as wisps of energy flowing through space
		// (drawn as LIGHT, like the orb: added glow in layers, brightest at the heart)
		var _px = floor(_m.x / 2) * 2, _py = floor(_m.y / 2) * 2;
		draw_set_color(hex_wisp_col(_wp.glow));
		if (point_distance(_m.x, _m.y, _m.t1x, _m.t1y) < 24) {
			draw_set_alpha(0.45 * _dim);
			draw_line_width(_m.x, _m.y, _m.t1x, _m.t1y, 4);             // the wisp it leaves behind
			if (point_distance(_m.t1x, _m.t1y, _m.t2x, _m.t2y) < 24) {
				draw_set_alpha(0.22 * _dim);
				draw_line_width(_m.t1x, _m.t1y, _m.t2x, _m.t2y, 3);
			}
		}
		draw_set_alpha(0.3 * _dim);
		draw_rectangle(_px - 4, _py - 4, _px + 3, _py + 3, false);     // the haze around it
		draw_set_color(hex_wisp_col(_wp.core));
		draw_set_alpha(0.55 * _dim);
		draw_rectangle(_px - 2, _py - 2, _px + 1, _py + 1, false);     // the puff
		draw_set_color(hex_wisp_col(_wp.spark));
		draw_set_alpha(0.85 * _dim);
		draw_rectangle(_px - 1, _py - 1, _px, _py, false);             // its bright heart
	} else {
		// thread: the bright core
		draw_set_color(_wisp ? hex_wisp_col(_wp.spark) : make_color_rgb(200, 175, 255));
		draw_set_alpha(_ca * _dim);
		draw_rectangle(_m.x - 1, _m.y - 1, _m.x + 1, _m.y + 1, false);
	}
}
gpu_set_blendmode(bm_normal);
draw_set_alpha(1);
draw_set_color(c_white);
hex_wisp_label(x, bbox_top - 24); // the palette's name for a moment after O or P
if (hex_hand_debug) {
	// J: a crosshair on her off hand's point, and the sprite it belongs to
	var _hp = hex_hand_pos();
	draw_set_color(c_lime);
	draw_line(_hp[0] - 4, _hp[1], _hp[0] + 4, _hp[1]);
	draw_line(_hp[0], _hp[1] - 4, _hp[0], _hp[1] + 4);
	draw_text(x - 60, bbox_bottom + 14, sprite_get_name(sprite_index));
	draw_set_color(c_white);
}
// (her hex amount is shown on the HUD now, not in a bar under her feet: fewer bars, more world)
