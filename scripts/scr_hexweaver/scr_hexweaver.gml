// The Hexweaver: spread hexes that ripen into toads, 
//with the ultimate ability to tear away the fabric of space, turning your enemies into stars in your galaxy

#macro HEX_VIOLET make_color_rgb(170, 90, 255)
#macro HEX_COLLAPSE_MASS 100 // how much one star must swallow before it caves in. the main knob
#macro HEX_MAX_HOLES     3   // black holes allowed at once (merging frees room for more)
#macro HEX_SMBH_GEN      2   // mergers before a black hole is supermassive (2 = three holes become one)
#macro HEX_HOLE_SPACING  500 // black holes must be at least this far apart, so they're spread across her sky
#macro HEX_HOLE_MIN_DIST 250 // and at least this far from her
#macro HEX_GATHER floor(game_get_speed(gamespeed_fps) * 1.5) // frames a dying star spends gathering in before it collapses
#macro HEX_STAR_SOFTEN 0.225 // 0 = full color, 1 = all white. how much the star colors are washed toward white
#macro HEX_MASS_BLUE 64    // the mass at which a star burns fully blue. lower = bluer skies, higher = redder
#macro HEX_HAZE_CAP 3000   // the most haze wisps her sky keeps. past this, the oldest make 
#macro HEX_BIRTH_EVERY 5  // seconds of fighting per star born from her old haze. lower = a busier sky between casts
#macro HEX_PEEK_BIRTHS 4   // the most haze births one cast shows, so each one gets noticed
#macro HEX_MASS_SUN_MIN 6   // stars at least this heavy are sun-like: they age, swell into red giants and die as planetary nebulae. lighter ones live forever
#macro HEX_MASS_GIANT   24  // this heavy and up is a blue giant: it skips the planetary nebula (it goes supernova later)
#macro HEX_HAZE_GLOW    0.6  // the exposure ceiling: how bright the densest gas can glow. dim gas stays dim, dense gas glows rich but never clips to white
#macro HEX_GAS_REF      20   // how much gas (summed glow) counts as a normal sky. more than this and stars form faster, so dense skies drain themselves
#macro HEX_COLLAPSE_L   0.45 // how dense a patch of gas must be before it can collapse into a star
#macro HEX_STAR_KEEP    0.3  // the share of a knot's gas the newborn star swallows
#macro HEX_POCKET_KEEP  0.12 // the share left around it as its pocket. the rest is thrown out along the jets: the garden trims itself
#macro HEX_SUN_LIFE     240 // seconds of her fighting a mass-10 star lives. heavier dies sooner, lighter lives longer


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
	var _st;
	if (!_merged) {
		_st = { ox: _p.ox, oy: _p.oy, s: _p.s, ph: _p.ph, hx: _e.star_hexed, big: _big, m: _e.star_hexed ? 3 : 1 };
		array_push(global.hex_stars, _st);
		_p.idx = array_length(global.hex_stars) - 1;
	} else {
		_st = global.hex_stars[_p.idx];
		_st.s   = min(4.5, _st.s + 0.35);    // bigger and brighter with each one, up to a cap
		_st.hx  = _st.hx || _e.star_hexed;
		_st.big = _st.big || _big;
		_st.m  += _e.star_hexed ? 3 : 1;     // mass: how much of her dead this star holds. it also sets the star's color
	}

	// tell the realm a star was just born (or fed), so it can flash. no rumble: the stardust is the quiet part, and stars catch in silence
	if (instance_exists(obj_unmaking)) {
		var _c = scr_hex_star_color(_st.m, _st.ph, _st.hx);
		with (obj_unmaking) array_push(ignitions, { ox: _p.ox, oy: _p.oy, t0: t, big: _big, s: _st.s, merged: _merged, c: _c });
	}

	_e.popping = true;
	scr_damage_enemy(_e, _e.hp + 1, HEX_VIOLET, false); // still a kill: souls, essence, charge

	var _tier_now = scr_hex_tier();
	if (_tier_now > _tier_before) {
		global.toast = { text: "ASCENSION", sub: "The Hexweaver's power grows (tier " + string(_tier_now) + ")", color: HEX_VIOLET, timer: game_get_speed(gamespeed_fps) * 3 };
		global.shake = max(global.shake, 8);
	}
}

// a star's color from its MASS, like real stars: the heavier it is, the hotter it burns and the bluer it shines.
// a lone enemy makes a red dwarf, a clump a yellow-white sun, a great crowd a blue giant (and blue giants are the ones that collapse).
// _ph adds a touch of variety so no two are quite alike. _hx (her own hexed dead) leans a little toward her violet
function scr_hex_star_color(_m, _ph, _hx = false) {
	var _stops = [make_color_rgb(255, 110, 80),    // red dwarf
	              make_color_rgb(255, 160, 95),    // orange
	              make_color_rgb(255, 215, 150),   // yellow, like the sun
	              make_color_rgb(255, 248, 235),   // white
	              make_color_rgb(185, 210, 255),   // blue-white
	              make_color_rgb(125, 160, 255)];  // hot blue giant
	var _k = clamp(log2(max(1, _m)) / log2(HEX_MASS_BLUE), 0, 1);           // 0 at a single enemy, 1 at HEX_MASS_BLUE
	_k = clamp(_k + (scr_hash(_ph * 0.37 + 11) - 0.5) * 0.12, 0, 1);       // a little variety
	var _f = _k * 5, _i = min(4, floor(_f));
	var _c = merge_color(_stops[_i], _stops[_i + 1], _f - _i);
	if (_hx) _c = merge_color(_c, make_color_rgb(200, 140, 255), 0.25);
	return merge_color(_c, c_white, HEX_STAR_SOFTEN);                       // the knob: a touch of white takes the edge off
}

// the gas a pixel's dust glows as. real nebulae glow in a few signature colors depending on what the gas is made of.
// returns -1 for dark pixels: dark dust, soot that dims what is behind it instead of shining
function scr_hex_gas_color(_c) {
	var _v = color_get_value(_c), _s = color_get_saturation(_c), _h = color_get_hue(_c);
	if (_v < 70) return -1;                                          // outlines and shadows: dust grains, like the dark lanes in the Pillars of Creation
	if (_s < 60) return make_color_rgb(190, 205, 255);               // greys and whites: dust lit blue by starlight (a reflection nebula)
	if (_h < 14 || _h >= 232) return make_color_rgb(255, 85, 115);   // reds: hydrogen, the pink-red glow of most of the universe
	if (_h < 46)  return make_color_rgb(255, 175, 75);               // oranges and yellows: sulphur, the gold of the Hubble palette
	if (_h < 140) return make_color_rgb(70, 230, 200);               // greens and teals: oxygen, that eerie teal
	if (_h < 190) return make_color_rgb(110, 150, 255);              // blues: reflection blue
	return make_color_rgb(210, 110, 255);                            // purples and magentas: her violet
}

// reads one frame of a sprite into a list of its solid pixels, in crumble order, each with its color.
// done once per sprite frame per cast, so every mote can be born the exact color of the pixel it came off
function scr_hex_sprite_pixels(_spr, _img) {
	var _w = sprite_get_width(_spr), _h = sprite_get_height(_spr);
	var _surf = surface_create(_w, _h);
	surface_set_target(_surf);
	draw_clear_alpha(c_black, 0);
	gpu_push_state();
	gpu_set_blendmode(bm_normal);
	draw_sprite_ext(_spr, _img, sprite_get_xoffset(_spr), sprite_get_yoffset(_spr), 1, 1, 0, c_white, 1); // its raw origin, so the frame fills the surface exactly
	gpu_pop_state();
	surface_reset_target();
	var _buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
	buffer_get_surface(_buf, _surf, 0);
	surface_free(_surf);

	var _list = [];
	for (var _yy = 0; _yy < _h; _yy++) {
		for (var _xx = 0; _xx < _w; _xx++) {
			var _o = (_yy * _w + _xx) * 4;                             // a surface stores each pixel as blue, green, red, alpha
			if (buffer_peek(_buf, _o + 3, buffer_u8) < 128) continue;  // see-through: not part of the body
			array_push(_list, { u: _xx, v: _yy, c: make_color_rgb(buffer_peek(_buf, _o + 2, buffer_u8), buffer_peek(_buf, _o + 1, buffer_u8), buffer_peek(_buf, _o, buffer_u8)) });
		}
	}
	buffer_delete(_buf);
	// crumble order, matching sh_crumble: head first but mostly ragged, so each mote comes off right where the body is breaking
	for (var i = 0; i < array_length(_list); i++) {
		var _pq = _list[i];
		_pq.k = _pq.v / max(1, _h - 1) * 0.45 + random(1) * 0.55;
	}
	array_sort(_list, function(_p, _q) { return _p.k - _q.k; });
	return { w: _w, h: _h, px: _list };
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
		_plan = { ox: _sx, oy: _sy, s: 0.6 + power(random(1), 2.5) * 1.6 + (_e.star_hexed ? 0.8 : 0), idx: -1,
		    ph: random(1000),   // a touch of color variety, decided now
		    mp: 0,              // planned mass: how much of the horde condenses here, so its dust already flies in the star's final color
		    landed: 0,          // motes landed on it so far
		    lit: false };       // true once its birth light has gone off: one lamp per star, however many enemies share it
		if (!is_undefined(_grid)) {
			var _key = string(floor(_sx / 20)) + "," + string(floor(_sy / 20));
			var _home = _grid[$ _key];
			if (is_undefined(_home)) { _home = []; _grid[$ _key] = _home; }
			array_push(_home, _plan);
		}
	}
	_plan.mp += _e.star_hexed ? 3 : 1;   // every enemy sharing this star adds its mass
	_e.star_plan = _plan; // structs are shared by reference, so every enemy in a clump points at the SAME plan
	_e.star_ox = _plan.ox;
	_e.star_oy = _plan.oy;
}

