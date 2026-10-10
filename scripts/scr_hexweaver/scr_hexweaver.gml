// The Hexweaver: spread hexes that ripen into toads, 
//with the ultimate ability to tear away the fabric of space, turning your enemies into stars in your galaxy

#macro HEX_VIOLET make_color_rgb(170, 90, 255)
#macro HEX_COLLAPSE_MASS 150 // how much one star must swallow before it caves in. the main knob
#macro HEX_MAX_HOLES     3   // black holes allowed per run
#macro HEX_HOLE_SPACING  500 // black holes must be at least this far apart, so they're spread across her sky
#macro HEX_HOLE_MIN_DIST 250 // and at least this far from her
#macro HEX_GATHER floor(game_get_speed(gamespeed_fps) * 1.5) // frames a dying star spends gathering in before it collapses
#macro HEX_STAR_SOFTEN 0.35 // 0 = full colour, 1 = all white. how much the star colours are washed toward white
#macro HEX_MASS_BLUE 64    // the mass at which a star burns fully blue. lower = bluer skies, higher = redder
#macro HEX_HAZE_CAP 1500   // the most haze wisps her sky keeps. past this, the oldest make way


// her power will scale from tiers 1 to 4, growing with how many enemies you unmake each run
function scr_hex_tier() {
	var _u = variable_global_exists("hex_unmade") ? global.hex_unmade : 0;
	return 1 + (_u >= 50) + (_u >= 200) + (_u >= 600);
}

// seconds for a curse to fully ripen, getting faster with continued ascension
function scr_hex_ripen_time() {
	var _times = [4, 3, 2, 1];
	return scr_stat("hex_ripen_time", _times[scr_hex_tier() - 1]);
}

// pile hex onto an enemy. toads (hex - 1) are already as cursed as it gets
function scr_hex_apply(_e, _amount) {
	if (_e.hex < 0) return;
	_e.hex = min(1, max(_e.hex, 0) + _amount);
}

// who can be turned: everyone small from the start, elites at tier 3, bosses at tier 4
function scr_hex_can_toad(_e) {
	var _tier = scr_hex_tier();
	if (_e.is_boss) return _tier >= 4;
	if (_e.is_elite) return _tier >= 3;
	return true;
}

//the curse completes: the enemy becomes a toad that carries its souls and drops
function scr_hex_toadify(_e) {
	var _t = instance_create_layer(_e.x, _e.y, "Instances", obj_toad);
	_t.soul_value	= _e.soul_value;
	_t.drop_chance	= _e.drop_chance;
	_t.is_elite		= _e.is_elite;
	_t.is_boss		= _e.is_boss;
	_t.elite_drop	= _e.elite_drop;
	part_particles_create(global.ps_sparks, _e.x, _e.y, global.pt_aura, 5);
	instance_destroy(_e);
}

// POP: the toad bursts. once she's ascended a little, the burst splashes hex onto everything nearby, spreading the curse
function scr_toad_pop(_toad) {
	var _x = _toad.x, _y = _toad.y;
	var _tier = scr_hex_tier();

	// no spreading at base power: it switches on at tier 2 (or from an item), and reaches further each tier after
	var _spread = scr_stat("hex_spread", (_tier >= 2) ? 1 : 0);
	var _r = (15 + 8 * _tier) * WORLD_SCALE;
	if (_spread > 0) {
		var _list = ds_list_create();
		var _n = collision_circle_list(_x, _y, _r, obj_enemy_parent, false, true, _list, false);
		for (var i = 0; i < _n; i++) scr_hex_apply(_list[| i], scr_stat("hex_splash", 0.5) * _spread);
		ds_list_destroy(_list);
		scr_burst_fx(_x, _y, _r, HEX_VIOLET, 10); // a big violet splash so you can see the curse jump
	} else {
		scr_burst_fx(_x, _y, 12 * WORLD_SCALE, make_color_rgb(110, 180, 80), 6); // just a little green pop
	}

	_toad.popping =  true;
	scr_damage_enemy(_toad, _toad.hp + 1, HEX_VIOLET, false); // counts as a kill: souls, essence, ult charge
}
// E: Hex, a crackling wave of chaotic hex enery rolling out from the witch
function scr_hex(_caster) {
	var _radii = [120, 150, 190, 240];
	var _w = instance_create_layer(_caster.x, _caster.y, "Instances", obj_hex_wave);
	_w.max_r	 = scr_stat("hex_radius", _radii[scr_hex_tier() - 1]) * WORLD_SCALE;
	_w.hex_amt   = scr_stat("hex_strength", 0.35);
	_w.dmg		 = scr_stat("ability_damage", 20);
	global.shake = max(global.shake, 2);
}

// Q: Unmaking, the world falls away and every enemy on the screen is erased into a star in her sky
function scr_unmaking(_caster) {
	if (instance_exists(obj_unmaking)) return; // one realm at a time
	instance_create_depth(0, 0, -100000, obj_unmaking);
}


