// Clickable area for menu row 1 (shared by drawing and clicking, so they always line up)
function scr_menu_row(_i, _y0 = display_get_gui_height() / 2) {
	var _cx = display_get_gui_width() / 2;
	return { x1: _cx - 140, y1: _y0 + _i * 28 - 4, x2: _cx + 140, y2: _y0 + _i * 28 + 24 };
}

// returns the row that was chosen per frame (Enter on the highlight or click on a row, or return -1
function scr_menu_pick(_index, _count, _y0 = display_get_gui_height() / 2) {
	if (keyboard_check_pressed(vk_enter)) return _index;
	if (mouse_check_button_pressed(mb_left)) {
		var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
		for (var i = 0; i < _count; i++) {
			var _r = scr_menu_row(i, _y0);
			if (point_in_rectangle(_mx, _my, _r.x1, _r.y1, _r.x2, _r.y2)) return i;
		}
	}
	return -1;
}

/// Keyboard moves the highlight; so does hovering the mouse over a row (only once the mouse actually moves)
function scr_menu_nav(_index, _count, _y0 = display_get_gui_height() / 2) {
	static _last_mx = -1;
	static _last_my = -1;

	var _d = (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S")))
	       - (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W")));
	_index = (_index + _d + _count) mod _count;

	var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
	if (_mx != _last_mx || _my != _last_my) {
		for (var i = 0; i < _count; i++) {
			var _r = scr_menu_row(i, _y0);
			if (point_in_rectangle(_mx, _my, _r.x1, _r.y1, _r.x2, _r.y2)) _index = i;
		}
		_last_mx = _mx;
		_last_my = _my;
	}
	return _index;
}

function scr_draw_menu(_title, _options, _index, _y0 = display_get_gui_height() / 2) {
	var _cx = display_get_gui_width() / 2;
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_cx, _y0 - 80, _title, 3, 3, 0);
	for (var i = 0; i < array_length(_options); i++) {
		var _sel = (i == _index);
		if (_sel) {
			var _r = scr_menu_row(i, _y0);
			draw_set_alpha(0.25);
			draw_set_color(c_aqua);
			draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, false);
			draw_set_alpha(1);
		}
		draw_set_color(_sel ? c_aqua : c_gray);
		draw_text(_cx, _y0 + i * 28, (_sel ? "> " : "") + _options[i]);
	}
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

function scr_draw_bar(_x, _y, _w, _h, _pct, _col, _label = "") {
	_pct = clamp(_pct, 0, 1);
	draw_set_color(c_black);  draw_rectangle(_x - 2, _y - 2, _x + _w + 2, _y + _h + 2, false);
	draw_set_color(c_dkgray); draw_rectangle(_x, _y, _x + _w, _y + _h, false);
	draw_set_color(_col);     draw_rectangle(_x, _y, _x + _w * _pct, _y + _h, false);
	if (_label != "") {
		draw_set_color(c_white);
		draw_set_valign(fa_middle);
		draw_text(_x + _w + 8, _y + _h / 2, _label);
		draw_set_valign(fa_top);
	}
	draw_set_color(c_white);
}

function scr_draw_infinity(_x, _y, _size, _col) {
	draw_set_color(_col);
	var _steps = 40;
	var _px = _x + _size, _py = _y;
	for (var i = 1; i <= _steps; i++) {
		var _t = (i / _steps) * 2 * pi;
		var _d = 1 + sqr(sin(_t));
		var _nx = _x + _size * cos(_t) / _d;
		var _ny = _y + _size * sin(_t) * cos(_t) / _d;
		draw_line_width(_px, _py, _nx, _ny, 2);
		_px = _nx; _py = _ny;
	}
	draw_set_color(c_white);
}

// the title screen (placeholder): the Hexweaver alone in the dark, casting her curse in front of her.
// covers the hub so the menu sits on its own screen. everything animates off current_time, so it needs no state
function scr_draw_title_backdrop() {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	var _t  = current_time / 1000;                       // seconds
	var _u  = _gh / 720;                                 // scale everything to the screen height

	scr_draw_title_sky(_gw, _gh, _t);

	// where she stands: left of the menu
	var _wx = _gw * 0.24, _wy = _gh * 0.52;
	var _ws = 5 * _u;                                    // her 64px sprite at 5x
	var _pulse = 0.5 + 0.5 * sin(_t * 2.1);              // the spell breathing

	// her light: a soft violet glow behind her
	gpu_set_blendmode(bm_add);
	draw_set_alpha(0.22 + 0.08 * _pulse);
	draw_circle_color(_wx, _wy, 260 * _u, CURSE_VIOLET, c_black, false);
	gpu_set_blendmode(bm_normal);

	// the curse on the ground under her (squashed flat), faint
	scr_draw_coven_sigil(_wx, _wy + 30 * _ws * 0.5, 120 * _u, 0.35, _t * 12, 0.4 + 0.2 * _pulse);

	// her, casting (falls back to her idle if the cast sprite is renamed)
	var _spr = asset_get_index("spr_player_witch1_idle_down_fire");
	if (_spr < 0) _spr = asset_get_index("spr_player_witch1_idle_down");
	if (_spr >= 0) {
		var _fr = 0;                                     // standing still (her idle loop read oddly at this size)
		draw_set_alpha(1);
		draw_sprite_ext(_spr, _fr, _wx, _wy, _ws, _ws, 0, c_white, 1);
	}

	// the curse in front of her: upright, facing us, turning while it hangs in the air
	scr_draw_coven_sigil(_wx, _wy + 55 * _u, 105 * _u, 1, -_t * 18, 0.75 + 0.25 * _pulse);

	// motes rising off the spell
	gpu_set_blendmode(bm_add);
	draw_set_color(make_color_rgb(215, 180, 255));
	for (var i = 0; i < 24; i++) {
		var _life = frac(_t * (0.18 + scr_coven_hash(i * 4.4) * 0.15) + scr_coven_hash(i * 8.8));
		var _mx = _wx + (scr_coven_hash(i * 6.1) - 0.5) * 200 * _u + sin(_t + i) * 8 * _u;
		var _my = _wy + 110 * _u - _life * 260 * _u;
		draw_set_alpha(sin(_life * pi) * 0.7);
		draw_rectangle(_mx - 1, _my - 1, _mx + 1, _my + 1, false);
	}
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	draw_set_color(c_white);
}

// the shared dark of the title screens: near-black violet over the hub, and faint stars twinkling on their own clocks
function scr_draw_title_sky(_gw, _gh, _t) {
	// the dark: near-black with a violet tint, covering the hub entirely
	draw_set_alpha(1);
	draw_set_color(make_color_rgb(8, 5, 14));
	draw_rectangle(0, 0, _gw, _gh, false);

	gpu_set_blendmode(bm_add);
	// faint stars, each twinkling on its own clock
	for (var i = 0; i < 90; i++) {
		var _sx = scr_coven_hash(i * 3.17) * _gw, _sy = scr_coven_hash(i * 7.91) * _gh;
		var _tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * (0.6 + scr_coven_hash(i * 1.3) * 1.4) + i));
		draw_set_alpha(_tw * (0.25 + 0.5 * scr_coven_hash(i * 5.3)));
		draw_set_color(merge_color(c_white, make_color_rgb(200, 170, 255), scr_coven_hash(i * 9.1)));
		draw_point(_sx, _sy);
		if (scr_coven_hash(i * 2.2) > 0.85) draw_rectangle(_sx - 1, _sy - 1, _sx + 1, _sy + 1, false);
	}

	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
}

