// The Hexweaver: spread hexes that ripen into toads, 
//with the ultimate ability to tear away the fabric of space, turning your enemies into stars in your galaxy

#macro HEX_VIOLET make_color_rgb(170, 90, 255)
#macro HEX_COLLAPSE_MASS 100 // how much one star must swallow before it caves in. the main knob
#macro HEX_MAX_HOLES     3   // black holes allowed at once (merging frees room for more)
#macro HEX_SMBH_GEN      2   // mergers before a black hole is supermassive (2 = three holes become one)
#macro HEX_HOLE_SPACING  500 // black holes must be at least this far apart, so they're spread across her sky
#macro HEX_GATHER floor(game_get_speed(gamespeed_fps) * 1.5) // frames a dying star spends gathering in before it collapses
#macro HEX_STAR_SOFTEN 0.225 // 0 = full color, 1 = all white. how much the star colors are washed toward white
#macro HEX_MASS_BLUE 64    // the mass at which a star burns fully blue. lower = bluer skies, higher = redder
#macro HEX_HAZE_CAP 3000   // the most haze wisps her sky keeps. past this, the oldest make 
#macro HEX_MASS_SUN_MIN 6   // stars at least this heavy are sun-like: they age, swell into red giants and die as planetary nebulae. lighter ones live forever
#macro HEX_MASS_GIANT   24  // this heavy and up is a blue giant: it skips the planetary nebula (it goes supernova later)
#macro HEX_HAZE_GLOW    0.6  // the exposure ceiling: how bright the densest gas can glow. dim gas stays dim, dense gas glows rich but never clips to white
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
	// every star she makes is a young STAR CLUSTER in her garden, living by the same physics as the ones the gas forms (scr_hex_pops_update):
	// born still wrapped in its dust (warm, orange, like the stardust that made it), it emerges blue-white over a few Myr, lights and heats
	// its nebula, blows its superbubble, hands its gas back. its mass: HEX_CAST_STAR_MASS for each of her dead it holds (her magic's
	// new matter, like the gas her kills become)
	var _w = _e.star_hexed ? 3 : 1;
	if (!_merged) {
		_st = scr_hex_cast_cluster(_p, _w, _e.star_hexed, _big);
		_p.idx = array_length(global.hex_stars) - 1;
	} else {
		_st = global.hex_stars[_p.idx];
		_st.s   = min(4.5, _st.s + 0.35);    // bigger and brighter with each one, up to a cap
		_st.hx  = _st.hx || _e.star_hexed;
		_st.big = _st.big || _big;
		scr_hex_cast_feed(_st, _w);           // more of her dead condense into it
	}

	// tell the realm a star was just born (or fed), so it can flash. no rumble: the stardust is the quiet part, and stars catch in silence
	if (instance_exists(obj_unmaking)) {
		var _c = _st[$ "cb"] ?? scr_hex_star_color(_st.m, _st.ph, _st.hx);
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

	// (no clear space around her any more: she is a silent observer, and her universe takes no notice of her)

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

// a black hole's size on screen: set by its mass alone, so it grows smoothly as it eats and merges, and a supermassive is big
// because it's heavy. (a real horizon grows in step with mass; we use the square root so the range fits on screen: a newborn
// hole of mass 40 is ~39px, a supermassive of 300 ~107px, capped at 160.) it used to also jump 45% with every merger it had
// swallowed (an art choice, not physics), and that jump read as the merged hole popping to a new size
function scr_hex_hole_size(_ho, _ring = false) {   // (_ring: the old ringdown wobble in the size. off everywhere: it made every disk, jet and glow bounce after a merge)
	var _ev = variable_struct_exists(_ho, "evk") ? _ho.evk : 0;          // evaporating: it shrinks away to nothing
	// (edit43) by the decades of its mass: a 100,000-sun seed ~30px, +18px for every tenfold, 140px at most. art, not its real horizon
	// (that's AU across, far under a pixel); its physical reach on the gas is HEX_BH_REACH, so this can be as big as it looks best
	var _r  = clamp(30 + 18 * log10(max(1, scr_hex_pop_msun(_ho.m)) / 100000), 30, 140) * (1 - 0.92 * _ev);
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
// THE SEED (HEX_SEED_MSUN): one black hole at the galaxy's heart, formed directly from collapsing gas at Dawn
function scr_hex_seed_hole() {
	array_push(global.hex_holes, { ox: 0, oy: 0, m: HEX_SEED_MSUN / scr_hex_pop_msun(1), s: 1, age: HEX_GATHER + game_get_speed(gamespeed_fps) * 3,
		ph: random(1000), tilt: random_range(-12, 12), feed: 0, gen: HEX_SMBH_GEN, eat: 0, mdot: 0, mdsm: 0, edd: 0, agn_t: 0, rho: 0 });
}
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
	if (scr_hex_iso()) return;                                                 // (physics only: no scripted rotation)
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
	if (!is_undefined(_mg)) {                                                  // a merging pair keeps its own orbit, but its center turns with the galaxy
		var _dx = _mg.cx - _cx, _dy = _mg.cy - _cy;
		var _w = -0.085 * _k * 300 / max(300, sqrt(_dx * _dx + _dy * _dy));
		var _c = dcos(_w), _s = dsin(_w);
		_mg.cx = _cx + _dx * _c + _dy * _s; _mg.cy = _cy - _dx * _s + _dy * _c;
		_mg.ang += _w;
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
	if (scr_hex_iso()) return;                                                 // (physics only: holes don't slide by script)
	var _bh = global.hex_holes;
	if (array_length(_bh) < 2) return;
	var _mg = variable_global_exists("hex_merge") ? global.hex_merge : undefined;
	for (var h = 0; h < array_length(_bh); h++) {
		var _a = _bh[h];
		if (_a.age < HEX_GATHER + game_get_speed(gamespeed_fps)) continue;
		if (!is_undefined(_mg) && (_a == _mg.a || _a == _mg.b)) continue;
		// pulled toward EACH other hole like gravity (mass over distance squared), so the nearest and heaviest win. (it used to head for
		// the average position of all the others, which can sit right beside her with one hole on each side: everyone froze there)
		var _gx = 0, _gy = 0, _gm = 0, _dmin = infinity;
		for (var k = 0; k < array_length(_bh); k++) {
			var _b = _bh[k];
			if (_b == _a || _b.age < HEX_GATHER) continue;
			var _dx = _b.ox - _a.ox, _dy = _b.oy - _a.oy, _dd = max(1, sqrt(_dx * _dx + _dy * _dy));
			var _pull = _b.m / (_dd * _dd);
			_gx += _dx / _dd * _pull; _gy += _dy / _dd * _pull; _gm += _b.m;
			_dmin = min(_dmin, _dd);
		}
		var _gl = sqrt(_gx * _gx + _gy * _gy);
		if (_gm <= 0 || _gl <= 0) continue;
		var _ux = _gx / _gl, _uy = _gy / _gl;
		var _mv = min(_dmin * 0.85, _px * 2 * _gm / (_gm + _a.m));
		var _nx = _a.ox + _ux * _mv, _ny = _a.oy + _uy * _mv;
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
}

// is there room in her sky for a new black hole here?
function scr_hex_hole_room(_ox, _oy) {
	if (array_length(global.hex_holes) >= HEX_MAX_HOLES) return false;
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
				draw_set_alpha(0.35 * _qk);
				draw_line_width_color(_q0x, _q0y, _qx, _qy, _r * 0.5, HEX_VIOLET, c_black);
				draw_set_alpha(0.7 * _qk);
				draw_line_width_color(_q0x, _q0y, _qx, _qy, _r * 0.14, make_color_rgb(190, 210, 255), c_black);
				draw_set_alpha(1 * _qk);
				draw_line_width_color(_q0x, _q0y, _qx, _qy, 3, c_white, make_color_rgb(200, 220, 255));
				// knots: real jets are lumpy, with bright blobs racing outward along them (M87's jet shows them moving
				// at what looks like faster than light, an illusion of their near-light speed toward us)
				for (var _kn = 0; _kn < 7; _kn++) {
					var _kf = frac(current_time / 2600 + _kn / 7 + (_js > 0) * 0.5);
					var _kl = _r * 1.2 + _kf * 1400;
					draw_sprite_ext(_soft, 0, _x + lengthdir_x(_kl, _jd), _y + lengthdir_y(_kl, _jd), _r * 0.022, _r * 0.022, 0,
						make_color_rgb(215, 230, 255), 0.75 * _qk * (1 - _kf));
				}
			}
			draw_sprite_ext(_soft, 0, _x, _y, _r * 9 / 20, _r * 9 / 20, 0, make_color_rgb(255, 235, 215), 0.3 * _qk);   // it outshines the galaxy
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
	// (the fluid pours each new wisp's gas into itself exactly once, when it settles: scr_hex_fluid_update)
}

// the peek: a knot of her old haze collapsing into a star. gathers every free wisp within reach of a spot into a nursery.
// returns undefined if the gas there is too thin to collapse, unless _force (the debug key), which sows a little cloud first
function scr_hex_nursery_at(_cx, _cy, _t0, _force) {
	if (scr_hex_iso() && !_force) return undefined;                            // (physics only: no stars built from wisps; B still works)
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
		if (_st[$ "pop"] == true) continue;                                        // (a star cluster's stars die by its own clock: scr_hex_pops_update)
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

// how much gas one wisp is (for the fluid): its light at full brightness. constant as it spreads, kept by merging, falls as it fades
function scr_hex_wisp_gas(_w) {
	var _s0 = variable_struct_exists(_w, "s0") ? _w.s0 : _w.s;
	var _at = variable_struct_exists(_w, "at") ? _w.at : 0;
	return max(_w.a, _at) * _w.f * sqrt(_s0 / max(1, _w.s)) * sqr(_w.s / 24);
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
// ---- the matter ledger: as the crunch begins, everything her universe holds (its gas, its stars, its black holes) is counted,
// and a sample of its colors kept. the Big Bang releases exactly that much, in those colors shifted into the new aeon's palette:
// matter is never made or lost here, only transformed. only her kills ever add new matter: her slimes fuel every universe ----
function scr_hex_matter_take() {
	var _L = 0, _cols = [];
	var _hz = global.hex_haze;
	for (var i = 0; i < array_length(_hz); i++) {
		var _w = _hz[i];
		if (_w.f <= 0.01) continue;
		_L += scr_hex_wisp_light(_w);
		if (_w.c != -1 && array_length(_cols) < 64 && random(1) < 0.08) array_push(_cols, _w.c);
	}
	for (var i = 0; i < array_length(global.hex_stars); i++) {
		var _q = global.hex_stars[i];
		if (_q.s <= 0) continue;
		_L += _q.m * 0.02;
		if (array_length(_cols) < 64 && random(1) < 0.05) array_push(_cols, scr_hex_star_color(_q.m, _q.ph, _q.hx));
	}
	for (var h = 0; h < array_length(global.hex_holes); h++) _L += global.hex_holes[h].m * 0.05;
	global.hex_ledger = { L: _L, cols: _cols };
}

// THE UNIVERSE'S LIFE (step 5). a closed universe: enough matter that its expansion stalls and it falls back into a Big Crunch.
// Friedmann's equations give its whole lifetime from how much matter it holds, T = pi Omega / (H0 (Omega - 1)^1.5): more matter,
// a shorter life. most matter is dark (fixed, HEX_UNI_DM); the gas, stars and holes (the baryons) are what her casts add to, so
// the more she unmakes, the sooner it ends. the baryons are conserved: gas lost off the edge of her sky returns to the unseen
// reservoir between galaxies, which rains back onto the galaxy along the cosmic web (cold flows), and the crunch hands all of it
// to the next Big Bang. stargazing alone, the same amount loops forever
#macro HEX_UNI_T 1800        // Myr: the lifetime of a typical run's universe (crunch around minute 30 at 1 Myr a second)
#macro HEX_UNI_B0 900        // gas units: the baryons of a universe nobody has fed (stargazing alone: ~35 minutes)
#macro HEX_UNI_BREF 2400     // the baryons of a typical run's universe, the one that lives HEX_UNI_T
#macro HEX_UNI_DM 5          // dark matter, in units of a typical run's baryons (the real cosmic ratio is ~5.4)
#macro HEX_UNI_DOM 0.05      // how far past the critical density a typical universe is (Omega - 1)
#macro HEX_UNI_TMIN 600      // Myr: the shortest it lives however much is fed in (a floor, so endless runs never loop in minutes)
#macro HEX_INFLOW_T 300      // Myr: the reservoir rains onto the galaxy on this e-fold time (it runs dry late: the galaxy starves)
#macro HEX_BANG_GAS 0.3      // share of the baryons each Big Bang drops straight into her sky (the rest starts in the reservoir)
#macro HEX_INFLOW_MAX 4      // gas units per Myr: the most the halo can take in (above ~10^12 suns, infalling gas is shock-heated and
                             // can't cool onto the galaxy: Dekel & Birnboim 2006), so a heavily fed universe keeps the rest out in the web
#macro HEX_BANG_MAX 300      // gas units: the most a Big Bang drops straight into her sky (a young galaxy's worth); the rest starts in the reservoir
#macro HEX_CRUNCH_MYR 12     // the crunch's last Myr: everything falls together
function scr_hex_uni_life(_B) {
	var _r = (HEX_UNI_DM * HEX_UNI_BREF + _B) / ((HEX_UNI_DM + 1) * HEX_UNI_BREF);   // its matter, over a typical universe's
	return max(HEX_UNI_TMIN, HEX_UNI_T * (1 + HEX_UNI_DOM * _r) / (1 + HEX_UNI_DOM) * power(_r, -1.5));
}
function scr_hex_cosmo_new(_B, _inSky) {
	global.hex_cosmo = { B: _B, R: _B - _inSky, G: 0, pend: _inSky, T: scr_hex_uni_life(_B), sfr: 0, sfpk: 0, sf0: 0, fa: random(360) };
}
// the cold flows: three filaments of the cosmic web, pointing their own way each universe and slowly wandering, pour the
// reservoir's gas in from beyond the edge of her view (pristine hydrogen and helium), falling inward and swirling the way the galaxy turns
function scr_hex_inflow(_fl, _cs, _I) {
	var _half = HEX_FLUID_CS * HEX_FLUID_W / 2, _vc = scr_hex_kms(HEX_GAL_VC_KMS) * HEX_FLUID_CS;
	for (var k = 0; k < 3; k++) {
		var _a = _cs.fa + k * 120 + _fl.myr * 0.15 + random_range(-6, 6), _r = _half * random_range(0.72, 0.9);
		var _x = lengthdir_x(_r, _a), _y = lengthdir_y(_r, _a);
		var _vr = scr_hex_kms(120) * HEX_FLUID_CS;                              // falling in at ~120 km/s, carrying spin
		var _vx = -_x / _r * _vr + 0.6 * _vc * _y / _r, _vy = -_y / _r * _vr - 0.6 * _vc * _x / _r;
		array_push(_fl.ret, [_x, _y, _I / 3, random_range(36, 56), merge_color(make_color_rgb(150, 185, 255), make_color_rgb(190, 170, 255), random(1)), _vx, _vy]);
	}
}
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
	if (!variable_struct_exists(_md, "red")) { _md.red = 0; _md.heat = 0; }
	var _tred = 0, _theat = 0;
	var _tbg = 1, _tdark = 0, _tspin = 1, _tlens = 1;
	// the color grade: every age has its own light, from real cosmology. young galaxies are vivid, a quasar blazes blue-white,
	// an old "red and dead" galaxy glows amber (its blue stars died first), a collapsing universe is blueshifted (its light is
	// squeezed, and the night sky itself brightens), and a newborn universe starts cool and clear
	var _tr = 1, _tgc = 1, _tb = 1, _tlift = 0;
	switch (_ae.phase) {
		case "quasar":   _tr = 1.0; _tgc = 1.06; _tb = 1.25; break;
		// twilight: "red and dead". the blue stars are gone, the rest glow orange (Draw tints every star by mood.red)
		case "twilight": _tbg = 0.6; _tr = 1.2; _tgc = 0.82; _tb = 0.55; _tred = min(1, _ae.t / (_fps * 12)); break;
		case "crunch":
			var _mk = min(1, _ae.t / (_fps * 12));
			_tbg = 1 - _mk; _tspin = 1 + 9 * _mk * _mk; _tlens = 1 + 0.5 * _mk;
			_tdark = clamp((_mk - 0.82) / 0.18, 0, 1);                        // the last moments: everything goes black
			_tr = lerp(1.05, 0.7, _mk); _tgc = lerp(0.9, 0.88, _mk); _tb = lerp(0.8, 1.45, _mk); _tlift = 0.05 * _mk;   // blueshift
			// the sky catches fire (Martin Rees, 1969): as everything packs together, the leftover light of the universe is squeezed
			// hotter and hotter, until the night sky itself glows red, then orange, then white, outshining the stars (Draw)
			_theat = clamp((_mk - 0.3) / 0.5, 0, 1);
			break;
		case "void": _tbg = 0; _tdark = 1; _tspin = 0.3; break;
	}
	if (variable_global_exists("hex_bang") && is_struct(global.hex_bang)) {                // a newborn universe: cool and clear
		var _bk2 = min(1, global.hex_bang.t / (_fps * 16));
		_tr = lerp(0.86, _tr, _bk2); _tgc = lerp(0.96, _tgc, _bk2); _tb = lerp(1.14, _tb, _bk2);
	}
	_md.gr += (_tr - _md.gr) * 0.02; _md.gg += (_tgc - _md.gg) * 0.02; _md.gb += (_tb - _md.gb) * 0.02;
	_md.lift += (_tlift - _md.lift) * 0.03;
	_md.red  += (_tred - _md.red) * 0.01;
	_md.heat += (_theat - _md.heat) * 0.05;
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
		// (first light: the new gas forms its own clusters, scr_hex_fluid_sinks)
		if (_bg.t > _fps * 16) global.hex_bang = undefined;
	}
	var _sm = scr_hex_find_smbh();
	if (keyboard_check_pressed(ord("K")) && !is_undefined(_sm) && variable_global_exists("hex_cosmo") && variable_struct_exists(global.hex_fluid, "myr")) {           // debug: skip to the next age of her universe
		var _kfl = global.hex_fluid, _kcs = global.hex_cosmo;
		if (_ae.phase == "galaxy" || _ae.phase == "dawn") _sm.qso = true;                                   // ignite the heart
		else if (_ae.phase == "quasar") { variable_struct_remove(_sm, "qso"); _sm.mdsm = 0; _kfl.myr = max(_kfl.myr, _kcs.T * 0.8); }   // to the twilight
		else if (_ae.phase == "twilight") _kfl.myr = max(_kfl.myr, _kcs.T - HEX_CRUNCH_MYR);                 // to the crunch
	}
	// (the cosmic web's cold flows are real gas now: scr_hex_inflow, from the reservoir, every read-back)
	// THE AGES, from what the garden is doing: dawn until its first stars, a galaxy, a quasar while its heart shines above 10^45 erg/s,
	// twilight once the universe is falling back and its star formation has faded, the crunch at the end of its Friedmann lifetime
	if (!variable_global_exists("hex_fluid") || !variable_struct_exists(global.hex_fluid, "myr") || !variable_global_exists("hex_cosmo")) return;
	var _cs = global.hex_cosmo, _myr = global.hex_fluid.myr;
	var _smd = (!is_undefined(_sm) && variable_struct_exists(_sm, "mdsm")) ? _sm.mdsm : 0;   // the heart's feeding (5 Myr average)
	if (_ae.phase != "crunch" && _ae.phase != "void" && !is_undefined(_sm) && _myr >= _cs.T - HEX_CRUNCH_MYR) { _ae.phase = "crunch"; _ae.t = 0; }
	var _late = (_myr > _cs.T * 0.8) || (_myr > _cs.T * 0.5 && _cs.sfpk > 0 && _cs.sfr < 0.3 * _cs.sfpk);   // falling back, and fading
	if (!is_undefined(_sm) && _ae.phase != "quasar" && variable_struct_exists(_sm, "qk")) _sm.qk = max(0, _sm.qk - 0.01);
	switch (_ae.phase) {
	case "dawn":
	case "galaxy":
		if (is_undefined(_sm)) { _ae.phase = "dawn"; if (gaze) scr_hex_seed_hole(); break; }
		if (_ae.phase == "dawn" && variable_struct_exists(global.hex_fluid, "sf_n") && global.hex_fluid.sf_n > 0) { _ae.phase = "galaxy"; _ae.t = 0; }
		if (variable_struct_exists(_sm, "qso") || _smd >= HEX_QSO_MDOT) { _ae.phase = "quasar"; _ae.t = 0; global.shake = max(global.shake, 16); }
		else if (_late) { _ae.phase = "twilight"; _ae.t = 0; }
		break;

	case "quasar":
		// it shines as brightly as it feeds (its jets and glow follow its feeding, eased); its own light clears its food away (AGN
		// feedback, the hole's bubble) until it dims below half the quasar line. K's forced quasar holds at least 16 s
		if (is_undefined(_sm)) { _ae.phase = "dawn"; break; }
		var _forced = variable_struct_exists(_sm, "qso");
		var _qt = _forced ? 1 : clamp(_smd / HEX_QSO_MDOT, 0, 1);
		_sm.qk = (variable_struct_exists(_sm, "qk") ? _sm.qk : 0) + (_qt - (variable_struct_exists(_sm, "qk") ? _sm.qk : 0)) * 0.02;
		if (_forced) _sm.feed = max(variable_struct_exists(_sm, "feed") ? _sm.feed : 0, 80);
		if (_forced && _ae.t >= _fps * 16) { variable_struct_remove(_sm, "qso"); _forced = false; }
		if (!_forced && _smd < 0.5 * HEX_QSO_MDOT) { _ae.phase = _late ? "twilight" : "galaxy"; _ae.t = 0; }
		break;

	case "twilight":
		// "red and dead": its blue stars die first and the reservoir runs dry, so nothing replaces them (the clusters age on their own clocks)
		if (is_undefined(_sm)) { _ae.phase = "dawn"; break; }
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
		global.hex_crunch_k = _ck;                                              // (the gas: gravity strengthens as space shrinks, and the heart swallows it: fluid update)
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
			// exactly what went in comes back out: the new universe holds the old one's baryons. HEX_BANG_GAS of them land in her sky
			// as clumpy gas flying apart with the expansion (faster the farther out: Hubble's law), turning the way the galaxy will; the
			// rest waits in the reservoir and rains in along the cosmic web
			scr_hex_fluid_reset();
			global.hex_crunch_k = 0;
			var _ocs = global.hex_cosmo, _bB = _ocs.B, _bg0 = min(HEX_BANG_MAX, _bB * HEX_BANG_GAS);
			scr_hex_cosmo_new(_bB, _bg0);
			var _bfl = global.hex_fluid, _bvc = scr_hex_kms(HEX_GAL_VC_KMS) * HEX_FLUID_CS;
			for (var k = 0; k < 120; k++) {
				var _bd = random(360), _bl = 60 + sqrt(random(1)) * 860;
				var _bx = _cx * 0.3 + lengthdir_x(_bl, _bd), _by = _cy * 0.3 + lengthdir_y(_bl, _bd);
				var _bh = 0.0012 * _bl, _bt = 0.8 * _bvc * _bl / sqrt(_bl * _bl + 150 * 150);
				array_push(_bfl.ret, [_bx, _by, _bg0 / 120 * random_range(0.5, 1.5), random_range(30, 70), _pal[irandom(2)],
					lengthdir_x(_bh, _bd) - dsin(_bd) * _bt, lengthdir_y(_bh, _bd) - dcos(_bd) * _bt]);
			}
			array_push(global.hex_ripples, { ox: _cx, oy: _cy, age: 0, len: _fps * 2.2, amp: 46 });   // space itself rings
			scr_hex_fluid_kick(_cx, _cy, 1500, 3, make_color_rgb(255, 240, 220));   // the fluid of the new universe, flung outward from the instant
			array_push(global.hex_ripples, { ox: _cx, oy: _cy, age: -_fps * 0.25, len: _fps * 2.8, amp: 26 });
			array_push(global.hex_ripples, { ox: _cx, oy: _cy, age: -_fps * 0.55, len: _fps * 3.4, amp: 14 });
			global.shake = max(global.shake, 40);
			// the impact frame: time stops on the instant of creation (Draw), then the white punch
			if (instance_exists(obj_player)) {
				var _ipd = point_distance(0, 0, _cx, _cy), _ipa = point_direction(0, 0, _cx, _cy) + sky_angle;
				impact_x = obj_player.x + lengthdir_x(_ipd, _ipa); impact_y = obj_player.y + lengthdir_y(_ipd, _ipa);
			}
			hitstop = 9; impact_kind = 2;
			global.hex_holes = [];
			if (variable_global_exists("hex_merge")) global.hex_merge = undefined;
			if (gaze) global.hex_stars = [];
			_ae.phase = "dawn"; _ae.t = 0;
		}
		break;
	}
}

// ---- INSPECT (I, sitting in her universe): names everything in her sky, so every object can be found and checked.
// notable things get a small label; hovering the mouse over any star shows what it is. drawn by HUD's Draw GUI ----
function scr_hex_sky_to_gui(_ox, _oy) {
	var _um = instance_find(obj_unmaking, 0);
	var _cam = view_camera[0];
	var _l = point_distance(0, 0, _ox, _oy), _a = point_direction(0, 0, _ox, _oy) + _um.sky_angle;
	var _wx = obj_player.x + lengthdir_x(_l, _a), _wy = obj_player.y + lengthdir_y(_l, _a);
	return [(_wx - camera_get_view_x(_cam)) / camera_get_view_width(_cam) * display_get_gui_width(),
	        (_wy - camera_get_view_y(_cam)) / camera_get_view_height(_cam) * display_get_gui_height()];
}

// what kind of star this is, in plain words
function scr_hex_star_kind(_st) {
	if (_st[$ "pop"] == true) {                                                // a cluster born from the gas: its stage, age and mass
		var _pa = scr_hex_age(_st);
		var _pk = (_pa < 3.5) ? "young star cluster, lighting its nebula" : ((_pa < 40) ? "star cluster, its giants going supernova"
		        : ((_pa < 1000) ? "aging star cluster" : "old star cluster"));
		return _pk + ", " + string(floor(_pa)) + " Myr, " + string_format(scr_hex_pop_msun(_st.m) / 1000000, 1, 1) + " million suns";
	}
	if (_st[$ "wd"] == true) return "white dwarf";
	if (_st[$ "ns"] == true) return "pulsar (neutron star)";
	var _life = scr_hex_age(_st) / scr_hex_star_life(_st.m);
	var _k = "red dwarf";
	if (_st.m >= HEX_MASS_GIANT) _k = (_life > 0.7) ? "red supergiant" : "blue giant";
	else if (_st.m >= HEX_MASS_SUN_MIN) _k = (_life > 0.7) ? "red giant" : "sun-like star";
	if (_st[$ "p3"] == true) _k = "Population III star (first light)";
	if (_st[$ "dying"] == true) _k += ", dying";
	return _k;
}

function scr_hex_inspect_draw() {
	if (!instance_exists(obj_unmaking) || !instance_exists(obj_player)) return;
	var _um = instance_find(obj_unmaking, 0);
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
	var _fps = game_get_speed(gamespeed_fps);
	draw_set_font(-1);
	draw_set_valign(fa_middle); draw_set_halign(fa_left);
	var _lab = function(_x, _y, _txt, _col) {                // a dot and a name beside it
		draw_set_alpha(0.9); draw_set_color(_col);
		draw_circle(_x, _y, 2, false);
		draw_set_color(c_black); draw_set_alpha(0.6);
		draw_text(_x + 9, _y + 1, _txt);
		draw_set_color(_col); draw_set_alpha(0.95);
		draw_text(_x + 8, _y, _txt);
	};
	var _onscr = function(_p, _gw, _gh) { return _p[0] > -20 && _p[1] > -20 && _p[0] < _gw + 20 && _p[1] < _gh + 20; };

	// black holes, and a merger in progress
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _ho = global.hex_holes[h];
		var _p = scr_hex_sky_to_gui(_ho.ox, _ho.oy);
		if (!_onscr(_p, _gw, _gh)) continue;
		var _t = scr_hex_is_smbh(_ho) ? "supermassive black hole" : "black hole";
		if (_ho.age < HEX_GATHER) _t = "collapsing star";
		var _fd = variable_struct_exists(_ho, "feed") ? _ho.feed : 0;
		_t += "  m " + string(floor(_ho.m)) + ((_fd > 5) ? "  feeding" : "  starving");
		if (variable_struct_exists(_ho, "qk") && _ho.qk > 0.05) _t = "QUASAR  " + _t;
		_lab(_p[0] + scr_hex_hole_size(_ho) * 0.5, _p[1] - scr_hex_hole_size(_ho) * 0.5, _t, make_color_rgb(255, 220, 160));
	}
	scr_hex_flow_draw_gui();                                               // the currents (the flow field)
	// LENS DEBUG: every lens drawn as a circle at its Einstein radius (where it bends light hardest), with its size in pixels.
	// if the stars boing while these circles stay steady, the lenses aren't the cause; if a circle jumps or wobbles, it is.
	// a swallowed hole's fading lens (a ghost) shows dashed
	var _gsc = _gw / camera_get_view_width(view_camera[0]);
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _ho = global.hex_holes[h];
		if (!variable_struct_exists(_ho, "le_w")) continue;
		var _p = scr_hex_sky_to_gui(_ho.ox, _ho.oy);
		draw_set_color(make_color_rgb(120, 255, 170)); draw_set_alpha(0.7);
		draw_circle(_p[0], _p[1], _ho.le_w * _gsc, true);
		draw_text(_p[0] - 20, _p[1] + _ho.le_w * _gsc + 4, "lens " + string(round(_ho.le_w)));
	}
	if (variable_global_exists("hex_lens_ghosts")) for (var h = 0; h < array_length(global.hex_lens_ghosts); h++) {
		var _gh = global.hex_lens_ghosts[h];
		if (!variable_struct_exists(_gh, "le_w")) continue;
		var _p = scr_hex_sky_to_gui(_gh.ox, _gh.oy);
		draw_set_color(make_color_rgb(120, 255, 170)); draw_set_alpha(0.5);
		for (var q = 0; q < 24; q += 2) draw_line(_p[0] + lengthdir_x(_gh.le_w * _gsc, q * 15), _p[1] + lengthdir_y(_gh.le_w * _gsc, q * 15),
			_p[0] + lengthdir_x(_gh.le_w * _gsc, q * 15 + 15), _p[1] + lengthdir_y(_gh.le_w * _gsc, q * 15 + 15));
	}
	draw_set_alpha(1);
	if (variable_global_exists("hex_merge") && is_struct(global.hex_merge)) {
		var _p = scr_hex_sky_to_gui(global.hex_merge.cx, global.hex_merge.cy);
		if (_onscr(_p, _gw, _gh)) _lab(_p[0], _p[1] + 40, "inspiral: two black holes merging", make_color_rgb(255, 180, 220));
	}
	// short-lived events that leave no object behind (tidal disruptions), named for a few seconds where they happened
	if (variable_global_exists("hex_marks")) {
		for (var i = array_length(global.hex_marks) - 1; i >= 0; i--) {
			var _mk = global.hex_marks[i];
			_mk.t--;
			if (_mk.t <= 0) { array_delete(global.hex_marks, i, 1); continue; }
			var _p = scr_hex_sky_to_gui(_mk.ox, _mk.oy);
			if (_onscr(_p, _gw, _gh)) _lab(_p[0], _p[1], _mk.txt, make_color_rgb(255, 190, 150));
		}
	}
	// the quasar's wind: where its snowplow front is right now, along the jets' axis (the Fermi bubbles' lobes)
	var _iae = variable_global_exists("hex_aeon") ? global.hex_aeon : undefined;
	var _ism = scr_hex_find_smbh();
	if (!is_undefined(_iae) && _iae.phase == "quasar" && !is_undefined(_ism) && variable_struct_exists(_iae, "qrw")) {
		for (var _s = -1; _s <= 1; _s += 2) {
			var _qd = _iae.qrw * 1.7, _qa = _iae.qax + (_s > 0 ? 0 : 180);
			var _p = scr_hex_sky_to_gui(_ism.ox + lengthdir_x(_qd, _qa), _ism.oy + lengthdir_y(_qd, _qa));
			if (_onscr(_p, _gw, _gh)) _lab(_p[0], _p[1], "quasar wind front (a Fermi bubble lobe)", make_color_rgb(190, 215, 255));
		}
	}
	// events: supernovae, planetary nebulae, stars being born
	with (_um) {
		for (var i = 0; i < array_length(novae); i++) {
			var _nv = novae[i];
			var _p = scr_hex_sky_to_gui(_nv.ox, _nv.oy);
			if (_onscr(_p, _gw, _gh)) _lab(_p[0], _p[1], (_nv[$ "pisn"] == true) ? "pair-instability supernova" : "supernova", make_color_rgb(255, 200, 120));
		}
		for (var i = 0; i < array_length(shells); i++) {
			var _p = scr_hex_sky_to_gui(shells[i].ox, shells[i].oy);
			if (_onscr(_p, _gw, _gh)) _lab(_p[0], _p[1], "planetary nebula", make_color_rgb(120, 230, 210));
		}
		for (var i = 0; i < array_length(nurseries); i++) {
			var _p = scr_hex_sky_to_gui(nurseries[i].ox, nurseries[i].oy);
			if (_onscr(_p, _gw, _gh)) _lab(_p[0], _p[1], "star forming (protostar)", make_color_rgb(200, 220, 255));
		}
	}
	// SUPERBUBBLES: each active one drawn at its radius (teal: still sealed in the disk; dashed: burst out and venting), so the holes
	// in the gas can be checked against the bubbles that should be making them
	if (variable_global_exists("hex_fluid") && variable_struct_exists(global.hex_fluid, "myr")) {
		for (var i = 0; i < array_length(global.hex_stars); i++) {
			var _st = global.hex_stars[i];
			if (!is_struct(_st) || _st[$ "pop"] != true) continue;
			var _bb = scr_hex_pop_bubble(_st, global.hex_fluid.myr - _st.tb);
			if (_bb[0] <= 0) continue;
			var _p = scr_hex_sky_to_gui(_st.ox, _st.oy);
			if (!_onscr(_p, _gw, _gh)) continue;
			var _br = _bb[1] * HEX_FLUID_CS * _gsc, _vent = (_bb[1] * HEX_FLUID_CS * HEX_PC_PER_PX >= 3 * HEX_DISK_H - 1);
			draw_set_color(make_color_rgb(110, 225, 210)); draw_set_alpha(0.55);
			if (!_vent) draw_circle(_p[0], _p[1], _br, true);
			else for (var q = 0; q < 24; q += 2) draw_line(_p[0] + lengthdir_x(_br, q * 15), _p[1] + lengthdir_y(_br, q * 15), _p[0] + lengthdir_x(_br, q * 15 + 15), _p[1] + lengthdir_y(_br, q * 15 + 15));
		}
		draw_set_alpha(1);
	}
	// notable stars get names; any star under the mouse gets its details
	var _shown = 0, _best = undefined, _bd = 26;
	for (var i = 0; i < array_length(global.hex_stars); i++) {
		var _st = global.hex_stars[i];
		var _p = scr_hex_sky_to_gui(_st.ox, _st.oy);
		if (!_onscr(_p, _gw, _gh)) continue;
		var _d = point_distance(_p[0], _p[1], _mx, _my);
		if (_d < _bd) { _bd = _d; _best = _st; }
		if (_st[$ "pop"] == true) continue;                                    // (clusters: hover for details; their bubbles are drawn below)
		var _note = (_st[$ "wd"] == true || _st[$ "ns"] == true || _st[$ "p3"] == true || _st[$ "dying"] == true || _st.m >= HEX_MASS_GIANT
		          || (_st.m >= HEX_MASS_SUN_MIN && scr_hex_age(_st) / scr_hex_star_life(_st.m) > 0.7));
		if (_note && _shown < 40) { _shown++; _lab(_p[0], _p[1], scr_hex_star_kind(_st), make_color_rgb(230, 220, 255)); }
	}
	if (!is_undefined(_best)) {
		var _p = scr_hex_sky_to_gui(_best.ox, _best.oy);
		var _life = (_best[$ "wd"] == true || _best[$ "ns"] == true) ? "a remnant: it no longer burns"
		          : ("life " + string(floor(100 * min(1, scr_hex_age(_best) / scr_hex_star_life(_best.m)))) + "% spent");
		draw_set_color(c_white); draw_set_alpha(0.8);
		draw_circle(_p[0], _p[1], 9, true);
		_lab(_p[0] + 6, _p[1] - 18, scr_hex_star_kind(_best) + "   mass " + string(floor(_best.m)) + "   " + _life, c_white);
	}
	// the corner tag
	draw_set_halign(fa_left); draw_set_valign(fa_top);
	draw_set_alpha(0.8); draw_set_color(make_color_rgb(220, 205, 255));
	draw_text(16, _gh * 0.5, "INSPECT (I)  -  hover a star for details");
	draw_set_alpha(1); draw_set_color(c_white);
}