// an enemy ignites: it becomes a star in her sky, and her ascension grows
function scr_unmake(_e) {
	var _tier_before = scr_hex_tier();
	if (!variable_instance_exists(_e, "star_plan")) scr_hex_plan_star(_e, instance_exists(obj_unmaking) ? obj_unmaking.sky_angle : 0);

	global.hex_unmade += _e.star_hexed ? 3 : 1; // her own cursed work feeds her ascension more (still counts per enemy)
	var _big = (_e.is_elite || _e.is_boss);

	// the first to arrive gives birth to the star; everyone after condenses into it
	var _p = _e.star_plan;
	var _merged = (_p.idx >= 0);
	var _size;
	var _ph;
	if (!_merged) {
		_ph = random(1000);
		array_push(global.hex_stars, { ox: _p.ox, oy: _p.oy, s: _p.s, ph: _ph, hx: _e.star_hexed, big: _big, m: _e.star_hexed ? 3 : 1 });
		_p.idx = array_length(global.hex_stars) - 1;
		_size = _p.s;
	} else {
		var _st = global.hex_stars[_p.idx];
		_st.s   = min(4.5, _st.s + 0.35);  // bigger and brighter with each one, up to a cap
		_st.hx  = _st.hx || _e.star_hexed;
		_st.big = _st.big || _big;
		_st.m  += _e.star_hexed ? 3 : 1; // mass: how much of her dead this star holds
		_size   = _st.s;
		_ph		= _st.ph; 
	}

	// tell the realm a star was just born (or fed), so it can flash
	if (instance_exists(obj_unmaking)) {
		with (obj_unmaking) array_push(ignitions, { ox: _p.ox, oy: _p.oy, t0: t, big: _big, s: _size, merged: _merged, c: scr_hex_star_colour(_ph) });
		global.shake = min(global.shake + 0.25, 4); // each ignition adds a little, so a big cascade builds into a rumble
	}

	_e.popping = true;
	scr_damage_enemy(_e, _e.hp + 1, HEX_VIOLET, false); // still a kill: souls, essence, charge

	var _tier_now = scr_hex_tier();
	if (_tier_now > _tier_before) {
		global.toast = { text: "ASCENSION", sub: "The Hexweaver's power grows (tier " + string(_tier_now) + ")", color: HEX_VIOLET, timer: game_get_speed(gamespeed_fps) * 3 };
		global.shake = max(global.shake, 8);
	}
}

// a star's colour from its random phase: mostly whites and blue-whites like a real sky,
// with warm yellow, orange and red glints, and the odd violet one that's hers
function scr_hex_star_colour(_ph) {
	var _p = scr_hash(_ph * 0.37 + 11);
	var _c;
	if      (_p < 0.22) _c = make_color_rgb(255, 250, 240); // white
	else if (_p < 0.42) _c = make_color_rgb(175, 205, 255); // blue-white
	else if (_p < 0.54) _c = make_color_rgb(120, 155, 255); // hot blue
	else if (_p < 0.68) _c = make_color_rgb(255, 225, 160); // yellow
	else if (_p < 0.82) _c = make_color_rgb(255, 165, 90);  // orange
	else if (_p < 0.92) _c = make_color_rgb(255, 105, 80);  // red
	else                _c = make_color_rgb(200, 140, 255); // her violet
	return merge_color(_c, c_white, HEX_STAR_SOFTEN);     // the knob: a touch of white takes the edge off
}
// decides, at the moment she casts, where this enemy's star will sit in her sky.
// crowded enemies share a star instead of smearing into a clump
function scr_hex_plan_star(_e, _sky_angle) {
	var _dx = _e.x - obj_player.x, _dy = _e.y - obj_player.y;
	var _a = point_direction(0, 0, _dx, _dy) - _sky_angle;
	var _l = point_distance(0, 0, _dx, _dy);
	var _sx = lengthdir_x(_l, _a), _sy = lengthdir_y(_l, _a);
	// scatter, so a tightly packed horde doesn't make a grid of stars
	var _jd = power(random(1), 1.5) * 45, _jdir = random(360);
	_sx += lengthdir_x(_jd, _jdir);
	_sy += lengthdir_y(_jd, _jdir);
	var _spread = random_range(1, 1.3);
	_sx *= _spread;
	_sy *= _spread;

	// a clear space around her, so she isn't buried in her own starlight
	var _d = point_distance(0, 0, _sx, _sy);
	if (_d < 60) {
		var _pd = (_d > 0.01) ? point_direction(0, 0, _sx, _sy) : random(360);
		var _push = 60 + random(25); // scatter along a ring instead of one perfect circle
		_sx = lengthdir_x(_push, _pd);
		_sy = lengthdir_y(_push, _pd);
	}

	_e.star_hexed = (_e.hex != 0);

	// condense: only look in the 3x3 block of 20px cells around this spot, not at every star planned so far
	var _grid = instance_exists(obj_unmaking) ? obj_unmaking.plan_grid : undefined;
	var _plan = undefined;
	if (!is_undefined(_grid)) {
		var _gx = floor(_sx / 20), _gy = floor(_sy / 20);
		for (var _cx = _gx - 1; _cx <= _gx + 1 && is_undefined(_plan); _cx++) {
			for (var _cy = _gy - 1; _cy <= _gy + 1 && is_undefined(_plan); _cy++) {
				var _cell = _grid[$ string(_cx) + "," + string(_cy)];
				if (is_undefined(_cell)) continue;
				for (var i = 0; i < array_length(_cell); i++) {
					var _p = _cell[i];
					if (point_distance(_p.ox, _p.oy, _sx, _sy) < 20) { _plan = _p; break; }
				}
			}
		}
	}
	if (is_undefined(_plan)) {
		_plan = { ox: _sx, oy: _sy, s: 0.6 + power(random(1), 2.5) * 1.6 + (_e.star_hexed ? 0.8 : 0), idx: -1 };
		if (!is_undefined(_grid)) {
			var _key = string(floor(_sx / 20)) + "," + string(floor(_sy / 20));
			var _home = _grid[$ _key];
			if (is_undefined(_home)) { _home = []; _grid[$ _key] = _home; }
			array_push(_home, _plan);
		}
	}
	_e.star_plan = _plan; // structs are shared by reference, so every enemy in a clump points at the SAME plan
	_e.star_ox = _plan.ox;
	_e.star_oy = _plan.oy;
}