// the save screen (placeholder): the saves in the middle, Munin (her raven) perched on the left, and the Hexweaver on the
// right, smaller, firing her wand toward the saves
function scr_draw_slots_backdrop() {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	var _t  = current_time / 1000;
	var _u  = _gh / 720;
	scr_draw_title_sky(_gw, _gh, _t);
	gpu_set_blendmode(bm_add);
	draw_set_alpha(0.16);
	draw_circle_color(_gw * 0.82, _gh * 0.55, 200 * _u, CURSE_VIOLET, c_black, false);   // her light
	draw_circle_color(_gw * 0.18, _gh * 0.55, 160 * _u, make_color_rgb(90, 110, 170), c_black, false);   // a cooler light on Munin
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	// Munin, facing the saves
	var _rv = asset_get_index("spr_fam_raven_idle");
	if (_rv >= 0) draw_sprite_ext(_rv, (_t * 3.5) mod sprite_get_number(_rv), _gw * 0.18, _gh * 0.55, 1.6 * _u, 1.6 * _u, 0, c_white, 1);
	// the Hexweaver, casting toward them
	var _wx = _gw * 0.82, _wy = _gh * 0.55;
	var _ws = asset_get_index("spr_player_witch1_idle_left_fire");
	if (_ws < 0) _ws = asset_get_index("spr_player_witch1_idle_left");
	if (_ws >= 0) draw_sprite_ext(_ws, (_t * 8) mod sprite_get_number(_ws), _wx, _wy, 3.5 * _u, 3.5 * _u, 0, c_white, 1);
	// her arcane missiles (the Arcane Wand's own sprite) flying left from her wand, fading before they reach the saves
	var _ms = asset_get_index("spr_wand_arcane_primary");
	for (var i = 0; i < 4; i++) {
		var _bk = frac(_t * 0.9 + i / 4);
		var _bx = _wx - 60 * _u - _bk * _gw * 0.22, _by = _wy + 6 * _u + sin(_bk * 9 + i) * 4 * _u;
		var _ba = sin(_bk * pi);
		if (_ms >= 0) draw_sprite_ext(_ms, (_t * 15 + i * 4) mod sprite_get_number(_ms), _bx, _by, 0.6 * _u, 0.6 * _u, 180, c_white, _ba);
		else { gpu_set_blendmode(bm_add); draw_set_alpha(_ba); draw_circle_color(_bx, _by, 6 * _u, make_color_rgb(235, 215, 255), CURSE_VIOLET, false); }
	}
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	draw_set_color(c_white);
}