// ---- THE CAPTURE KEY: hold C and every section of the Unmaking's Step and Draw is timed, frame by frame. let go and HUD's
// Draw GUI shows the slowest sections during exactly that moment (average and worst), for 10 seconds. costs nothing when off ----
function scr_prof_capture() {
	if (!variable_global_exists("prof_on")) { global.prof_on = false; global.prof_show = 0; global.prof_table = []; }
	var _held = keyboard_check(ord("C"));
	if (_held && !global.prof_on) { global.prof_sum = {}; global.prof_max = {}; global.prof_frames = 0; global.prof_cur = {}; }
	if (_held) {
		// close out last frame: fold each section's time into the totals and the worst
		var _ks = variable_struct_get_names(global.prof_cur);
		for (var i = 0; i < array_length(_ks); i++) {
			var _k = _ks[i], _v = global.prof_cur[$ _k];
			global.prof_sum[$ _k] = (global.prof_sum[$ _k] ?? 0) + _v;
			global.prof_max[$ _k] = max(global.prof_max[$ _k] ?? 0, _v);
		}
		global.prof_cur = {};
		global.prof_frames++;
	}
	if (!_held && global.prof_on && global.prof_frames > 0) {               // let go: build the table, slowest first
		var _ks = variable_struct_get_names(global.prof_sum), _tab = [];
		for (var i = 0; i < array_length(_ks); i++) {
			var _k = _ks[i];
			array_push(_tab, { name: _k, avg: global.prof_sum[$ _k] / global.prof_frames, worst: global.prof_max[$ _k] });
		}
		array_sort(_tab, function(_a, _b) { return (_b.avg > _a.avg) ? 1 : ((_b.avg < _a.avg) ? -1 : 0); });
		global.prof_table = _tab;
		global.prof_show = game_get_speed(gamespeed_fps) * 10;
	}
	global.prof_on = _held;
}
function scr_prof_start(_tag) {
	if (!variable_global_exists("prof_on") || !global.prof_on) return;
	global.prof_tag = _tag;
	global.prof_t = get_timer();
}
function scr_prof_lap(_name) {
	if (!variable_global_exists("prof_on") || !global.prof_on) return;
	var _now = get_timer();
	var _k = global.prof_tag + "  " + _name;
	global.prof_cur[$ _k] = (global.prof_cur[$ _k] ?? 0) + (_now - global.prof_t) / 1000;
	global.prof_t = get_timer();
}
// the table (HUD's Draw GUI calls this)
function scr_prof_draw() {
	if (!variable_global_exists("prof_show")) return;
	var _gw = display_get_gui_width();
	if (global.prof_on) {
		draw_set_halign(fa_right); draw_set_color(make_color_rgb(255, 120, 120)); draw_set_alpha(0.9);
		draw_text(_gw - 16, 60, "CAPTURING (" + string(global.prof_frames) + " frames)");
		draw_set_alpha(1); draw_set_halign(fa_left); draw_set_color(c_white);
		return;
	}
	if (global.prof_show <= 0) return;
	global.prof_show--;
	var _x = _gw - 470, _y = 60, _n = min(14, array_length(global.prof_table));
	draw_set_alpha(0.75); draw_set_color(c_black);
	draw_rectangle(_x - 10, _y - 8, _gw - 10, _y + 26 + _n * 17, false);
	draw_set_alpha(1); draw_set_color(make_color_rgb(230, 215, 255));
	draw_text(_x, _y, "CAPTURE: " + string(global.prof_frames) + " frames      avg ms    worst ms");
	for (var i = 0; i < _n; i++) {
		var _r = global.prof_table[i];
		draw_set_color((_r.avg > 4) ? make_color_rgb(255, 140, 120) : ((_r.avg > 1.5) ? make_color_rgb(255, 220, 140) : c_white));
		draw_text(_x, _y + 20 + i * 17, _r.name);
		draw_text(_x + 330, _y + 20 + i * 17, string_format(_r.avg, 2, 2));
		draw_text(_x + 400, _y + 20 + i * 17, string_format(_r.worst, 2, 2));
	}
	draw_set_color(c_white);
}