// stretches an array of noise so its lowest value becomes 0 and its highest becomes 1.
// layered noise bunches up around the middle, so without this the thickest, brightest colours almost never appear
function scr_normalize_array(_a) {
	var _lo = infinity, _hi = -infinity, _n = array_length(_a);
	for (var i = 0; i < _n; i++) { _lo = min(_lo, _a[i]); _hi = max(_hi, _a[i]); }
	var _span = max(_hi - _lo, 0.0001);
	for (var i = 0; i < _n; i++) _a[i] = (_a[i] - _lo) / _span;
	return _a;
}

// ---------- her space: noise, nebula and stars ----------

// a repeatable "random" number from 0 to 1: the same input always gives the same answer.
// abs() keeps it positive, since frac() of a negative number is negative (the bug from the beam!)
function scr_hash(_n) { return frac(abs(sin(_n * 12.9898) * 43758.5453)); }

// folds any number back into 0..1 like a mirror (1.2 -> 0.8, -0.3 -> 0.3), so ground past the photo's
// edge reflects the ground just inside it: no seam, no smear, just more of the same field
function scr_mirror01(_f) {
	_f = abs(_f);
	var _k = _f mod 2;
	return (_k > 1) ? 2 - _k : _k;
}

// a 64x64 grid of random values, the raw material for smooth noise. the same seed always makes the same grid
function scr_noise_grid(_seed) {
	random_set_seed(_seed);
	var _g = array_create(64 * 64);
	for (var i = 0; i < 64 * 64; i++) _g[i] = random(1);
	randomize(); // hand proper randomness back to the rest of the game
	return _g;
}

// smooth value noise: blends the four grid values around a point, eased so there are no hard creases
function scr_vnoise(_g, _x, _y) {
	var _xi = floor(_x), _yi = floor(_y);
	var _xf = _x - _xi, _yf = _y - _yi;
	_xf = _xf * _xf * (3 - 2 * _xf);
	_yf = _yf * _yf * (3 - 2 * _yf);
	var _x0 = _xi & 63, _y0 = _yi & 63;           // & 63 wraps around the 64-wide grid
	var _x1 = (_x0 + 1) & 63, _y1 = (_y0 + 1) & 63;
	var _a = _g[_x0 + _y0 * 64], _b = _g[_x1 + _y0 * 64];
	var _c = _g[_x0 + _y1 * 64], _d = _g[_x1 + _y1 * 64];
	return lerp(lerp(_a, _b, _xf), lerp(_c, _d, _xf), _yf);
}

// fBm: layers of noise, each twice as detailed and half as strong, like big cloud shapes with small wisps
function scr_fbm(_g, _x, _y, _oct) {
	var _sum = 0, _amp = 0.5, _norm = 0;
	repeat (_oct) {
		_sum += _amp * scr_vnoise(_g, _x, _y);
		_norm += _amp;
		_x = _x * 2 + 17.3; // the offset stops every layer lining up at the same spot
		_y = _y * 2 + 9.1;
		_amp *= 0.5;
	}
	return _sum / _norm;
}

// the expensive part, done once per run: raw noise for the nebula's gas, dust and colour, stored in arrays
function scr_hex_nebula_fields(_seed) {
	var _w = 128, _h = 128;
	var _gn = scr_noise_grid(_seed), _wn = scr_noise_grid(_seed + 1);
	var _dn = scr_noise_grid(_seed + 2), _tn = scr_noise_grid(_seed + 3);
	var _gas = array_create(_w * _h), _dust = array_create(_w * _h), _tint = array_create(_w * _h);

	for (var py = 0; py < _h; py++) {
		for (var px = 0; px < _w; px++) {
			var _u = px / _w * 4, _v = py / _w * 4; // same scale on both axes so the clouds aren't stretched
			// domain warp: bend the coordinates with one noise before sampling another, which makes billowing wisps
			var _wx = scr_fbm(_wn, _u, _v, 3);
			var _wy = scr_fbm(_wn, _u + 5.2, _v + 1.3, 3);
			var _i = px + py * _w;
			_gas[_i]  = scr_fbm(_gn, _u + _wx * 2.2, _v + _wy * 2.2, 4);
			_dust[_i] = scr_fbm(_dn, _u * 1.6 + _wx, _v * 1.6 + _wy, 4);
			_tint[_i] = scr_vnoise(_tn, _u * 1.2, _v * 1.2);
		}
	}
	_gas = scr_normalize_array(_gas);
	_dust = scr_normalize_array(_dust);
	return { w: _w, h: _h, gas: _gas, dust: _dust, tint: _tint };
}