// Stable pseudo-random values for decorative title-screen stars and sigil glyphs.
function scr_coven_hash(_n) { return frac(abs(sin(_n * 12.9898) * 43758.5453)); }

// Coven sigil artwork, shared by the title screen and curse effects.
// _squash flattens it (1 = facing us, ~0.35 = lying on the floor). _rot is its clock, in degrees: each layer turns
// slowly off it, alternating direction. _alpha fades the whole thing.
//
// the design follows real ceremonial magic circles (the grimoire kind): rings of script, a star at the heart.
//   - the outer band: a double ring, then a ring of witch's script (curling glyphs, a wave of light reading them)
//   - a seven-pointed star {7/2} (the witch's or faery star) inside a faint heptagon, with a seal at each point
//     holding one of the seven classical planets' symbols (sun, moon, Mercury, Venus, Mars, Jupiter, Saturn:
//     the old occult correspondence for seven)
//   - a beaded ring, then a pentagram turning the other way
//   - at the heart: the triple moon (waxing, full, waning), which stays upright
// THE PALETTE: her curse's color identity lives in these three lines (deep glow, main line, hot core)
// _prog (optional, 0 to 1) draws it in: the outer rings sweep around first, then the script, the star, its seals, the
// pentagram, and the moon last. 1 (the default) is the whole sigil
function scr_draw_coven_sigil(_x, _y, _r, _squash, _rot, _alpha, _prog = 1) {
	var _pk = function(_p, _a, _b) { return clamp((_p - _a) / (_b - _a), 0, 1); };   // how far one layer has drawn in
	var _cglow = make_color_rgb(150, 30, 190);   // deep magenta-violet: the wide soft glow
	var _cline = make_color_rgb(220, 90, 255);   // magenta-violet: the lines themselves
	var _ccore = make_color_rgb(255, 225, 250);  // pinkish white: the hottest centers of the lines
	var _t = current_time / 1000;
	var _a7 = _rot * 0.6, _a5 = -_rot * 0.9;     // the star's turn, and the pentagram's (the other way)
	var _r7 = _r * 0.76, _rs = _r * 0.085;       // the star's points, and the size of each seal

	gpu_set_blendmode(bm_add);
	// the halo: a soft disc of her color behind everything (squashed with the sigil)
	draw_set_alpha(0.18 * _alpha * _prog);
	draw_ellipse_color(_x - _r * 1.25, _y - _r * 1.25 * _squash, _x + _r * 1.25, _y + _r * 1.25 * _squash, _cglow, c_black, false);

	// three passes per shape: wide dim glow, medium line, thin hot core. that layering is what makes it read as light
	for (var _pass = 0; _pass < 3; _pass++) {
		var _lw = [8, 3, 1][_pass];
		var _al = [0.30, 0.75, 0.9][_pass] * _alpha;
		var _tw = max(1, _lw * 0.6);             // thin strokes (script, seals)
		draw_set_color([_cglow, _cline, _ccore][_pass]);
		draw_set_alpha(_al);

		// the outer band: double ring, the script, and the ring that holds it
		var _k1 = _pk(_prog, 0, 0.3), _k2 = _pk(_prog, 0.2, 0.5), _k3 = _pk(_prog, 0.35, 0.65);
		var _k4 = _pk(_prog, 0.55, 0.8), _k5 = _pk(_prog, 0.65, 0.9), _k6 = _pk(_prog, 0.85, 1);
		if (_k1 > 0) {
			scr_coven_sigil_arc(_x, _y, _r,        _rot, _rot + 360 * _k1, _squash, _lw, max(1, round(64 * _k1)));
			scr_coven_sigil_arc(_x, _y, _r * 0.94, _rot, _rot - 360 * _k1, _squash, max(1, _lw - 1), max(1, round(64 * _k1)));
			scr_coven_sigil_arc(_x, _y, _r7,       _rot, _rot + 360 * _k1, _squash, max(1, _lw - 1), max(1, round(64 * _k1)));
		}
		if (_pass > 0 && _k2 > 0) { draw_set_alpha(_al * _k2); scr_coven_sigil_runes(_x, _y, _r, _squash, _rot * 0.3, _tw, _t, _al * _k2); draw_set_alpha(_al); }

		// the seven-pointed star {7/2} and its faint heptagon
		for (var k = 0; k < 7; k++) {
			var _p1 = _a7 + 90 + k * 360 / 7, _p2 = _p1 + 2 * 360 / 7, _p3 = _p1 + 360 / 7;
			if (_k3 <= 0) break;
			var _x1 = _x + lengthdir_x(_r7, _p1), _y1 = _y + lengthdir_y(_r7, _p1) * _squash;
			var _x2 = _x + lengthdir_x(_r7, _p2), _y2 = _y + lengthdir_y(_r7, _p2) * _squash;
			draw_line_width(_x1, _y1, lerp(_x1, _x2, _k3), lerp(_y1, _y2, _k3), _lw);
			draw_set_alpha(_al * 0.4 * _k3);
			draw_line_width(_x1, _y1, _x + lengthdir_x(_r7, _p3), _y + lengthdir_y(_r7, _p3) * _squash, max(1, _lw - 1));
			draw_set_alpha(_al);
		}
		// the seals at its points, each with a planet's symbol (kept upright, so they read)
		for (var k = 0; k < 7; k++) {
			var _p1 = _a7 + 90 + k * 360 / 7;
			var _sx = _x + lengthdir_x(_r7, _p1), _sy = _y + lengthdir_y(_r7, _p1) * _squash;
			if (_k4 <= 0) break;
			draw_set_alpha(_al * _k4);
			scr_coven_sigil_ring(_sx, _sy, _rs, _squash, 0, max(1, _lw - 1), 20);
			if (_pass > 0) scr_coven_sigil_planet(_sx, _sy, _rs * 0.7, _squash, k, _tw);
			draw_set_alpha(_al);
		}

		// the beaded ring, then the pentagram in its circle
		var _r5 = _r * 0.44;
		draw_set_alpha(_al * _k5);
		if (_pass > 0 && _k5 > 0) for (var k = 0; k < 36 * _k5; k++) {
			var _ba = _a5 * 0.5 + k * 10;
			draw_circle(_x + lengthdir_x(_r * 0.49, _ba), _y + lengthdir_y(_r * 0.49, _ba) * _squash, max(1, _r * 0.008 + _lw * 0.3), false);
		}
		scr_coven_sigil_ring(_x, _y, _r5, _squash, _a5, max(1, _lw - 1), 48);
		for (var k = 0; k < 5; k++) {
			var _p1 = _a5 + 90 + k * 72, _p2 = _p1 + 144;
			draw_line_width(_x + lengthdir_x(_r5, _p1), _y + lengthdir_y(_r5, _p1) * _squash,
			                _x + lengthdir_x(_r5, _p2), _y + lengthdir_y(_r5, _p2) * _squash, _lw);
		}

		// the triple moon at the heart: a full moon between a waxing and a waning crescent (always upright)
		draw_set_alpha(_al * _k6);
		var _m = _r * 0.075;
		scr_coven_sigil_ring(_x, _y, _m, _squash, 0, max(1, _lw - 1), 20);
		for (var _side = -1; _side <= 1; _side += 2) {
			var _cx = _x + _side * _m * 2.1;
			// the outer edge: a half circle bulging away from the full moon
			scr_coven_sigil_arc(_cx, _y, _m, (_side > 0) ? -90 : 90, (_side > 0) ? 90 : 270, _squash, max(1, _lw - 1), 10);
			// the inner edge: a wider, shallower arc through the same two tips (its center 1.25m behind)
			scr_coven_sigil_arc(_cx - _side * 1.254 * _m, _y, _m * 1.604, (_side > 0) ? -38.6 : 141.4, (_side > 0) ? 38.6 : 218.6, _squash, max(1, _lw - 1), 8);
		}
	}
	// the full moon's glow, breathing
	var _cb = (0.6 + 0.4 * sin(_t * 1.5)) * _pk(_prog, 0.85, 1);
	draw_set_alpha(0.45 * _cb * _alpha);
	draw_circle_color(_x, _y, _r * 0.14, _cline, c_black, false);
	// the spark: a bright point racing around the outer ring, with a fading tail
	for (var k = 0; k < 10; k++) {
		var _sa = _t * 140 - k * 3;
		draw_set_alpha((1 - k / 10) * 0.9 * _alpha * _pk(_prog, 0.25, 0.35));
		draw_set_color(k == 0 ? _ccore : _cline);
		draw_circle(_x + lengthdir_x(_r * 0.97, _sa), _y + lengthdir_y(_r * 0.97, _sa) * _squash, max(1, _r * 0.02 * (1 - k / 12)), false);
	}
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	draw_set_color(c_white);
}