// ---- THE FLOW FIELD: the currents of her universe. real nebulae never sit still: gas swirls in eddies, black holes drag
// whirlpools around themselves, and every supernova sends a shockwave through everything near it. one shared current map
// carries all her settled gas along, so the whole garden breathes and churns between the big events.
// three layers, added together wherever a wisp is:
//   1) the slow currents: a swirl built from a few broad waves (made swirl-only, so gas mixes instead of spreading out or
//      bunching up: "divergence-free", like a real incompressible flow). they slowly evolve, and each aeon gets its own
//   2) shockwaves: supernovae and the Big Bang kick the field outward where they happen, and it fades (scr_hex_flow_kick)
//   3) whirlpools: every black hole stirs the gas around it, turning the way the galaxy turns, faster close in
// the rudimentary version, on the CPU: a 40 x 40 grid, 80px cells (3,200px across, centered on her). a fluid simulation on
// the GPU is the planned upgrade (HYPERMAX) ----
#macro HEX_FLOW_CELL 80
#macro HEX_FLOW_N 40
#macro HEX_FLOW_SPEED 0.2    // the slow currents' top speed, pixels per frame (0.22 felt a touch timelapse-y)
function scr_hex_flow_init(_seed) {
	var _N = HEX_FLOW_N, _NN = _N * _N;
	var _ff = { ax: array_create(_NN, 0), ay: array_create(_NN, 0), bx: array_create(_NN, 0), by: array_create(_NN, 0),
		kx: array_create(_NN, 0), ky: array_create(_NN, 0), kick: 0, t: 0, seed: _seed, tick: 0 };
	// a handful of broad waves, each a stream function psi = a * sin(k . x + phase). the flow is (dpsi/dy, -dpsi/dx), which can only
	// swirl. A is the waves now, B the same waves a quarter-turn on: blending them over time makes the currents drift and evolve
	var _nw = 6, _waves = [];
	for (var k = 0; k < _nw; k++) {
		var _th = scr_hash(_seed * 3.1 + k * 7.7) * 360, _lam = 380 + scr_hash(_seed * 5.3 + k * 2.9) * 620;
		var _kk = 2 * pi / _lam;
		array_push(_waves, { kx: _kk * dcos(_th), ky: _kk * dsin(_th), a: 0.5 + scr_hash(_seed * 1.7 + k * 4.1), ph: scr_hash(_seed * 9.9 + k) * 2 * pi });
	}
	var _mx = 0.0001;
	for (var j = 0; j < _N; j++) for (var i = 0; i < _N; i++) {
		var _cx = (i - _N / 2 + 0.5) * HEX_FLOW_CELL, _cy = (j - _N / 2 + 0.5) * HEX_FLOW_CELL;
		var _ax = 0, _ay = 0, _bx = 0, _by = 0;
		for (var k = 0; k < _nw; k++) {
			var _wv = _waves[k];
			var _p = _wv.kx * _cx + _wv.ky * _cy + _wv.ph;
			var _c = cos(_p) * _wv.a, _s = sin(_p) * _wv.a;
			_ax += _wv.ky * _c; _ay -= _wv.kx * _c;
			_bx += _wv.ky * _s; _by -= _wv.kx * _s;
		}
		var _q = i + j * _N;
		_ff.ax[_q] = _ax; _ff.ay[_q] = _ay; _ff.bx[_q] = _bx; _ff.by[_q] = _by;
		_mx = max(_mx, abs(_ax), abs(_ay), abs(_bx), abs(_by));
	}
	var _sc = HEX_FLOW_SPEED / _mx;
	for (var q = 0; q < _NN; q++) { _ff.ax[q] *= _sc; _ff.ay[q] *= _sc; _ff.bx[q] *= _sc; _ff.by[q] *= _sc; }
	global.hex_ff = _ff;
}

// a shockwave through the currents: everything within _r of (_x, _y) is pushed outward, hardest in the middle. it fades on its own
function scr_hex_flow_kick(_x, _y, _r, _str) {
	if (!variable_global_exists("hex_ff")) return;
	var _ff = global.hex_ff, _N = HEX_FLOW_N;
	var _i0 = max(0, floor((_x - _r) / HEX_FLOW_CELL + _N / 2)), _i1 = min(_N - 1, floor((_x + _r) / HEX_FLOW_CELL + _N / 2));
	var _j0 = max(0, floor((_y - _r) / HEX_FLOW_CELL + _N / 2)), _j1 = min(_N - 1, floor((_y + _r) / HEX_FLOW_CELL + _N / 2));
	for (var j = _j0; j <= _j1; j++) for (var i = _i0; i <= _i1; i++) {
		var _dx = (i - _N / 2 + 0.5) * HEX_FLOW_CELL - _x, _dy = (j - _N / 2 + 0.5) * HEX_FLOW_CELL - _y;
		var _d = sqrt(_dx * _dx + _dy * _dy);
		if (_d >= _r || _d < 1) continue;
		var _k = _str * (1 - _d / _r);
		_ff.kx[i + j * _N] += _dx / _d * _k; _ff.ky[i + j * _N] += _dy / _d * _k;
	}
	_ff.kick = 1;
	// (the fluid no longer feels these: they were single stars' blasts sized for the old smoke, kiloparsecs wide. the gas is pushed only
	// by real feedback now: star clusters' superbubbles. legacy #8)
}

// the currents at a point: the slow swirl (blended through time) plus any shockwave, read smoothly between grid cells
function scr_hex_flow_sample(_ff, _x, _y, _c, _s) {
	var _N = HEX_FLOW_N;
	var _gx = clamp(_x / HEX_FLOW_CELL + _N / 2 - 0.5, 0, _N - 1.001), _gy = clamp(_y / HEX_FLOW_CELL + _N / 2 - 0.5, 0, _N - 1.001);
	var _i = floor(_gx), _j = floor(_gy), _fx = _gx - _i, _fy = _gy - _j;
	var _q00 = _i + _j * _N, _q10 = _q00 + 1, _q01 = _q00 + _N, _q11 = _q01 + 1;
	var _w00 = (1 - _fx) * (1 - _fy), _w10 = _fx * (1 - _fy), _w01 = (1 - _fx) * _fy, _w11 = _fx * _fy;
	var _ax = _ff.ax, _ay = _ff.ay, _bx = _ff.bx, _by = _ff.by, _kx = _ff.kx, _ky = _ff.ky;
	var _vx = (_ax[_q00] * _c + _bx[_q00] * _s + _kx[_q00]) * _w00 + (_ax[_q10] * _c + _bx[_q10] * _s + _kx[_q10]) * _w10
	        + (_ax[_q01] * _c + _bx[_q01] * _s + _kx[_q01]) * _w01 + (_ax[_q11] * _c + _bx[_q11] * _s + _kx[_q11]) * _w11;
	var _vy = (_ay[_q00] * _c + _by[_q00] * _s + _ky[_q00]) * _w00 + (_ay[_q10] * _c + _by[_q10] * _s + _ky[_q10]) * _w10
	        + (_ay[_q01] * _c + _by[_q01] * _s + _ky[_q01]) * _w01 + (_ay[_q11] * _c + _by[_q11] * _s + _ky[_q11]) * _w11;
	return [_vx, _vy];
}

// every frame (obj_unmaking Step): the currents carry her settled gas along. half the wisps move each frame, twice as far,
// so it costs half as much. gas that's flying, falling into a hole, or shaped by a young star moves on its own instead
function scr_hex_flow_step() {
	if (!variable_global_exists("hex_flow_on")) global.hex_flow_on = true;
	if (!global.hex_flow_on) return;
	var _an = variable_global_exists("hex_aeon") ? global.hex_aeon.n : 0;
	if (!variable_global_exists("hex_ff") || global.hex_ff.seed != _an + 1) scr_hex_flow_init(_an + 1);   // each aeon, its own currents
	var _ff = global.hex_ff;
	_ff.tick++;
	_ff.t += 0.0025;                                                     // the currents slowly evolve (a full turn in ~40s)
	var _c = cos(_ff.t), _s = sin(_ff.t);
	if (_ff.kick > 0 && _ff.tick mod 2 == 0) {                             // shockwaves fade
		var _kx = _ff.kx, _ky = _ff.ky, _big = 0;
		for (var q = 0; q < HEX_FLOW_N * HEX_FLOW_N; q++) { _kx[q] *= 0.9; _ky[q] *= 0.9; _big = max(_big, abs(_kx[q]) + abs(_ky[q])); }
		if (_big < 0.005) { _ff.kick = 0; for (var q = 0; q < HEX_FLOW_N * HEX_FLOW_N; q++) { _kx[q] = 0; _ky[q] = 0; } }
	}
	// the whirlpools: each black hole, worked out once this frame
	var _hl = [];
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _ho = global.hex_holes[h];
		if (_ho.age < HEX_GATHER) continue;
		var _hr = scr_hex_hole_size(_ho, false);
		array_push(_hl, [_ho.ox, _ho.oy, _hr, sqr(_hr * 9)]);
	}
	var _nh = array_length(_hl);
	var _hz = global.hex_haze, _par = _ff.tick mod 2;
	// the fluid's read-back currents, sampled right here (no function call or throwaway array per wisp: those were the cost)
	var _rv = (variable_global_exists("hex_fluid") && scr_hex_fluid_ok()) ? global.hex_fluid.rv : [];
	var _gpu = array_length(_rv) == HEX_FLUID_RW * HEX_FLUID_RH * 2;
	var _RW = HEX_FLUID_RW, _RH = HEX_FLUID_RH, _rsc = HEX_FLUID_CS * HEX_FLUID_W / HEX_FLUID_RW, _rk = HEX_FLUID_CS;
	for (var i = _par; i < array_length(_hz); i += 2) {
		var _w = _hz[i];
		if (_w.f <= 0.01 || _w.fl || _w.u || _w.tr) continue;
		var _vx, _vy;
		if (_gpu) {
			var _gx = clamp(_w.ox / _rsc + _RW / 2 - 0.5, 0, _RW - 1.001), _gy = clamp(_w.oy / _rsc + _RH / 2 - 0.5, 0, _RH - 1.001);
			var _gi = floor(_gx), _gj = floor(_gy), _fx = _gx - _gi, _fy = _gy - _gj;
			var _q = (_gi + _gj * _RW) * 2, _q3 = _q + _RW * 2;
			_vx = ((_rv[_q] * (1 - _fx) + _rv[_q + 2] * _fx) * (1 - _fy) + (_rv[_q3] * (1 - _fx) + _rv[_q3 + 2] * _fx) * _fy) * _rk;
			_vy = ((_rv[_q + 1] * (1 - _fx) + _rv[_q + 3] * _fx) * (1 - _fy) + (_rv[_q3 + 1] * (1 - _fx) + _rv[_q3 + 3] * _fx) * _fy) * _rk;
		} else {
			var _v = scr_hex_flow_sample(_ff, _w.ox, _w.oy, _c, _s);         // the CPU currents, when the fluid isn't running
			_vx = _v[0]; _vy = _v[1];
		}
		if (!_gpu) for (var h = 0; h < _nh; h++) {                            // (the fluid already has the whirlpools in it)
			var _hh = _hl[h];
			var _dx = _w.ox - _hh[0], _dy = _w.oy - _hh[1], _d2 = _dx * _dx + _dy * _dy;
			if (_d2 > _hh[3] || _d2 < 1) continue;
			var _d = sqrt(_d2), _sw = 0.6 * _hh[2] / max(_d, _hh[2]);        // faster close in
			_vx += (_dy / _d) * _sw - (_dx / _d) * _sw * 0.25;                // turning with the galaxy, drawn slightly inward
			_vy += (-_dx / _d) * _sw - (_dy / _d) * _sw * 0.25;
		}
		var _wt = (gaze || !_gpu) ? 2 * scr_hex_time() : 0;                   // (the clock: half speed moves half as far; held still during a cast)
		_w.ox += _vx * _wt; _w.oy += _vy * _wt;
		// the currents made visible: each wisp slowly turns to lie along its current and draws out with its speed, so the flow shows
		// as streams and filaments (real nebulae trace their currents the same way). around a hole that's a spiral of streams
		var _spd = sqrt(_vx * _vx + _vy * _vy);
		if (_spd > 0.02) _w.ang += angle_difference(point_direction(0, 0, _vx, _vy), _w.ang) * 0.06;
		_w.st = lerp(_w.st, 1 + min(0.4, _spd * 2), 0.05);              // (a gentle stretch: more drew the soft blobs out into rectangles)
	}
}

// Inspect: the currents drawn as small arrows (every other cell on screen), so the flow can be seen and checked
function scr_hex_flow_draw_gui() {
	// the fluid running: its real currents, from the read-back copy (each arrow = how far that gas travels in one second)
	if (variable_global_exists("hex_fluid") && scr_hex_fluid_ok() && array_length(global.hex_fluid.rv) == HEX_FLUID_RW * HEX_FLUID_RH * 2) {
		var _rv = global.hex_fluid.rv, _sc = HEX_FLUID_CS * HEX_FLUID_W / HEX_FLUID_RW, _fps = game_get_speed(gamespeed_fps);
		var _gw = display_get_gui_width(), _gh = display_get_gui_height();
		draw_set_color(make_color_rgb(120, 255, 220)); draw_set_alpha(0.5);
		for (var j = 0; j < HEX_FLUID_RH; j += 2) for (var i = 0; i < HEX_FLUID_RW; i += 2) {
			var _x = (i - HEX_FLUID_RW / 2 + 0.5) * _sc, _y = (j - HEX_FLUID_RH / 2 + 0.5) * _sc;
			var _p = scr_hex_sky_to_gui(_x, _y);
			if (_p[0] < 0 || _p[1] < 0 || _p[0] > _gw || _p[1] > _gh) continue;
			var _q = (i + j * HEX_FLUID_RW) * 2;
			var _vx = _rv[_q] * HEX_FLUID_CS * _fps, _vy = _rv[_q + 1] * HEX_FLUID_CS * _fps;   // sky pixels per second
			var _len = point_distance(0, 0, _vx, _vy), _dir = point_direction(0, 0, _vx, _vy) + instance_find(obj_unmaking, 0).sky_angle;   // (the sky's frame turns)
			if (_len < 3) continue;
			_len = min(_len, 120);
			var _ex = _p[0] + lengthdir_x(_len, _dir), _ey = _p[1] + lengthdir_y(_len, _dir);
			draw_line(_p[0], _p[1], _ex, _ey);
			draw_line(_ex, _ey, _ex + lengthdir_x(5, _dir + 150), _ey + lengthdir_y(5, _dir + 150));
		}
		draw_set_alpha(1); draw_set_color(c_white);
		return;
	}
	if (!variable_global_exists("hex_ff") || !(variable_global_exists("hex_flow_on") && global.hex_flow_on)) return;
	var _ff = global.hex_ff, _N = HEX_FLOW_N, _c = cos(_ff.t), _s = sin(_ff.t);
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_color(make_color_rgb(140, 200, 255)); draw_set_alpha(0.35);
	for (var j = 0; j < _N; j += 2) for (var i = 0; i < _N; i += 2) {
		var _x = (i - _N / 2 + 0.5) * HEX_FLOW_CELL, _y = (j - _N / 2 + 0.5) * HEX_FLOW_CELL;
		var _p = scr_hex_sky_to_gui(_x, _y);
		if (_p[0] < 0 || _p[1] < 0 || _p[0] > _gw || _p[1] > _gh) continue;
		var _v = scr_hex_flow_sample(_ff, _x, _y, _c, _s);
		var _len = point_distance(0, 0, _v[0], _v[1]) * 90, _dir = point_direction(0, 0, _v[0], _v[1]);
		if (_len < 2) continue;
		var _ex = _p[0] + lengthdir_x(_len, _dir), _ey = _p[1] + lengthdir_y(_len, _dir);
		draw_line(_p[0], _p[1], _ex, _ey);
		draw_line(_ex, _ey, _ex + lengthdir_x(5, _dir + 150), _ey + lengthdir_y(5, _dir + 150));
	}
	draw_set_alpha(1); draw_set_color(c_white);
}

// ---- THE GAS: her universe's gas, simulated the way astrophysics codes do it, on the graphics card (stage 6).
// the sky is a grid of cells covering 3,072 x 1,728 sky pixels, centered on her. each cell holds its gas (as colored mass: the
// element colors her kills became, whose sum is its density) and its momentum. the physics, bottom to top:
//   1) NEW GAS enters once, when a wisp settles (a kill's cloud, supernova debris, a dying star's shell)
//   2) GRAVITY: Poisson's equation on a coarse grid, sourced by the gas's clumping plus every star and black hole
//   3) THE GAS (sh_hex_fluid_p): compressible, self-gravitating, isothermal gas, finite-volume (what crosses each cell wall is
//      worked out from both sides, so mass is exactly conserved), with MUSCL reconstruction for sharp filaments. it is pushed
//      by its own pressure and pulled by gravity; clouds bigger than the Jeans length collapse, smaller ones puff out; shocks
//      and shells come out by themselves. no wind, no stirring: space has none. black holes swallow what falls inside them
//   4) LIGHT: drawn lit by her stars (emission, reflection, absorption: scr_hex_fluid_light, sh_hex_fluid)
// QUALITY TIERS (Y in the stargazer cycles them live): resolution and substeps. all speeds and forces are in REFERENCE cells
// (8 sky pixels, the High grid), so every tier moves the same; finer tiers just hold finer structure. HYPERMAX: 1,024 x 576,
// a cell every 3 sky pixels, 4 substeps a frame.
// the wisps are the game's ledger of the gas (births, feeding, the crunch still count them); they ride the gas's own velocity
// (a small copy is read back every 12 frames). textures can vanish (alt-tab, resizing): rebuilt, and every wisp re-poured ----
#macro HEX_FLUID_W 384            // the REFERENCE grid (High): positions, sizes and speeds handed to the shader use these
#macro HEX_FLUID_H 384            // (square: a round galaxy's orbits must stay inside; the wide box swept orbiting gas out of its edges)
#macro HEX_FLUID_CS 8             // sky pixels per reference cell
#macro HEX_FLUID_GAIN 1.6         // how bright the fluid gas is drawn (the main look knob)
#macro HEX_FLUID_INK 2           // how dense one wisp's gas is when it's poured into the fluid (once, when it settles). the gas look's
#macro HEX_POUR_PIECES 4          // new gas arrives as a TIDAL STREAM: this many clumps strung along its orbit (like the Sagittarius
                                  // Stream, a small galaxy the Milky Way tore apart), each sheared along the orbit too
#macro HEX_POUR_ARC 7             // the stream's length, in stamp radii (capped at a third of a radian of its orbit)
#macro HEX_POUR_SOFT 1.8          // (edit48) how much wider than the dust itself each poured stamp is: neighbors blend into one cloud
#macro HEX_POUR_PER_FRAME 120     // the most wisps poured in one frame (a big cast lands thousands at once: spread over a few frames)
#macro HEX_SPELL_GLOW 0.6         // how brightly her spell lights the gas during a cast (fades over ~4 s after it)
#macro HEX_GAS_TINT 0.45          // (edit48: 0.3 -> 0.45, now steeped in violet) how much of her kills' own colors stays in the gas's light; the rest is the physics of its emission lines
#macro HEX_POUR_STRETCH 3       // new gas arrives as a streak this many times longer than wide, along its orbit (same area: same gas)
#macro HEX_POUR_TILT 25         // and tilted up to this many degrees off the orbit, so the streaks don't all line up
                                 // main brightness knob, with HEX_FLUID_GAIN
#macro HEX_LIGHT_W 192            // the starlight map: 192 x 192 (16 sky px a texel), redrawn every 3 frames
#macro HEX_LIGHT_H 192
#macro HEX_ION_MASS 16            // stars at least this heavy are hot enough (O and B types) to ionize the gas around them
#macro HEX_FLUID_AMB0 0.04        // the faint diffuse glow of gas with no young stars at all (old starlight)...
#macro HEX_FLUID_AMB1 0.4         // ...rising with the young clusters' ultraviolet (it used to follow the star count, so her cast's
                                  // ~1,000 dim red stars lit every fresh cloud at full glow: the 'too bright off rip')