// the cheap part, done each cast: colour the stored noise for how far she's ascended, and bake it into a sprite
function scr_hex_build_nebula(_cover, _bright) {
	var _f = global.hex_neb;
	var _gas = _f.gas, _dust = _f.dust, _tint = _f.tint;
	// two families of colour like the references: violet-magenta clouds, and deep blue-teal clouds
	var _v0 = make_color_rgb(30, 10, 75), _v1 = make_color_rgb(125, 45, 215), _v2 = make_color_rgb(235, 90, 225);
	var _b0 = make_color_rgb(10, 18, 70), _b1 = make_color_rgb(40, 80, 200),  _b2 = make_color_rgb(70, 190, 230);
	var _core = make_color_rgb(250, 225, 255);
	var _gold = make_color_rgb(240, 180, 110);

	var _surf = surface_create(_f.w, _f.h);
	surface_set_target(_surf);
	draw_clear_alpha(c_black, 1);
	for (var py = 0; py < _f.h; py++) {
		for (var px = 0; px < _f.w; px++) {
			var _i = px + py * _f.w;
			var _d = clamp((_gas[_i] - _cover) / (1 - _cover), 0, 1);
			if (_d <= 0) continue;

			// each family runs from dark at the thin edges to bright in the thick middles
			var _cv = (_d < 0.5) ? merge_color(_v0, _v1, _d * 2) : merge_color(_v1, _v2, (_d - 0.5) * 2);
			var _cb = (_d < 0.5) ? merge_color(_b0, _b1, _d * 2) : merge_color(_b1, _b2, (_d - 0.5) * 2);
			// the tint noise decides which family a region belongs to, blending where they meet.
			// it never goes fully blue, so a little of her violet stays everywhere: it's her space
			var _mix = clamp((_tint[_i] - 0.35) / 0.3, 0, 1);
			var _col = merge_color(_cv, _cb, _mix * 0.85);

			// the very thickest gas glows almost white, like the hot hearts of real nebulae
			if (_d > 0.8) _col = merge_color(_col, _core, (_d - 0.8) * 2.5);

			// dust: darken FIRST, then light the edges, so the warm rim isn't swallowed by the dark
			var _lane = clamp((_dust[_i] - 0.55) / 0.2, 0, 1);
			var _rim  = _lane * (1 - _lane) * 4;
			_col = merge_color(_col, c_black, _lane * 0.85);
			_col = merge_color(_col, _gold, _rim * 0.5 * _d);

			draw_point_color(px, py, merge_color(c_black, _col, min(1, _d * _bright)));
		}
	}
	surface_reset_target();
	// origin in the middle, so it can spin around her
	var _spr = sprite_create_from_surface(_surf, 0, 0, _f.w, _f.h, false, false, _f.w / 2, _f.h / 2);
	surface_free(_surf);
	return _spr;
}

// how thick the nebula is at a spot on screen (0 to 1), so star dust can gather in the clouds
function scr_hex_neb_density(_sx, _sy, _cover) {
	var _f = global.hex_neb;
	var _gas = _f.gas;
	var _i = clamp(floor(_sx * _f.w), 0, _f.w - 1) + clamp(floor(_sy * _f.h), 0, _f.h - 1) * _f.w;
	return clamp((_gas[_i] - _cover) / (1 - _cover), 0, 1);
}

// a bright star: soft halo, hot core, and thin spikes that fade toward their tips (draw in additive mode)
function scr_draw_star_flare(_x, _y, _size, _col, _a) {
	draw_set_alpha(0.35 * _a);
	draw_circle_color(_x, _y, _size * 3, _col, c_black, false); // halo fades into the void
	draw_set_alpha(_a);
	draw_set_color(merge_color(_col, c_white, 0.35)); // white-hot, but the star's own colour still shows through
	draw_circle(_x, _y, max(1, _size * 0.5), false);           // white-hot core
	for (var k = 0; k < 8; k++) {
		var _len = (k mod 2 == 0) ? _size * 6 : _size * 2;      // long straight spikes, short diagonals
		draw_set_alpha(((k mod 2 == 0) ? 0.9 : 0.4) * _a);
		draw_line_color(_x, _y, _x + lengthdir_x(_len, k * 45), _y + lengthdir_y(_len, k * 45), _col, c_black);
	}
}

// turns on the silhouette shader: every sprite drawn until shader_reset() comes out as a flat-colour shape
function scr_silhouette_begin(_col) {
	shader_set(sh_silhouette);
	var _u = shader_get_uniform(sh_silhouette, "u_colour");
	shader_set_uniform_f(_u, colour_get_red(_col) / 255, colour_get_green(_col) / 255, colour_get_blue(_col) / 255);
}