// one ring of the sigil, as _n segments (the caller sets color and alpha)
function scr_coven_sigil_ring(_x, _y, _rr, _squash, _rot, _lw, _n) {
	scr_coven_sigil_arc(_x, _y, _rr, _rot, _rot + 360, _squash, _lw, _n);
}

// an arc from angle _a1 to _a2 (degrees), as _n segments
function scr_coven_sigil_arc(_x, _y, _rr, _a1, _a2, _squash, _lw, _n) {
	var _px = _x + lengthdir_x(_rr, _a1), _py = _y + lengthdir_y(_rr, _a1) * _squash;
	for (var q = 1; q <= _n; q++) {
		var _a = lerp(_a1, _a2, q / _n);
		var _nx = _x + lengthdir_x(_rr, _a), _ny = _y + lengthdir_y(_rr, _a) * _squash;
		draw_line_width(_px, _py, _nx, _ny, _lw);
		_px = _nx; _py = _ny;
	}
}

// a polyline in a seal's local space: _pts = [x0, y0, x1, y1, ...] in -1..1 (y down), scaled by _s
function scr_coven_sigil_poly(_x, _y, _s, _squash, _pts, _lw) {
	for (var i = 2; i < array_length(_pts); i += 2)
		draw_line_width(_x + _pts[i - 2] * _s, _y + _pts[i - 1] * _s * _squash, _x + _pts[i] * _s, _y + _pts[i + 1] * _s * _squash, _lw);
}