// stretches an array of noise so its lowest value becomes 0 and its highest becomes 1.
// layered noise bunches up around the middle, so without this the thickest, brightest colors almost never appear
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

// the expensive part, done once per run: raw noise for the nebula's gas, dust and color, stored in arrays
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

// the cheap part, done each cast: color the stored noise for how far she's ascended, and bake it into a sprite
function scr_hex_build_nebula(_cover, _bright) {
	var _f = global.hex_neb;
	var _gas = _f.gas, _dust = _f.dust, _tint = _f.tint;
	// two families of color like the references: violet-magenta clouds, and deep blue-teal clouds
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
	draw_set_color(merge_color(_col, c_white, 0.35)); // white-hot, but the star's own color still shows through
	draw_circle(_x, _y, max(1, _size * 0.5), false);           // white-hot core
	for (var k = 0; k < 8; k++) {
		var _len = (k mod 2 == 0) ? _size * 6 : _size * 2;      // long straight spikes, short diagonals
		draw_set_alpha(((k mod 2 == 0) ? 0.9 : 0.4) * _a);
		draw_line_color(_x, _y, _x + lengthdir_x(_len, k * 45), _y + lengthdir_y(_len, k * 45), _col, c_black);
	}
}

// turns on the silhouette shader: every sprite drawn until shader_reset() comes out as a flat-color shape
function scr_silhouette_begin(_col) {
	shader_set(sh_silhouette);
	var _u = shader_get_uniform(sh_silhouette, "u_color");
	shader_set_uniform_f(_u, color_get_red(_col) / 255, color_get_green(_col) / 255, color_get_blue(_col) / 255);
}

// draws an instance as a solid-color silhouette a few pixels out in every direction: a glowing outline
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
				array_push(ignitions, { ox: _big.ox, oy: _big.oy, t0: t, big: false, s: _big.s, merged: true, c: scr_hex_star_color(_big.m, _big.ph, _big.hx) });
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
		var _hr = scr_hex_hole_size(_ho);
		for (var i = 0; i < _m; i++) {
			var _a = _live[i];
			if (_a.s <= 0) continue;
			var _dx = _ho.ox - _a.ox, _dy = _ho.oy - _a.oy;
			var _d2 = _dx * _dx + _dy * _dy;
			var _d  = max(0.01, sqrt(_d2));
			if (_d < _hr * 1.1) {                                      // crossed the event horizon: swallowed
				_ho.m += _a.m;
				_a.s = 0;
				array_push(ignitions, { ox: _a.ox, oy: _a.oy, t0: t, big: false, s: 1.5, merged: true, c: scr_hex_star_color(_a.m, _a.ph, _a.hx) }); // a last flash at the rimm
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

// a black hole's size on screen: its mass, and every merger it has swallowed. a supermassive dwarfs the rest
function scr_hex_hole_size(_ho, _ring = true) {
	var _g = variable_struct_exists(_ho, "gen") ? _ho.gen : 0;
	var _ev = variable_struct_exists(_ho, "evk") ? _ho.evk : 0;          // evaporating: it shrinks away to nothing
	var _r  = min(160, scr_hex_hole_radius(_ho.m) * (1 + 0.45 * _g)) * (1 - 0.92 * _ev);
	if (variable_struct_exists(_ho, "ck")) _r *= 1 + 9 * power(_ho.ck, 5);   // the crunch: its horizon swells until it swallows the whole sky
	// the ringdown: a freshly merged horizon wobbles like a struck bell before it settles (real: LIGO hears this as the last note)
	if (_ring) _r *= scr_hex_ringk(_ho);
	return _r;
}
// the ringdown wobble on its own (1 = still)
function scr_hex_ringk(_ho) {
	if (variable_struct_exists(_ho, "mf") && _ho.mf >= 0 && _ho.mf < 100) return 1 + 0.16 * exp(-_ho.mf / 20) * sin(_ho.mf * 0.85);
	return 1;
}
// its size as drawn: eased toward its true size, so merges and growth swell smoothly instead of snapping (Step eases rs)
function scr_hex_hole_vis(_ho) { return variable_struct_exists(_ho, "rs") ? _ho.rs : scr_hex_hole_size(_ho, false); }
function scr_hex_is_smbh(_ho) { return variable_struct_exists(_ho, "gen") && _ho.gen >= HEX_SMBH_GEN; }

// the heaviest supermassive in her sky, or undefined
function scr_hex_find_smbh() {
	var _best = undefined;
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _ho = global.hex_holes[h];
		if (scr_hex_is_smbh(_ho) && (is_undefined(_best) || _ho.m > _best.m)) _best = _ho;
	}
	return _best;
}

// once a supermassive anchors her sky, everything turns around it: a galaxy. like real galaxies the outer parts take
// longer to go round (a flat rotation curve), so the gas is slowly sheared into spiral arms. _k = how many frames' worth
function scr_hex_galaxy_turn(_k) {
	var _sm = scr_hex_find_smbh();
	if (is_undefined(_sm)) return;
	var _cx = _sm.ox, _cy = _sm.oy;
	var _mg = variable_global_exists("hex_merge") ? global.hex_merge : undefined;
	var _st = global.hex_stars;
	for (var i = 0; i < array_length(_st); i++) {
		var _q = _st[i];
		if (_q.s <= 0) continue;
		var _dx = _q.ox - _cx, _dy = _q.oy - _cy;
		var _w = -0.085 * _k * 300 / max(300, sqrt(_dx * _dx + _dy * _dy));   // degrees: inside 300px it turns as one, outside ever slower
		var _c = dcos(_w), _s = dsin(_w);
		_q.ox = _cx + _dx * _c + _dy * _s; _q.oy = _cy - _dx * _s + _dy * _c;
	}
	var _hz = global.hex_haze;
	for (var i = 0; i < array_length(_hz); i++) {
		var _q = _hz[i];
		if (_q.f <= 0.01 || _q.u || _q.tr) continue;                          // gas shaped by a star or falling into a hole moves on its own
		var _dx = _q.ox - _cx, _dy = _q.oy - _cy;
		var _w = -0.085 * _k * 300 / max(300, sqrt(_dx * _dx + _dy * _dy));
		var _c = dcos(_w), _s = dsin(_w);
		_q.ox = _cx + _dx * _c + _dy * _s; _q.oy = _cy - _dx * _s + _dy * _c;
		_q.ang += _w;
	}
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _q = global.hex_holes[h];
		if (_q == _sm || (!is_undefined(_mg) && (_q == _mg.a || _q == _mg.b))) continue;
		var _dx = _q.ox - _cx, _dy = _q.oy - _cy;
		var _w = -0.085 * _k * 300 / max(300, sqrt(_dx * _dx + _dy * _dy));
		var _c = dcos(_w), _s = dsin(_w);
		_q.ox = _cx + _dx * _c + _dy * _s; _q.oy = _cy - _dx * _s + _dy * _c;
	}
}