// draws an instance as a solid-colour silhouette a few pixels out in every direction: a glowing outline
function scr_draw_glow_outline(_inst, _col, _dist, _alpha) {
	with (_inst) {
		if (sprite_index >= 0) {
			scr_silhouette_begin(_col);
			for (var _o = 0; _o < 8; _o++) {
				draw_sprite_ext(sprite_index, image_index, x + lengthdir_x(_dist, _o * 45), y + lengthdir_y(_dist, _o * 45),
					image_xscale, image_yscale, image_angle, c_white, _alpha);
			}
			shader_reset();
		}
	}
}	

// accretion: this cast's newborn stars pull on each other, and any that touch merge into one.
// call it from obj_unmaking (it pushes flashes onto that instance's 'ignitions')
function scr_hex_accrete(_from) {
	var _st = global.hex_stars;
	var _n  = array_length(_st);
	var _G     = 2.5;
	var _reach = 90;

	// copy this cast's living newborns into their own list, sorted left to right.
	// structs are shared by reference, so changing a star in this list changes the real one too
	var _live = [];
	for (var i = _from; i < _n; i++) {
		var _a = _st[i];
		if (_a.s <= 0) continue;
		if (!variable_struct_exists(_a, "vx")) { _a.vx = 0; _a.vy = 0; }
		array_push(_live, _a);
	}
	array_sort(_live, function(_p, _q) { return _p.ox - _q.ox; });
	var _m = array_length(_live);

	// 1) each star only looks rightward, and only until the stars get too far right to matter
	for (var i = 0; i < _m; i++) {
		var _a = _live[i];
		if (_a.s <= 0) continue;
		for (var j = i + 1; j < _m; j++) {
			var _b = _live[j];
			var _dx = _b.ox - _a.ox;
			if (_dx > _reach) break;          // sorted by x: everyone after this is even farther, so stop looking
			if (_b.s <= 0) continue;
			var _dy = _b.oy - _a.oy;
			if (abs(_dy) > _reach) continue;
			var _d2 = _dx * _dx + _dy * _dy;
			var _d  = max(0.01, sqrt(_d2));
			var _ma = _a.s * _a.s, _mb = _b.s * _b.s;

			if (_d < (_a.s + _b.s) * 1.5) {
				var _big = (_ma >= _mb) ? _a : _b, _small = (_ma >= _mb) ? _b : _a;
				var _mm = _ma + _mb;
				_big.ox = (_a.ox * _ma + _b.ox * _mb) / _mm;
				_big.oy = (_a.oy * _ma + _b.oy * _mb) / _mm;
				_big.vx = (_a.vx * _ma + _b.vx * _mb) / _mm;
				_big.vy = (_a.vy * _ma + _b.vy * _mb) / _mm;
				_big.s  = min(5, sqrt(_mm));
				_big.hx  = _a.hx || _b.hx;
				_big.big = _a.big || _b.big;
				_big.m   = _a.m + _b.m;
				_small.s = 0;
				array_push(ignitions, { ox: _big.ox, oy: _big.oy, t0: t, big: false, s: _big.s, merged: true, c: scr_hex_star_colour(_big.ph) });
				if (_small == _a) break;
				continue;
			}

			var _f = _G / (_d2 + 25);
			var _ux = _dx / _d, _uy = _dy / _d;
			_a.vx += _ux * _f * _mb;  _a.vy += _uy * _f * _mb;
			_b.vx -= _ux * _f * _ma;  _b.vy -= _uy * _f * _ma;
		}
	}
	// 1b) black holes pull every newborn in, with a sideways push so they spiral instead of falling straight
	var _holes = global.hex_holes;
	for (var h = 0; h < array_length(_holes); h++) {
		var _ho = _holes[h];
		var _hr = scr_hex_hole_radius(_ho.m);
		for (var i = 0; i < _m; i++) {
			var _a = _live[i];
			if (_a.s <= 0) continue;
			var _dx = _ho.ox - _a.ox, _dy = _ho.oy - _a.oy;
			var _d2 = _dx * _dx + _dy * _dy;
			var _d  = max(0.01, sqrt(_d2));
			if (_d < _hr * 1.1) {                                      // crossed the event horizon: swallowed
				_ho.m += _a.m;
				_a.s = 0;
				array_push(ignitions, { ox: _a.ox, oy: _a.oy, t0: t, big: false, s: 1.5, merged: true, c: scr_hex_star_colour(_a.ph) }); // a last flash at the rimm
				continue;
			}
			if (_d > 400) continue;
			var _f  = _G * _ho.m * 0.25 / (_d2 + 100);                 // 0.25 is the hole's pull knob
			var _ux = _dx / _d, _uy = _dy / _d;                         // unit direction toward the hole
			// (-_uy, _ux) is that direction turned 90 degrees: pushing along it is what makes the spiral
			_a.vx += _ux * _f - _uy * _f * 0.8;
			_a.vy += _uy * _f + _ux * _f * 0.8;
		}
	}
	// 2) move them, and collapse any star that has grown too heavy to hold itself up
	var _need = global.hex_debug_holes ? 15 : HEX_COLLAPSE_MASS;
	var _can  = global.hex_debug_holes || scr_hex_tier() >= 4;
	for (var i = _n - 1; i >= _from; i--) {
		var _a = _st[i];
		if (_a.s <= 0) { array_delete(_st, i, 1); continue; }

		var _dc = point_distance(0, 0, _a.ox, _a.oy);
		// heavy enough to collapse but too close to her: nudge it outward, so it caves in out in her sky instead of on top of her
		if (_a.m >= _need && _dc < HEX_HOLE_MIN_DIST) {
			var _od = (_dc > 0.01) ? point_direction(0, 0, _a.ox, _a.oy) : random(360);
			_a.vx += lengthdir_x(0.25, _od);
			_a.vy += lengthdir_y(0.25, _od);
		}

		if (_can && _a.m >= _need && scr_hex_hole_room(_a.ox, _a.oy)) {
			array_push(global.hex_holes, { ox: _a.ox, oy: _a.oy, m: _a.m, s: _a.s, age: 0, ph: random(1000), tilt: random_range(-12, 12) });
			array_delete(_st, i, 1);
			duration = max(duration, t + HEX_GATHER + game_get_speed(gamespeed_fps) * 3); // the gather, then 3s of aftermath
			continue;
		}

		if (!variable_struct_exists(_a, "vx")) continue;
		var _sp = point_distance(0, 0, _a.vx, _a.vy);
		if (_sp > 3) { _a.vx *= 3 / _sp; _a.vy *= 3 / _sp; }
		_a.ox += _a.vx;
		_a.oy += _a.vy;
		_a.vx *= 0.95;
		_a.vy *= 0.95;
	}
}

