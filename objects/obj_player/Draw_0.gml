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
	var _af = hex_hand_amt / max(1, hex_max);                      // how much of her hex is in her hand: less in hand is a smaller ball
	// (sizes went up ~50% with the round 12 look: the magic is drawn in 2-pixel steps, and at the old size it read tiny)
	var _tR = 9 * (0.65 + 0.35 * _af), _tE = 0.12;                  // at rest in her hand: small and calm
	if (hex_active) {
		if (hex_mode == "charge") { _tR = 9.5 + 6.5 * _kn; _tE = 0.45 + 0.55 * _kn; }
		else { _tR = 9.5; _tE = 0.35; }                             // stance up (the orb tightens into her channeling pocket below)
	}
	_ws.eE += (_tE - _ws.eE) * 0.12;                                // eased, so a change of stance swells instead of snapping
	_ws.eR += (_tR - _ws.eR) * 0.2;
	// THE SOURCE stays in her hand. The orb never flies to the cursor: what reaches out into the world is her hex itself,
	// flowing as a river, and it gathers where it arrives. (Charging is the exception: the orb forms just in front of her hand.)
	var _hp = hex_hand_pos();
	// CHANNELING (stance, reaching, holding): the orb in her palm tightens into a small erratic pocket of hex (white-hot core,
	// smoke around it, a thin veil, licks flaring at its edge), like Wanda's energy cupped between her fingers.
	// hex_hand_f eases between resting and channeling, so it never pops
	var _fT = (hex_active && hex_mode != "charge") ? 1 : 0;
	hex_hand_f += (_fT - hex_hand_f) * 0.1;
	var _eff = 0.8;                                                  // how hard she's working: most when holding something heavy
	if (hex_held != noone) _eff = (hex_kind == "env") ? clamp(0.8 + 0.1 * hex_held.weight, 0.8, 1) : 0.9;
	hex_hand_e += (_eff - hex_hand_e) * 0.08;
	var _hf = hex_hand_f;
	if (hex_mode == "charge") hex_wisp_att(hex_hx, hex_hy, 11 + 20 * _kn, 0.65 + 0.35 * _kn, 0, 0, false, _ws.eR, _ws.eE, 0, 0.6);   // softer strands while charging (the charged orb's own look is still on the bible's to-do list)
	else hex_wisp_att(_hp[0], _hp[1], 15, 0.75, 0, 0, false, lerp(_ws.eR, 4, _hf), lerp(_ws.eE, hex_hand_e, _hf), 0.9 * _hf, lerp(1, 0.3, _hf), 0, 0, 1, lerp(1, 0.5, _hf));   // (veil 0.5: just enough to read the core)
	// the gathering knot at the river's mouth: as big as the hex that has actually arrived there (hex_at, moved by Step),
	// eased so it grows in and dissolves instead of popping
	var _gT = (hex_active && hex_mode == "grab" && hex_held == noone) ? clamp(hex_at / max(1, min(hex_need, hex_reach_cap)), 0, 1) : 0;
	hex_gR += (_gT - hex_gR) * 0.12;
	// it coalesces: first a faint knot of mist, and only once most of it has gathered does its white-hot heart kindle
	if (hex_gR > 0.04) hex_wisp_att(hex_gx, hex_gy, 15, 0.6, 0, 0, false, 2 + 9 * hex_gR, 0.25 + 0.35 * hex_gR, 0, 1, 0, 0, clamp((hex_gR - 0.45) / 0.55, 0, 1));
	// THE SURROUND: her hex around what she holds, never over it (clear in the middle), with licks of overflow straining at
	// its edge. Grows in as the river drains into it; after she lets go it rides along with the thrown thing and dissolves
	if (hex_active && hex_held != noone) { hex_wobj = hex_held; hex_wkind = hex_kind; }
	var _wT = (hex_active && hex_held != noone) ? clamp(hex_at / max(1, hex_cost), 0, 1) : 0;   // as much as has drained into it
	hex_wR += (_wT - hex_wR) * ((_wT > hex_wR) ? 0.1 : 0.05);
	if (hex_wR > 0.04 && instance_exists(hex_wobj)) {
		var _env = (hex_wkind == "env"), _or = _env ? hex_wobj.r : 22;
		hex_wisp_att(hex_wobj.x, hex_wobj.y - (_env ? hex_wobj.z : 0), _or + 8, 0.6, 0, 0, false, (_or + 1) * hex_wR, 0.55 * hex_wR, 0.8 * hex_wR, 0.5, _or + 1, 0, 0, 0.5);
	}
	with (obj_hex_shot) {
		hex_wisp_att(x, y, 11 * size, 0.95, vx, vy, true, max(6, 7 * size), 0.9);   // a shot in flight is wild
	}
	if (_orb) {
		// THE RIVERS (drawn under the orbs): the one flowing out (or turning back), and every one flowing home.
		// How wide and bright each is comes from how much hex it's carrying
		if ((hex_rv_hi - hex_rv_lo) > 0.002) {
			var _c2 = hex_river_bend(_hp[0], _hp[1], hex_rv_tx, hex_rv_ty);
			hex_river_draw(_hp[0], _hp[1], hex_rv_tx, hex_rv_ty, _c2[0], _c2[1], hex_rv_lo, hex_rv_hi, hex_out + ((hex_rv_state == 2) ? hex_cost * 0.5 : 0), (hex_rv_state == 3) ? -1 : 1);
		}
		for (var _i = 0; _i < array_length(hex_home); _i++) {
			var _h = hex_home[_i], _c3 = hex_river_bend(_hp[0], _hp[1], _h.x, _h.y);
			hex_river_draw(_hp[0], _hp[1], _h.x, _h.y, _c3[0], _c3[1], _h.lo, _h.hi, _h.amt, -1);
		}
		hex_orb_draw();
	}
	else hex_wisp_draw([], hex_active);   // (the old smoke-wisp look drew motes; with her hex as one amount it has nothing to draw)
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