#macro HEX_FLUID_AMBQ 10          // millions of suns of young (<3.5 Myr) clusters for ~63% of that rise
#macro HEX_FLUID_ION 0.8          // how brightly gas glows where hot stars ionize it (emission nebulae)
#macro HEX_STROMGREN_D 0.5        // the gas density at which a hot star's ionized bubble has shrunk to ~60% of its reach in empty space
#macro HEX_FLUID_REFL 0.35        // how brightly dust reflects the stars' own light (reflection nebulae)
#macro HEX_FLUID_DUST 0.9         // how strongly dense gas blocks the light behind it (dark nebulae)
#macro HEX_GRAV_W 128             // the gravity grid: 128 x 128 (24 sky px a cell; gravity is smooth, it needs no finer)
#macro HEX_GRAV_H 128
// GRAVITY, the real law: G = 0.004301 parsec (km/s)^2 per sun. with the garden's mass unit (HEX_SIGMA_UNIT suns per square parsec
// at density 1) a cloud's pull follows directly, so there's no strength to tune: the acceleration from the potential's slope (in gravity
// cells) is G x SIGMA x slope, in (km/s)^2 per parsec, turned into reference cells per frame^2 (1 (km/s)^2/pc = 1.0459 pc/Myr^2)
#macro HEX_GRAV (0.004301 * HEX_SIGMA_UNIT * 1.0459 / (HEX_PC_PER_PX * HEX_FLUID_CS) * sqr(HEX_MYR_PER_S / 60))
#macro HEX_PC_PER_PX 10
#macro HEX_MYR_PER_S 1
function scr_hex_kms(_v) { return _v * 1.0227 / HEX_PC_PER_PX * HEX_MYR_PER_S / 60 / HEX_FLUID_CS; }   // (1 km/s = 1.0227 pc per million years)
function scr_hex_time() { if (!variable_global_exists("hex_time")) global.hex_time = 1; return global.hex_time; }   // 1 = full, 0.5 = half speed
#macro HEX_GAL_VC_KMS 220          // the galaxy's rotation: 220 km/s, the Milky Way's (one orbit at 600px from the center ~2.8 min)
#macro HEX_GAS_CS_KMS 10           // the gas's internal motion (velocity dispersion), what its pressure is: ~10 km/s in real galaxy disks
#macro HEX_ION_CS_KMS 20           // gas heated by hot stars (photoionized, ~10,000 degrees): ~2x the disk's gas
#macro HEX_GAL_VC scr_hex_kms(HEX_GAL_VC_KMS)   // (the same three, in the sim's units)
#macro HEX_GAS_CS scr_hex_kms(HEX_GAS_CS_KMS)
#macro HEX_ION_CS scr_hex_kms(HEX_ION_CS_KMS)
#macro HEX_GAL_R0 150              // the halo's core radius, sky px (inside it rotation rises, outside it stays flat)
#macro HEX_GAS_PER_MASS 0.8        // how much gas (read-back units) one unit of star mass is made of. stars weigh what they formed from
// STAR FORMATION at the garden's scale (480 pc read-back samples) follows the law astronomers measure at exactly that scale, the
// KENNICUTT-SCHMIDT LAW (Kennicutt 1998): stars form at 2.5e-4 x Sigma^1.4 suns a year per kpc^2, Sigma the gas in suns per pc^2.
// (a cloud's own collapse happens far below 480 pc, inside each sample; averaged over the sample, this is what comes out.) below
// ~5 suns per pc^2 gas is too thin and warm to form stars (Kennicutt 1989; Bigiel et al. 2008)
#macro HEX_KS_A 0.00025             // suns / yr / kpc^2 at 1 sun / pc^2
#macro HEX_KS_N 1.4
#macro HEX_SF_SIGMA_MIN 5           // suns / pc^2
#macro HEX_SF_MMIN 0.5              // one cluster's gas, read-back units (~2.3 million suns: a cluster complex, what one point of light is at this scale;
                                    // 0.2 made ~5 a second, 700+ bodies in a few minutes, and the frame rate halved).
                                    // formed STOCHASTICALLY (as galaxy codes do: Springel & Hernquist 2003): each check, a patch makes one with
                                    // the chance (stars it should form now) / (one cluster), so the average rate is exactly the law's
#macro HEX_SF_MMAX 2.2              // the largest one event can form (~10 million suns: the biggest star-forming complexes; X only)
#macro HEX_SF_R 72                 // the reach (sky px) a forming star gathers its gas from
// ---- STELLAR POPULATIONS AND FEEDBACK (step 3). at 10 parsecs a pixel no single star is visible: every point of light in a
// real galaxy image is a whole cluster. so each star the gas forms is a star CLUSTER with a real population inside it: its massive
// stars light and heat their nebula for ~3.5 Myr, explode as supernovae from 3 to 40 Myr (blowing a SUPERBUBBLE), and the whole
// population hands gas back for billions of years (winds, supernova debris, dying sun-like stars). gas -> stars -> gas ----
#macro HEX_SIGMA_UNIT 20           // the garden's mass unit: gas at read-back density 1 holds 20 suns per square parsec (about the
                                   // Milky Way's gas near the Sun). only F1's real masses and the ionized bubbles' sizes depend on it;
                                   // the superbubbles don't (their size depends only on mass ratios)
#macro HEX_SAMPLE_PC 480           // one read-back sample, in parsecs (6 reference cells of 80 pc)
#macro HEX_DISK_H 150              // the gas disk's thickness (scale height), parsecs: a bubble bigger than ~3x this bursts out of it
#macro HEX_SN_K 1                  // supernova energy, 1 = textbook (1e51 erg each, one supernova per ~90 suns formed: Kroupa IMF)
// BLACK HOLES (step 4). each Dawn one seed forms at the galaxy's heart straight from collapsing gas (a "direct collapse" seed, 10^4-10^6
// suns). it feeds at the Bondi rate (gas falling into a point mass: 4 pi G^2 M^2 rho / c^3), boosted because the grid can't resolve the
// dense gas right next to it (Springel, Di Matteo & Hernquist 2005 use 100), never faster than the Eddington limit (where its own light
// pushes infalling gas away: M / 45 Myr at 10% efficiency). 10% of what falls in leaves as light; 5% of that light heats and shoves the
// gas around it (Di Matteo et al. 2005), through the same bubble system as the clusters' supernovae. it starves itself, refills, flares
#macro HEX_SEED_MSUN 100000        // the seed's mass in suns
#macro HEX_BONDI_BOOST 100         // Bondi boost for gas the grid can't resolve
#macro HEX_EDD_T 45                // Myr: the Eddington feeding rate is the hole's mass every 45 Myr (it grows e-fold every 50)
#macro HEX_RAD_EFF 0.1             // share of the infalling mass radiated away (the rest adds to the hole)
#macro HEX_AGN_COUPLE 0.05         // share of that light that pushes on the gas
#macro HEX_QSO_MDOT 180000         // suns per Myr: a quasar shines above ~10^45 erg/s, which at 10% efficiency is this feeding rate
#macro HEX_BH_REACH 40        // px: where it takes gas from (400 pc: about one read-back sample, the smallest the grid resolves the Bondi flow)
#macro HEX_EAT_MAX 0.1             // (the most of the gas over its heart it can take in one frame)
#macro HEX_FB_RMIN 2.5             // the smallest bubble the grid can hold, reference cells (200 pc)
#macro HEX_FB_W 384                // the feedback (bubble pressure) map: one texel per reference cell
#macro HEX_FB_H 384
#macro HEX_JEANS 4                // the Jeans pressure floor (Truelove et al. 1997): a disk's Jeans length c^2 / (G Sigma) is kept at least this
                                  // many cells, so collapse stops at the grid's limit instead of faking fragments (only in gas ~10x denser than average)
#macro HEX_KICK 0.08              // how hard a shockwave pushes the gas, per frame of its push
#macro HEX_GRAV_STAR 1            // stars weigh what the gas they formed from weighed (1 = mass conserved, the real law)
#macro HEX_FLUID_WISP 0           // how strongly the old wisps are still drawn on top while the fluid is on (1 = as before, 0 = pure fluid, and cheaper)
#macro HEX_FLUID_RW 64            // the copy read back (velocity, density): 64 x 64 (each sample covers 48 x 48 sky pixels)
#macro HEX_FLUID_RH 64
// the quality tier: [cells across, cells down, pressure passes, name]. 0 Low, 1 High, 2 HYPERMAX (the default for now)
function scr_hex_fluid_tier() {
	if (!variable_global_exists("hex_fluid_q")) global.hex_fluid_q = 2;
	switch (clamp(global.hex_fluid_q, 0, 2)) {
		case 0:  return [256, 256, 1, "Low"];                                // [cells across, down, gas substeps a frame, name]
		case 1:  return [384, 384, 1, "High"];
		default: return [1024, 1024, 2, "HYPERMAX"];
	}
}
// PHYSICS ONLY (debug key O, ON by default while the garden is being rebuilt): switches off the legacy systems that still reach
// into the new physics (notes/garden-architecture.md), so a test shows the physics alone: the scripted galaxy turn, scripted black
// hole sliding and the whole-sky spin (the ledger's thinning, the old wisp births and star merging are deleted)
function scr_hex_iso() {
	if (!variable_global_exists("hex_iso")) global.hex_iso = true;
	return global.hex_iso;
}

// is the fluid running? if not, global.hex_fluid_why says why (shown in the stargazer readout, and printed once to Output)
function scr_hex_fluid_ok() {
	if (!variable_global_exists("hex_flow_on")) global.hex_flow_on = true;
	var _why = "";
	// (named directly, not looked up by text: GameMaker strips assets it thinks are unused, and a text lookup doesn't count as a use)
	var _sh = sh_hex_fluid, _sp = sh_hex_fluid_p;
	if (_sh == -1 || _sp == -1) _why = "a fluid shader asset is missing";
	else if (!shader_is_compiled(_sh)) _why = "sh_hex_fluid didn't compile";
	else if (!shader_is_compiled(_sp)) _why = "sh_hex_fluid_p didn't compile";
	else if (!surface_format_is_supported(surface_rgba16float)) _why = "no float surfaces";   // velocities need signed, precise numbers
	if (!variable_global_exists("hex_fluid_why") || global.hex_fluid_why != _why) {
		global.hex_fluid_why = _why;
		if (_why != "") show_debug_message("[FLUID] off: " + _why);
	}
	return _why == "" && global.hex_flow_on;
}
function scr_hex_fluid_surfaces() {
	if (!variable_global_exists("hex_fluid")) global.hex_fluid = { va: -1, vb: -1, da: -1, db: -1, rs: -1, rbuf: -1, rv: [], kicks: [], t: 0, ink: [] };
	var _fl = global.hex_fluid;
	if (!variable_struct_exists(_fl, "rs")) { _fl.rs = -1; _fl.rbuf = -1; _fl.rv = []; }
	if (!variable_struct_exists(_fl, "vc")) { _fl.vc = -1; _fl.dc = -1; }
	var _fmt = surface_format_is_supported(surface_rgba32float) ? surface_rgba32float : surface_rgba16float;   // (32-bit where the card allows: exact sums)
	var _tr = scr_hex_fluid_tier(), _W = _tr[0], _H = _tr[1];
	// the tier changed: new textures at the new size, with the old gas and momentum stretched into them (so the switch is seamless)
	if (surface_exists(_fl.va) && surface_get_width(_fl.va) != _W) {
		var _old = [_fl.va, _fl.da];
		var _new = [surface_create(_W, _H, _fmt), surface_create(_W, _H, _fmt)];
		gpu_push_state(); gpu_set_blendenable(false); gpu_set_tex_filter(true);
		for (var i = 0; i < 2; i++) { surface_set_target(_new[i]); draw_clear_alpha(c_black, 0); draw_surface_stretched(_old[i], 0, 0, _W, _H); surface_reset_target(); }
		gpu_pop_state();
		var _all = [_fl.va, _fl.vb, _fl.da, _fl.db, _fl.vc, _fl.dc];
		for (var i = 0; i < 6; i++) if (surface_exists(_all[i])) surface_free(_all[i]);
		_fl.va = _new[0]; _fl.da = _new[1]; _fl.vb = -1; _fl.db = -1; _fl.vc = -1; _fl.dc = -1;
	}
	var _made = [];
	var _lost = (!surface_exists(_fl.va) || !surface_exists(_fl.da)) && variable_struct_exists(_fl, "bkd") && _fl.bkw > 0;
	if (!surface_exists(_fl.va)) { _fl.va = surface_create(_W, _H, _fmt); array_push(_made, _fl.va); }   // momentum
	if (!surface_exists(_fl.vb)) { _fl.vb = surface_create(_W, _H, _fmt); array_push(_made, _fl.vb); }
	if (!surface_exists(_fl.da)) { _fl.da = surface_create(_W, _H, _fmt); array_push(_made, _fl.da); }   // the gas (colored mass)
	if (!surface_exists(_fl.db)) { _fl.db = surface_create(_W, _H, _fmt); array_push(_made, _fl.db); }
	if (!surface_exists(_fl.vc)) { _fl.vc = surface_create(_W, _H, _fmt); array_push(_made, _fl.vc); }   // (Runge-Kutta's trial step)
	if (!surface_exists(_fl.dc)) { _fl.dc = surface_create(_W, _H, _fmt); array_push(_made, _fl.dc); }
	// the read-back copy: velocity on the left half, gas density on the right (plain 8-bit: easy to read back)
	if (surface_exists(_fl.rs) && surface_get_width(_fl.rs) != HEX_FLUID_RW * 2) { surface_free(_fl.rs); buffer_delete(_fl.rbuf); _fl.rbuf = -1; }
	if (!surface_exists(_fl.rs)) _fl.rs = surface_create(HEX_FLUID_RW * 2, HEX_FLUID_RH);
	if (_fl.rbuf == -1) _fl.rbuf = buffer_create(HEX_FLUID_RW * 2 * HEX_FLUID_RH * 4, buffer_fixed, 1);
	for (var i = 0; i < array_length(_made); i++) { surface_set_target(_made[i]); draw_clear_alpha(c_black, 0); surface_reset_target(); }
	// the graphics card threw the textures away (switching fullscreen, resizing): put the garden back from its last backup instead of
	// starting over (scr_hex_fluid_backup, every 2 s)
	if (_lost) {
		var _bw = _fl.bkw, _bufs = [_fl.bkd, _fl.bkv], _dst = [_fl.da, _fl.va];
		gpu_push_state(); gpu_set_blendenable(false); gpu_set_tex_filter(true);
		for (var i = 0; i < 2; i++) {
			if (!array_contains(_made, _dst[i])) continue;
			var _tmp = surface_create(_bw, _bw, _fl.bkf);
			buffer_set_surface(_bufs[i], _tmp, 0);
			surface_set_target(_dst[i]); draw_surface_stretched(_tmp, 0, 0, _W, _H); surface_reset_target();
			surface_free(_tmp);
		}
		gpu_pop_state();
		_fl.restored = (variable_struct_exists(_fl, "restored") ? _fl.restored : 0) + 1;
		show_debug_message("[FLUID] textures were lost (fullscreen or resize): the garden was restored from its backup");
	}
	if (!variable_struct_exists(_fl, "gr")) { _fl.gr = -1; _fl.gpa = -1; }
	if (!variable_struct_exists(_fl, "gpy")) { _fl.gpy = [-1, -1, -1, -1]; _fl.gat = -1; _fl.gbuf = -1; _fl.phi = []; }
	if (!surface_exists(_fl.gr))  _fl.gr  = surface_create(HEX_GRAV_W, HEX_GRAV_H, _fmt);
	for (var i = 0; i < 4; i++) if (!surface_exists(_fl.gpy[i])) _fl.gpy[i] = surface_create(HEX_GRAV_W >> (i + 1), HEX_GRAV_H >> (i + 1), _fmt);   // the mass, halved 4 times
	if (!surface_exists(_fl.gat)) _fl.gat = surface_create(HEX_GRAV_W * 2 - 8, HEX_GRAV_H, _fmt);   // all 5 levels side by side (128+64+32+16+8)
	if (_fl.gbuf == -1) _fl.gbuf = buffer_create(HEX_GRAV_W * HEX_GRAV_H * ((_fmt == surface_rgba32float) ? 16 : 8), buffer_fixed, 1);
	if (!surface_exists(_fl.gpa)) { _fl.gpa = surface_create(HEX_GRAV_W, HEX_GRAV_H, _fmt); surface_set_target(_fl.gpa); draw_clear_alpha(c_black, 0); surface_reset_target(); }
	if (!variable_struct_exists(_fl, "lt")) _fl.lt = -1;
	if (!surface_exists(_fl.lt)) { _fl.lt = surface_create(HEX_LIGHT_W, HEX_LIGHT_H, surface_rgba16float); _fl.lt_t = -1; }
	if (!variable_struct_exists(_fl, "scan")) { _fl.scan = 0; _fl.F = 0; _fl.rd = []; }
	// the garden's own clock (Myr, runs only while the physics does), gas waiting to be poured back, and the feedback map
	if (!variable_struct_exists(_fl, "myr")) { _fl.myr = 0; _fl.ret = []; _fl.ret_gas = 0; _fl.fb = -1; _fl.fbscale = 1; _fl.fbn = 0; _fl.force_sf = undefined; }
	if (!surface_exists(_fl.fb)) { _fl.fb = surface_create(HEX_FB_W, HEX_FB_H, _fmt); surface_set_target(_fl.fb); draw_clear_alpha(c_black, 0); surface_reset_target(); }
	if (array_contains(_made, _fl.da) && !_lost) _fl.scan = 0;               // (a brand-new garden: start the pour scan over)
	return _fl;
}
// a shockwave through the fluid: pushes outward from (_x, _y) in sky pixels for a few frames, and puffs color in
function scr_hex_fluid_kick(_x, _y, _r, _str, _col) {
	if (!variable_global_exists("hex_fluid")) return;
	var _fl = global.hex_fluid;
	if (array_length(_fl.kicks) < 8) array_push(_fl.kicks, { x: _x, y: _y, r: _r, s: _str, age: 0 });
	// (a shockwave only pushes now: the gas it throws out is real gas, poured in by its own wisps when they settle)
}
// the fluid's current at a point in her sky (pixels per frame), from the read-back copy. undefined if there isn't one yet
function scr_hex_fluid_vel(_x, _y) {
	if (!variable_global_exists("hex_fluid")) return undefined;
	var _rv = global.hex_fluid.rv;
	if (array_length(_rv) == 0) return undefined;
	var _RW = HEX_FLUID_RW, _RH = HEX_FLUID_RH, _sc = HEX_FLUID_CS * HEX_FLUID_W / _RW;   // sky pixels per sample
	var _gx = clamp(_x / _sc + _RW / 2 - 0.5, 0, _RW - 1.001), _gy = clamp(_y / _sc + _RH / 2 - 0.5, 0, _RH - 1.001);
	var _i = floor(_gx), _j = floor(_gy), _fx = _gx - _i, _fy = _gy - _j;
	var _q = (_i + _j * _RW) * 2;
	var _q2 = _q + 2, _q3 = _q + _RW * 2, _q4 = _q3 + 2;
	var _vx = lerp(lerp(_rv[_q], _rv[_q2], _fx), lerp(_rv[_q3], _rv[_q4], _fx), _fy);
	var _vy = lerp(lerp(_rv[_q + 1], _rv[_q2 + 1], _fx), lerp(_rv[_q3 + 1], _rv[_q4 + 1], _fx), _fy);
	return [_vx * HEX_FLUID_CS, _vy * HEX_FLUID_CS];                         // reference cells per frame to pixels per frame
}
// a fluid shader's uniform handles, looked up once per shader
function scr_hex_fluid_u(_sh) {
	if (!variable_global_exists("hex_fluid_us")) global.hex_fluid_us = {};
	var _key = string(_sh);
	if (!variable_struct_exists(global.hex_fluid_us, _key)) {
		var _n = ["u_texel", "u_uvmax", "u_size", "u_k", "u_time", "u_mode", "u_diss", "u_holes", "u_kicks", "u_dt", "u_keep", "u_kick", "u_jeans", "u_stage", "u_halo", "u_cshot", "u_lightmax", "u_amb", "u_ion", "u_refl", "u_dust", "u_src", "u_phimax", "u_phitexel", "u_grav", "u_cs", "u_fbmax", "u_fbtexel", "u_fbscale", "u_gn", "u_geps", "u_tint", "u_spell"];
		var _u = {};
		for (var i = 0; i < array_length(_n); i++) variable_struct_set(_u, _n[i], shader_get_uniform(_sh, _n[i]));
		_u.s_vel = shader_get_sampler_index(_sh, "u_vel");
		_u.s_gas = shader_get_sampler_index(_sh, "u_gas");
		_u.s_gas0 = shader_get_sampler_index(_sh, "u_gas0");
		_u.s_vel0 = shader_get_sampler_index(_sh, "u_vel0");
		_u.s_light = shader_get_sampler_index(_sh, "u_light");
		_u.s_phi = shader_get_sampler_index(_sh, "u_phi");
		_u.s_fb = shader_get_sampler_index(_sh, "u_fb");
		variable_struct_set(global.hex_fluid_us, _key, _u);
	}
	return variable_struct_get(global.hex_fluid_us, _key);
}
// the uniforms both fluid shaders share, set on whichever is current
function scr_hex_fluid_common(_U, _tw, _th, _W, _H, _t, _ho, _kk) {
	shader_set_uniform_f(_U.u_texel, _tw, _th);
	shader_set_uniform_f(_U.u_uvmax, _W * _tw, _H * _th);
	shader_set_uniform_f(_U.u_size, HEX_FLUID_W, HEX_FLUID_H);
	shader_set_uniform_f(_U.u_k, _W / HEX_FLUID_W);
	if (_U.u_time != -1) shader_set_uniform_f(_U.u_time, _t);
	shader_set_uniform_f_array(_U.u_holes, _ho);
	if (_U.u_kicks != -1) shader_set_uniform_f_array(_U.u_kicks, _kk);
}
// one pass of the fluid: _src drawn into _dst through mode _mode
function scr_hex_fluid_pass(_U, _mode, _src, _dst) {
	shader_set_uniform_f(_U.u_mode, _mode);
	surface_set_target(_dst);
	draw_surface(_src, 0, 0);
	surface_reset_target();
}
// THE STARLIGHT MAP: every star's light, laid over the same patch of sky as the fluid, so the gas can be lit by it (redrawn every
// 3 frames: stars move slowly). light falls off like real light (bright close in, a long faint reach), approximated by a tight
// bright stamp plus a wide faint one. two kinds, kept in separate channels:
//   rgb: every star's own light, in its own color, brighter for heavier stars (what dust reflects)
//   a:   only the hot stars' ultraviolet (O and B stars, and white dwarfs, the bare hot cores that light planetary nebulae), which
//        ionizes gas so it glows in its own color. a blue giant lights up a whole region; a red dwarf ionizes nothing
function scr_hex_fluid_light(_fl) {
	if (_fl.lt_t >= 0 && _fl.t - _fl.lt_t < 3) return;
	_fl.lt_t = _fl.t;
	var _LS = HEX_FLUID_CS * HEX_FLUID_W / HEX_LIGHT_W, _LW2 = HEX_LIGHT_W / 2, _LH2 = HEX_LIGHT_H / 2;
	var _st = global.hex_stars, _ns = array_length(_st), _hot = [];
	surface_set_target(_fl.lt);
	draw_clear_alpha(c_black, 0);
	gpu_set_blendenable(true);
	gpu_set_blendmode_ext_sepalpha(bm_src_alpha, bm_one, bm_one, bm_one);    // light adds up
	gpu_set_colorwriteenable(true, true, true, false);
	for (var i = 0; i < _ns; i++) {
		var _s = _st[i];
		if (!is_struct(_s) || _s[$ "ns"] == true) continue;                    // (a neutron star is too small to light anything)
		var _m = _s.m, _wd = (_s[$ "wd"] == true);
		var _lx = _s.ox / _LS + _LW2, _ly = _s.oy / _LS + _LH2;
		if (_lx < -60 || _ly < -60 || _lx > HEX_LIGHT_W + 60 || _ly > HEX_LIGHT_H + 60) continue;
		if (_s[$ "pop"] == true) {                                             // a star cluster: its whole population's light, fading as it ages
			var _pL = variable_struct_exists(_s, "lum") ? _s.lum : 1;
			var _pR = min(300, 50 + 90 * sqrt(_pL)) / _LS / 20, _pw = clamp(0.35 * sqrt(_pL), 0.03, 1);
			draw_sprite_ext(spr_soft, 0, _lx, _ly, _pR * 0.3, _pR * 0.3, 0, _s.c0, _pw);
			draw_sprite_ext(spr_soft, 0, _lx, _ly, _pR, _pR, 0, _s.c0, _pw * 0.35);
			if (scr_hex_pop_q(_fl.myr - _s.tb) > 0.01) array_push(_hot, _s);   // young enough that its O stars still ionize
			continue;
		}
		if (_wd || _m >= HEX_ION_MASS) array_push(_hot, _s);
		if (_m < 2 && !_wd) continue;                                          // (the faintest red dwarfs barely light anything)
		var _ck = _m + (_s.hx ? 100000 : 0);
		if (_s[$ "cm"] != _ck) { _s.cm = _ck; _s.c0 = scr_hex_star_color(_m, _s.ph, _s.hx); }
		var _c = _wd ? make_color_rgb(205, 225, 255) : _s.c0;
		var _R = min(300, 40 + 15 * sqrt(_m)) / _LS / 20;                     // (in spr_soft scale units: 20px of radius each)
		var _w = clamp(sqrt(_m) / 8, 0.05, 1);
		draw_sprite_ext(spr_soft, 0, _lx, _ly, _R * 0.3, _R * 0.3, 0, _c, _w);
		draw_sprite_ext(spr_soft, 0, _lx, _ly, _R, _R, 0, _c, _w * 0.35);
	}
	// the ultraviolet is used up by the gas it ionizes: a hot star in a dense cloud lights only a small bubble around itself (its
	// Stromgren sphere, radius ~ density^(-2/3)), while in thin gas its light reaches far. the local density comes from the fluid's
	// read-back map
	gpu_set_colorwriteenable(false, false, false, true);
	var _rd = _fl.rd, _rok = (array_length(_rd) == HEX_FLUID_RW * HEX_FLUID_RH), _rsc = HEX_FLUID_CS * HEX_FLUID_W / HEX_FLUID_RW;
	for (var i = 0; i < array_length(_hot); i++) {
		var _s = _hot[i], _wd = (_s[$ "wd"] == true);
		var _lx = _s.ox / _LS + _LW2, _ly = _s.oy / _LS + _LH2;
		var _w = _wd ? 0.8 : min(1, 0.3 + 1.2 * clamp((_s.m - HEX_ION_MASS) / 48, 0, 1));
		var _dl = 0;
		if (_rok) {
			var _gi = clamp(floor(_s.ox / _rsc + HEX_FLUID_RW / 2), 0, HEX_FLUID_RW - 1), _gj = clamp(floor(_s.oy / _rsc + HEX_FLUID_RH / 2), 0, HEX_FLUID_RH - 1);
			_dl = _rd[_gi + _gj * HEX_FLUID_RW];
		}
		var _strom = power(1 + _dl / HEX_STROMGREN_D, -2 / 3);
		var _R = (_wd ? 120 : min(500, 120 + 6 * _s.m)) * _strom / _LS / 20;
		if (_s[$ "pop"] == true) {
			// a cluster's ionized bubble from the real Stromgren radius, R = (3Q / (4 pi alpha n^2))^(1/3): ~4e46 ionizing photons a second
			// per sun of a young cluster (Starburst99) gives 1,076 pc for a million suns in gas of 1 atom per cm^3. n from the gas there
			var _q = scr_hex_pop_q(_fl.myr - _s.tb);
			var _nH = max(0.05, _dl * HEX_SIGMA_UNIT / (2 * HEX_DISK_H) / 0.0346);   // atoms per cm^3 (0.0346 suns per pc^3 each, with helium)
			_R = min(400, 107.6 * power(scr_hex_pop_msun(_s.m) / 1000000 * _q, 1 / 3) * power(_nH, -2 / 3)) / _LS / 20;
			_w = min(1, _q);
		}
		draw_sprite_ext(scr_hex_soft_alpha(), 0, _lx, _ly, _R * 0.3, _R * 0.3, 0, c_white, _w);   // (alpha-shaped stamp: this pass writes alpha)
		draw_sprite_ext(scr_hex_soft_alpha(), 0, _lx, _ly, _R, _R, 0, c_white, _w * 0.35);
	}
	gpu_set_colorwriteenable(true, true, true, true);
	surface_reset_target();
	_fl.nstars = _ns;
	// the young stars' total ionizing output (millions of suns of clusters still under 3.5 Myr, fading after): what powers the faint
	// DIFFUSE IONIZED GAS between the bright nebulae (~a third of young clusters' ultraviolet escapes into the wider galaxy). the gas's
	// faint overall glow follows it, so a garden with no young stars yet is dark dust, and it lights up as clusters form
	var _qs = 0;
	for (var i = 0; i < _ns; i++) { var _s = _st[i]; if (is_struct(_s) && _s[$ "pop"] == true) _qs += scr_hex_pop_q(_fl.myr - _s.tb) * scr_hex_pop_msun(_s.m) / 1000000; }
	_fl.qsum = _qs;
}