// the seven classical planets' symbols, simplified to strokes. _k: 0 sun, 1 moon, 2 Mercury, 3 Venus, 4 Mars, 5 Jupiter, 6 Saturn
function scr_coven_sigil_planet(_x, _y, _s, _squash, _k, _lw) {
	switch (_k) {
		case 0: // sun: a circle with a point at its center
			scr_coven_sigil_ring(_x, _y, _s * 0.7, _squash, 0, _lw, 14);
			draw_circle(_x, _y, max(1, _lw), false);
			break;
		case 1: // moon: a crescent
			scr_coven_sigil_arc(_x, _y, _s * 0.75, 90, 270, _squash, _lw, 8);
			scr_coven_sigil_arc(_x + _s * 0.94, _y, _s * 1.2, 141.4, 218.6, _squash, _lw, 6);
			break;
		case 2: // Mercury: horns over a circle over a cross
			scr_coven_sigil_ring(_x, _y - _s * 0.05, _s * 0.35, _squash, 0, _lw, 12);
			scr_coven_sigil_arc(_x, _y - _s * 0.75, _s * 0.3, 180, 360, _squash, _lw, 6);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [0, 0.3, 0, 0.95], _lw);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [-0.28, 0.65, 0.28, 0.65], _lw);
			break;
		case 3: // Venus: a circle over a cross
			scr_coven_sigil_ring(_x, _y - _s * 0.3, _s * 0.42, _squash, 0, _lw, 12);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [0, 0.12, 0, 0.95], _lw);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [-0.3, 0.55, 0.3, 0.55], _lw);
			break;
		case 4: // Mars: a circle with an arrow
			scr_coven_sigil_ring(_x - _s * 0.15, _y + _s * 0.15, _s * 0.42, _squash, 0, _lw, 12);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [0.15, -0.15, 0.7, -0.7], _lw);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [0.3, -0.7, 0.7, -0.7, 0.7, -0.3], _lw);
			break;
		case 5: // Jupiter: the curled 4
			scr_coven_sigil_poly(_x, _y, _s, _squash, [-0.5, -0.55, -0.15, -0.6, 0.0, -0.35, -0.55, 0.25, 0.6, 0.25], _lw);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [0.3, -0.7, 0.3, 0.8], _lw);
			break;
		case 6: // Saturn: a cross with a hooked tail
			scr_coven_sigil_poly(_x, _y, _s, _squash, [-0.35, -0.55, 0.25, -0.55], _lw);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [-0.1, -0.85, -0.1, 0.25], _lw);
			scr_coven_sigil_poly(_x, _y, _s, _squash, [-0.1, -0.1, 0.25, -0.2, 0.42, 0.08, 0.18, 0.42, 0.32, 0.8], _lw);
			break;
	}
}