// her sky's baked art for one tier: built the first time she casts at that tier, then reused every cast after.
// building it means drawing thousands of pixels one by one, which is what made the cast stutter
function scr_hex_sky_art(_tier, _cover, _bright, _S) {
	if (!variable_global_exists("hex_sky_cache")) global.hex_sky_cache = array_create(4, undefined);
	var _art = global.hex_sky_cache[_tier - 1];
	if (!is_undefined(_art)) return _art;

	_art = { neb: scr_hex_build_nebula(_cover, _bright), dust: [-1, -1] };
	for (var _half = 0; _half < 2; _half++) {
		var _surf = surface_create(_S, _S);
		surface_set_target(_surf);
		draw_clear_alpha(c_black, 1);
		for (var b = _half; b < 2200; b += 2) {
			var _hx = scr_hash(b * 3.1), _hy = scr_hash(b * 7.7 + 1.3);
			if (scr_hash(b * 1.9 + 4.4) > 0.4 + scr_hex_neb_density(_hx, _hy, _cover)) continue;
			draw_set_alpha(0.3 + 0.6 * scr_hash(b * 5.3));
			draw_point_color(_hx * _S, _hy * _S, (b mod 5 == 0) ? make_color_rgb(190, 210, 255) : make_color_rgb(235, 225, 255));
		}
		draw_set_alpha(1);
		surface_reset_target();
		_art.dust[_half] = sprite_create_from_surface(_surf, 0, 0, _S, _S, false, false, _S / 2, _S / 2);
		surface_free(_surf);
	}
	global.hex_sky_cache[_tier - 1] = _art;
	return _art;
}

// throws the cached sky art away (a new run has a new seed, so a new sky)
function scr_hex_sky_art_free() {
	if (!variable_global_exists("hex_sky_cache")) return;
	for (var i = 0; i < 4; i++) {
		var _art = global.hex_sky_cache[i];
		if (is_undefined(_art)) continue;
		if (sprite_exists(_art.neb)) sprite_delete(_art.neb);
		if (sprite_exists(_art.dust[0])) sprite_delete(_art.dust[0]);
		if (sprite_exists(_art.dust[1])) sprite_delete(_art.dust[1]);
	}
	global.hex_sky_cache = array_create(4, undefined);
}


// horizon size: starts around the player's height and only grows a little with mass (mass mainly sets the pull)
function scr_hex_hole_radius(_m) { return min(56, 34 + sqrt(_m) * 0.8); }

// is there room in her sky for a new black hole here?
function scr_hex_hole_room(_ox, _oy) {
	if (array_length(global.hex_holes) >= HEX_MAX_HOLES) return false;
	if (point_distance(0, 0, _ox, _oy) < HEX_HOLE_MIN_DIST) return false;
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _ho = global.hex_holes[h];
		if (_ho.age < HEX_GATHER + game_get_speed(gamespeed_fps)) return false; // one collapse at a time, so each impact lands alone
		if (point_distance(_ho.ox, _ho.oy, _ox, _oy) < HEX_HOLE_SPACING) return false;
	}
	return true;
}