// ORBITS (step 4's core, brought forward): stars and black holes move in the same gravity as the gas, so a star stays with the
// cloud it was born in and the whole garden turns together (this replaces the scripted galaxy turn and the whole-sky spin).
// stepped with LEAPFROG (kick, drift, kick: a symplectic integrator, the standard for orbits in astrophysics; unlike Runge-Kutta
// it never gains or loses energy over many orbits, so orbits stay stable forever). the pull: the dark matter halo (the same
// a = -vc^2 r / (r^2 + r0^2) the gas feels). a body with no velocity yet starts on a circular orbit, like the gas poured in
// THE SOFT STAMP, IN ALPHA. spr_soft (obj_unmaking Create) keeps its bell curve in its COLOR on a solid square (alpha 1 everywhere),
// which is right for anything that adds color. anything that works by alpha (taking gas out, signed momentum, the ionizing
// light) needs the bell in the alpha: this copy is white with the same bell as its alpha. (using spr_soft there acted on whole
// SQUARES: new gas got square patches of motion with almost no gas in the corners, flung at top speed, blasting the garden empty;
// stars took their gas in squares; hot stars' light reached across squares)
function scr_hex_soft_alpha() { return scr_hex_alpha_stamp(0); }
// _kind 0: the soft bell. 1: a bubble's PRESSURE: highest in the middle, easing down 40% toward 70% of its radius (so gas left inside
// is pushed out too, as the hot gas ablates and pushes cold clumps), then a smooth rim to nothing at 31 px, where the shell is shoved
function scr_hex_alpha_stamp(_kind) {
	var _key = (_kind == 0) ? "softa" : "plat2";
	if (!variable_global_exists("hex_stamps")) global.hex_stamps = {};          // (its own home: obj_unmaking's Create rebuilds global.hex_fx every cast)
	if (variable_struct_exists(global.hex_stamps, _key) && sprite_exists(variable_struct_get(global.hex_stamps, _key))) return variable_struct_get(global.hex_stamps, _key);
	var _s = surface_create(64, 64);
	surface_set_target(_s);
	draw_clear_alpha(c_white, 0);
	gpu_push_state();
	gpu_set_colorwriteenable(true, true, true, true);
	gpu_set_blendenable(true);
	gpu_set_blendmode_ext_sepalpha(bm_zero, bm_one, bm_one, bm_one);        // (color stays white; alpha adds up ring by ring)
	draw_set_color(c_white);
	for (var _k = 0; _k < 24; _k++) {                                          // ring by ring (bell: the same as spr_soft, exp(-3 (r/31)^2))
		var _r0 = 31 * (1 - _k / 24), _r1 = 31 * (1 - (_k + 1) / 24);
		var _f0, _f1;
		if (_kind == 0) { _f0 = exp(-3 * sqr(_r0 / 31)); _f1 = exp(-3 * sqr(_r1 / 31)); }
		else {
			var _x0 = clamp((_r0 / 31 - 0.7) / 0.3, 0, 1), _x1 = clamp((_r1 / 31 - 0.7) / 0.3, 0, 1);
			_f0 = (1 - _x0 * _x0 * (3 - 2 * _x0)) * (1 - 0.4 * sqr(min(1, _r0 / 31 / 0.7)));
			_f1 = (1 - _x1 * _x1 * (3 - 2 * _x1)) * (1 - 0.4 * sqr(min(1, _r1 / 31 / 0.7)));
		}
		draw_set_alpha(_f1 - _f0);
		draw_circle(32, 32, _r0, false);
	}
	draw_set_alpha(1);
	gpu_pop_state();
	surface_reset_target();
	var _spr = sprite_create_from_surface(_s, 0, 0, 64, 64, false, false, 32, 32);
	surface_free(_s);
	variable_struct_set(global.hex_stamps, _key, _spr);
	return _spr;
}

// ---- STAR CLUSTERS (step 3): the physics of a population, all from published fits ----
// a star she makes (scr_unmake): a young cluster, born at the garden's present moment, its birth color the stardust's (scr_hex_star_color
// of how many of her dead it holds, as the cast's motes fly). counted in F1's budget as formed (new matter from her kills)
#macro HEX_CAST_STAR_MASS 0.05      // cluster mass (units of star mass) per enemy unmade: ~180,000 suns
function scr_hex_cast_cluster(_p, _w, _hx, _big) {
	var _myr = (variable_global_exists("hex_fluid") && variable_struct_exists(global.hex_fluid, "myr")) ? global.hex_fluid.myr : 0;
	var _m = _w * HEX_CAST_STAR_MASS;
	var _s = { ox: _p.ox, oy: _p.oy, s: _p.s, ph: _p.ph, hx: _hx, big: _big, m: _m, age: 0,
	           pop: true, m0: _m, tb: _myr, rd0: 1, ar: 0, ap: 0, ne: _w, nm: 2, lum: 0 };
	_s.cb = scr_hex_star_color(_w, _p.ph, _hx);
	_s.c0 = _s.cb;
	array_push(global.hex_stars, _s);
	if (variable_global_exists("hex_fluid")) {
		var _fl = global.hex_fluid;
		_fl.sf_n = (variable_struct_exists(_fl, "sf_n") ? _fl.sf_n : 0) + 1;
		_fl.sf_gas = (variable_struct_exists(_fl, "sf_gas") ? _fl.sf_gas : 0) + _m * HEX_GAS_PER_MASS;
	}
	return _s;
}
function scr_hex_cast_feed(_s, _w) {
	if (_s[$ "pop"] != true) { _s.m += _w; return; }                          // (a star from before clusters: the old way)
	var _dm = _w * HEX_CAST_STAR_MASS;
	_s.m += _dm; _s.m0 += _dm; _s.ne += _w;
	_s.nm = clamp(round(2 + 2 * log10(1 + 3 * scr_hex_pop_msun(_s.m0) / 1000000)), 2, 6);
	_s.cb = scr_hex_star_color(_s.ne, _s.ph, _s.hx);
	_s.c0 = _s.cb;
	if (variable_global_exists("hex_fluid")) global.hex_fluid.sf_gas = (variable_struct_exists(global.hex_fluid, "sf_gas") ? global.hex_fluid.sf_gas : 0) + _dm * HEX_GAS_PER_MASS;
}
// a short line shown on screen for a few seconds while stargazing (HUD draws it): what a debug key just did
function scr_hex_toast(_txt) { global.hex_toast = { txt: _txt, t: game_get_speed(gamespeed_fps) * 4 }; show_debug_message("[GARDEN] " + _txt); }
// a cluster's mass in suns (one unit of star mass = HEX_GAS_PER_MASS of read-back gas)
function scr_hex_pop_msun(_m) { return _m * HEX_GAS_PER_MASS * HEX_SIGMA_UNIT * HEX_SAMPLE_PC * HEX_SAMPLE_PC; }
// the share of its mass its stars have handed back by age _t (Myr): massive stars' winds, supernova debris, then dying sun-like stars
// (Leitner & Kravtsov 2011, for a Chabrier IMF: 0.046 ln(1 + t / 0.276 Myr). 11% by 3 Myr, 23% by 40 Myr, 38% by a billion years)
function scr_hex_pop_fret(_t) { return 0.046 * ln(1 + max(0, _t) / 0.276); }
// its ionizing light, relative to its first 3.5 Myr: steady while its O stars live, then falling fast as they die (Starburst99)
// it starts hidden: a newborn cluster sits inside the dense core it formed from, which swallows its ultraviolet (an ultracompact
// region far smaller than our cells) until its light and winds break the cocoon open over its first ~2-3 Myr (the embedded phase:
// Lada & Lada 2003). so its glow swells in gently instead of switching on at full strength, in step with its color emerging
// GML has no smoothstep (it is a shader function): the same smooth 0-to-1 ramp between _a and _b
function scr_hex_smooth(_a, _b, _x) { var _t = clamp((_x - _a) / (_b - _a), 0, 1); return _t * _t * (3 - 2 * _t); }
function scr_hex_pop_q(_age) {
	if (_age < 0) return 0;
	var _esc = scr_hex_smooth(0.3, 2.5, _age);                                    // the share escaping its cocoon
	return _esc * ((_age < 3.5) ? 1 : power(_age / 3.5, -4));
}
// THE SUPERBUBBLE (Weaver et al. 1977; McCray & Kafatos 1987; blowout: Mac Low & McCray 1988). from 3 Myr its massive stars explode,
// one every ~90 suns, and the blasts merge into one hot bubble. its radius and pressure come straight from the energy put in:
//   radius   R = 0.76 (L t^3 / rho0)^(1/5)          pressure   P = 0.072 L t / R^3      (L: supernova power, rho0: the gas it formed in)
// in parsecs and Myr that's R = 16.4 (A t^3)^(1/5), and P / (rho0 cs^2) = 323,600 A t / (cs^2 R^3), with A the area the cluster's own
// gas would cover at its birth density (its mass over that density). once the bubble is ~3 disk thicknesses wide it bursts out of the
// disk (a "chimney") and vents: its pressure falls, and the shell it swept up coasts on by its own momentum. returns [pressure as a
// multiple of the cold gas's own pressure at its birth, radius in reference cells]
function scr_hex_pop_bubble(_st, _t) {
	var _a = _t - 3;                                                          // (the first supernova goes off at ~3 Myr)
	if (_a <= 0 || _a > 39) return [0, 0];
	var _A = (_st.m0 * HEX_GAS_PER_MASS / max(0.2, _st.rd0)) * HEX_SAMPLE_PC * HEX_SAMPLE_PC * (2 * HEX_DISK_H / 300) * HEX_SN_K;
	var _PCC = HEX_PC_PER_PX * HEX_FLUID_CS;                                  // parsecs per reference cell
	var _Rbo = 3 * HEX_DISK_H, _Rmin = HEX_FB_RMIN * _PCC;
	var _k = 323600 / (HEX_GAS_CS_KMS * HEX_GAS_CS_KMS);
	var _RW = 16.4 * power(_A * _a * _a * _a, 0.2);
	var _P, _R;
	if (_RW < _Rbo) {
		_R = max(_RW, _Rmin);                                                  // (smaller than the grid can hold: its energy spread over the smallest bubble it can)
		_P = _k * _A * _a / (_R * _R * _R);
	} else {
		var _tbo = power(power(_Rbo / 16.4, 5) / _A, 1 / 3);                   // when it burst out of the disk
		_R = _Rbo;
		_P = _k * _A * _tbo / (_R * _R * _R) * (0.85 * exp(-(_a - _tbo) / 1.5) + 0.15);   // venting (the hot gas escapes in ~1.5 Myr)
	}
	if (_a > 37) _P *= max(0, 1 - (_a - 37) / 2);                            // the last supernova (the lightest stars that explode, 8 suns, at ~40 Myr)
	return [_P, _R / _PCC];
}
// a whole population's color by age (its integrated light: blue while its massive stars live, whitening and yellowing as they burn out
// and red giants take over; Bruzual & Charlot 2003). the same palette as single stars
function scr_hex_pop_color(_age, _ph) {
	var _stops = [make_color_rgb(255, 110, 80), make_color_rgb(255, 160, 95), make_color_rgb(255, 215, 150),
	              make_color_rgb(255, 248, 235), make_color_rgb(185, 210, 255), make_color_rgb(125, 160, 255)];
	var _la = log10(max(1, _age));
	var _ages = [0, 0.7, 1, 1.5, 2, 2.5, 3, 3.5, 4];                         // log10 of the age in Myr: 1, 5, 10, 30, 100, 300 Myr, 1, 3, 10 Gyr
	var _ks   = [1, 1, 0.95, 0.88, 0.78, 0.65, 0.55, 0.45, 0.32];             // blue, blue, ..., white, yellow, warm yellow
	var _k = _ks[8];
	for (var i = 0; i < 8; i++) if (_la < _ages[i + 1]) { _k = lerp(_ks[i], _ks[i + 1], (_la - _ages[i]) / (_ages[i + 1] - _ages[i])); break; }
	_k = clamp(_k + (scr_hash(_ph * 0.37 + 11) - 0.5) * 0.06, 0, 1);
	var _f = _k * 5, _i = min(4, floor(_f));
	return merge_color(merge_color(_stops[_i], _stops[_i + 1], _f - _i), c_white, HEX_STAR_SOFTEN);
}
// where one of a young cluster's brightest members sits, in sky pixels from its middle (the same every time: hashed from the cluster)
function scr_hex_pop_member(_st, _k) {
	var _sz = clamp(0.8 + 0.25 * log10(1 + scr_hex_pop_msun(_st.m0) / 1000000), 0.8, 1.5);
	var _r = (2.5 + 5 * scr_hash(_st.ph * 2.3 + _k * 1.3)) * _sz, _a = 360 * scr_hash(_st.ph * 0.91 + _k * 7.7);
	return [lengthdir_x(_r, _a), lengthdir_y(_r, _a)];
}
// when that member dies: massive stars live 3 to 40 Myr
function scr_hex_pop_death(_st, _k) { return 3 + 37 * scr_hash(_st.ph * 1.7 + _k * 3.1); }