// black holes sink toward each other (heavy things settle together in a crowd: dynamical friction). _px = how many
// pixels each can travel this step. the lighter one moves more
function scr_hex_holes_migrate(_px) {
	var _bh = global.hex_holes;
	if (array_length(_bh) < 2) return;
	var _mg = variable_global_exists("hex_merge") ? global.hex_merge : undefined;
	for (var h = 0; h < array_length(_bh); h++) {
		var _a = _bh[h];
		if (_a.age < HEX_GATHER + game_get_speed(gamespeed_fps)) continue;
		if (!is_undefined(_mg) && (_a == _mg.a || _a == _mg.b)) continue;
		var _sx = 0, _sy = 0, _sm = 0;
		for (var k = 0; k < array_length(_bh); k++) {
			var _b = _bh[k];
			if (_b == _a || _b.age < HEX_GATHER) continue;
			_sx += _b.ox * _b.m; _sy += _b.oy * _b.m; _sm += _b.m;
		}
		if (_sm <= 0) continue;
		var _tx = _sx / _sm, _ty = _sy / _sm;
		var _d = point_distance(_a.ox, _a.oy, _tx, _ty);
		if (_d < 1) continue;
		var _mv = min(_d * 0.85, _px * 2 * _sm / (_sm + _a.m));
		var _nx = _a.ox + (_tx - _a.ox) / _d * _mv, _ny = _a.oy + (_ty - _a.oy) / _d * _mv;
		// never pile onto another hole: while two others are spiralling together, wait well clear (a queue, not a heap),
		// and never overlap anyone. holes only meet through a merger
		var _ok = true, _ra = scr_hex_hole_size(_a);
		for (var k = 0; k < array_length(_bh); k++) {
			var _b = _bh[k];
			if (_b == _a) continue;
			var _gap = (_ra + scr_hex_hole_size(_b)) * (is_undefined(_mg) ? 1.2 : 2.8);
			if (point_distance(_nx, _ny, _b.ox, _b.oy) < _gap && point_distance(_nx, _ny, _b.ox, _b.oy) < point_distance(_a.ox, _a.oy, _b.ox, _b.oy)) { _ok = false; break; }
		}
		if (_ok) { _a.ox = _nx; _a.oy = _ny; }
	}
	scr_hex_holes_clear_her();
}