// The Coven sigil inscription uses a deterministic decorative glyph alphabet. Every letter has
// one fixed glyph, built from a stem or a sweeping curve, a curl or hook, and sometimes a tail or a dot, chosen by a hash of
// the letter itself, so the same letter always looks the same and the band really spells something. spaces are small dots,
// and a larger dot marks where the inscription begins and ends.
// THE INSCRIPTION: "AS ABOVE SO BELOW", the Hermetic maxim from the Emerald Tablet: what happens in the heavens mirrors what
// happens on earth. The inscription reflects the Coven's celestial and earthly themes.
#macro COVEN_SIGIL_TEXT "AS ABOVE SO BELOW"
function scr_coven_sigil_runes(_x, _y, _R, _squash, _rot, _lw, _t, _al) {
	var _rmid = _R * 0.85, _hu = _R * 0.05, _hv = _R * 0.04;     // band center, glyph half-height and half-width
	var _txt = COVEN_SIGIL_TEXT + " ";                             // the extra space is where the start-and-end mark sits
	var _n = string_length(_txt);
	for (var k = 0; k < _n; k++) {
		var _a  = _rot - k * 360 / _n;                               // read clockwise around the ring
		var _ax = lengthdir_x(1, _a), _ay = lengthdir_y(1, _a);    // outward (the glyph's "up")
		var _px = -_ay, _py = _ax;                                   // along the band
		var _mx = _x + _ax * _rmid, _my = _y + _ay * _rmid * _squash;
		var _wave = power(max(0, dcos(_a - _t * 50)), 6);         // the reading wave
		draw_set_alpha(_al * (0.55 + 0.45 * _wave));
		var _ch = string_char_at(_txt, k + 1);
		if (_ch == " ") {                                            // a word break: a small dot (the last one, a larger mark)
			draw_circle(_mx, _my, max(1, _lw * ((k == _n - 1) ? 1.8 : 0.8)), (k == _n - 1));
			continue;
		}
		var _c = ord(_ch) * 1.618 + 7;                               // this letter's seed: the same glyph every time it appears
		var _h1 = scr_coven_hash(_c * 5.1 + 2), _h2 = scr_coven_hash(_c * 9.3 + 1), _h3 = scr_coven_hash(_c * 3.7 + 8), _h4 = scr_coven_hash(_c * 7.7 + 3);
		var _sv = (_h2 - 0.5) * 0.8;                                // where along the glyph its stem stands
		// 1) the backbone: a straight stem, or a big sweeping curve
		if (_h1 < 0.5) scr_coven_sigil_glyph_line(_mx, _my, _ax, _ay, _px, _py, _hu, _hv, _squash, -1, _sv, 1, _sv, _lw);
		else scr_coven_sigil_glyph_arc(_mx, _my, _ax, _ay, _px, _py, _hu, _hv, _squash, 0, 0, 0.8, _h2 * 360, _h2 * 360 + 160 + _h3 * 110, _lw);
		// 2) a curl or hook hanging off the top or bottom
		var _cu = (_h3 < 0.5) ? 0.65 : -0.65;
		scr_coven_sigil_glyph_arc(_mx, _my, _ax, _ay, _px, _py, _hu, _hv, _squash, _cu, _sv + 0.35, 0.35, _h4 * 360, _h4 * 360 + 200, _lw);
		// 3) sometimes a tail or crossing stroke
		if (_h4 < 0.6) scr_coven_sigil_glyph_line(_mx, _my, _ax, _ay, _px, _py, _hu, _hv, _squash, -0.2 + _h1 * 0.4, -0.9, 0.3 - _h3 * 0.8, 0.9, _lw);
		// 4) sometimes a dot above it
		if (_h2 > 0.65) draw_circle(_mx + _ax * _hu * 1.35, _my + _ay * _hu * 1.35 * _squash, max(1, _lw), false);
	}
}