// every read-back (0.2 Myr), while the physics runs: each cluster ages by the garden's clock, dims and reddens, hands its gas back
// (queued for the fluid: scr_hex_fluid_update pours it in), and its brightest members, one by one, go supernova (a flash). old
// clusters past 100 Myr that drift together merge (clusters dissolve into the galaxy's old stars), so the count stays bounded
function scr_hex_pops_update(_fl) {
	var _st = global.hex_stars, _T = _fl.myr, _old = undefined, _drop = false, _smr = 0, _sm = 0, _act = [];
	if (!variable_global_exists("hex_snf")) global.hex_snf = [];
	for (var i = 0; i < array_length(_st); i++) {
		var _s = _st[i];
		if (!is_struct(_s) || _s[$ "pop"] != true) continue;
		var _age = _T - _s.tb;
		_s.age = _age;
		_sm += _s.m; _smr += _s.m * point_distance(0, 0, _s.ox, _s.oy);         // (the clusters' mass-weighted size, for F1)
		if (_age > 2.8 && _age < 42.5) array_push(_act, _s);                     // (in or near its supernova years: the feedback map's list)
		// its gas comes home: in the supernova years as metal-rich debris (oxygen teal, sulphur and iron gold, hydrogen red), later
		// as the gentle winds of dying sun-like stars (mostly hydrogen and dust). poured where its stars are, moving as they move
		var _dm = _s.m0 * (scr_hex_pop_fret(_age) - scr_hex_pop_fret(_s.ar));
		_s.ar = _age;
		if (_dm > 0) {
			var _b = scr_hex_pop_bubble(_s, _age), _h = scr_hash(_s.ph + _age * 13.7);
			var _c = (_age < 40) ? ((_h < 0.45) ? make_color_rgb(70, 220, 200) : ((_h < 0.7) ? make_color_rgb(255, 200, 90) : make_color_rgb(255, 85, 115)))
			                     : ((_h < 0.6) ? make_color_rgb(255, 85, 115) : ((_h < 0.9) ? make_color_rgb(255, 175, 75) : make_color_rgb(70, 220, 200)));
			// while its superbubble is open, the debris joins the shell it is sweeping (mass-loading: the hot interior's gas ends up in the
			// shell): poured at ~80% of the bubble's radius, moving outward at the shell's speed (dR/dt = 0.6 R / t for R ~ t^0.6).
			// otherwise (before 3 Myr, after 40 Myr) it's the gentle winds of its stars: poured where they are
			var _ja = random(360), _jr = 0, _jv = 0, _jw = 16;
			if (_b[1] > 0) {
				var _Rp = _b[1] * HEX_FLUID_CS;                                       // its radius, sky px
				_jr = 0.8 * _Rp; _jw = max(12, 0.25 * _Rp);
				_jv = min(0.2 * HEX_FLUID_CS, 0.6 * _Rp / max(0.3, _age - 3) / 60);   // px a frame (1 Myr = 60 frames)
			}
			array_push(_fl.ret, [_s.ox + lengthdir_x(_jr, _ja), _s.oy + lengthdir_y(_jr, _ja), _dm * HEX_GAS_PER_MASS,
			                     _jw, _c, _s.gvx + lengthdir_x(_jv, _ja), _s.gvy + lengthdir_y(_jv, _ja)]);
			_s.m -= _dm;
			_fl.ret_gas += _dm * HEX_GAS_PER_MASS;
		}
		// its light: a population fades as it ages (~t^-0.8, the classic fading of a single burst of stars)
		var _L = scr_hex_pop_msun(_s.m) / 1000000 * power(max(1, _age), -0.8);
		_s.lum = _L;
		_s.s = clamp(0.7 + 0.9 * power(_L, 1 / 3), 0.6, 2.4);
		// its color: born wrapped in the dust it formed from (warm and reddened: the stardust's color for her stars, a dusty orange for
		// the gas's own), it emerges over its first ~4 Myr as its winds and light clear the cocoon, into its population's own light
		var _cb = _s[$ "cb"] ?? make_color_rgb(255, 165, 110);
		_s.c0 = merge_color(_cb, scr_hex_pop_color(_age, _s.ph), scr_hex_smooth(0.5, 4, _age));
		if (_s.hx) _s.c0 = merge_color(_s.c0, make_color_rgb(200, 140, 255), 0.2);   // (her own hexed dead keep a touch of her violet)
		// its brightest members die one by one, each a supernova
		for (var k = 0; k < _s.nm; k++) {
			var _dk = scr_hex_pop_death(_s, k);
			if (_dk > _s.ap && _dk <= _age) {
				var _mo = scr_hex_pop_member(_s, k);
				array_push(global.hex_snf, { ox: _s.ox + _mo[0], oy: _s.oy + _mo[1], t0: _fl.t });
			}
		}
		_s.ap = _age;
		// dissolving: an old cluster that meets another old one merges with it (mass, momentum and age kept, weighted by mass)
		if (_age > 100) {
			if (is_undefined(_old)) _old = ds_map_create();
			var _key = floor(_s.ox / 40) * 100000 + floor(_s.oy / 40);
			var _o = _old[? _key];
			if (is_undefined(_o)) _old[? _key] = _s;
			else {
				var _wa = _o.m / max(0.0001, _o.m + _s.m);
				_o.ox = lerp(_s.ox, _o.ox, _wa); _o.oy = lerp(_s.oy, _o.oy, _wa);
				_o.gvx = lerp(_s.gvx, _o.gvx, _wa); _o.gvy = lerp(_s.gvy, _o.gvy, _wa);
				_o.tb = lerp(_s.tb, _o.tb, _wa); _o.ar = _T - _o.tb; _o.ap = _o.ar;
				_o.m += _s.m; _o.m0 += _s.m0;
				_s.s = 0; _s.pop = false; _s.gone = true; _drop = true;
			}
		}
	}
	if (!is_undefined(_old)) ds_map_destroy(_old);
	_fl.rstar = (_sm > 0) ? _smr / _sm * HEX_PC_PER_PX / 1000 : 0;               // kpc
	_fl.fbact = _act;
	if (_drop) {
		var _keep = [];
		for (var i = 0; i < array_length(_st); i++) if (!(is_struct(_st[i]) && _st[i][$ "gone"] == true)) array_push(_keep, _st[i]);
		global.hex_stars = _keep;
	}
}

// THE FEEDBACK MAP: every active superbubble's pressure, laid over the fluid (a flat top with a soft rim, so its push lands on the
// shell around it). the gas solver feels its slope as a force (sh_hex_fluid_p): the bubble shoves its shell outward, wherever the shell is
function scr_hex_feedback_map(_fl) {
	var _pl = scr_hex_alpha_stamp(1);
	var _st = variable_struct_exists(_fl, "fbact") ? _fl.fbact : global.hex_stars, _FS = HEX_FLUID_CS * HEX_FLUID_W / HEX_FB_W, _list = [], _mx = 0;
	for (var i = 0; i < array_length(_st); i++) {                              // (only clusters in their supernova years: pops_update lists them)
		var _s = _st[i];
		if (!is_struct(_s) || _s[$ "pop"] != true) continue;
		var _b = scr_hex_pop_bubble(_s, _fl.myr - _s.tb);
		if (_b[0] <= 0) continue;
		var _v = _b[0] * max(0.2, _s.rd0);                                     // (pressure in units of the cold gas's: ratio x its birth density)
		array_push(_list, [_s.ox / _FS + HEX_FB_W / 2, _s.oy / _FS + HEX_FB_H / 2, _b[1] * HEX_FB_W / HEX_FLUID_W, _v]);
		_mx = max(_mx, _v);
	}
	// the black holes' light pushing on the gas: a bubble like a cluster's, with the supernova power swapped for the hole's (energy into
	// the gas 0.05 x 0.1 x feeding x c^2; a cluster's supernovae give 1e51 erg per 90 suns over 37 Myr, so it's a cluster this heavy)
	for (var h = 0; h < array_length(global.hex_holes); h++) {
		var _ho = global.hex_holes[h];
		if (!variable_struct_exists(_ho, "agn_t") || _ho.agn_t <= 0) continue;
		var _meq = HEX_AGN_COUPLE * HEX_RAD_EFF * _ho.mdsm * 5960700 / HEX_SN_K;   // suns (1.79e54 erg per sun of c^2, over 1e51 erg per 90 suns per 37 Myr. GML has no "e" notation)
		var _b = scr_hex_pop_bubble({ m0: _meq / scr_hex_pop_msun(1), rd0: _ho.rho }, min(_ho.agn_t, 30) + 3);   // (after 30 Myr: steady, venting)
		if (_b[0] <= 0) continue;
		var _v = _b[0] * max(0.2, _ho.rho);
		array_push(_list, [_ho.ox / _FS + HEX_FB_W / 2, _ho.oy / _FS + HEX_FB_H / 2, _b[1] * HEX_FB_W / HEX_FLUID_W, _v]);
		_mx = max(_mx, _v);
	}
	_fl.fbscale = max(1, _mx);
	_fl.fbn = array_length(_list);
	surface_set_target(_fl.fb);
	draw_clear_alpha(c_black, 0);
	gpu_push_state();
	gpu_set_blendenable(true);
	gpu_set_colorwriteenable(true, true, true, true);
	gpu_set_blendmode_ext_sepalpha(bm_src_alpha, bm_one, bm_one, bm_one);    // (overlapping bubbles' pressures add up)
	for (var i = 0; i < array_length(_list); i++) {
		var _q = _list[i], _sc = _q[2] / 31;                                    // (the plateau's rim is at 31 px of its sprite)
		draw_sprite_ext(_pl, 0, _q[0], _q[1], _sc, _sc, 0, c_white, _q[3] / _fl.fbscale);
	}
	gpu_pop_state();
	surface_reset_target();
}

// A NEW RUN STARTS WITH AN EMPTY UNIVERSE (obj_game_controller Create). the gas lives in textures that outlive a run, so without this the
// last run's garden carried over as real gas (parked idea: a faint remnant of your last universe, inherited on purpose)
function scr_hex_fluid_reset() {
	if (!variable_global_exists("hex_fluid")) return;
	var _fl = global.hex_fluid;
	var _all = [_fl[$ "va"], _fl[$ "vb"], _fl[$ "vc"], _fl[$ "da"], _fl[$ "db"], _fl[$ "dc"], _fl[$ "gpa"]];
	for (var i = 0; i < array_length(_all); i++) if (!is_undefined(_all[i]) && surface_exists(_all[i])) surface_free(_all[i]);   // (recreated empty)
	_fl.bkw = 0;                                                                // (and the backup isn't restored into the new run)
	_fl.F = 0; _fl.rd = []; _fl.rv = []; _fl.phi = []; _fl.ret = []; _fl.kicks = []; _fl.scan = 0; _fl.force_sf = undefined;
	_fl.myr = 0; _fl.sf_n = 0; _fl.sf_gas = 0; _fl.ret_gas = 0; _fl.bh_gas = 0; _fl.fbscale = 1; _fl.fbn = 0; _fl.rgas = 0; _fl.qsum = 0;
	global.hex_snf = [];
}
// ...and so does the rest of her universe's state that outlived the last run (the aeon clock read 'dawn 60s' at a run's first second)
function scr_hex_universe_reset() {
	scr_hex_fluid_reset();
	global.hex_aeon = { phase: "dawn", t: 0, n: 0 };
	scr_hex_cosmo_new(HEX_UNI_B0, 0);                                         // a fresh, unfed universe: all its gas still in the reservoir
	global.hex_crunch_k = 0;
	global.hex_mood = { bg: 1, dark: 0, spin: 1, lensk: 1, gr: 1, gg: 1, gb: 1, lift: 0 };
	global.hex_bang = undefined; global.hex_merge = undefined; global.hex_ripples = []; global.hex_lens_ghosts = [];
	if (!variable_global_exists("hex_merge_rush")) global.hex_merge_rush = false;   // (obj_unmaking Step sets it alongside hex_merge, only if hex_merge was missing)
	global.hex_marks = []; global.hex_flow = []; global.hex_toast = undefined; global.hex_snf = [];
	global.hex_card_ph = ""; global.hex_card_t = 999;                         // (the DAWN title card shows again)
}
// THE BACKUP (every 2 s): the gas and its momentum, shrunk by halves (each halving averages 2 x 2 cells exactly, so the gas is kept)
// to at most 256 x 256 and copied into memory. graphics cards may throw textures away when the window changes (fullscreen); then the
// garden is put back from this instead of being lost
function scr_hex_fluid_backup(_fl, _W, _fmt) {
	var _bw = _W;
	while (_bw > 256) _bw = _bw div 2;
	var _bpp = (_fmt == surface_rgba32float) ? 16 : 8;
	if (!variable_struct_exists(_fl, "bkd") || _fl.bkw != _bw || _fl.bkf != _fmt) {
		if (variable_struct_exists(_fl, "bkd") && buffer_exists(_fl.bkd)) { buffer_delete(_fl.bkd); buffer_delete(_fl.bkv); }
		_fl.bkd = buffer_create(_bw * _bw * _bpp, buffer_fixed, 1); _fl.bkv = buffer_create(_bw * _bw * _bpp, buffer_fixed, 1);
		_fl.bkw = 0; _fl.bkf = _fmt;
	}
	gpu_push_state(); gpu_set_blendenable(false); gpu_set_tex_filter(true);
	var _src = [_fl.da, _fl.va], _bufs = [_fl.bkd, _fl.bkv];
	for (var i = 0; i < 2; i++) {
		var _cur = _src[i], _cw = _W, _tmps = [];
		while (_cw > _bw) {
			var _nw = _cw div 2, _n = surface_create(_nw, _nw, _fmt);
			surface_set_target(_n); draw_clear_alpha(c_black, 0); draw_surface_stretched(_cur, 0, 0, _nw, _nw); surface_reset_target();
			array_push(_tmps, _n); _cur = _n; _cw = _nw;
		}
		buffer_get_surface(_bufs[i], _cur, 0);
		for (var k = 0; k < array_length(_tmps); k++) surface_free(_tmps[k]);
	}
	gpu_pop_state();
	_fl.bkw = _bw;
}

function scr_hex_halo_acc(_x, _y) {
	var _vc = HEX_GAL_VC * HEX_FLUID_CS, _r2 = _x * _x + _y * _y + HEX_GAL_R0 * HEX_GAL_R0;   // (sky px per frame)
	return [-_vc * _vc * _x / _r2, -_vc * _vc * _y / _r2];
}
// the pull of all the gas, stars and black holes at (x, y): the same potential the gas feels (read back by scr_hex_fluid_update), so
// every pull goes both ways: clusters stay with their gas and sink into its lanes
function scr_hex_gas_acc(_x, _y) {
	var _ax = 0, _ay = 0;
	if (variable_global_exists("hex_fluid") && variable_struct_exists(global.hex_fluid, "phi") && array_length(global.hex_fluid.phi) == HEX_GRAV_W * HEX_GRAV_H) {
		var _ph = global.hex_fluid.phi, _GS = HEX_FLUID_CS * HEX_FLUID_W / HEX_GRAV_W;
		var _gx = _x / _GS + HEX_GRAV_W / 2 - 0.5, _gy = _y / _GS + HEX_GRAV_H / 2 - 0.5;
		if (_gx > 1.5 && _gy > 1.5 && _gx < HEX_GRAV_W - 2.5 && _gy < HEX_GRAV_H - 2.5) {   // (well inside: GameMaker's comparisons carry a small tolerance)
			var _a = scr_hex_phi_at(_ph, _gx + 1, _gy) - scr_hex_phi_at(_ph, _gx - 1, _gy);
			var _b = scr_hex_phi_at(_ph, _gx, _gy + 1) - scr_hex_phi_at(_ph, _gx, _gy - 1);
			_ax -= 0.5 * _a * HEX_GRAV * HEX_FLUID_CS; _ay -= 0.5 * _b * HEX_GRAV * HEX_FLUID_CS;   // (slope per gravity cell -> sky px per frame^2)
		}
	}
	return [_ax, _ay];
}
// a body's whole pull: the halo exactly, plus the gas's (which changes slowly: refreshed every 4th frame, each body on its own beat)
function scr_hex_body_acc(_b, _fresh) {
	if (_fresh || !variable_struct_exists(_b, "gax")) { var _g = scr_hex_gas_acc(_b.ox, _b.oy); _b.gax = _g[0]; _b.gay = _g[1]; }
	var _h = scr_hex_halo_acc(_b.ox, _b.oy);
	return [_h[0] + _b.gax, _h[1] + _b.gay];
}
// the potential between gravity cells (bilinear)
function scr_hex_phi_at(_ph, _x, _y) {
	var _i = clamp(floor(_x), 0, HEX_GRAV_W - 2), _j = clamp(floor(_y), 0, HEX_GRAV_H - 2);   // (never off the grid, whatever the rounding)
	var _fx = clamp(_x - _i, 0, 1), _fy = clamp(_y - _j, 0, 1), _q = _i + _j * HEX_GRAV_W;
	return lerp(lerp(_ph[_q], _ph[_q + 1], _fx), lerp(_ph[_q + HEX_GRAV_W], _ph[_q + HEX_GRAV_W + 1], _fx), _fy);
}
function scr_hex_orbits() {
	var _dt = scr_hex_time();                                                  // (one frame of cosmic time: full or half speed)
	var _mg = variable_global_exists("hex_merge") ? global.hex_merge : undefined;
	var _ot = variable_global_exists("hex_fluid") ? global.hex_fluid.t : 0;
	var _lists = [global.hex_stars, global.hex_holes];
	for (var L = 0; L < 2; L++) {
		var _st = _lists[L];
		for (var i = 0; i < array_length(_st); i++) {
			var _b = _st[i];
			if (!is_struct(_b)) continue;
			if (L == 0 && _b.s <= 0) continue;
			if (L == 1 && !is_undefined(_mg) && (_b == _mg.a || _b == _mg.b)) continue;   // (a pair spiralling together moves on its own)
			var _fr = ((_ot + i) mod 4 == 0);
			var _a = (variable_struct_exists(_b, "lax")) ? [_b.lax, _b.lay] : scr_hex_body_acc(_b, true);   // (last step's closing kick: no need to recompute)
			if (!variable_struct_exists(_b, "gvx")) {                              // a circular orbit to start (turning the way the gas does)
				var _r = max(1, point_distance(0, 0, _b.ox, _b.oy)), _vc = HEX_GAL_VC * HEX_FLUID_CS * _r / sqrt(_r * _r + HEX_GAL_R0 * HEX_GAL_R0);
				_b.gvx = _vc * _b.oy / _r; _b.gvy = -_vc * _b.ox / _r;
			}
			_b.gvx += _a[0] * 0.5 * _dt; _b.gvy += _a[1] * 0.5 * _dt;            // kick
			_b.ox += _b.gvx * _dt; _b.oy += _b.gvy * _dt;                           // drift
			_a = scr_hex_body_acc(_b, _fr);
			_b.lax = _a[0]; _b.lay = _a[1];
			_b.gvx += _a[0] * 0.5 * _dt; _b.gvy += _a[1] * 0.5 * _dt;            // kick
		}
	}
}

