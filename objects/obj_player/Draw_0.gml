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
if (hover_z > 0) {
	// floating: a soft shadow stays on the ground under her (placeholder until the visual pass)
	draw_set_color(c_black);
	draw_set_alpha(0.3 * min(1, hover_z / max(1, hex.tune.over_hover)));
	draw_ellipse(x - 11, bbox_bottom - 4, x + 11, bbox_bottom + 3, false);
	draw_set_alpha(1);
	draw_set_color(c_white);
}
if (sprite_index != -1) draw_sprite_ext(sprite_index, image_index, x, y - hover_z, image_xscale, image_yscale, image_angle, image_blend, image_alpha);   // (draw_self, lifted by her overflow; no sprite yet at startup: nothing to draw)

// The living curse. O cycles three looks (scr_hex_wisp): the hex orb (default: a small crackling cloud of hex energy per ball of her
// magic), the smoke wisp (light carried along a swirling current), and the original soft circles, kept so they can be compared.
// P cycles the palette. The bright threads (the motes that are out in the world) are drawn here as added light in every look.
var _mv = hex.mv;   // her move state (scr_hex_moves): read only
var _ws = hex_wisp_state();
var _wisp = _ws.on;
var _wp = hex_wisp_pal();
var _orb = (_ws.mode == 0);   // the hex orb look (otherwise the smoke wisp)
if (_wisp && hex_on) {   // (only a witch whose hex it is draws it)
	// the balls of her magic: where her curse is (in her hand, the charging orb, what she holds), and any shot in flight.
	// for the orb each one also carries a core radius (world pixels) and an energy (0 calm .. 1 wild); her stance sets the main ball's
	var _ht = hex.tune;
	var _rat = is_undefined(_mv.ra) ? 0 : _mv.ra.at;               // how much has gathered on her reach's anchor
	var _rwant = is_undefined(_mv.ra) ? 0 : _mv.ra.want;          // ...and how much it wants
	var _nh = array_length(_mv.holds);                              // how many things she's holding up
	var _kn = (_mv.mode == "charge" && !is_undefined(_mv.oa)) ? clamp(_mv.oa.pool / _ht.charge_cap, 0, 1) : 0;
	var _af = hex.hand / max(1, hex.max);                         // how much of her hex is in her hand: less in hand is a smaller ball
	// (sizes went up ~50% with the round 12 look: the magic is drawn in 2-pixel steps, and at the old size it read tiny)
	var _tR = 9 * (0.65 + 0.35 * _af), _tE = 0.12;                  // at rest in her hand: small and calm
	if (_mv.active) {
		if (_mv.mode == "charge") { _tR = 9.5 + 6.5 * _kn; _tE = 0.45 + 0.55 * _kn; }
		else { _tR = 9.5; _tE = 0.35; }                             // stance up (the orb tightens into her channeling pocket below)
	}
	if (_mv.mode != "charge") { _tR += 4 * _mv.over_f; _tE = min(1, _tE + 0.5 * _mv.over_f); }   // OVERFLOW: her palm flares (placeholder)
	_ws.eE += (_tE - _ws.eE) * 0.12;                                // eased, so a change of stance swells instead of snapping
	_ws.eR += (_tR - _ws.eR) * 0.2;
	// THE SOURCE stays in her hand. The orb never flies to the cursor: what reaches out into the world is her hex itself,
	// flowing as a river, and it gathers where it arrives. (Charging is the exception: the orb forms just in front of her hand.)
	var _hp = hex_hand_pos();
	// CHANNELING (stance, reaching, holding): the orb in her palm tightens into a small erratic pocket of hex (white-hot core,
	// smoke around it, a thin veil, licks flaring at its edge), like Wanda's energy cupped between her fingers.
	// hex_hand_f eases between resting and channeling, so it never pops
	var _fT = (_mv.active && _mv.mode != "charge") ? 1 : 0;
	hex_hand_f += (_fT - hex_hand_f) * 0.1;
	var _eff = 0.8;                                                  // how hard she's working: most when holding something heavy
	if (_nh > 0) _eff = min(1, 0.85 + 0.05 * _nh);                   // (the more she holds up, the harder she strains)
	_eff = min(1, _eff + 0.2 * _mv.over_f);                          // (overflowing, her palm burns wilder)
	hex_hand_e += (_eff - hex_hand_e) * 0.08;
	var _hf = hex_hand_f;
	if (_mv.mode == "charge") hex_wisp_att(_mv.hx, _mv.hy, 15, 0.8, 0, 0, false, 12, max(0.02, _kn), 0, 1, 0, 7);   // THE CHARGE: spark -> crackle -> glow -> bloom as it fills (shader mode 7)
	else hex_wisp_att(_hp[0], _hp[1], 15, 0.75, 0, 0, false, lerp(_ws.eR, 4, _hf), lerp(_ws.eE, hex_hand_e, _hf), 0.9 * _hf, lerp(1, 0.3, _hf), 0, 0, 1, lerp(1, 0.5, _hf));   // (veil 0.5: just enough to read the core)
	// the gathering knot where her hex arrives: as big as the hex that has actually gathered there (its anchor's at),
	// eased so it grows in and dissolves instead of popping
	var _gT = (_mv.active && _mv.mode == "grab" && _nh == 0) ? clamp(_rat / max(1, min(_rwant, _ht.reach_cap)), 0, 1) : 0;
	hex_gR += (_gT - hex_gR) * 0.12;
	// it coalesces: first a faint knot of mist, and only once most of it has gathered does its white-hot heart kindle
	// FOCUS (placeholder): held still, the knot's heart kindles fully and it burns wilder as its focus builds
	var _foc = is_undefined(_mv.ra) ? 0 : _mv.ra.focus;
	if (hex_gR > 0.04) hex_wisp_att(_mv.gx, _mv.gy, 15, 0.6, 0, 0, false, 2 + 9 * hex_gR, min(1, 0.25 + 0.35 * hex_gR + 0.4 * _foc), 0, 1, 0, 0, max(clamp((hex_gR - 0.45) / 0.55, 0, 1), _foc));
	// WHAT SHE HOLDS: the hex cupping each thing IS the levitation (its parcels, drawn with the river), so there's no
	// separate scoop here. Rocks she holds are lit from below by it (obj_env_parent draws that, reading hex_lit)
	for (var _i = 0; _i < _nh; _i++) {
		var _hd = _mv.holds[_i];
		if (_hd.kind == "env" && instance_exists(_hd.inst)) { _hd.inst.hex_lit = 1; _hd.inst.hex_lit_e = clamp(0.25 + 0.35 * _hd.inst.weight, 0.25, 1); }
	}
	with (obj_hex_shot) {
		hex_wisp_att(x, y, 11 * size, 0.95, vx, vy, true, max(6, 7 * size), 0.9);   // a shot in flight is wild
	}
	if (_orb) {
		// HER HEX OUT IN THE WORLD (drawn under the orbs): every parcel, as one body of hex (scr_hex_wisp, hex_field_draw)
		hex_field_draw(hex.parcels);
		hex_orb_draw();
	}
	else hex_wisp_draw([], _mv.active);   // (the old smoke-wisp look drew motes; with her hex as one amount it has nothing to draw)
}
gpu_set_blendmode(bm_add);
if (_mv.active && !_orb) {   // (the orb has its own glow and heart)
	var _knot = (_mv.mode == "charge") ? clamp(_mv.orb_n / hex.tune.charge_cap, 0, 1) : 0; // how full the charging orb is
	// her magic lights the ground under it
	draw_set_color(_wisp ? hex_wisp_col(_wp.glow, 0.64) : make_color_rgb(70, 40, 140));
	draw_set_alpha(0.22 + 0.05 * sin(current_time / 120) + 0.2 * _knot);
	draw_circle(_mv.hx, _mv.hy + 4, 22 + 10 * _knot, false);
	if (_knot > 0) {
		// the knot's bright heart as it charges
		draw_set_color(_wisp ? hex_wisp_col(_wp.spark) : make_color_rgb(200, 170, 255));
		draw_set_alpha(0.5 * _knot);
		draw_circle(_mv.hx, _mv.hy, (2 + 9 * _knot) * (1 + 0.2 * sin(_mv.charge * 0.5)), false);
	}
}
if (!_mv.active && !_wisp && hex_on) {
	// the ball's soft glow in her hand (the wisp draws its own)
	draw_set_color(make_color_rgb(80, 45, 160));
	draw_set_alpha(0.14 + 0.04 * sin(current_time / 150));
	draw_circle(_mv.hx, _mv.hy, 14, false);
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