// draws one black hole in her sky. call from obj_unmaking's Draw while blending is additive
function scr_hex_draw_hole(_ho, _x, _y, _glow) {
	var _fps  = game_get_speed(gamespeed_fps);
	var _time = current_time / 1000;

	// ---- 1) the gathering: everything near it starts rushing in, and the star swells before it's crushed ----
	if (_ho.age < HEX_GATHER) {
		var _k = _ho.age / HEX_GATHER;
		for (var i = 0; i < 48; i++) {
			var _h   = scr_hash(_ho.ph + i * 2.9);
			var _ang = _h * 360 + i * 7;
			var _u   = frac(_h * 3 + _k * (1.5 + 2.5 * _k));   // each streak loops inward, faster as the end nears
			var _d0  = 260 * (1 - _u), _d1 = _d0 + 12 + 30 * _k;
			draw_set_alpha(_k * sin(_u * pi));                 // fades in and out along its run, no popping
			draw_line_color(_x + lengthdir_x(_d1, _ang), _y + lengthdir_y(_d1, _ang),
				_x + lengthdir_x(_d0, _ang), _y + lengthdir_y(_d0, _ang), c_black, make_color_rgb(230, 210, 255));
		}
		var _sw = (_k < 0.8) ? lerp(1, 2.2, _k / 0.8) : lerp(2.2, 0.1, (_k - 0.8) / 0.2); // swell... then crushed
		scr_draw_star_flare(_x, _y, _ho.s * 2 * _sw, c_white, 1);
		draw_set_alpha(1);
		return;
	}

	var _a = _ho.age - HEX_GATHER; // frames since the impact

	// ---- 2) the aftermath: an afterglow, a heavy violet shockwave band, and a fast thin white ring ----
	if (_a < _fps * 1.2) {
		var _k  = _a / (_fps * 1.2);
		var _ek = 1 - power(1 - _k, 3);                        // bursts out fast, then slows
		draw_sprite_ext(_glow, 0, _x, _y, 10 * (1 - _k), 10 * (1 - _k), 0, c_white, max(0, 1 - _k * 3));
		var _rr = 30 + _ek * 420;
		for (var w = 0; w < 8; w++) {                          // a thick band: stacked rings, brightest at the front
			draw_set_alpha((1 - _k) * (1 - w / 8));
			draw_set_color(merge_color(c_white, HEX_VIOLET, w / 8));
			draw_circle(_x, _y, max(1, _rr - w * 4), true);
		}
		var _k2 = clamp(_a / (_fps * 0.5), 0, 1);
		draw_set_alpha(1 - _k2);
		draw_set_color(c_white);
		draw_circle(_x, _y, 20 + (1 - power(1 - _k2, 2)) * 600, true);
	}

		// the horizon swells into place, overshooting a touch before settling
	var _g = clamp(_a / (_fps * 0.6), 0, 1);
	var _r = scr_hex_hole_radius(_ho.m) * (1 + 2.7 * power(_g - 1, 3) + 1.7 * power(_g - 1, 2));
	var _disk = clamp(_a / (_fps * 0.4), 0, 1);
	var _x2 = clamp(_a / (_fps * 2), 0, 1);
	var _boost = 10 / 3 * (1 - power(1 - _x2, 3));                       // born spinning furiously, settling over 2s
	var _ct = dcos(_ho.tilt), _st = dsin(_ho.tilt);
	var _hot  = make_color_rgb(255, 225, 190);                            // white-gold, the hot inner disk
	var _cool = merge_color(make_color_rgb(255, 150, 110), HEX_VIOLET, 0.55); // cooling to her violet at the edge
	var _sq = 0.22;                                                       // how flat the disk looks (0 = edge-on)

	for (var _pass = 0; _pass < 2; _pass++) {
		if (_pass == 0) {
			// a) the lensed ring: light from the far side of the disk, bent over the top and under the bottom.
			// a soft band, bright on its inner edge and fading outward, brightest above and below the hole
			draw_primitive_begin(pr_trianglestrip);
			for (var j = 0; j <= 72; j++) {
				var _la  = j / 72 * 360;
				var _lit = (0.3 + 0.7 * abs(dsin(_la))) * (0.6 + 0.4 * dcos(_la));
				var _ix = lengthdir_x(_r * 1.04, _la), _iy = lengthdir_y(_r * 1.04, _la);
				var _ox = lengthdir_x(_r * 1.5, _la),  _oy = lengthdir_y(_r * 1.5, _la);
				draw_vertex_color(_x + _ix * _ct + _iy * _st, _y - _ix * _st + _iy * _ct, _hot, 0.85 * _lit * _disk);
				draw_vertex_color(_x + _ox * _ct + _oy * _st, _y - _ox * _st + _oy * _ct, _cool, 0);
			}
			draw_primitive_end();
			// b) the disk's body: one soft squashed glow, so the streaks ride on a continuous sheet of light
			draw_sprite_ext(_glow, 0, _x, _y, _r * 3.4 / 15, _r * 3.4 * _sq / 15, _ho.tilt, _cool, 0.5 * _disk);
		}

		// c) streaks of matter on their orbits: the far half this pass, the near half next pass
		for (var p = 0; p < 220; p++) {
			var _h1  = scr_hash(_ho.ph + p * 1.7), _h2 = scr_hash(_ho.ph + p * 3.1);
			var _rad = _r * (1.35 + 2.0 * _h1);
			var _ang = _h2 * 360 + (1400 / _rad) * (_time + _boost);       // inner matter orbits faster
			var _lx  = lengthdir_x(_rad, _ang), _ly = lengthdir_y(_rad, _ang) * _sq;
			if ((_ly < 0) != (_pass == 0)) continue;
			var _beam = 0.2 + 0.8 * (0.5 + 0.5 * dcos(_ang));               // the side swinging toward us blazes
			var _lx0 = lengthdir_x(_rad, _ang - 14), _ly0 = lengthdir_y(_rad, _ang - 14) * _sq;
			draw_set_alpha(0.8 * _beam * _disk);
			draw_line_width_color(_x + _lx0 * _ct + _ly0 * _st, _y - _lx0 * _st + _ly0 * _ct,
				_x + _lx * _ct + _ly * _st, _y - _lx * _st + _ly * _ct,
				(0.6 + (1 - _h1)) * _r / 18, c_black, merge_color(_hot, _cool, _h1)); // thicker streaks for a bigger hole
		}

		if (_pass == 0) {
			// the event horizon: true black (normal blending, because adding black adds nothing)
			gpu_set_blendmode(bm_normal);
			draw_set_alpha(1);
			draw_set_color(c_black);
			draw_circle(_x, _y, _r, false);
			gpu_set_blendmode(bm_add);
			// the photon ring: a crisp line of trapped light hugging the shadow
			draw_set_color(make_color_rgb(255, 240, 255));
			draw_set_alpha(_disk);
			draw_circle(_x, _y, _r + 1, true);
			draw_set_alpha(0.5 * _disk);
			draw_circle(_x, _y, _r + 2, true);
		}
	}
	draw_set_alpha(1);
}