// STAR FORMATION FROM THE GAS. after each read-back (0.2 Myr), every 480 pc patch forms stars at the Kennicutt-Schmidt rate for its
// gas (HEX_KS_A, HEX_KS_N), stochastically, one cluster complex (HEX_SF_MMIN) at a time, anywhere in the patch, except within a black
// hole's tidal reach (its pull tears clouds apart faster than they can collapse: the Roche limit). the cluster weighs exactly the gas
// taken out of the fluid there, moves as that gas moved, and from then on lives by its population's clock (scr_hex_pops_update)
function scr_hex_fluid_sinks(_fl, _W, _H, _CS) {
	var _RW = HEX_FLUID_RW, _RH = HEX_FLUID_RH, _rd = _fl.rd, _rv = _fl.rv;
	if (array_length(_rd) != _RW * _RH || array_length(_rv) != _RW * _RH * 2) return;
	var _SS = HEX_FLUID_CS * HEX_FLUID_W / _RW;                                // sky px per sample
	var _dt = 12 * scr_hex_time() / 60;                                         // Myr since the last check
	var _take = [];
	// X (debug): the gas at the mouse becomes a young giant cluster at once (half of it, 2.5 Myr old: straight into its bright years)
	if (is_array(_fl.force_sf)) {
		var _fx = _fl.force_sf;
		_fl.force_sf = undefined;
		var _xi = clamp(floor(_fx[0] / _SS + _RW / 2), 1, _RW - 2), _xj = clamp(floor(_fx[1] / _SS + _RH / 2), 1, _RH - 2);
		var _xk = scr_hex_sink_make(_fl, _xi, _xj, 0.5, 2.5, 0);
		scr_hex_toast(is_undefined(_xk) ? "X: too little gas here for a cluster (try a dense cloud, or B first)"
		                                : "X: a young cluster of " + string_format(scr_hex_pop_msun(global.hex_stars[array_length(global.hex_stars) - 1].m0) / 1000000, 1, 1) + " million suns");
		if (!is_undefined(_xk)) array_push(_take, _xk);
	}
	// suns a Myr per patch = HEX_KS_A x Sigma^1.4 x (patch area in kpc^2) x 10^6; in read-back gas units (HEX_SIGMA_UNIT x patch area in
	// pc^2 suns each) that's HEX_KS_A x Sigma^1.4 / HEX_SIGMA_UNIT per Myr
	var _rmin = HEX_SF_SIGMA_MIN / HEX_SIGMA_UNIT;
	for (var j = 1; j < _RH - 1; j++) for (var i = 1; i < _RW - 1; i++) {
		var _q = i + j * _RW, _d = _rd[_q];
		if (_d < _rmin) continue;
		var _due = HEX_KS_A * power(_d * HEX_SIGMA_UNIT, HEX_KS_N) / HEX_SIGMA_UNIT * _dt;   // the stars this patch should form now
		if (random(1) >= _due / HEX_SF_MMIN) continue;
		var _sx = (i + 0.5 - _RW / 2) * _SS, _sy = (j + 0.5 - _RH / 2) * _SS, _ok = true;
		for (var h = 0; h < array_length(global.hex_holes); h++) {
			var _ho = global.hex_holes[h];
			if (point_distance(_sx, _sy, _ho.ox, _ho.oy) < scr_hex_hole_size(_ho) * 1.5) { _ok = false; break; }   // (its real tidal reach is parsecs, far under a cell: this only keeps births off its drawn disk)
		}
		if (!_ok) continue;
		var _k = scr_hex_sink_make(_fl, i, j, 0, 0, HEX_SF_MMIN);
		if (!is_undefined(_k)) array_push(_take, _k);
	}
	if (array_length(_take) == 0) return;
	// the gas becomes the stars: taken out of the fluid right there (gas and its momentum together, so its motion is unchanged)
	gpu_set_blendenable(true);
	gpu_set_blendmode_ext(bm_zero, bm_inv_src_alpha);                          // (what's left = what was there x (1 - alpha))
	var _tgt = [_fl.da, _fl.va];
	for (var s = 0; s < 2; s++) {
		surface_set_target(_tgt[s]);
		for (var c = 0; c < array_length(_take); c++) {
			var _k = _take[c];
			var _rr = (HEX_SF_R / _CS) / 20;
			draw_sprite_ext(scr_hex_soft_alpha(), 0, _k[0] / _CS + _W / 2, _k[1] / _CS + _H / 2, _rr, _rr, 0, c_white, _k[2]);   // (a soft bell, not a square)
		}
		surface_reset_target();
	}
	gpu_set_blendenable(false);
}
// one cluster forms at read-back sample (i, j): _mass read-back units of gas (or, if _mass is 0, a share _eff of the gas around it),
// _head Myr old already (0 for a real birth). returns [x, y, share] for the gas to take out, or undefined if there's too little gas
function scr_hex_sink_make(_fl, i, j, _eff, _head, _mass) {
	var _RW = HEX_FLUID_RW, _RH = HEX_FLUID_RH, _rd = _fl.rd, _rv = _fl.rv, _SS = HEX_FLUID_CS * HEX_FLUID_W / _RW;
	// the gas it gathers: the patches around it, weighted like the soft stamp that takes them out
	var _gas = 0, _rs = HEX_SF_R / _SS;
	for (var b = -2; b <= 2; b++) for (var a = -2; a <= 2; a++) {
		var _ii = i + a, _jj = j + b;
		if (_ii < 0 || _jj < 0 || _ii >= _RW || _jj >= _RH) continue;
		_gas += _rd[_ii + _jj * _RW] * exp(-(a * a + b * b) / (2 * _rs * _rs * 0.25));
	}
	if (_mass <= 0) _mass = min(_eff * _gas, HEX_SF_MMAX);
	_mass = min(_mass, 0.5 * _gas);                                             // (never more than half the gas that's there)
	if (_mass < HEX_SF_MMIN) return undefined;
	var _m = _mass / HEX_GAS_PER_MASS;
	_eff = _mass / max(0.0001, _gas);                                           // the share of the gas there it takes
	_fl.sf_n = (variable_struct_exists(_fl, "sf_n") ? _fl.sf_n : 0) + 1;      // (the mass budget, shown in F1)
	_fl.sf_gas = (variable_struct_exists(_fl, "sf_gas") ? _fl.sf_gas : 0) + _m * HEX_GAS_PER_MASS;
	var _sx = (i + random(1) - _RW / 2) * _SS, _sy = (j + random(1) - _RH / 2) * _SS;   // (anywhere in its patch: never on a lattice)
	var _ph = random(1000), _q0 = (i + j * _RW) * 2, _M6 = scr_hex_pop_msun(_m) / 1000000;
	var _s = { ox: _sx, oy: _sy, s: 1, ph: _ph, hx: false, big: false, m: _m, age: _head,
	           pop: true, m0: _m, tb: _fl.myr - _head, rd0: _rd[i + j * _RW], ar: 0, ap: _head,
	           nm: clamp(round(2 + 2 * log10(1 + 3 * _M6)), 2, 6),                 // its brightest members, shown while they live
	           gvx: _rv[_q0] * HEX_FLUID_CS, gvy: _rv[_q0 + 1] * HEX_FLUID_CS };  // it moves as its gas was moving (ref cells/frame to px/frame)
	_s.lum = _M6;
	_s.s = clamp(0.7 + 0.9 * power(_M6, 1 / 3), 0.6, 2.4);
	_s.c0 = scr_hex_pop_color(_head, _ph);
	array_push(global.hex_stars, _s);
	if (variable_instance_exists(id, "ignitions")) array_push(ignitions, { ox: _sx, oy: _sy, t0: t, big: false, s: _s.s, merged: false, c: _s.c0, pop: true });
	return [_sx, _sy, _eff];
}