// glyph helpers: (u, v) is the glyph's local space, u = up (outward), v = along the band, both -1..1
function scr_coven_sigil_glyph_line(_mx, _my, _ax, _ay, _px, _py, _hu, _hv, _squash, _u1, _v1, _u2, _v2, _lw) {
	draw_line_width(_mx + _ax * _u1 * _hu + _px * _v1 * _hv, _my + (_ay * _u1 * _hu + _py * _v1 * _hv) * _squash,
	                _mx + _ax * _u2 * _hu + _px * _v2 * _hv, _my + (_ay * _u2 * _hu + _py * _v2 * _hv) * _squash, _lw);
}
function scr_coven_sigil_glyph_arc(_mx, _my, _ax, _ay, _px, _py, _hu, _hv, _squash, _uc, _vc, _rad, _a1, _a2, _lw) {
	var _lx = 0, _ly = 0;
	for (var q = 0; q <= 8; q++) {
		var _th = lerp(_a1, _a2, q / 8);
		var _u = _uc + _rad * dsin(_th), _v = _vc + _rad * dcos(_th);
		var _sx = _mx + _ax * _u * _hu + _px * _v * _hv, _sy = _my + (_ay * _u * _hu + _py * _v * _hv) * _squash;
		if (q > 0) draw_line_width(_lx, _ly, _sx, _sy, _lw);
		_lx = _sx; _ly = _sy;
	}
}