// one crack in the frozen world: jagged, thick near her and hair-thin far away, glowing with her light,
// with a hot spark at its tip while it's still racing outward. _flare (0 or 1) makes it blaze just before the break
function scr_hex_crack(_p, _q, _cx, _cy, _reach, _R, _flare, _glow) {
	var _dp = point_distance(_cx, _cy, _p[0], _p[1]), _dq = point_distance(_cx, _cy, _q[0], _q[1]);
	if (_dq < _dp) { var _tp = _p; _p = _q; _q = _tp; var _td = _dp; _dp = _dq; _dq = _td; } // grow from the end nearest her
	if (_reach <= _dp) return;
	var _f = (_dq - _dp > 0.01) ? clamp((_reach - _dp) / (_dq - _dp), 0, 1) : 1;

	// bend the straight line at two points so it looks broken, not ruled. the bends come from a hash of the
	// crack's own position, so they're the same every frame instead of jittering
	var _len = point_distance(_p[0], _p[1], _q[0], _q[1]);
	var _nx = -(_q[1] - _p[1]) / max(0.01, _len), _ny = (_q[0] - _p[0]) / max(0.01, _len); // a sideways direction
	var _jag  = min(10, _len * 0.12);
	var _seed = _p[0] * 0.13 + _q[1] * 0.71;
	var _xs = [_p[0], 0, 0, _q[0]], _ys = [_p[1], 0, 0, _q[1]];
	for (var k = 1; k <= 2; k++) {
		var _o = (scr_hash(_seed + k * 3.7) - 0.5) * 2 * _jag;
		_xs[k] = lerp(_p[0], _q[0], k / 3) + _nx * _o;
		_ys[k] = lerp(_p[1], _q[1], k / 3) + _ny * _o;
	}

	var _w = lerp(5, 1.5, clamp(_dp / _R, 0, 1)) * (1 + _flare); // thick near her, thin far away
	for (var k = 0; k < 3; k++) {
		var _a = k / 3, _b = (k + 1) / 3;
		if (_f <= _a) break;                                   // the crack hasn't grown this far yet
		var _e  = min(1, (_f - _a) / (_b - _a));
		var _x2 = lerp(_xs[k], _xs[k + 1], _e), _y2 = lerp(_ys[k], _ys[k + 1], _e);
		draw_set_alpha(0.25);
		draw_line_width_color(_xs[k], _ys[k], _x2, _y2, _w * 4, HEX_VIOLET, HEX_VIOLET);  // wide glow: her light bleeding out
		draw_set_alpha(0.7);
		draw_line_width_color(_xs[k], _ys[k], _x2, _y2, _w * 2, HEX_VIOLET, HEX_VIOLET);
		draw_set_alpha(1);
		draw_line_width_color(_xs[k], _ys[k], _x2, _y2, _w * 0.6 + _flare * 2, c_white, c_white); // the white-hot core
		if (_e < 1) draw_sprite_ext(_glow, 0, _x2, _y2, 0.6, 0.6, 0, c_white, 1);           // a spark at the growing tip
	}
}

// the world slams back: a shockwave rolls out from her, shoving survivors away and branding them with her curse
function scr_hex_return(_x, _y) {
	var _w = camera_get_view_width(view_camera[0]);
	global.shake = max(global.shake, 14);
	scr_burst_fx(_x, _y, _w * 0.6, HEX_VIOLET, 30); // the shockwave
	scr_burst_fx(_x, _y, _w * 0.25, c_white, 14);   // a hot flash at her heart
	with (obj_enemy_parent) {
		if (unmaking > 0) continue;                 // already becoming stars
		var _d = point_distance(_x, _y, x, y);
		if (_d > _w * 0.6) continue;
		var _dir  = point_direction(_x, _y, x, y);
		var _push = 22 * (1 - _d / (_w * 0.6));     // shoved hardest close to her
		knock_x += lengthdir_x(_push, _dir);
		knock_y += lengthdir_y(_push, _dir);
		scr_hex_apply(id, 0.5);                     // branded by the world she just left
	}
}