// every frame, before the sky is drawn (obj_unmaking Draw)
function scr_hex_fluid_update() {
	if (!scr_hex_fluid_ok()) return;
	if (variable_instance_exists(id, "gaze_paused") && gaze_paused) return;   // P holds the fluid still too
	var _fl = scr_hex_fluid_surfaces();
	var _sh = sh_hex_fluid, _U = scr_hex_fluid_u(_sh);
	var _sp = sh_hex_fluid_p, _UP = scr_hex_fluid_u(_sp);
	var _tr = scr_hex_fluid_tier(), _W = _tr[0], _H = _tr[1], _sub = _tr[2];
	var _CS = HEX_FLUID_CS * HEX_FLUID_W / _W;                                // this tier's real cell, in sky pixels
	_fl.t += 1;
	if (_fl.t mod 120 == 60) scr_hex_fluid_backup(_fl, _W, surface_format_is_supported(surface_rgba32float) ? surface_rgba32float : surface_rgba16float);   // (the garden's safety copy: fullscreen can wipe textures)
	scr_hex_soft_alpha();                                                      // (made once, before any drawing targets are set)
	scr_hex_alpha_stamp(1);
	var _live = (variable_instance_exists(id, "gaze") && gaze);               // (who owns the sky: see below)
	if (_live) _fl.myr += scr_hex_time() / 60;                                 // the garden's clock: 1 Myr a second at full speed
	gpu_push_state();
	gpu_set_tex_filter(true);
	gpu_set_tex_repeat(false);
	scr_hex_fluid_light(_fl);

	// 1) NEW GAS. each wisp's gas is poured in exactly once, when it settles (a fresh kill's cloud, supernova debris, a dying
	// star's shell; flying and falling gas waits until it lands), at most HEX_POUR_PER_FRAME a frame. from then on only the physics
	// moves it. and the gas the star clusters hand back is poured in where they are (scr_hex_pops_update)
	surface_set_target(_fl.da);
	gpu_set_blendenable(true);
	gpu_set_blendmode(bm_add);
	var _hz = global.hex_haze, _nh = array_length(_hz);
	if (_fl.scan >= _nh) _fl.scan = 0;
	var _end = min(_nh, _fl.scan + 2000), _spin = [], _np = 0;              // (spent wisps are skipped at once: a quick scan)
	var _wi = _fl.scan;
	for (_wi = _fl.scan; _wi < _end; _wi++) {
		var _w = _hz[_wi];
		if (_w.f <= 0.01 || _w.fl || _w.tr) continue;                           // (flying gas hasn't landed yet)
		var _cx = _w.ox / _CS + _W / 2, _cy = _w.oy / _CS + _H / 2;
		if (_cx < 0 || _cy < 0 || _cx >= _W || _cy >= _H) continue;            // (beyond the fluid's reach: not counted either)
		if (_np >= HEX_POUR_PER_FRAME) break;                                  // (the rest next frame)
		_np++;
		var _m = scr_hex_wisp_gas(_w);
		// its gas: amount ~ ink x mass, spread wider (not brighter) when there's a lot of it
		var _r = max(_w.s * 0.9, 24 * sqrt(HEX_FLUID_INK * _m)) * HEX_POUR_SOFT;   // (edit48: wider, softer stamps merge into clouds instead of shearing into rainbow dashes)
		var _A = min(1, HEX_FLUID_INK * _m * 576 / (_r * _r));
		var _rr = max(0.8, _r / _CS) / 20;                                      // spr_soft is 20px of radius per unit of scale
		var _wc = (_w.c == -1) ? make_color_rgb(70, 62, 88) : _w.c;              // (soot is dust: real mass too, poured in dim and dusty)
		var _csum = (color_get_red(_wc) + color_get_green(_wc) + color_get_blue(_wc)) / 255;
		// AS A TIDAL STREAM: HEX_POUR_PIECES clumps of uneven size strung along its orbit (same radius, a little scatter), each sheared
		// along the orbit (HEX_POUR_STRETCH) and moving at its own circular speed. the clumps' gas adds up exactly to the cloud's:
		// sum of (alpha x scale_a x scale_b) = A x rr^2
		var _wr = max(1, point_distance(0, 0, _w.ox, _w.oy)), _wa0 = point_direction(0, 0, _w.ox, _w.oy);
		var _arc = min(HEX_POUR_ARC * _r / _wr, 0.33) * 180 / pi;                // degrees of orbit it spans
		var _N = HEX_POUR_PIECES, _ws = array_create(_N, 0), _wt = 0;
		for (var k = 0; k < _N; k++) { _ws[k] = random_range(0.4, 1.6); _wt += _ws[k]; }
		for (var k = 0; k < _N; k++) {
			var _ka = _wa0 + ((k + 0.5) / _N - 0.5) * _arc + random_range(-0.15, 0.15) * _arc / _N;
			var _kr = _wr * (1 + random_range(-0.06, 0.06));
			var _kx = lengthdir_x(_kr, _ka), _ky = lengthdir_y(_kr, _ka);
			var _ks = _rr * sqrt(_ws[k] / _wt) * 1.25;                          // (a clump's size grows with its share)
			var _ka2 = _ks * sqrt(HEX_POUR_STRETCH), _kb2 = _ks / sqrt(HEX_POUR_STRETCH);
			var _kA = _A * _rr * _rr * (_ws[k] / _wt) / (_ka2 * _kb2);
			if (_kA > 1) { _ka2 *= sqrt(_kA); _kb2 *= sqrt(_kA); _kA = 1; }       // (too dense for one stamp: wider instead)
			var _kang = _ka + 90 + random_range(-HEX_POUR_TILT, HEX_POUR_TILT) * 0.5;
			draw_sprite_ext(spr_soft, 0, _kx / _CS + _W / 2, _ky / _CS + _H / 2, _ka2, _kb2, _kang, _wc, _kA);
			// it arrives orbiting the garden's center at the halo's circular speed (rising inside the core, flat outside)
			var _kv = HEX_GAL_VC * _kr / sqrt(_kr * _kr + HEX_GAL_R0 * HEX_GAL_R0), _rc = _csum * _kA;   // (its density at the stamp's peak)
			array_push(_spin, [_kx / _CS + _W / 2, _ky / _CS + _H / 2, _ka2, _rc * _kv * _ky / _kr, -_rc * _kv * _kx / _kr, _kb2, _kang]);
		}
		// RULE 1 (one owner per quantity): its gas lives only in the fluid now, so the wisp is spent (swept out within 2 s). nothing
		// that still reads wisps (old black hole feeding, the aeon's wind, merging) can touch, copy or double this gas again
		_w.f = 0;
	}
	_fl.scan = _wi;                                                            // (where it stopped: the next frame carries on)
	// gas coming home from the star clusters (and B's clouds): each amount poured in exactly. a soft stamp of color c and alpha A adds
	// (r+g+b)/255 x A x 806 x scale^2 to the cells (806: the area under spr_soft's bell, built ring by ring in obj_unmaking Create:
	// exp(-3 (r/31)^2) less its rim value, over the disk), which is that over (cells per read-back sample) in read-back units
	for (var i = 0; i < array_length(_fl.ret); i++) {
		var _r = _fl.ret[i];
		var _rx = _r[0] / _CS + _W / 2, _ry = _r[1] / _CS + _H / 2;
		if (_rx < 0 || _ry < 0 || _rx >= _W || _ry >= _H) continue;
		var _rsc = _r[3] / _CS / 20, _csum = (color_get_red(_r[4]) + color_get_green(_r[4]) + color_get_blue(_r[4])) / 255;
		var _rA = _r[2] * sqr(_W / HEX_FLUID_RW) / (_csum * 806 * _rsc * _rsc);
		if (_rA > 1) { _rsc *= sqrt(_rA); _rA = 1; }                          // (too much for one stamp: spread it wider instead)
		draw_sprite_ext(spr_soft, 0, _rx, _ry, _rsc, _rsc, 0, _r[4], _rA);
		var _rc = _csum * _rA;                                                   // its density at the stamp's peak, moving as its stars move
		array_push(_spin, [_rx, _ry, _rsc, _rc * _r[5] / HEX_FLUID_CS, _rc * _r[6] / HEX_FLUID_CS, _rsc, 0]);
	}
	_fl.ret = [];
	surface_reset_target();
	if (array_length(_spin) > 0) {                                             // its momentum: signed, so drawn through the shader, added exactly
		surface_set_target(_fl.va);
		gpu_set_blendmode_ext(bm_one, bm_one);
		shader_set(_sh);
		var _U0 = scr_hex_fluid_u(_sh);
		shader_set_uniform_f(_U0.u_mode, 12);
		var _ms = 0.000001;                                                      // the biggest momentum this pour: the scale its colors share
		for (var i = 0; i < array_length(_spin); i++) _ms = max(_ms, abs(_spin[i][3]), abs(_spin[i][4]));
		shader_set_uniform_f(_U0.u_src, _ms, 0);
		var _spa = scr_hex_soft_alpha();
		for (var i = 0; i < array_length(_spin); i++) {
			var _q = _spin[i];
			var _mc = make_color_rgb(round(127.5 + 127.5 * _q[3] / _ms), round(127.5 + 127.5 * _q[4] / _ms), 0);   // (its momentum, in its color: one batch)
			draw_sprite_ext(_spa, 0, _q[0], _q[1], _q[2], _q[5], _q[6], _mc, 1);   // (same shape as the gas it moves)
		}
		shader_reset();
		gpu_set_blendmode(bm_add);
		surface_reset_target();
	}

	// the black holes (where gas is swallowed) and the shockwaves, handed to the shader in REFERENCE cells
	var _RCS = HEX_FLUID_CS, _RW2 = HEX_FLUID_W / 2, _RH2 = HEX_FLUID_H / 2;
	var _ho = array_create(16, 0), _hn = 0;
	var _crk = variable_global_exists("hex_crunch_k") ? global.hex_crunch_k : 0;
	for (var h = 0; h < array_length(global.hex_holes) && _hn < 4; h++) {
		var _b = global.hex_holes[h];
		if (_b.age < HEX_GATHER) continue;
		_ho[_hn * 4] = _b.ox / _RCS + _RW2; _ho[_hn * 4 + 1] = _b.oy / _RCS + _RH2;
		var _crb = scr_hex_is_smbh(_b) ? _crk : 0;                               // (the crunch: the heart swallows everything, its reach growing to the whole sky)
		_ho[_hn * 4 + 2] = max(variable_struct_exists(_b, "eat") ? _b.eat : 0, 0.12 * _crb);
		_ho[_hn * 4 + 3] = HEX_BH_REACH * (1 + 30 * _crb * _crb) / _RCS;
		_hn++;
	}
	var _kk = array_create(32, 0), _kn = 0;
	for (var i = array_length(_fl.kicks) - 1; i >= 0; i--) {
		var _k = _fl.kicks[i];
		_k.age++;
		if (_k.age > 14) { array_delete(_fl.kicks, i, 1); continue; }
		if (_kn >= 8) continue;
		_kk[_kn * 4] = _k.x / _RCS + _RW2; _kk[_kn * 4 + 1] = _k.y / _RCS + _RH2;
		_kk[_kn * 4 + 2] = _k.r / _RCS; _kk[_kn * 4 + 3] = _k.s * 0.25 * (1 - _k.age / 14);
		_kn++;
	}

	gpu_set_blendenable(false);                                                // (every pass writes each cell's value exactly)
	var _tex = surface_get_texture(_fl.va);                                   // (read the real texel size: some drivers pad surfaces)
	var _tw = texture_get_texel_width(_tex), _th = texture_get_texel_height(_tex);
	var _tmp;

	// WHO OWNS THE SKY: during a cast, the cast's choreography owns the screen (its stardust, protostars and threads are scripted
	// visuals, not bodies), so her universe's clock waits: new gas is still poured in (already carrying its orbit), but nothing
	// moves. stargazing (G), the physics owns everything and it all turns together. (both moving at once was the "floating away")
	if (_live) {
		scr_hex_feedback_map(_fl);                                             // 2a) every active superbubble's pressure (step 3)
		// 2) GRAVITY, AS A REAL THIN DISK FEELS IT. a galaxy is a thin disk in 3D space, so the pull between two clouds falls off as
		// 1 / distance^2 (softened by the disk's thickness). (it used to be solved on a flat sheet, 2D Poisson, where pull falls off only
		// as 1 / distance: distant gas pulled far too hard and every run gathered into one central mass. offline: grav_compare.png.)
		// the potential at every gravity cell is summed straight from the mass, phi = -sum m / sqrt(d^2 + h^2), the way tree codes do it
		// (Barnes & Hut 1986): nearby mass cell by cell, farther mass from coarser and coarser averages (5 levels; tested offline against
		// the exact sum: ~1% error in the force). nothing wraps around at the edges: space outside the garden is empty
		shader_set(_sh);
		scr_hex_fluid_common(_U, _tw, _th, _W, _H, _fl.t / 60, _ho, _kk);
		shader_set_uniform_f(_U.u_diss, _W / HEX_GRAV_W / 4);                    // (taps spread over each gravity cell)
		shader_set_uniform_f(_U.u_src, 0, 1);                                    // (all of the mass: an isolated galaxy, nothing taken away)
		shader_set_uniform_f(_U.u_mode, 8);
		surface_set_target(_fl.gr);
		draw_surface_stretched(_fl.da, 0, 0, HEX_GRAV_W, HEX_GRAV_H);             // (the gas, averaged onto the gravity grid)
		surface_reset_target();
		shader_reset();
		// stars and black holes weigh what the gas they formed from weighed (HEX_GAS_PER_MASS a unit of their mass; one read-back sample is
		// 4 gravity cells), stamped as a soft bell holding exactly that mass (spr_soft's bell holds 806 x scale^2 cells at alpha 1)
		surface_set_target(_fl.gr);
		gpu_set_blendenable(true); gpu_set_blendmode(bm_add);
		var _GS = HEX_FLUID_CS * HEX_FLUID_W / HEX_GRAV_W;
		var _per = HEX_GRAV_STAR * 4 * HEX_GAS_PER_MASS;
		if (_per > 0) {
			var _bodies = [global.hex_stars, global.hex_holes];
			for (var b = 0; b < 2; b++) {
				var _st = _bodies[b];
				for (var i = 0; i < array_length(_st); i++) {
					var _s = _st[i];
					if (!is_struct(_s)) continue;
					var _gx = _s.ox / _GS + HEX_GRAV_W / 2, _gy = _s.oy / _GS + HEX_GRAV_H / 2;
					if (_gx < 0 || _gy < 0 || _gx >= HEX_GRAV_W || _gy >= HEX_GRAV_H) continue;
					var _gm = _s.m * _per;                                           // its mass, in gravity-grid units
					var _gsc = 0.075 * sqrt(max(1, _gm / 4.53));                     // (a 2.4-cell bell; wider for heavy bodies, never above 1)
					draw_sprite_ext(spr_soft, 0, _gx, _gy, _gsc, _gsc, 0, c_white, min(1, _gm / (806 * _gsc * _gsc)));
				}
			}
		}
		surface_reset_target();
		gpu_set_blendenable(false);
		// the mass pyramid: each level is the one below averaged 2 x 2 (exact, by the card's filtering), then all 5 laid side by side
		var _gsrc = _fl.gr;
		for (var i = 0; i < 4; i++) {
			surface_set_target(_fl.gpy[i]);
			draw_surface_stretched(_gsrc, 0, 0, HEX_GRAV_W >> (i + 1), HEX_GRAV_H >> (i + 1));
			surface_reset_target();
			_gsrc = _fl.gpy[i];
		}
		surface_set_target(_fl.gat);
		draw_clear_alpha(c_black, 0);
		draw_surface(_fl.gr, 0, 0);
		var _gax = HEX_GRAV_W;
		for (var i = 0; i < 4; i++) { draw_surface(_fl.gpy[i], _gax, 0); _gax += HEX_GRAV_W >> (i + 1); }
		surface_reset_target();
		var _gtx = surface_get_texture(_fl.gr), _gtw = texture_get_texel_width(_gtx), _gth = texture_get_texel_height(_gtx);
		var _gat = surface_get_texture(_fl.gat);
		shader_set(_sp);
		scr_hex_fluid_common(_UP, texture_get_texel_width(_gat), texture_get_texel_height(_gat), HEX_GRAV_W, HEX_GRAV_H, _fl.t / 60, _ho, _kk);
		shader_set_uniform_f(_UP.u_mode, 5);
		shader_set_uniform_f(_UP.u_gn, HEX_GRAV_W);
		shader_set_uniform_f(_UP.u_geps, HEX_DISK_H / (_GS * HEX_PC_PER_PX));   // the disk's thickness, in gravity cells
		gpu_set_tex_filter(false);                                                 // (each cell read exactly)
		surface_set_target(_fl.gpa);
		draw_surface_part(_fl.gat, 0, 0, HEX_GRAV_W, HEX_GRAV_H, 0, 0);
		surface_reset_target();
		gpu_set_tex_filter(true);
		// the potential read back a few times a second, so stars and black holes feel the same pull as the gas (scr_hex_orbits)
		if (_fl.t mod 12 == 6) {
			buffer_get_surface(_fl.gbuf, _fl.gpa, 0);
			var _gn = HEX_GRAV_W * HEX_GRAV_H, _g32 = (buffer_get_size(_fl.gbuf) == _gn * 16);   // (32-bit floats, or 16-bit on cards without them)
			if (array_length(_fl.phi) != _gn) _fl.phi = array_create(_gn, 0);
			var _ph = _fl.phi, _gb = _fl.gbuf;
			if (_g32) for (var q = 0; q < _gn; q++) _ph[q] = buffer_peek(_gb, q * 16, buffer_f32);
			else      for (var q = 0; q < _gn; q++) _ph[q] = buffer_peek(_gb, q * 8, buffer_f16);
		}

		// 3) THE GAS: compressible, self-gravitating, mass-conserving (sh_hex_fluid_p). a few substeps a frame on the finer tiers,
		// so no signal ever crosses more than about half a cell per step (the Courant condition, what keeps it stable)
		scr_hex_fluid_common(_UP, _tw, _th, _W, _H, _fl.t / 60, _ho, _kk);
		shader_set_uniform_f(_UP.u_dt, scr_hex_time() / _sub);                    // (the clock: half speed steps half as far)
		shader_set_uniform_f(_UP.u_keep, 1);
		shader_set_uniform_f(_UP.u_kick, HEX_KICK);
		shader_set_uniform_f(_UP.u_grav, HEX_GRAV);
		shader_set_uniform_f(_UP.u_cs, HEX_GAS_CS);
		// (the Jeans floor's pressure per unit density for a reference cell: N x G x SIGMA x 80 pc, in reference cells^2 / frame^2)
		shader_set_uniform_f(_UP.u_jeans, HEX_JEANS * 0.004301 * HEX_SIGMA_UNIT * HEX_PC_PER_PX * HEX_FLUID_CS * sqr(scr_hex_kms(1)));
		shader_set_uniform_f(_UP.u_halo, HEX_GAL_VC * (1 + 3 * sqr(_crk)), HEX_GAL_R0 / HEX_FLUID_CS);   // (the crunch: gravity strengthens as everything packs together)
		shader_set_uniform_f(_UP.u_cshot, HEX_ION_CS);
		var _ltx2 = surface_get_texture(_fl.lt);
		texture_set_stage(_UP.s_light, _ltx2);
		shader_set_uniform_f(_UP.u_lightmax, HEX_LIGHT_W * texture_get_texel_width(_ltx2), HEX_LIGHT_H * texture_get_texel_height(_ltx2));
		shader_set_uniform_f(_UP.u_phimax, HEX_GRAV_W * _gtw, HEX_GRAV_H * _gth);
		shader_set_uniform_f(_UP.u_phitexel, _gtw, _gth);
		texture_set_stage(_UP.s_phi, surface_get_texture(_fl.gpa));
		var _fbt = surface_get_texture(_fl.fb);                                   // the superbubbles' pressure (its slope pushes the gas)
		texture_set_stage(_UP.s_fb, _fbt);
		shader_set_uniform_f(_UP.u_fbmax, HEX_FB_W * texture_get_texel_width(_fbt), HEX_FB_H * texture_get_texel_height(_fbt));
		shader_set_uniform_f(_UP.u_fbtexel, texture_get_texel_width(_fbt), texture_get_texel_height(_fbt));
		shader_set_uniform_f(_UP.u_fbscale, _fl.fbscale);
		repeat (_sub) {                                                            // each substep: two Runge-Kutta stages (SSP-RK2)
			shader_set_uniform_f(_UP.u_stage, 0);                                  // stage 1: a trial step from the start (da, va) into (db, vb)
			texture_set_stage(_UP.s_gas, surface_get_texture(_fl.da));
			texture_set_stage(_UP.s_vel, surface_get_texture(_fl.va));
			scr_hex_fluid_pass(_UP, 10, _fl.da, _fl.db);                          // the gas: in minus out
			scr_hex_fluid_pass(_UP, 11, _fl.va, _fl.vb);                          // its momentum: in minus out, plus pressure, gravity, shocks
			shader_set_uniform_f(_UP.u_stage, 1);                                  // stage 2: step again from the trial, average with the start
			texture_set_stage(_UP.s_gas, surface_get_texture(_fl.db));
			texture_set_stage(_UP.s_vel, surface_get_texture(_fl.vb));
			texture_set_stage(_UP.s_gas0, surface_get_texture(_fl.da));
			texture_set_stage(_UP.s_vel0, surface_get_texture(_fl.va));
			scr_hex_fluid_pass(_UP, 10, _fl.db, _fl.dc);
			scr_hex_fluid_pass(_UP, 11, _fl.vb, _fl.vc);
			_tmp = _fl.da; _fl.da = _fl.dc; _fl.dc = _tmp;
			_tmp = _fl.va; _fl.va = _fl.vc; _fl.vc = _tmp;
		}
	}
	// 4) every 12 frames: a small copy read back: the gas's velocity (so the wisps ride the same currents) and its density (so the
	// game can find the dense clouds, and check the fluid's total gas against the ledger)
	if (_fl.t mod 12 == 0) {                                                    // (the read-back stalls on the graphics card, so not too often)
		var _RW = HEX_FLUID_RW, _RH = HEX_FLUID_RH;
		shader_set(_sh);
		scr_hex_fluid_common(_U, _tw, _th, _W, _H, _fl.t / 60, _ho, _kk);
		surface_set_target(_fl.rs);
		shader_set_uniform_f(_U.u_mode, 3);
		shader_set_uniform_f(_U.u_diss, _W / _RW / 4);                         // (velocity: mass-weighted over each sample's patch, 4 x 4 taps)
		texture_set_stage(_U.s_vel, surface_get_texture(_fl.da));
		draw_surface_stretched(_fl.va, 0, 0, _RW, _RH);                       // (velocity = momentum / density)
		shader_set_uniform_f(_U.u_mode, 7);
		shader_set_uniform_f(_U.u_diss, _W / _RW / 4);                         // (density: averaged over each sample's patch, 4 x 4 taps)
		draw_surface_stretched(_fl.da, _RW, 0, _RW, _RH);
		surface_reset_target();
		shader_reset();
		buffer_get_surface(_fl.rbuf, _fl.rs, 0);
		var _n = _RW * _RH;
		if (array_length(_fl.rv) != _n * 2) _fl.rv = array_create(_n * 2, 0);
		if (array_length(_fl.rd) != _n) _fl.rd = array_create(_n, 0);
		var _rv = _fl.rv, _rd = _fl.rd, _bf = _fl.rbuf, _F = 0;
		for (var j = 0; j < _RH; j++) for (var i = 0; i < _RW; i++) {
			var _q = j * _RW + i, _b = (j * _RW * 2 + i) * 4;
			_rv[_q * 2]     = (buffer_peek(_bf, _b, buffer_u8) / 255 - 0.5) * 0.6;   // x was written to red AND blue, y to green: byte order can't fool it
			_rv[_q * 2 + 1] = (buffer_peek(_bf, _b + 1, buffer_u8) / 255 - 0.5) * 0.6;   // (+-0.3 ref cells/frame: ~11 km/s steps)
			var _db = min(0.996, sqr(buffer_peek(_bf, _b + _RW * 4 + 1, buffer_u8) / 255));   // density, stored as sqrt(d / (1 + d))
			_rd[_q] = _db / (1 - _db);
			_F += _rd[_q];
		}
		_fl.F = _F;
		// the gas's size: its mass-weighted mean distance from the center, in kpc (F1). steady = the garden holds; falling = collapsing
		var _rs = 0;
		for (var j = 0; j < _RH; j++) for (var i = 0; i < _RW; i++) _rs += _rd[j * _RW + i] * point_distance(i + 0.5 - _RW / 2, j + 0.5 - _RH / 2, 0, 0);
		_fl.rgas = (_F > 0.001) ? _rs / _F * HEX_SAMPLE_PC / 1000 : 0;
		// BLACK HOLES FEED ON THE GAS (HEX_SEED_MSUN block): the shader took each hole's rate (eat) of the gas over its heart every frame.
		// measured here from the read-back: it grows by 90% of that (10% left as light), then its rate for the next 12 frames is set
		// from the gas over it now: Bondi, capped at Eddington
		if (_live) for (var h = 0; h < array_length(global.hex_holes); h++) {
			var _ho = global.hex_holes[h];
			if (_ho.age < HEX_GATHER || !variable_struct_exists(_ho, "eat")) continue;
			var _hs = HEX_BH_REACH, _SS = HEX_FLUID_CS * HEX_FLUID_W / _RW, _U = HEX_SIGMA_UNIT * HEX_SAMPLE_PC * HEX_SAMPLE_PC;
			var _gi = clamp(floor(_ho.ox / _SS + _RW / 2), 0, _RW - 1), _gj = clamp(floor(_ho.oy / _SS + _RH / 2), 0, _RH - 1);
			var _rho = _rd[_gi + _gj * _RW], _hg = max(0.000001, _rho * min(1, pi * sqr(0.7 * _hs) / sqr(_SS)));   // gas over its heart
			var _ate = _hg * (1 - power(1 - _ho.eat, 12 * scr_hex_time()));
			_ho.m += (1 - HEX_RAD_EFF) * _ate / HEX_GAS_PER_MASS;
			_fl.bh_gas = (variable_struct_exists(_fl, "bh_gas") ? _fl.bh_gas : 0) + _ate;   // (the fluid can be made before the run reset adds this)
			var _M = scr_hex_pop_msun(_ho.m), _rv = _rho * HEX_SIGMA_UNIT / (2 * HEX_DISK_H);                // suns; suns per cubic pc
			var _bondi = HEX_BONDI_BOOST * 4 * pi * sqr(0.004301 * _M) * _rv / power(HEX_GAS_CS_KMS, 3) * 1.0227;   // suns per Myr
			var _edd = _M / HEX_EDD_T;
			_ho.eat = min(HEX_EAT_MAX, min(_bondi, _edd) / _U / 60 / _hg);       // (per frame at full speed: 1/60 Myr)
			_ho.mdot = _ho.eat * _hg * 60 * _U;
			_ho.edd = _ho.mdot / _edd;
			_ho.mdsm += (_ho.mdot - _ho.mdsm) * (1 - exp(-0.2 * scr_hex_time() / 5));   // (5 Myr average: what the quasar test reads)
			_ho.agn_t = (_ho.edd > 0.01) ? _ho.agn_t + 0.2 * scr_hex_time() : 0;   // how long it's been shining (its bubble's age)
			_ho.rho = _rho;
			_ho.feed = max(_ho.feed, 100 * sqrt(_ho.edd));                        // its disk and jets blaze with its feeding (decays in Step)
		}
		// THE UNIVERSE'S BOOKS (HEX_UNI_T block): everything in her sky (gas, clusters, what the holes ate) against the last read-back.
		// what the reservoir sent in is expected; anything more is new matter (her casts, B's clouds), anything less left her sky
		// and returns to the reservoir. then the reservoir rains its share in, and the lifetime is worked out from the total
		if (_live && variable_global_exists("hex_cosmo") && variable_struct_exists(_fl, "F") && global.hex_aeon.phase != "crunch" && global.hex_aeon.phase != "void") {
			var _cs = global.hex_cosmo;
			var _G = _fl.F + (variable_struct_exists(_fl, "sf_gas") ? _fl.sf_gas : 0) - (variable_struct_exists(_fl, "ret_gas") ? _fl.ret_gas : 0)
			       + (variable_struct_exists(_fl, "bh_gas") ? _fl.bh_gas : 0);
			var _ex = _G - _cs.G - _cs.pend;
			if (_ex > 0) _cs.B += _ex; else _cs.R = min(_cs.B, _cs.R - _ex);
			_cs.G = _G; _cs.pend = 0;
			var _I = min(_cs.R * (1 - exp(-0.2 * scr_hex_time() / HEX_INFLOW_T)), HEX_INFLOW_MAX * 0.2 * scr_hex_time());
			if (_I > 0.001) { scr_hex_inflow(_fl, _cs, _I); _cs.R -= _I; _cs.pend = _I; }
			_cs.T = scr_hex_uni_life(_cs.B);
			var _sfd = (variable_struct_exists(_fl, "sf_gas") ? _fl.sf_gas : 0) - _cs.sf0;   // star formation over the last 0.2 Myr...
			_cs.sf0 += _sfd;
			_cs.sfr += (_sfd / max(0.01, 0.2 * scr_hex_time()) - _cs.sfr) * (1 - exp(-0.2 * scr_hex_time() / 50));   // ...averaged over 50 Myr
			_cs.sfpk = max(_cs.sfpk, _cs.sfr);
		}
		if (_live) {
			scr_hex_fluid_sinks(_fl, _W, _H, _CS);                                // star clusters born from the gas itself
			scr_hex_pops_update(_fl);                                              // ...and living out their lives (step 3)
		}
	} else shader_reset();
	gpu_pop_state();
}
// drawn into her sky (obj_unmaking Draw, after the wisps): the fluid gas, stretched over the sky, turning with it, through the
// detail pass (filaments and torn edges)
function scr_hex_fluid_draw(_px, _py, _sky_angle, _alpha) {
	if (!scr_hex_fluid_ok() || !variable_global_exists("hex_fluid") || !surface_exists(global.hex_fluid.da)) return;
	if (variable_global_exists("hex_fluid_hide") && global.hex_fluid_hide) return;   // (diagnostic L: hidden, still simulated)
	var _sh = sh_hex_fluid, _U = scr_hex_fluid_u(_sh);
	var _W = surface_get_width(global.hex_fluid.da), _H = surface_get_height(global.hex_fluid.da);
	var _CS = HEX_FLUID_CS * HEX_FLUID_W / _W;
	var _cx = -_W / 2 * _CS, _cy = -_H / 2 * _CS;                             // the grid's top-left corner, in sky pixels
	var _cl = point_distance(0, 0, _cx, _cy), _ca = point_direction(0, 0, _cx, _cy) + _sky_angle;
	var _fl = global.hex_fluid;
	gpu_set_tex_filter(true);
	shader_set(_sh);
	var _tex = surface_get_texture(global.hex_fluid.da);
	var _tw = texture_get_texel_width(_tex), _th = texture_get_texel_height(_tex);
	shader_set_uniform_f(_U.u_texel, _tw, _th);
	shader_set_uniform_f(_U.u_uvmax, _W * _tw, _H * _th);
	shader_set_uniform_f(_U.u_size, HEX_FLUID_W, HEX_FLUID_H);
	shader_set_uniform_f(_U.u_k, _W / HEX_FLUID_W);
	shader_set_uniform_f(_U.u_time, global.hex_fluid.t / 60);
	shader_set_uniform_f(_U.u_mode, 2);
	shader_set_uniform_f(_U.u_diss, HEX_FLUID_GAIN * _alpha);
	var _ltx = (variable_struct_exists(_fl, "lt") && surface_exists(_fl.lt)) ? surface_get_texture(_fl.lt) : -1;
	if (_ltx != -1) {
		texture_set_stage(_U.s_light, _ltx);
		shader_set_uniform_f(_U.u_lightmax, HEX_LIGHT_W * texture_get_texel_width(_ltx), HEX_LIGHT_H * texture_get_texel_height(_ltx));
	}
	var _qs = variable_struct_exists(_fl, "qsum") ? _fl.qsum : 0;
	shader_set_uniform_f(_U.u_amb, HEX_FLUID_AMB0 + HEX_FLUID_AMB1 * (1 - exp(-_qs / HEX_FLUID_AMBQ)));
	shader_set_uniform_f(_U.u_ion, HEX_FLUID_ION);
	shader_set_uniform_f(_U.u_refl, HEX_FLUID_REFL);
	shader_set_uniform_f(_U.u_dust, HEX_FLUID_DUST * _alpha);
	shader_set_uniform_f(_U.u_tint, HEX_GAS_TINT);
	// HER SPELL'S LIGHT: while she casts, the Unmaking itself lights the gas it makes, in its own colors (the stardust's glow), and the
	// light fades over a few seconds once the cast is over, so the garden's own starlight takes over smoothly instead of the gas
	// suddenly dimming. drawing only: it never touches the physics
	if (!variable_global_exists("hex_spell")) global.hex_spell = 0;
	var _casting = instance_exists(obj_unmaking) && !obj_unmaking.gaze;
	global.hex_spell = _casting ? min(1, global.hex_spell + 0.05) : global.hex_spell * 0.985;
	shader_set_uniform_f(_U.u_spell, global.hex_spell * HEX_SPELL_GLOW);
	var _dx = _px + lengthdir_x(_cl, _ca), _dy = _py + lengthdir_y(_cl, _ca);
	shader_set_uniform_f(_U.u_mode, 1);                                        // first its dust: what's behind, times what gets through (per color)
	gpu_set_blendmode_ext(bm_zero, bm_src_color);
	draw_surface_ext(global.hex_fluid.da, _dx, _dy, _CS, _CS, _sky_angle, c_white, 1);
	shader_set_uniform_f(_U.u_mode, 2);                                        // then the light it gives off and scatters, added
	gpu_set_blendmode_ext(bm_one, bm_one);
	draw_surface_ext(global.hex_fluid.da, _dx, _dy, _CS, _CS, _sky_angle, c_white, 1);
	shader_reset();
	gpu_set_blendmode(bm_add);                                                 // (what the sky drawing after this expects, as before)
	gpu_set_tex_filter(false);
}