// black holes keep their distance from her: she's the gardener, not food. the bigger the hole, the more room it keeps
function scr_hex_holes_clear_her() {
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _a = global.hex_holes[h];
		if (variable_struct_exists(_a, "ck")) continue;                      // the crunch takes everything, her view included
		var _need = max(HEX_HOLE_MIN_DIST, scr_hex_hole_size(_a) * 3.2);
		var _d = point_distance(0, 0, _a.ox, _a.oy);
		if (_d >= _need) continue;
		var _dir = (_d < 1) ? random(360) : point_direction(0, 0, _a.ox, _a.oy);
		var _nd  = lerp(_d, _need, 0.08);                                    // eased out, not snapped
		_a.ox = lengthdir_x(_nd, _dir); _a.oy = lengthdir_y(_nd, _dir);
	}
}

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
function scr_hex_draw_hole(_ho, _x, _y, _glow, _gpu = false) {
	var _fps  = game_get_speed(gamespeed_fps);
	var _time = current_time / 1000;

	// ---- 1) the inhale: the dying giant's gravity takes hold. light and gas are drawn in toward it: rings of light contract
	// onto it, streaks pour inward, the rest of her sky dims (Draw), and space around it already starts to bend (sh_hex_lens).
	// the star swells one last time, then is crushed to a point ----
	if (_ho.age < HEX_GATHER) {
		var _k = _ho.age / HEX_GATHER;
		for (var w = 0; w < 3; w++) {                                    // rings of light falling inward, one after another
			var _wk = frac(_k * 1.6 + w / 3);
			var _wr = lerp(320, 16, _wk * _wk);
			draw_set_alpha(_k * sin(_wk * pi) * 0.55);
			draw_set_color(merge_color(make_color_rgb(200, 170, 255), c_white, _wk));
			draw_circle(_x, _y, _wr, true);
			draw_circle(_x, _y, _wr + 1.5, true);
		}
		for (var i = 0; i < 28; i++) {                                   // and streaks pouring in
			var _h   = scr_hash(_ho.ph + i * 2.9);
			var _ang = _h * 360 + i * 13;
			var _u   = frac(_h * 3 + _k * (1.5 + 2.5 * _k));
			var _d0  = 280 * (1 - _u), _d1 = _d0 + 10 + 24 * _k;
			draw_set_alpha(0.7 * _k * sin(_u * pi));
			draw_line_color(_x + lengthdir_x(_d1, _ang), _y + lengthdir_y(_d1, _ang),
				_x + lengthdir_x(_d0, _ang), _y + lengthdir_y(_d0, _ang), c_black, make_color_rgb(230, 210, 255));
		}
		var _sw = (_k < 0.8) ? lerp(1, 2.2, _k / 0.8) : lerp(2.2, 0.1, (_k - 0.8) / 0.2); // swell... then crushed
		scr_draw_star_flare(_x, _y, _ho.s * 2 * _sw, merge_color(c_white, make_color_rgb(255, 150, 110), _k), 1);
		draw_set_alpha(1);
		return;
	}

	var _a = _ho.age - HEX_GATHER; // frames since the collapse

	// ---- 2) the collapse: no explosion. the star is simply gone, and for an instant twin beams lance out of its poles
	// across the whole sky (a collapsar's gamma-ray burst, the brightest thing in the universe for a moment). a ripple of
	// bent space rolls outward (sh_hex_lens), the photon ring ignites, and the star's leftovers spiral in to build the disk ----
	if (_a < _fps * 0.7) {
		var _bk  = _a / (_fps * 0.7);
		var _bl  = 1400 * min(1, _a / (_fps * 0.08));                   // the beams shoot out almost at once
		var _bfl = (1 - _bk) * (1 - _bk) * (0.85 + 0.15 * sin(_a * 2.3));  // fading, flickering
		for (var _bs = -1; _bs <= 1; _bs += 2) {
			var _bd = _ho.tilt + 90 * _bs;                               // out of the poles, square to the disk
			var _pbx = _x + lengthdir_x(_bl, _bd), _pby = _y + lengthdir_y(_bl, _bd);
			draw_set_alpha(0.25 * _bfl);
			draw_line_width_color(_x, _y, _pbx, _pby, 14, HEX_VIOLET, c_black);
			draw_set_alpha(0.6 * _bfl);
			draw_line_width_color(_x, _y, _pbx, _pby, 5, make_color_rgb(190, 210, 255), c_black);
			draw_set_alpha(_bfl);
			draw_line_width_color(_x, _y, _pbx, _pby, 1.6, c_white, make_color_rgb(200, 220, 255));
		}
		if (_a < _fps * 0.15) draw_sprite_ext(_glow, 0, _x, _y, 2.5 * (1 - _a / (_fps * 0.15)), 2.5 * (1 - _a / (_fps * 0.15)), 0, c_white, 1);
	}

	// the horizon swells into place, overshooting a touch before settling
	var _g = clamp(_a / (_fps * 0.6), 0, 1);
	var _r = scr_hex_hole_size(_ho) * (1 + 2.7 * power(_g - 1, 3) + 1.7 * power(_g - 1, 2));
	var _disk = clamp(_a / (_fps * 0.4), 0, 1);
	var _x2 = clamp(_a / (_fps * 2), 0, 1);
	var _boost = 10 / 3 * (1 - power(1 - _x2, 3));                       // born spinning furiously, settling over 2s
	var _ct = dcos(_ho.tilt), _st = dsin(_ho.tilt);
	var _hot  = make_color_rgb(255, 225, 190);                            // white-gold, the hot inner disk
	var _cool = merge_color(make_color_rgb(255, 150, 110), HEX_VIOLET, 0.55); // cooling to her violet at the edge
	var _blue = make_color_rgb(225, 235, 255);                            // the side rushing toward us, blueshifted and blazing
	var _sq = 0.22;                                                       // how flat the disk looks (0 = edge-on)
	var _soft = global.hex_fx.soft;

	// a) bloom: the whole hole sits in the glow of its own disk (kept faint: everything below adds up)
	if (_gpu) {
		// while it feeds hard, faint jets stream out of its poles: the gas it throws back out into the garden (Step)
		var _jf = variable_struct_exists(_ho, "feed") ? _ho.feed : 0;
		if (_jf > 8 && _a > _fps * 2.5) {
			var _jk = min(1, (_jf - 8) / 60);
			for (var _js = -1; _js <= 1; _js += 2) {
				var _jd = _ho.tilt + 90 * _js;
				var _jl = _r * (5 + 7 * _jk) * (scr_hex_is_smbh(_ho) ? 1.8 : 1);
				var _jx = _x + lengthdir_x(_jl, _jd), _jy = _y + lengthdir_y(_jl, _jd);
				var _j0x = _x + lengthdir_x(_r * 1.1, _jd), _j0y = _y + lengthdir_y(_r * 1.1, _jd);
				draw_set_alpha(0.1 * _jk);
				draw_line_width_color(_j0x, _j0y, _jx, _jy, _r * 0.18, make_color_rgb(150, 170, 255), c_black);
				draw_set_alpha(0.3 * _jk);
				draw_line_width_color(_j0x, _j0y, _jx, _jy, 1.4, make_color_rgb(225, 235, 255), c_black);
			}
		}
		// a quasar: relativistic jets that cross the whole sky
		var _qk = variable_struct_exists(_ho, "qk") ? _ho.qk : 0;
		if (_qk > 0) {
			for (var _js = -1; _js <= 1; _js += 2) {
				var _jd = _ho.tilt + 90 * _js;
				var _qx = _x + lengthdir_x(2200, _jd), _qy = _y + lengthdir_y(2200, _jd);
				var _q0x = _x + lengthdir_x(_r * 1.1, _jd), _q0y = _y + lengthdir_y(_r * 1.1, _jd);
				draw_set_alpha(0.22 * _qk);
				draw_line_width_color(_q0x, _q0y, _qx, _qy, _r * 0.5, HEX_VIOLET, c_black);
				draw_set_alpha(0.5 * _qk);
				draw_line_width_color(_q0x, _q0y, _qx, _qy, _r * 0.14, make_color_rgb(190, 210, 255), c_black);
				draw_set_alpha(0.9 * _qk);
				draw_line_width_color(_q0x, _q0y, _qx, _qy, 2, c_white, make_color_rgb(200, 220, 255));
			}
			draw_sprite_ext(_soft, 0, _x, _y, _r * 9 / 20, _r * 9 / 20, 0, make_color_rgb(255, 235, 215), 0.18 * _qk);   // it outshines the galaxy
		}
		// evaporating: Hawking radiation. the smaller it gets, the hotter and brighter it burns
		var _ek = variable_struct_exists(_ho, "evk") ? _ho.evk : 0;
		if (_ek > 0) {
			draw_sprite_ext(_soft, 0, _x, _y, (40 + 80 * _ek) / 20, (40 + 80 * _ek) / 20, 0, make_color_rgb(200, 220, 255), 0.25 * _ek * _ek);
			draw_sprite_ext(_glow, 0, _x, _y, 0.6 + 1.6 * _ek, 0.6 + 1.6 * _ek, 0, c_white, 0.7 * _ek * _ek);
		}
		draw_set_alpha(1);
		return;                                                           // sh_hex_lens draws the rest, per pixel, with real lensing
	}
	draw_sprite_ext(_soft, 0, _x, _y, _r * 7 / 20, _r * 3.5 / 20, _ho.tilt, _cool, 0.07 * _disk);
	draw_sprite_ext(_soft, 0, _x, _y, _r * 3.4 / 20, _r * 1.8 / 20, _ho.tilt, _hot, 0.08 * _disk);

	for (var _pass = 0; _pass < 2; _pass++) {
		// b) the disk: a thin, wide sheet of gas, crowded close in and thinning out toward the rim (no rings: rings seen edge-on pile up
		// at their ends into bright tips). hot white-gold at the inner edge, orange, then her violet at the rim. Doppler beaming: the side
		// swinging toward us is brighter and bluer, the side moving away dimmer and redder, but still there
		var _orng = make_color_rgb(255, 160, 90);
		for (var j = 0; j < 150; j++) {
			var _h1  = scr_hash(_ho.ph + j * 2.3), _h2 = scr_hash(_ho.ph + j * 5.7);
			var _u   = _h1 * _h1;                                              // 0 = the inner edge, 1 = the rim. most matter crowds close in
			var _rad = _r * (1.5 + 3.4 * _u);
			var _ang = _h2 * 360 + (1400 / _rad) * (_time + _boost);         // inner matter orbits faster
			var _lx = lengthdir_x(_rad, _ang), _ly = lengthdir_y(_rad, _ang) * _sq;
			if ((_ly < 0) != (_pass == 0)) continue;
			var _rc  = (_u < 0.35) ? merge_color(_hot, _orng, _u / 0.35) : merge_color(_orng, _cool, (_u - 0.35) / 0.65); // cooler further out
			var _dop = 0.5 + 0.5 * dcos(_ang);                                // 1 on the approaching side, 0 on the receding side
			var _col = merge_color(_rc, (_dop > 0.5) ? _blue : make_color_rgb(170, 70, 80), abs(_dop - 0.5) * 0.8);
			var _bx = _x + _lx * _ct + _ly * _st, _by = _y - _lx * _st + _ly * _ct;
			draw_sprite_ext(_soft, 0, _bx, _by, (7 - 3 * _u) * _r / 200, (2.6 - 0.9 * _u) * _r / 200, _ho.tilt, _col,
				0.07 * (0.3 + 0.7 * power(_dop, 1.5)) * (1 - 0.75 * _u) * _disk);   // tapers off toward the rim
		}
		// c) streaks of matter on their orbits, riding the disk
		for (var p = 0; p < 90; p++) {
			var _h1  = scr_hash(_ho.ph + p * 1.7), _h2 = scr_hash(_ho.ph + p * 3.1);
			var _rad = _r * (1.45 + 2.6 * _h1);
			var _ang = _h2 * 360 + (1400 / _rad) * (_time + _boost);       // inner matter orbits faster
			var _lx  = lengthdir_x(_rad, _ang), _ly = lengthdir_y(_rad, _ang) * _sq;
			if ((_ly < 0) != (_pass == 0)) continue;
			var _beam = 0.5 + 0.5 * dcos(_ang);                             // the side swinging toward us blazes
			var _lx0 = lengthdir_x(_rad, _ang - 12), _ly0 = lengthdir_y(_rad, _ang - 12) * _sq;
			draw_set_alpha((0.08 + 0.4 * _beam * _beam) * _disk);
			draw_line_width_color(_x + _lx0 * _ct + _ly0 * _st, _y - _lx0 * _st + _ly0 * _ct,
				_x + _lx * _ct + _ly * _st, _y - _lx * _st + _ly * _ct,
				(0.5 + (1 - _h1)) * _r / 22, c_black, merge_color(merge_color(_hot, _cool, _h1), _blue, 0.35 * _beam));
		}

		if (_pass == 0) {
			// d) the lensed disk: light from the far side of the disk, bent by gravity up and over the top of the shadow, and a thinner
			// image wrapped under the bottom. together with the shadow this is the silhouette everyone knows (Gargantua, NASA's 2019 render)
			for (var j = 0; j <= 40; j++) {
				var _la = 8 + j * (164 / 40);                                // the arc over the top, hugging the shadow
				var _lx = lengthdir_x(_r * 1.22, _la), _ly = lengthdir_y(_r * 1.34, _la);
				var _lit = power(dsin(_la), 0.7) * (0.55 + 0.45 * (0.5 + 0.5 * dcos(_la)));   // brightest at the top, the approaching side a touch brighter
				draw_sprite_ext(_soft, 0, _x + _lx * _ct + _ly * _st, _y - _lx * _st + _ly * _ct, _r * 0.42 / 20, _r * 0.18 / 20, _ho.tilt + _la - 90,
					merge_color(_hot, make_color_rgb(255, 170, 100), 0.35), 0.11 * _lit * _disk);
				var _ub = 192 + j * (156 / 40);                              // the thinner arc under the bottom
				var _ux = lengthdir_x(_r * 1.14, _ub), _uy = lengthdir_y(_r * 1.16, _ub);
				draw_sprite_ext(_soft, 0, _x + _ux * _ct + _uy * _st, _y - _ux * _st + _uy * _ct, _r * 0.3 / 20, _r * 0.1 / 20, _ho.tilt + _ub - 90, _cool, 0.07 * abs(dsin(_ub)) * _disk);
			}
			// e) the event horizon: true black (normal blending, because adding black adds nothing)
			gpu_set_blendmode(bm_normal);
			draw_set_alpha(1);
			draw_set_color(c_black);
			draw_circle(_x, _y, _r, false);
			gpu_set_blendmode(bm_add);
			// f) the photon ring: a crisp hairline of trapped light hugging the shadow, with a soft glow just outside it
			draw_set_color(make_color_rgb(255, 214, 170));                    // warm, not white: it's the disk's own light, wrapped around
			draw_set_alpha(0.5 * _disk);
			draw_circle(_x, _y, _r + 1, true);
			draw_set_alpha(0.18 * _disk);
			draw_circle(_x, _y, _r + 2.5, true);
			draw_sprite_ext(_soft, 0, _x + lengthdir_x(_r, _ho.tilt), _y + lengthdir_y(_r, _ho.tilt), _r * 0.5 / 20, _r * 1.4 / 20, _ho.tilt,
				_blue, 0.12 * _disk);                                         // brighter on the side rushing toward us
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

// adds a wisp to her haze. once the haze is full, the oldest wisp makes way
function scr_hex_haze_add(_w) {
	scr_hex_wisp_norm(_w);
	if (array_length(global.hex_haze) < HEX_HAZE_CAP) array_push(global.hex_haze, _w);
	else { global.hex_haze[global.hex_haze_i] = _w; global.hex_haze_i = (global.hex_haze_i + 1) mod HEX_HAZE_CAP; }
}

// the peek: a knot of her old haze collapsing into a star. gathers every free wisp within reach of a spot into a nursery.
// returns undefined if the gas there is too thin to collapse, unless _force (the debug key), which sows a little cloud first
function scr_hex_nursery_at(_cx, _cy, _t0, _force) {
	// a quasar's blast, and the long twilight after it, leave no cold gas calm enough to collapse: no new stars
	if (!_force && variable_global_exists("hex_aeon") && (global.hex_aeon.phase == "quasar" || global.hex_aeon.phase == "twilight")) return undefined;
	// close to a black hole, its pull tears a cloud apart faster than it can collapse (the tidal, or Roche, limit): no stars form there
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _nh = global.hex_holes[h];
		if (point_distance(_cx, _cy, _nh.ox, _nh.oy) < scr_hex_hole_size(_nh) * 7) return undefined;
	}
	var _hz = global.hex_haze;
	var _ws = [], _sx = 0, _sy = 0, _m = 0, _gc = -1;
	for (var i = 0; i < array_length(_hz); i++) {
		var _q = _hz[i];
		if (_q[$ "u"] == true) continue;                                   // already part of another star
		if (point_distance(_cx, _cy, _q.ox, _q.oy) > 80) continue;
		array_push(_ws, _q);
		_sx += _q.ox; _sy += _q.oy;
		if (_q.c != -1) { _m++; if (_gc == -1 || random(1) < 0.3) _gc = _q.c; }  // soot collapses too, but only glowing gas counts as mass
	}
	if (_m < 3) {
		if (!_force) return undefined;
		repeat (8) {   // debug: sow a little cloud here so there's something to collapse
			var _gr = random(60), _gd = random(360);
			var _q = { ox: _cx + lengthdir_x(_gr, _gd), oy: _cy + lengthdir_y(_gr, _gd), ang: random(360),
			           c: choose(make_color_rgb(255, 85, 115), make_color_rgb(70, 220, 200), make_color_rgb(255, 200, 90)),
			           s: 26, s0: 26, smax: 50, a: 0.12, f: 1 };
			scr_hex_haze_add(_q);
			array_push(_ws, _q);
			_sx += _q.ox; _sy += _q.oy; _m++;
			if (_gc == -1) _gc = _q.c;
		}
	}
	for (var i = 0; i < array_length(_ws); i++) _ws[i].u = true;           // claimed: no other star can take this gas
	var _mass = max(1, round(_m * 0.6));                                    // more gas, heavier star: red dwarf to blue giant
	var _ph = random(1000);
	return { ox: _sx / array_length(_ws), oy: _sy / array_length(_ws),     // the middle of the knot, in her sky's own frame
	         ws: _ws, pvx: [], pvy: [],                                    // its gas, and how hard the newborn pushes each wisp away
	         m: _mass, ph: _ph, c: scr_hex_star_color(_mass, _ph),
	         gc: (_gc == -1) ? make_color_rgb(255, 85, 115) : _gc,         // the color of its gas (for the infall and the jets)
	         spin: choose(-1, 1), jet: random(360),                        // which way its matter swirls, and where its poles point
	         t0: _t0, lit: false, jetgo: false };
}

// finds a knot of free haze worth collapsing: dense (a random wisp lands in dense gas more often, so dense gas collapses first,
// like real clouds), on screen, not right on top of her, and not crowding another birth this cast
function scr_hex_find_nursery(_taken, _t0, _rmax) {
	var _hz = global.hex_haze, _n = array_length(_hz);
	if (_n == 0) return undefined;
	repeat (16) {
		var _w = _hz[irandom(_n - 1)];
		if (_w.c == -1 || _w[$ "u"] == true) continue;
		var _wd = point_distance(0, 0, _w.ox, _w.oy);
		if (_wd < 90 || _wd > _rmax) continue;
		var _clear = true;
		for (var i = 0; i < array_length(_taken); i++) {
			if (point_distance(_w.ox, _w.oy, _taken[i].ox, _taken[i].oy) < 140) { _clear = false; break; }
		}
		if (!_clear) continue;
		var _nu = scr_hex_nursery_at(_w.ox, _w.oy, _t0, false);
		if (!is_undefined(_nu)) return _nu;
	}
	return undefined;
}

// how old a star is in cosmic seconds (stars from before aging existed count as newborn)
function scr_hex_age(_st) {
	var _a = _st[$ "age"];
	return is_undefined(_a) ? 0 : _a;
}

// a star's life, in seconds of her fighting. heavier stars burn hotter and die sooner, like real ones. red dwarfs never die
function scr_hex_star_life(_m) {
	if (_m < HEX_MASS_SUN_MIN) return infinity;
	return HEX_SUN_LIFE * power(10 / _m, 1.2);
}

// the sun-like star furthest past the end of its life, or undefined if none is due
function scr_hex_find_death() {
	var _best = undefined, _over = 0;
	for (var i = 0; i < array_length(global.hex_stars); i++) {
		var _st = global.hex_stars[i];
		if (_st.s <= 0 || _st[$ "wd"] == true || _st[$ "ns"] == true || _st[$ "dying"] == true) continue; // gone, a dead core already, or dying now
		if (_st.m < HEX_MASS_SUN_MIN) continue;                                    // red dwarfs never die
		var _ov = scr_hex_age(_st) - scr_hex_star_life(_st.m);
		if (_ov <= 0) continue;
		if (_st.m >= HEX_MASS_GIANT) _ov += 100000;                                 // a giant due to blow takes priority: the loud death
		if (_ov > _over) { _over = _ov; _best = _st; }
	}
	return _best;
}

// gives a wisp every field the hot loops read, so they can use plain dot access (fast) instead of looking fields up by name every frame
function scr_hex_wisp_norm(_w) {
	if (!variable_struct_exists(_w, "ex")) _w.ex = 1;          // exposure
	if (!variable_struct_exists(_w, "st")) _w.st = 1;          // stretch
	if (!variable_struct_exists(_w, "tx")) _w.tx = 1;          // how far its texture has come in
	if (!variable_struct_exists(_w, "fr")) _w.fr = irandom(7); // which atlas cell
	if (!variable_struct_exists(_w, "at")) _w.at = 0;          // brightness it's still growing toward
	if (!variable_struct_exists(_w, "u"))  _w.u  = false;      // claimed by a star
	if (!variable_struct_exists(_w, "tr")) _w.tr = false;      // caught by a black hole: falling in, leaving a trail
	if (!variable_struct_exists(_w, "fz")) _w.fz = 1;
	if (!variable_struct_exists(_w, "fl")) _w.fl = false;      // flying: thrown out by a black hole, not yet settled          // how far its orbit has flattened into a black hole's disk (1 = round)
}

// the light one wisp puts out: its brightness spread over its area. merging gas keeps this the same, so no light is lost or added
function scr_hex_wisp_light(_w) {
	return _w.a * _w.f * sqrt(_w.s0 / _w.s) * sqr(_w.s / 24);
}

// the exposure curve: how a camera sees gas. light from overlapping wisps doesn't just add up to white: each patch of sky
// glows toward a ceiling (1 - e^-x), so dim gas stays dim and dense gas glows rich and saturated. sets each wisp's exposure
// (ex), easing toward it by _k (1 = at once). returns the patches: { L (how much gas glows there), x, y (its middle) }
function scr_hex_haze_expose(_k) {
	var _hz = global.hex_haze, _n = array_length(_hz);
	var _map = ds_map_create(), _cells = [];                       // number keys in a ds_map: far cheaper than building strings
	var _wc = array_create(_n, undefined);
	for (var i = 0; i < _n; i++) {
		var _w = _hz[i];
		if (_w.c == -1) continue;                                  // soot doesn't glow
		var _key = (floor(_w.ox / 48) + 4096) * 16384 + (floor(_w.oy / 48) + 4096);
		var _ce = _map[? _key];
		if (is_undefined(_ce)) { _ce = { L: 0, x: 0, y: 0, r: 1 }; _map[? _key] = _ce; array_push(_cells, _ce); }
		var _l = scr_hex_wisp_light(_w);
		_ce.L += _l; _ce.x += _w.ox * _l; _ce.y += _w.oy * _l;
		_wc[i] = _ce;
	}
	ds_map_destroy(_map);
	for (var i = 0; i < array_length(_cells); i++) {
		var _ce = _cells[i];
		if (_ce.L <= 0.0001) continue;
		_ce.x /= _ce.L; _ce.y /= _ce.L;
		_ce.r = HEX_HAZE_GLOW * (1 - exp(-_ce.L / HEX_HAZE_GLOW)) / _ce.L;
	}
	for (var i = 0; i < _n; i++) {
		var _ce = _wc[i];
		if (is_undefined(_ce)) continue;
		var _w = _hz[i];
		_w.ex = lerp(_w.ex, _ce.r, _k);
	}
	return _cells;
}

// between casts her gas spreads and settles: every wisp thins a little, wisps thinned to nothing (or eaten by stars) are gone,
// and crowded wisps merge into bigger, softer ones with the same light. smooth clouds instead of froth, and the haze stays bounded
function scr_hex_haze_merge() {
	var _hz = global.hex_haze, _n = array_length(_hz);
	var _map = ds_map_create(), _groups = [], _out = [];
	for (var i = 0; i < _n; i++) {
		var _w = _hz[i];
		scr_hex_wisp_norm(_w);                                     // old wisps get the fields the fast draw needs
		_w.fl = false;                                             // anything still flying out of a black hole has landed
		_w.s = min(_w.s * 1.06, 90);                               // it spreads...
		_w.a *= 0.96;                                              // ...and thins
		if (_w.a * _w.f < 0.003) continue;                         // nothing left of it
		if (_w.u) { array_push(_out, _w); continue; }              // gas shaped by a star (its pocket, its jet streaks) keeps its shape
		var _key = ((floor(_w.ox / 36) + 4096) * 16384 + (floor(_w.oy / 36) + 4096)) * 2 + ((_w.c == -1) ? 1 : 0);
		var _cl = _map[? _key];
		if (is_undefined(_cl)) { _cl = []; _map[? _key] = _cl; array_push(_groups, _cl); }
		array_push(_cl, _w);
	}
	ds_map_destroy(_map);
	for (var k = 0; k < array_length(_groups); k++) {
		var _cl = _groups[k];
		while (array_length(_cl) > 2) {
			var _p = array_pop(_cl), _q = array_pop(_cl);
			var _lp = scr_hex_wisp_light(_p), _lq = scr_hex_wisp_light(_q), _lt = max(0.0001, _lp + _lq);
			var _ms = min(90, sqrt(sqr(_p.s) + sqr(_q.s)));           // their areas add
			array_insert(_cl, 0, { ox: (_p.ox * _lp + _q.ox * _lq) / _lt, oy: (_p.oy * _lp + _q.oy * _lq) / _lt,
				ang: (_p.s >= _q.s) ? _p.ang : _q.ang,
				c: (_p.c == -1) ? -1 : merge_color(_p.c, _q.c, _lq / _lt),  // their colors mix by how much light each brings
				s: _ms, s0: _ms, smax: min(110, _ms * 1.4), a: _lt / sqr(_ms / 24), f: 1,
				fr: (random(1) < 0.6) ? 4 + irandom(3) : irandom(3),         // big settled gas grows threads
				ex: 1, st: 1, tx: 1, at: 0, u: false, tr: false, fz: 1, fl: false });
		}
		for (var j = 0; j < array_length(_cl); j++) { scr_hex_wisp_norm(_cl[j]); array_push(_out, _cl[j]); }   // every field the rest of the code reads, filled in
	}
	global.hex_haze = _out;
	global.hex_haze_i = 0;
	global.hex_flow = [];
}

// her gas, given texture: 8 cells of real nebula structure in one atlas (one texture, so thousands of wisps still draw as one batch).
// cells 0-3 are billowing clouds, 4-7 are threads and filaments. each is a soft bell like spr_soft, carved by noise: warped fBm curls
// the billows, ridged noise draws the threads, so the gas reads as wisps, lanes and tendrils instead of round puffs.
// every cell carries the same total light as a soft puff, just shaped, so swapping it in doesn't brighten or dim the sky
function scr_hex_wisp_sprite() {
	var _W = 256, _H = 128;
	var _g = scr_noise_grid(7177);
	var _buf = buffer_create(_W * _H * 4, buffer_fixed, 1);
	buffer_fill(_buf, 0, buffer_u8, 0, _W * _H * 4);
	for (var _c = 0; _c < 8; _c++) {
		var _cx = (_c mod 4) * 64, _cy = (_c div 4) * 64;
		var _fil = (_c >= 4);
		var _ox = _c * 13.7, _oy = _c * 7.9;
		var _d = array_create(4096, 0), _sum = 0, _bell = 0;
		for (var _yy = 0; _yy < 64; _yy++) {
			for (var _xx = 0; _xx < 64; _xx++) {
				var _u = (_xx - 31.5) / 31, _v = (_yy - 31.5) / 31;
				var _wu = _u + 0.45 * (scr_fbm(_g, _u * 1.3 + _ox + 3.1, _v * 1.3 + _oy, 3) - 0.5);   // warp: shapes curl
				var _wv = _v + 0.45 * (scr_fbm(_g, _u * 1.3 + _ox, _v * 1.3 + _oy + 5.7, 3) - 0.5);
				var _eu = _fil ? _u * 0.75 : _u, _ev = _fil ? _v * 1.7 : _v;                          // threads are long and thin
				var _r2 = _eu * _eu + _ev * _ev;
				var _env = exp(-3 * _r2) * clamp(1 - _r2, 0, 1);
				var _n = scr_fbm(_g, _wu * 2.4 + _ox, _wv * 2.4 + _oy, 4);
				var _val;
				if (_fil) { var _rg = 1 - abs(2 * _n - 1); _val = 0.2 * _n + 1.2 * power(_rg, 4); }
				else _val = clamp((_n - 0.3) * 2.2, 0, 1.5);
				var _dv = _env * _val;
				_d[_xx + _yy * 64] = _dv;
				_sum += _dv;
				var _br = _u * _u + _v * _v;
				_bell += exp(-3 * _br) * clamp(1 - _br, 0, 1);
			}
		}
		var _k = (_sum > 0) ? 0.9 * _bell / _sum : 1;
		for (var i = 0; i < 4096; i++) {
			var _b = round(clamp(_d[i] * _k, 0, 1) * 255);
			var _o = ((_cy + (i div 64)) * _W + (_cx + (i mod 64))) * 4;
			buffer_poke(_buf, _o,     buffer_u8, _b);
			buffer_poke(_buf, _o + 1, buffer_u8, _b);
			buffer_poke(_buf, _o + 2, buffer_u8, _b);
			buffer_poke(_buf, _o + 3, buffer_u8, 255);
		}
	}
	var _s = surface_create(_W, _H);
	buffer_set_surface(_buf, _s, 0);
	var _spr = sprite_create_from_surface(_s, 0, 0, _W, _H, false, false, 0, 0);
	surface_free(_s);
	buffer_delete(_buf);
	return _spr;
}

// draws one cell of the wisp atlas centered at (_x, _y), scaled and turned like draw_sprite_ext would.
// draw_sprite_general turns a part around its top-left corner, so this moves that corner to keep the cell's middle in place
function scr_hex_draw_wisp(_spr, _fr, _x, _y, _xs, _ys, _rot, _col, _a) {
	var _cs = dcos(_rot), _sn = dsin(_rot);
	var _hx = 32 * _xs, _hy = 32 * _ys;
	draw_sprite_general(_spr, 0, (_fr mod 4) * 64, (_fr div 4) * 64, 64, 64,
		_x - _hx * _cs - _hy * _sn, _y + _hx * _sn - _hy * _cs, _xs, _ys, _rot, _col, _col, _col, _col, _a);
}


// ---- the aeon: her universe's whole life, and its rebirth ----
// galaxy: the supermassive anchors everything and feeds. once it has eaten enough, it ignites:
// quasar: its disk outshines the whole sky, jets span the screen, and its wind blows the gas out of the galaxy (real: why big
//   galaxies go "red and dead"). no new stars
// twilight: no cold gas left to collapse. the old stars age out into giants, rings and embers. warm, dim, quiet
// evaporation: the supermassive shrinks away by Hawking radiation (real, in compressed time), hotter and brighter as it shrinks,
//   and ends in one final flash
// dawn: the flash becomes fresh primordial gas: a new nebula in a new palette, and everything begins again (a nod to Penrose's
//   conformal cyclic cosmology: a dead universe of evaporated black holes becomes the next Big Bang). call every frame from obj_unmaking
#macro HEX_QUASAR_MEAL 300   // how much gas the supermassive must eat before it ignites as a quasar
function scr_hex_aeon_step() {
	var _fps = game_get_speed(gamespeed_fps);
	if (!variable_global_exists("hex_aeon")) global.hex_aeon = { phase: "dawn", t: 0, n: 0 };
	if (!variable_global_exists("hex_flow")) global.hex_flow = [];
	if (!variable_global_exists("hex_ripples")) global.hex_ripples = [];
	var _ae = global.hex_aeon;
	_ae.t++;
	// ---- the aeon director: the universe's mood. each age sets targets, and the real values ease toward them every frame, so
	// every hand-off between ages is smooth. everything that changes the whole sky reads from here instead of setting its own:
	// bg = how much of the old backdrop is visible, dark = how black the screen is, spin = how fast disks turn, lensk = lens strength ----
	if (!variable_global_exists("hex_mood")) global.hex_mood = { bg: 1, dark: 0, spin: 1, lensk: 1, gr: 1, gg: 1, gb: 1, lift: 0 };
	var _md = global.hex_mood;
	if (!variable_struct_exists(_md, "gr")) { _md.gr = 1; _md.gg = 1; _md.gb = 1; _md.lift = 0; }
	var _tbg = 1, _tdark = 0, _tspin = 1, _tlens = 1;
	// the color grade: every age has its own light, from real cosmology. young galaxies are vivid, a quasar blazes blue-white,
	// an old "red and dead" galaxy glows amber (its blue stars died first), a collapsing universe is blueshifted (its light is
	// squeezed, and the night sky itself brightens), and a newborn universe starts cool and clear
	var _tr = 1, _tgc = 1, _tb = 1, _tlift = 0;
	switch (_ae.phase) {
		case "quasar":   _tr = 1.05; _tgc = 1.03; _tb = 1.12; break;
		case "twilight": _tbg = 0.75; _tr = 1.12; _tgc = 0.86; _tb = 0.66; break;
		case "crunch":
			var _mk = min(1, _ae.t / (_fps * 12));
			_tbg = 1 - _mk; _tspin = 1 + 9 * _mk * _mk; _tlens = 1 + 0.5 * _mk;
			_tdark = clamp((_mk - 0.82) / 0.18, 0, 1);                        // the last moments: everything goes black
			_tr = lerp(1.05, 0.7, _mk); _tgc = lerp(0.9, 0.88, _mk); _tb = lerp(0.8, 1.45, _mk); _tlift = 0.05 * _mk;   // blueshift
			break;
		case "void": _tbg = 0; _tdark = 1; _tspin = 0.3; break;
	}
	if (variable_global_exists("hex_bang") && is_struct(global.hex_bang)) {                // a newborn universe: cool and clear
		var _bk2 = min(1, global.hex_bang.t / (_fps * 16));
		_tr = lerp(0.86, _tr, _bk2); _tgc = lerp(0.96, _tgc, _bk2); _tb = lerp(1.14, _tb, _bk2);
	}
	_md.gr += (_tr - _md.gr) * 0.02; _md.gg += (_tgc - _md.gg) * 0.02; _md.gb += (_tb - _md.gb) * 0.02;
	_md.lift += (_tlift - _md.lift) * 0.03;
	if (variable_global_exists("hex_bang") && is_struct(global.hex_bang)) _tbg = min(_tbg, sqr(min(1, global.hex_bang.t / (_fps * 14))));   // the new universe's light arrives slowly
	_md.bg    += (_tbg - _md.bg) * 0.06;
	_md.dark  += (_tdark - _md.dark) * 0.15;
	_md.spin  += (_tspin - _md.spin) * 0.05;
	_md.lensk += (_tlens - _md.lensk) * 0.03;
	// the disks' clock: it runs at the director's spin, faster during the crunch (Draw passes it to sh_hex_lens)
	if (!variable_global_exists("hex_disk_time")) global.hex_disk_time = 0;
	global.hex_disk_time += _md.spin / _fps;
	if (variable_global_exists("hex_bang") && is_struct(global.hex_bang)) {
		var _bg = global.hex_bang;
		_bg.t++;
		// first light: as the new gas comes to rest, its densest clumps collapse into the first stars of the new aeon
		if (_bg.t > _fps * 2.5 && _bg.t < _fps * 16 && _bg.t mod round(_fps * 1.4) == 0 && array_length(_bg.ws) > 0) {
			repeat (4) {
				var _bw = _bg.ws[irandom(array_length(_bg.ws) - 1)];
				if (_bw.f <= 0.01 || _bw.fl) continue;
				var _bnu = scr_hex_nursery_at(_bw.ox, _bw.oy, t, false);
				if (!is_undefined(_bnu)) { array_push(nurseries, _bnu); break; }
			}
		}
		if (_bg.t > _fps * 16) global.hex_bang = undefined;
	}
	var _sm = scr_hex_find_smbh();
	if (keyboard_check_pressed(ord("K")) && !is_undefined(_sm)) {           // debug: skip to the next age of her universe
		if (_ae.phase == "galaxy" || _ae.phase == "dawn") _sm.meal = HEX_QUASAR_MEAL;
		else if (_ae.phase != "crunch" && _ae.phase != "void") _ae.t = 999999;   // the end of the universe can't be skipped
	}
	switch (_ae.phase) {
	case "dawn":
	case "galaxy":
		if (is_undefined(_sm)) { _ae.phase = "dawn"; break; }
		_ae.phase = "galaxy";
		if (!variable_struct_exists(_sm, "meal")) _sm.meal = 0;
		if (_sm.meal >= HEX_QUASAR_MEAL) { _ae.phase = "quasar"; _ae.t = 0; global.shake = max(global.shake, 16); }
		break;

	case "quasar":
		if (is_undefined(_sm)) { _ae.phase = "dawn"; break; }
		var _qlen = _fps * 10;
		_sm.qk = min(1, _ae.t / (_fps * 1.5)) * (1 - max(0, (_ae.t - _qlen * 0.75) / (_qlen * 0.25)));   // flares up, holds, fades
		_sm.feed = max(variable_struct_exists(_sm, "feed") ? _sm.feed : 0, 80);                                          // jets blazing
		// the quasar's wind: gas across the galaxy is blown outward, faster close in
		var _hz = global.hex_haze, _blown = 0, _qR = scr_hex_hole_size(_sm) * 12;
		for (var i = irandom(19); i < array_length(_hz) && _blown < 12 && array_length(global.hex_flow) < 700; i += 20) {
			var _w = _hz[i];
			if (_w.f <= 0.01 || _w.fl || _w.u) continue;
			var _dx = _w.ox - _sm.ox, _dy = _w.oy - _sm.oy, _d = point_distance(0, 0, _dx, _dy);
			if (_d > _qR || _d < 1) continue;
			var _v = random_range(3.5, 6) * (1.3 - _d / _qR);
			_w.vx = _dx / _d * _v; _w.vy = _dy / _d * _v; _w.fl = true; _w.tr = false;
			_w.c = merge_color(_w.c, make_color_rgb(200, 215, 255), 0.4);      // heated by the blast
			array_push(global.hex_flow, _w);
			_blown++;
		}
		if (_ae.t >= _qlen) { _ae.phase = "twilight"; _ae.t = 0; _sm.qk = 0; _sm.meal = 0; }
		break;

	case "twilight":
		if (is_undefined(_sm)) { _ae.phase = "dawn"; break; }
		var _hz = global.hex_haze;                                              // what gas is left slowly dims as it thins out
		for (var i = _ae.t mod 10; i < array_length(_hz); i += 10) { var _w = _hz[i]; _w.a *= 0.995; }
		if (_ae.t >= _fps * 45) { _ae.phase = "crunch"; _ae.t = 0; }
		break;

	case "crunch":
		// ---- THE BIG CRUNCH. a cyclic universe's end in the Big Bounce models: everything falls back together. gas, stars and the
		// last black holes spiral into the supermassive, spinning faster and faster as they fall (conservation of angular momentum:
		// a skater pulling in her arms), space itself bends harder as it all packs denser, and then it bounces ----
		if (is_undefined(_sm)) { _ae.phase = "dawn"; break; }
		var _clen = _fps * 12;
		var _ck  = min(1, _ae.t / _clen);
		var _ck0 = min(1, (_ae.t - 1) / _clen);
		_sm.ck = _ck;
		_sm.feed = max(variable_struct_exists(_sm, "feed") ? _sm.feed : 0, 60 + 200 * _ck);
		global.shake = max(global.shake, 1 + 9 * _ck * _ck);
		_sm.ox = lerp(_sm.ox, 0, 0.02 * _ck);                                  // the end comes for her view too
		_sm.oy = lerp(_sm.oy, 0, 0.02 * _ck);
		var _cx = _sm.ox, _cy = _sm.oy, _cr = scr_hex_hole_size(_sm);
		// everything's remaining distance shrinks on a schedule that reaches zero exactly at the end: slow at first, then a rush
		var _rem0 = power(1 - _ck0, 1.6), _rem1 = power(1 - _ck, 1.6);
		var _csh  = (_rem0 > 0.00001) ? _rem1 / _rem0 : 0;
		var _cspn = 0.5 + 10 * _ck * _ck;                                        // and it all spins up as it falls (angular momentum)
		var _hz = global.hex_haze;
		for (var i = 0; i < array_length(_hz); i++) {
			var _w = _hz[i];
			if (_w.f <= 0.01) continue;
			if (_w.fl) { _w.fl = false; _w.vx = 0; _w.vy = 0; }               // nothing escapes now
			var _dx = _w.ox - _cx, _dy = _w.oy - _cy, _d = sqrt(_dx * _dx + _dy * _dy);
			if (_d * _csh < _cr * 1.05) { _w.f = 0; continue; }
			if (_d < _cr * 2.5) _w.f *= 0.9;                                    // close to the horizon it fades into it instead of piling up
			var _wa = min(12, _cspn * 300 / max(_d, 120));
			var _c = dcos(_wa), _s = dsin(_wa);
			_w.ox = _cx + (_dx * _c + _dy * _s) * _csh; _w.oy = _cy + (-_dx * _s + _dy * _c) * _csh;
			_w.ang = point_direction(0, 0, _dx, _dy) - 90;                      // stretched along its spiral
			_w.st  = 1 + 0.9 * _ck; _w.tr = false; _w.smax = _w.s;
		}
		if (gaze) {                                                            // the stars fall in too (only while she's watching: casts track stars by index)
			for (var i = array_length(global.hex_stars) - 1; i >= 0; i--) {
				var _q = global.hex_stars[i];
				var _dx = _q.ox - _cx, _dy = _q.oy - _cy, _d = sqrt(_dx * _dx + _dy * _dy);
				if (_d * _csh < _cr) { array_delete(global.hex_stars, i, 1); continue; }
				var _wa = min(12, _cspn * 300 / max(_d, 120));
				var _c = dcos(_wa), _s = dsin(_wa);
				_q.ox = _cx + (_dx * _c + _dy * _s) * _csh; _q.oy = _cy + (-_dx * _s + _dy * _c) * _csh;
			}
		}
		for (var h = array_length(global.hex_holes) - 1; h >= 0; h--) {        // and the last black holes
			var _q = global.hex_holes[h];
			if (_q == _sm) continue;
			var _dx = _q.ox - _cx, _dy = _q.oy - _cy, _d = sqrt(_dx * _dx + _dy * _dy);
			if (_d * _csh < _cr * 1.2) { array_push(global.hex_ripples, { ox: _q.ox, oy: _q.oy, age: 0, len: _fps * 1.2, amp: 8 }); array_delete(global.hex_holes, h, 1); continue; }
			var _wa = min(12, _cspn * 300 / max(_d, 120));
			var _c = dcos(_wa), _s = dsin(_wa);
			_q.ox = _cx + (_dx * _c + _dy * _s) * _csh; _q.oy = _cy + (-_dx * _s + _dy * _c) * _csh;
		}
		if (_ae.t >= _clen) { _ae.phase = "void"; _ae.t = 0; }
		break;

	case "void":
		// ---- nothing. the universe has ended: one horizon holds everything there ever was, and she stands alone in the dark
		// outside it. a beat of silence... and then the lightswitch ----
		if (is_undefined(_sm)) { _ae.phase = "dawn"; break; }
		_sm.ck = 1;
		var _cx = _sm.ox, _cy = _sm.oy;
		global.shake = 0;
		if (_ae.t >= _fps * 1.1) {
			var _palettes = [
				[make_color_rgb(120, 200, 255), make_color_rgb(255, 120, 160), make_color_rgb(160, 120, 255)],
				[make_color_rgb(90, 230, 190), make_color_rgb(255, 190, 110), make_color_rgb(230, 110, 140)],
				[make_color_rgb(255, 140, 200), make_color_rgb(140, 170, 255), make_color_rgb(120, 230, 230)],
				[make_color_rgb(255, 170, 120), make_color_rgb(170, 110, 255), make_color_rgb(110, 210, 160)]
			];
			_ae.n++;
			var _pal = _palettes[_ae.n mod array_length(_palettes)];
			// ---- THE BIG BANG (the bounce). the singularity flares and the sky washes white. a new universe of gas rushes out from
			// that one point, white-hot and cooling into its colors as it expands, and coasts to rest across her whole sky. the sky
			// glows with the mottled, cooling afterglow of creation (the cosmic microwave background: sh_hex_lens), and the first
			// stars of the new aeon light up in its densest clumps ----
			global.hex_bang = { ox: _cx, oy: _cy, t: 0, ws: [] };
			if (variable_global_exists("hex_mood")) { global.hex_mood.dark = 0; global.hex_mood.bg = 0; }
			var _hot = make_color_rgb(255, 246, 236);
			var _mx = _cx * 0.3, _my = _cy * 0.3;                               // the new universe settles around her, so she can see it
			repeat (44) {                                                       // many small clumps: the seeds of the new universe's structure
				var _kd = random(360), _kl = sqrt(random(1)) * 720 + 60;
				var _kx = _mx + lengthdir_x(_kl, _kd), _ky = _my + lengthdir_y(_kl, _kd);
				var _kc = _pal[irandom(2)];
				repeat (10) {
					if (array_length(global.hex_haze) >= HEX_HAZE_CAP + 1300) break;
					var _gd = random(360), _gl = random(70) * random(1);
					var _tx = _kx + lengthdir_x(_gl, _gd), _ty = _ky + lengthdir_y(_gl, _gd);   // where this bit of the new universe comes to rest
					var _sx = _cx + random_range(-14, 14), _sy = _cy + random_range(-14, 14);
					var _dd = max(1, point_distance(_sx, _sy, _tx, _ty));
					var _vv = _dd * (1 - 0.985) * random_range(0.96, 1.04);           // launched just hard enough to coast there (it slows by 1.5% a frame)
					var _gs = random_range(14, 24);
					var _gw = { ox: _sx, oy: _sy, ang: random(360),
						c: _hot, s: _gs * 0.4, s0: _gs * 0.4, smax: _gs * 1.5, a: 0.05, at: 0.13, f: 1,
						ex: 1, st: 1, tx: 0, fr: irandom(3), u: false };             // soft round billows: a blooming cloud, not darts
					scr_hex_wisp_norm(_gw);
					_gw.vx = (_tx - _sx) / _dd * _vv; _gw.vy = (_ty - _sy) / _dd * _vv;
					_gw.fl = true; _gw.cool = merge_color(_kc, _pal[irandom(2)], random(0.35));   // white-hot, cooling into its color as it expands
					array_push(global.hex_haze, _gw);
					array_push(global.hex_flow, _gw);
					array_push(global.hex_bang.ws, _gw);
				}
			}
			repeat (70) {                                                       // and a broad, soft haze of new gas filling the space between
				if (array_length(global.hex_haze) >= HEX_HAZE_CAP + 1400) break;
				var _bd = random(360), _bl = sqrt(random(1)) * 900;
				var _tx = _mx + lengthdir_x(_bl, _bd), _ty = _my + lengthdir_y(_bl, _bd);
				var _dd = max(1, point_distance(_cx, _cy, _tx, _ty));
				var _vv = _dd * (1 - 0.985) * random_range(0.96, 1.04);
				var _gs = random_range(36, 60);
				var _gw = { ox: _cx, oy: _cy, ang: random(360), c: _hot, s: _gs * 0.3, s0: _gs * 0.3, smax: _gs, a: 0.02, at: 0.05, f: 1,
					ex: 1, st: 1, tx: 0, fr: irandom(3), u: false };
				scr_hex_wisp_norm(_gw);
				_gw.vx = (_tx - _cx) / _dd * _vv; _gw.vy = (_ty - _cy) / _dd * _vv;
				_gw.fl = true; _gw.cool = _pal[irandom(2)];
				array_push(global.hex_haze, _gw);
				array_push(global.hex_flow, _gw);
			}
			array_push(global.hex_ripples, { ox: _cx, oy: _cy, age: 0, len: _fps * 3, amp: 26 });
			global.shake = max(global.shake, 34);
			global.hex_holes = [];
			if (variable_global_exists("hex_merge")) global.hex_merge = undefined;
			if (gaze) global.hex_stars = [];
			_ae.phase = "dawn"; _ae.t = 0;
		}
		break;
	}
}
