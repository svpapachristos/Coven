if (!instance_exists(obj_player)) exit;
if (clean_pending) exit; // the clean frame: draw nothing, so Draw GUI can photograph the bare world
var _fps = game_get_speed(gamespeed_fps);
var _drained = (t >= glitch_at + floor(glitch_len * 0.6)); // the world drains on the glitch's white frame
var _tear = 1; // the shatter does the opening now: the sky is fully there from the start, hidden behind the frozen world
var _close = _fps * 0.3;

var _cam = view_camera[0];
var _vx = camera_get_view_x(_cam), _vy = camera_get_view_y(_cam);
var _vw = camera_get_view_width(_cam), _vh = camera_get_view_height(_cam);
var _px = obj_player.x, _py = obj_player.y;
var _diag = point_distance(0, 0, _vw, _vh);
var _S = _diag * 1.1; // her sky is a square this wide, centred on her, big enough to cover the screen however it's turned

var _open = 1;
if (t < _tear) _open = t / _tear;
else if (t > duration - _close) _open = (duration - t) / _close;
_open = clamp(_open, 0, 1);
var _ease = 1 - sqr(1 - _open);
var _r = _diag * _ease;
var _neb = power(_ease, 3);

// ---- 1) the tear: near-black space swallowing the world, spreading from her ----
draw_set_alpha(1);
draw_set_color(make_color_rgb(4, 3, 10));
draw_primitive_begin(pr_trianglefan);
draw_vertex(_px, _py);
for (var j = 0; j <= 64; j++) {
	var _ang = j / 64 * 360;
	var _rr = _r * (1 + 0.05 * sin(j * 2.3 + current_time / 60));
	draw_vertex(_px + lengthdir_x(_rr, _ang), _py + lengthdir_y(_rr, _ang));
}
draw_primitive_end();

gpu_push_state();
gpu_set_blendmode(bm_add);

// ---- 2) her nebula, centred on her and turning with the sky ----
if (sprite_exists(nebula)) {
	gpu_set_tex_filter(true);
	var _sc = _S / sprite_get_width(nebula);
	var _bl = _sc * 0.7; // how far each copy is nudged: about two-thirds of one nebula pixel
	// drawn five times, each nudged a little and at a fifth of the strength. in additive mode the five copies add
	// back up to full brightness, but the blocky edges between the nebula's pixels smear into smooth gradients
	for (var q = 0; q < 5; q++) {
		var _qx = (q == 0) ? 0 : lengthdir_x(_bl, q * 90 + 45);
		var _qy = (q == 0) ? 0 : lengthdir_y(_bl, q * 90 + 45);
		draw_sprite_ext(nebula, 0, _px + _qx, _py + _qy, _sc, _sc, sky_angle, c_white, _neb / 5);
	}
	gpu_set_tex_filter(false);
}

// ---- 4) the deep field: baked at the cast, turning slowest. two halves twinkle out of step ----
var _far = sky_angle * 0.5;
draw_sprite_ext(dust[0], 0, _px, _py, 1, 1, _far, c_white, (0.75 + 0.25 * sin(current_time / 700)) * _neb);
draw_sprite_ext(dust[1], 0, _px, _py, 1, 1, _far, c_white, (0.75 + 0.25 * sin(current_time / 700 + pi)) * _neb);

// ---- 5) scattered stars: a middle layer of small glowing stars in every colour, turning a little faster ----
var _mid = sky_angle * 0.75;
for (var m = 0; m < 140; m++) {
	var _ox = (scr_hash(m * 11.3 + 7) - 0.5) * _S, _oy = (scr_hash(m * 17.9 + 3) - 0.5) * _S;
	var _l = point_distance(0, 0, _ox, _oy);
	if (_l > _r) continue;
	var _a = point_direction(0, 0, _ox, _oy) + _mid;
	var _mx = _px + lengthdir_x(_l, _a), _my = _py + lengthdir_y(_l, _a);
	if (!point_in_rectangle(_mx, _my, _vx - 10, _vy - 10, _vx + _vw + 10, _vy + _vh + 10)) continue;
	var _pk = scr_hash(m * 2.7);
	var _mc = (_pk < 0.5) ? c_white : ((_pk < 0.75) ? make_color_rgb(200, 215, 255)
		: ((_pk < 0.9) ? make_color_rgb(230, 195, 255) : make_color_rgb(255, 220, 170)));
	var _ms = 0.8 + scr_hash(m * 6.1) * 1.4;
	var _tw = 0.6 + 0.4 * sin(current_time / (250 + (m mod 5) * 120) + m * 3);
	draw_sprite_ext(spr_glow, 0, _mx, _my, _ms * 3 / 15, _ms * 3 / 15, 0, _mc, 0.25 * _tw);  // soft glow
	draw_sprite_ext(spr_dot,  0, _mx, _my, _ms * 0.6 / 15, _ms * 0.6 / 15, 0, _mc, _tw);    // the star
}


// ---- 6) a handful of brilliant stars with long spikes, nearest of the backdrop ----
var _near = sky_angle * 0.9;
for (var h = 0; h < 16; h++) {
	var _ox = (scr_hash(h * 13.7 + 2) - 0.5) * _S, _oy = (scr_hash(h * 29.1 + 5) - 0.5) * _S;
	var _l = point_distance(0, 0, _ox, _oy);
	if (_l > _r) continue;
	var _a = point_direction(0, 0, _ox, _oy) + _near;
	var _hc = (h mod 3 == 0) ? make_color_rgb(170, 200, 255) : ((h mod 3 == 1) ? make_color_rgb(255, 190, 240) : c_white);
	scr_draw_star_flare(_px + lengthdir_x(_l, _a), _py + lengthdir_y(_l, _a), 3 + scr_hash(h * 3.3) * 3, _hc,
		(0.75 + 0.25 * sin(current_time / 400 + h * 2)) * _neb);
}

// ---- 7) her sky: one star for every enemy she has unmade this run ----
var _stars = global.hex_stars;
var _n = array_length(_stars);
// the finale: a wave runs outward through ONLY this cast's newborn stars, so they pop as the new arrivals
var _wave_len = _fps * 1.1;
var _wave_on  = (pulse_t >= 0 && pulse_t < _wave_len);
var _wave_r   = _wave_on ? _diag * 0.8 * (pulse_t / _wave_len) : -9999;
for (var i = max(0, _n - 800); i < _n; i++) {
	var _st = _stars[i];
	var _l = point_distance(0, 0, _st.ox, _st.oy);
	if (_l > _r) continue;
	var _a = point_direction(0, 0, _st.ox, _st.oy) + sky_angle;
	var _sx = _px + lengthdir_x(_l, _a), _sy = _py + lengthdir_y(_l, _a);

	// colour first, since the wave glow below needs it
	var _sc = scr_hex_star_colour(_st.ph);
	var _tw = 0.8 + 0.2 * sin(current_time / (300 + (i mod 7) * 90) + _st.ph); // a gentle twinkle that never goes dark
	var _wb = 0;
	if (_wave_on && i >= new_from) {
		var _band = _wave_r - _l;                                   // how far the wavefront has passed this star
		if (_band > 0 && _band < 80) _wb = sin(_band / 80 * pi);    // rises to 1 mid-band and back to 0, no hard edges
	}
	_tw = min(1, _tw + _wb);
	var _ss = _st.s * (1 + 1.5 * _wb); // only newborns swell now, so they can swell harder without whiting out the sky
		if (_wb > 0) draw_sprite_ext(spr_glow, 0, _sx, _sy, _ss * 7 / 15, _ss * 7 / 15, 0, _sc, 0.6 * _wb);

	if (_st.s > 2.5 || _wb > 0.6) {   // newborns briefly flare with spikes at the crest of the wave
		scr_draw_star_flare(_sx, _sy, _ss, _sc, _tw);
	} else {
		var _core = max(1.2, _ss * 0.8); // never smaller than a crisp pixel, or it vanishes once its flare ends
		draw_sprite_ext(spr_glow, 0, _sx, _sy, _ss * 3 / 15, _ss * 3 / 15, 0, _sc, 0.5 * _tw);                    // soft glow
		draw_sprite_ext(spr_dot,  0, _sx, _sy, _core / 15, _core / 15, 0, merge_color(_sc, c_white, 0.5), _tw); // white-hot core
	}
}
// ---- 7b) her black holes, turning with her stars ----
var _holes = global.hex_holes;
// while a star gathers itself to collapse, the rest of her sky dims, as if its light is being drawn in
var _dim = 0;
for (var h = 0; h < array_length(_holes); h++) {
	var _ho = _holes[h];
	if (_ho.age < HEX_GATHER) _dim = max(_dim, sqr(_ho.age / HEX_GATHER));
}
if (_dim > 0) {
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(0.7 * _dim);
	draw_set_color(c_black);
	draw_rectangle(_vx, _vy, _vx + _vw, _vy + _vh, false);
	gpu_set_blendmode(bm_add);
}
for (var h = 0; h < array_length(_holes); h++) {
	var _ho = _holes[h];
	var _hl = point_distance(0, 0, _ho.ox, _ho.oy);
	if (_hl > _r) continue;
	var _ha = point_direction(0, 0, _ho.ox, _ho.oy) + sky_angle;
	var _hx = _px + lengthdir_x(_hl, _ha), _hy = _py + lengthdir_y(_hl, _ha);
	if (_ho.age <= HEX_GATHER) { impact_x = _hx; impact_y = _hy; } // remember where the impact frame centres
	scr_hex_draw_hole(_ho, _hx, _hy, spr_glow);
}

// ---- 7c) the entrance: time locks, her hex draws itself beneath her, reality glitches, everything holds its breath,
// then a crack runs in from the right, forks behind her, and the world breaks into chunks that drift away ----
if (t < shatter_at + slab_len && surface_exists(snap)) {
	var _wsc = snap_sc;
	var _saw = surface_get_width(snap), _sah = surface_get_height(snap);
	var _m   = 64; // a margin around the snapshot, so a shake can't show past its edge
	if (!surface_exists(world_surf)) world_surf = surface_create(_saw + _m * 2, _sah + _m * 2); // surfaces can vanish (alt-tab)
	var _whx = (crack_cx - snap_x) * _wsc + _m, _why = (crack_cy - snap_y) * _wsc + _m; // her, in the surface's pixels
	var _wox = snap_x - _m / _wsc, _woy = snap_y - _m / _wsc;                            // the surface's corner, in the room

	// the frozen world: drained to violet-grey, falling away into shadow
	surface_set_target(world_surf);
	draw_clear_alpha(c_black, 0);
	gpu_set_blendmode(bm_normal);
	shader_set(sh_timestop);
	shader_set_uniform_f(u_ts_center, _whx, _why);
	shader_set_uniform_f(u_ts_desat, _drained ? 0.6 : 0);   // full colour until the glitch's white frame
	shader_set_uniform_f(u_ts_tint, 0.95, 0.8, 1.15);   // and lean the rest harder toward her violet
	shader_set_uniform_f(u_ts_dark, _drained ? 0.375 : 0);
	shader_set_uniform_f(u_ts_solid, 1);
	draw_surface_ext(snap, 0, 0, (_saw + _m * 2) / _saw, (_sah + _m * 2) / _sah, 0, c_white, 1); // stretched copy fills the margin
	draw_surface_ext(snap, _m, _m, 1, 1, 0, c_white, 1);                                          // the real photo on top
	shader_reset();
	surface_reset_target();
	if (t < tear_at) draw_surface_ext(world_surf, _wox, _woy, 1 / _wsc, 1 / _wsc, 0, c_white, 1); // one piece, until it breaks

	// ---- the tear and the break: the crack runs in from the right edge, the ground gapes along it,
	// then breaks into three huge chunks that drift off, revealing her universe beneath ----
	var _reach = 1 - sqr(1 - clamp((t - tear_at) / tear_len, 0, 1));   // how far the crack has run, 0 to 1
	var _front = tear_n - _reach * tear_n;                             // the column its tip has reached
	var _u     = clamp((t - shatter_at) / slab_len, 0, 1);             // how far through the break, 0 to 1
	if (t >= tear_at) {
		var _tex = surface_get_texture(world_surf);
		var _tuv = texture_get_uvs(_tex);
		var _sw2 = surface_get_width(world_surf), _sh2 = surface_get_height(world_surf);
		var _dirs = [[0, -1], [0, 1], [-1, 0]];                         // which way each chunk parts from the crack
		
		// light from below: her cosmos shines up through the crack as it opens, brightest the moment the ground breaks,
		// then fades as the chunks drift off. drawn BEFORE the chunks, so the ground covers it and it only shows in the gap
		var _gape  = clamp((t - tear_at) / (tear_len + gape_len), 0, 1);   // how far the crack has gaped, 0 to 1
		var _shine = _gape * (1 - _u);
		var _opn   = 48 * min(1, _u * 8);                                   // the ground holds together until the impact, then rips open                            // how far each side has pulled back from the crack
		if (_shine > 0) {
			gpu_set_blendmode(bm_add);
			var _gcol = make_color_rgb(150, 70, 255);
			for (var i = 0; i < tear_n; i++) {
				if (i + 1 < _front) continue;                                  // the crack hasn't reached here yet
				for (var k = 0; k < 4; k++) {                                  // four stamps per column: one smooth strip, not beads
					var _f  = k / 4;
					var _gx = lerp(tear_x[i], tear_x[i + 1], _f);
					var _ya = lerp(chunks[0].lo[i], chunks[0].lo[i + 1], _f) + _opn * 0.6;   // just below the upper cliff, in the open gap
					var _yb = lerp(chunks[1].up[i], chunks[1].up[i + 1], _f) + _opn * 0.6;
					var _fl = 0.85 + 0.15 * sin(current_time / 90 + i * 1.7 + k);    // a slow shimmer, never quite steady
					draw_sprite_ext(spr_glow, 0, _gx, _ya, 2.2, 1.6, 0, _gcol, 0.35 * _shine * _fl);
					if (_yb - _ya > 4) draw_sprite_ext(spr_glow, 0, _gx, _yb, 2.2, 1.6, 0, _gcol, 0.35 * _shine * _fl); // the second branch, behind the fork
				}
			}
			gpu_set_blendmode(bm_normal);                                      // the chunks draw normally, on top of it
		}
		
		var _order = [0, 2, 1];                                            // top to bottom: each chunk's ground covers the cliff of the one above it
		for (var _o = 0; _o < 3; _o++) {
			var s = _order[_o];
			var _ch  = chunks[s];
			var _g   = 1 + _ch.grow * _u * _u;                           // lifting toward us
			var _ang = _ch.spin * _u * _u;
			var _cr  = dcos(_ang), _sr = dsin(_ang);
  			var _mv  = 0.08 * min(1, _u * 8) + 0.92 * power(_u, 2.2);     // a sharp pop as it breaks, then it accelerates away
  			var _mvx = _ch.vx * _mv, _mvy = _ch.vy * _mv;
			var _al  = 1 - clamp((_u - 0.75) / 0.25, 0, 1);
			var _th   = 800                    // bottomless while it gapes, then a towering cliff of earth once it breaks free
			                                                                  // then a thick slab of earth once it breaks free
  			var _fall = 0.6 * _u * _u;                                     // sinks into her dark as it drifts away
			var _gd  = _dirs[s];
			if (_al <= 0) continue;

			// where each of its points is now, and where that point was in the frozen world (for its texture)
			var _qx = [], _qy = [], _qu = [], _qv = [];
			for (var r = 0; r <= tear_rows; r++) {
				var _rx = [], _ry = [], _ru = [], _rv = [];
				for (var i = _ch.i0; i <= _ch.i1; i++) {
					var _px0 = tear_x[i], _py0 = lerp(_ch.up[i], _ch.lo[i], r / tear_rows);
					var _op  = clamp(i - _front + 1, 0, 1) * _opn;        // once the crack has reached this column, it gapes
					var _dx  = (_px0 - _ch.cx) * _g, _dy = (_py0 - _ch.cy) * _g;
					array_push(_rx, _ch.cx + _dx * _cr + _dy * _sr + _mvx + _gd[0] * _op);
					array_push(_ry, _ch.cy - _dx * _sr + _dy * _cr + _mvy + _gd[1] * _op);
					array_push(_ru, lerp(_tuv[0], _tuv[2], (_m + scr_mirror01((_px0 - snap_x) / snap_w) * _saw) / _sw2)); // past the photo's edge, the ground mirrors back
					array_push(_rv, lerp(_tuv[1], _tuv[3], (_m + scr_mirror01((_py0 - snap_y) / snap_h) * _sah) / _sh2));
				}
				array_push(_qx, _rx); array_push(_qy, _ry); array_push(_qu, _ru); array_push(_qv, _rv);
			}
			var _nc = _ch.i1 - _ch.i0;

						// its cliff first: a wall of earth hanging from its bottom edge (the only side we can see from up here).
			// one strip of bands, so its ends are clean straight edges instead of a staircase of stacked copies
			var _nb = 12;                                                     // bands of strata down the wall
			var _er = tear_rows;                                              // its bottom row: the edge the wall hangs from
			for (var i = 0; i < _nc; i++) {
				draw_primitive_begin(pr_trianglelist);                       // a fresh batch per column: one batch only holds about 1000 vertices
				// once it breaks free the underside tears ragged: each column hangs a little deeper or shallower
				var _ja  = 1 + 0.12 * (sin((_ch.i0 + i) * 0.35 + s * 2.3) + 0.5 * sin((_ch.i0 + i) * 0.9 + s));      // broad, gentle lumps:
				var _jb  = 1 + 0.12 * (sin((_ch.i0 + i + 1) * 0.35 + s * 2.3) + 0.5 * sin((_ch.i0 + i + 1) * 0.9 + s));  // torn rock, not teeth
				var _wxa = _qx[_er][i],     _wya = _qy[_er][i];
				var _wxb = _qx[_er][i + 1], _wyb = _qy[_er][i + 1];
				for (var b = 0; b < _nb; b++) {
					var _dd = (b + 0.5) / _nb;                                // 0 at the lip, 1 at the very bottom
					var _wc = merge_color(make_color_rgb(96, 74, 70), make_color_rgb(70, 62, 84), min(1, _dd * 2)); // warm earth, then cooler stone
					_wc = merge_color(_wc, make_color_rgb(14, 10, 24), sqr(_dd));                           // fading into the dark of the chasm
					if (b mod 2 == 1) _wc = merge_color(_wc, c_white, 0.06);                               // faint strata stripes
					_wc = merge_color(_wc, make_color_rgb(130, 80, 220), 0.5 * power(_dd, 4));             // only the bottom catches her light
					_wc = merge_color(_wc, make_color_rgb(10, 6, 20), _fall);                              // falling away into her dark
					// this band's top and bottom, at this column (a) and the next (b). the lines between bands wobble a little
					var _ta = (b == 0) ? 0 : b / _nb * _th + sin((_ch.i0 + i) * 0.9 + b * 1.3) * 3;
					var _tb = (b == 0) ? 0 : b / _nb * _th + sin((_ch.i0 + i + 1) * 0.9 + b * 1.3) * 3;
					var _ba = (b + 1) / _nb * _th + ((b == _nb - 1) ? 0 : sin((_ch.i0 + i) * 0.9 + (b + 1) * 1.3) * 3);
					var _bb = (b + 1) / _nb * _th + ((b == _nb - 1) ? 0 : sin((_ch.i0 + i + 1) * 0.9 + (b + 1) * 1.3) * 3);
					draw_vertex_color(_wxa, _wya + _ta * _ja, _wc, _al);
					draw_vertex_color(_wxb, _wyb + _tb * _jb, _wc, _al);
					draw_vertex_color(_wxb, _wyb + _bb * _jb, _wc, _al);
					draw_vertex_color(_wxa, _wya + _ta * _ja, _wc, _al);
					draw_vertex_color(_wxb, _wyb + _bb * _jb, _wc, _al);
					draw_vertex_color(_wxa, _wya + _ba * _ja, _wc, _al);
				}
				draw_primitive_end();                                        // close this column's batch
			}



			// then the ground itself on top
			var _top = merge_color(c_white, make_color_rgb(10, 6, 20), _fall);
			for (var r = 0; r < tear_rows; r++) {
				draw_primitive_begin_texture(pr_trianglelist, _tex);   // a fresh batch per row: the wider ground is too many vertices for one
				for (var i = 0; i < _nc; i++) {
					// one cell of the grid is two triangles
					draw_vertex_texture_color(_qx[r][i],         _qy[r][i],         _qu[r][i],         _qv[r][i],         _top, _al);
					draw_vertex_texture_color(_qx[r][i + 1],     _qy[r][i + 1],     _qu[r][i + 1],     _qv[r][i + 1],     _top, _al);
					draw_vertex_texture_color(_qx[r + 1][i + 1], _qy[r + 1][i + 1], _qu[r + 1][i + 1], _qv[r + 1][i + 1], _top, _al);
					draw_vertex_texture_color(_qx[r][i],         _qy[r][i],         _qu[r][i],         _qv[r][i],         _top, _al);
					draw_vertex_texture_color(_qx[r + 1][i + 1], _qy[r + 1][i + 1], _qu[r + 1][i + 1], _qv[r + 1][i + 1], _top, _al);
					draw_vertex_texture_color(_qx[r + 1][i],     _qy[r + 1][i],     _qu[r + 1][i],     _qv[r + 1][i],     _top, _al);
				}
				draw_primitive_end();
			}
			// the broken edge catches her light: a pale rim along it, wherever the crack has run
			draw_set_color(make_color_rgb(205, 190, 225));
			draw_set_alpha(0.7 * _al * (1 - _fall));                          // the rim loses her light as it falls
			for (var _e = 0; _e < 2; _e++) {
				if ((_e == 0 && !_ch.cu) || (_e == 1 && !_ch.cl)) continue;   // only the edges that are cracks
				var _er = (_e == 0) ? 0 : tear_rows;                          // its top row or its bottom row
				for (var i = 0; i < _nc; i++) {
					if (_ch.i0 + i + 1 < _front) continue;
					draw_line_width(_qx[_er][i], _qy[_er][i], _qx[_er][i + 1], _qy[_er][i + 1], 2);
				}
			}
		}

		// rubble: big lumps of rock flung out of the crack as the ground breaks, tumbling off into her cosmos
		if (_u > 0) {
			var _rp  = 0.35 * min(1, _u * 6) + 0.65 * _u;                         // a burst as it breaks, then a steady drift
			var _ral = 1 - clamp((_u - 0.6) / 0.4, 0, 1);                         // gone before the stardust begins
			for (var k = 0; k < array_length(rocks); k++) {
				var _rk  = rocks[k];
				var _rkx = _rk.px + _rk.vx * _rp, _rky = _rk.py + _rk.vy * _rp;
				var _ra  = _rk.rot + _rk.spin * _u;
				draw_primitive_begin(pr_trianglefan);
				draw_vertex_color(_rkx, _rky, make_color_rgb(48, 40, 62), _ral);
				for (var c = 0; c <= 7; c++) {
					var _ca  = _ra + c * 360 / 7;
					var _cr2 = _rk.r * (0.7 + 0.3 * scr_hash(_rk.seed + (c mod 7) * 1.7));      // uneven corners: a rough lump, not a disc
					var _cc  = merge_color(make_color_rgb(70, 58, 78), make_color_rgb(140, 90, 230), 0.6 * max(0, -dsin(_ca))); // faces turned down catch her light
					draw_vertex_color(_rkx + lengthdir_x(_cr2, _ca), _rky + lengthdir_y(_cr2, _ca), _cc, _ral);
				}
				draw_primitive_end();
			}
		}

		// the light: it floods into the crack as it runs and builds through the gape, like something about to burst.
		// then the impact frame (Step), then it blasts out as the ground explodes apart
		var _chg = clamp((t - tear_at) / (tear_len + gape_len), 0, 1);           // the build, 0 to 1, up to the break
		var _bf  = (t - shatter_at) / (game_get_speed(gamespeed_fps) * 0.45);   // the blast, 0 to 1, after it
		var _lk  = 0;                                                            // how strong the light is right now
		if (t >= tear_at && t < shatter_at) _lk = 0.6 + 0.4 * sqr(_chg);         // the streak blazes as it runs, then builds to the impact
		else if (_bf >= 0 && _bf < 1) _lk = sqr(1 - _bf);
		if (_lk > 0) {
			var _blast = (t >= shatter_at);
			gpu_set_blendmode(bm_add);
			draw_set_alpha(_lk);
			// a soft violet glow along the crack, and one unbroken white-hot line down its middle
			for (var i = 0; i < tear_n; i++) {
				if (i + 1 < _front) continue;                                        // only where the crack has run
				var _bya = chunks[0].lo[i], _byb = chunks[1].up[i];
				var _bnx = tear_x[i + 1], _bna = chunks[0].lo[i + 1], _bnb = chunks[1].up[i + 1];
				var _gh  = 2 + (_blast ? 4 * _bf : 0);                               // the glow balloons outward in the blast
				draw_sprite_ext(spr_glow, 0, tear_x[i], _bya, 4, _gh, 0, make_color_rgb(190, 140, 255), 0.35 * _lk);
				draw_line_width_color(tear_x[i], _bya, _bnx, _bna, 3, c_white, c_white);
				if (_byb - _bya > 4) {                                               // the second branch, behind the fork
					draw_sprite_ext(spr_glow, 0, tear_x[i], _byb, 4, _gh, 0, make_color_rgb(190, 140, 255), 0.35 * _lk);
					draw_line_width_color(tear_x[i], _byb, _bnx, _bnb, 3, c_white, c_white);
				}
			}
			
			// the streak's head: a blazing point racing along the crack as it runs
			if (t < tear_at + tear_len) {
				var _hc = clamp(floor(_front), 0, tear_n);
				draw_sprite_ext(spr_glow, 0, tear_x[_hc], chunks[0].lo[_hc], 5, 5, 0, c_white, 0.9);
				if (chunks[1].up[_hc] - chunks[0].lo[_hc] > 4) draw_sprite_ext(spr_glow, 0, tear_x[_hc], chunks[1].up[_hc], 5, 5, 0, c_white, 0.9); // both branches past the fork
			}
			
			// the rays: short and flickering while the pressure builds, then full and shooting outward in the blast
			for (var q = 0; q < 36; q++) {
				var _ci = floor(scr_hash(q * 7.1 + 3) * tear_n);                     // which column it bursts from
				if (_ci + 1 < _front) continue;                                      // not until the crack reaches it
				var _cf   = scr_hash(q * 2.9 + 1);
				var _up   = (q mod 2 == 0);                                          // half spear up the screen, half down
				var _rbx  = lerp(tear_x[_ci], tear_x[_ci + 1], _cf);
				var _rby  = _up ? lerp(chunks[0].lo[_ci], chunks[0].lo[_ci + 1], _cf) : lerp(chunks[1].up[_ci], chunks[1].up[_ci + 1], _cf);
				var _rang = (_up ? 90 : 270) + (scr_hash(q * 5.3) - 0.5) * 50;       // roughly straight out, never quite
				var _rlen = (80 + 260 * scr_hash(q * 3.7))
				          * (_blast ? 0.6 + 0.6 * _bf : (0.1 + 0.4 * sqr(_chg)) * (0.7 + 0.3 * sin(current_time / 40 + q * 2)));
				var _rw   = 4 + 10 * scr_hash(q * 1.3);                              // half-width at the crack
				var _tx   = _rbx + lengthdir_x(_rlen, _rang), _ty = _rby + lengthdir_y(_rlen, _rang);
				var _wx   = lengthdir_x(_rw, _rang + 90), _wy = lengthdir_y(_rw, _rang + 90);
				draw_set_color(make_color_rgb(170, 110, 255));                       // its violet body
				draw_set_alpha(0.8 * _lk);
				draw_triangle(_rbx + _wx, _rby + _wy, _rbx - _wx, _rby - _wy, _tx, _ty, false);
				draw_set_color(c_white);                                             // its white-hot core, thinner and shorter
				draw_set_alpha(_lk);
				draw_triangle(_rbx + _wx * 0.35, _rby + _wy * 0.35, _rbx - _wx * 0.35, _rby - _wy * 0.35,
				              _rbx + lengthdir_x(_rlen * 0.75, _rang), _rby + lengthdir_y(_rlen * 0.75, _rang), false);
			}
			draw_set_alpha(1);
			gpu_set_blendmode(bm_normal);
		}

		// pebbles knocked loose, rising and tumbling slowly: a dark body with a lit face
		for (var p = 0; p < array_length(grit); p++) {
			var _gr = grit[p];
			if (_gr.i < _front) continue;
			var _gt  = t - tear_at;
			var _grx = _gr.px + _gr.vx * _gt, _gry = _gr.py + _gr.vy * _gt;
			var _ga  = _gr.rot + _gr.spin * _gt;
			var _ps  = _gr.s;
			// four uneven corners, so each pebble is a rough lump rather than a neat square
			var _ax = _grx + lengthdir_x(_ps, _ga),             _ay = _gry + lengthdir_y(_ps, _ga);
			var _bx = _grx + lengthdir_x(_ps * 0.8, _ga + 80),  _by = _gry + lengthdir_y(_ps * 0.8, _ga + 80);
			var _cx = _grx + lengthdir_x(_ps, _ga + 190),       _cy = _gry + lengthdir_y(_ps, _ga + 190);
			var _dx = _grx + lengthdir_x(_ps * 0.7, _ga + 265), _dy = _gry + lengthdir_y(_ps * 0.7, _ga + 265);
			draw_set_alpha(1 - _u);
			draw_set_color(make_color_rgb(55, 45, 65));
			draw_triangle(_ax, _ay, _bx, _by, _cx, _cy, false);
			draw_triangle(_ax, _ay, _cx, _cy, _dx, _dy, false);
			draw_set_color(make_color_rgb(150, 138, 170));                   // the face catching her light
			draw_triangle(_ax, _ay, _bx, _by, _grx, _gry, false);
		}
		draw_set_alpha(1);
	}
	// until the world falls away, the doomed stand frozen in it, drained grey like everything else.
	// (they were left out of the photograph, so they stay behind when the ground drifts off)
	if (t < birth_at) {
		gpu_set_blendmode(bm_normal);
		shader_set(sh_timestop);
		shader_set_uniform_f(u_ts_center, crack_cx, crack_cy);
		shader_set_uniform_f(u_ts_desat, 0);    // her ingredients keep their colour: they're coming with her
		shader_set_uniform_f(u_ts_tint, 1, 1, 1);
		shader_set_uniform_f(u_ts_dark, 0);
		shader_set_uniform_f(u_ts_solid, 0);
		with (obj_enemy_parent) {          // sprite enemies go through the grey shader
			if (unmaking <= 0 || sprite_index < 0) continue;
				draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, image_blend, 1);
	}
		shader_reset();
		// toads are drawn with plain shapes, which the shader can't see, so they drain their own colours (obj_toad Draw)
		with (obj_enemy_parent) {
			if (unmaking <= 0 || sprite_index >= 0) continue;
				var _keep = unmaking;          // they fade by how far they're unmade, so hold them solid while they stand frozen
			unmaking = 0.001;
			event_perform(ev_draw, 0);
			unmaking = _keep;
		}
		gpu_set_blendmode(bm_add);
	}
	var _glitch = (t >= glitch_at && t < still_at);
	var _tick   = t div 2; // the glitch changes its mind every 2 frames
	gpu_set_blendmode(bm_add);

	// her hex: a sigil drawing itself on the ground at her feet, squashed flat so it lies on the floor.
	// it turns slowly, stutters with the glitch, stops dead in the stillness, blazes as the world breaks, then fades
	var _hp  = clamp((t - still_at) / (still_len * 0.75), 0, 1); // draws itself over the first 3/4 of the stillness
	var _hxc = crack_cx, _hyc = crack_cy + 8;
	var _hr  = 110;
	var _rot = min(t, tear_at) * 0.4;                              // turns while it draws, stops dead when the crack hits
	var _hal = (_glitch && scr_hash(_tick * 4.7) < 0.3) ? 0.3 : 1;
	if (t >= tear_at) _hal = ((t - tear_at < 3) ? 2 : 1) * max(0, 1 - (t - tear_at) / (tear_len + gape_len));
	if (t >= shatter_at) _hal = 0;
	for (var _pass = 0; _pass < 2; _pass++) {
		draw_set_color((_pass == 0) ? HEX_VIOLET : make_color_rgb(235, 215, 255));
		draw_set_alpha(((_pass == 0) ? 0.35 : 1) * _hal);
		var _lw = (_pass == 0) ? 7 : 2;
		for (var _ring = 0; _ring < 2; _ring++) {
			var _rr  = (_ring == 0) ? _hr : _hr * 0.78;
			var _dir = (_ring == 0) ? 1 : -1;
			var _rp  = clamp((_hp - _ring * 0.15) / 0.5, 0, 1);
			for (var q = 0; q < 48 * _rp; q++) {
				var _a1 = _rot * _dir + q / 48 * 360 * _dir, _a2 = _rot * _dir + (q + 1) / 48 * 360 * _dir;
				draw_line_width(_hxc + lengthdir_x(_rr, _a1), _hyc + lengthdir_y(_rr, _a1) * 0.5,
				                _hxc + lengthdir_x(_rr, _a2), _hyc + lengthdir_y(_rr, _a2) * 0.5, _lw);
			}
		}
		for (var k = 0; k < 6; k++) {
			var _lp = clamp((_hp - 0.4 - k * 0.07) / 0.15, 0, 1);
			if (_lp <= 0) continue;
			var _s1 = _rot + 90 + k * 60, _s2 = _s1 + 120;
			var _x1 = _hxc + lengthdir_x(_hr * 0.78, _s1), _y1 = _hyc + lengthdir_y(_hr * 0.78, _s1) * 0.5;
			var _x2 = _hxc + lengthdir_x(_hr * 0.78, _s2), _y2 = _hyc + lengthdir_y(_hr * 0.78, _s2) * 0.5;
			draw_line_width(_x1, _y1, lerp(_x1, _x2, _lp), lerp(_y1, _y2, _lp), _lw);
		}
		if (_hp > 0.85) for (var k = 0; k < 12; k++) {
			var _ta = _rot + k * 30 + 15;
			draw_line_width(_hxc + lengthdir_x(_hr * 0.82, _ta), _hyc + lengthdir_y(_hr * 0.82, _ta) * 0.5,
			                _hxc + lengthdir_x(_hr * 0.96, _ta), _hyc + lengthdir_y(_hr * 0.96, _ta) * 0.5, _lw);
		}
	}

		// the glitch: rectangular bars slashing diagonally across the screen, each a window onto her nebula behind the
	// world. solid and saturated like Diavolo's, mottled by the sky behind, with a shine along the top. the nebula is
	// mapped by SCREEN position, so every bar shows part of the same sky, sliding slowly (the parallax)
	if (_glitch && scr_hash(_tick * 6.6) > 0.2) {
		var _ntex  = sprite_get_texture(nebula, 0);
		var _nuv   = sprite_get_uvs(nebula, 0);
		var _drift = (t - glitch_at) / glitch_len * 0.15;
		gpu_set_tex_filter(true);                                               // smooth the nebula, not blocky pixels
		for (var g = 0; g < 8; g++) {
			var _gx = _vx + scr_hash(_tick * 1.3 + g * 5.9) * _vw;
			var _gy = _vy + scr_hash(_tick * 2.9 + g * 8.1) * _vh;
			var _gl = 300 + scr_hash(_tick * 4.1 + g * 2.6) * 900;               // length: shorter, so they read as blocks
			var _gw = 20 + power(scr_hash(_tick * 7.3 + g * 6.2), 2) * 70;       // thickness: no hairlines
			var _gc = (g mod 3 == 0) ? make_color_rgb(140, 18, 55) : ((g mod 3 == 1) ? make_color_rgb(95, 30, 160) : make_color_rgb(165, 30, 95));
			var _ex = lengthdir_x(_gl / 2, 15), _ey = lengthdir_y(_gl / 2, 15);
			var _wx = lengthdir_x(_gw / 2, 105), _wy2 = lengthdir_y(_gw / 2, 105);
			var _cx4 = [_gx - _ex - _wx, _gx + _ex - _wx, _gx - _ex + _wx, _gx + _ex + _wx];   // top-left, top-right, bottom-left, bottom-right
			var _cy4 = [_gy - _ey - _wy2, _gy + _ey - _wy2, _gy - _ey + _wy2, _gy + _ey + _wy2];
			// 1) its body: solid and saturated, drawn normally so it covers the world instead of washing over it
			gpu_set_blendmode(bm_normal);
			draw_primitive_begin(pr_trianglestrip);
			for (var c = 0; c < 4; c++) draw_vertex_color(_cx4[c], _cy4[c], _gc, 0.85);
			draw_primitive_end();
			// 2) her nebula through it, at two depths: big soft clouds, plus a finer mirrored layer sliding the other way.
			// two sizes of cloud on top of each other read as detail. each layer is dim, so together they're no brighter
			gpu_set_blendmode(bm_add);
			for (var _d = 0; _d < 2; _d++) {
				draw_primitive_begin_texture(pr_trianglestrip, _ntex);
				for (var c = 0; c < 4; c++) {
					var _nx = (_cx4[c] - _vx) / _vw, _ny = (_cy4[c] - _vy) / _vh;   // where this corner is on screen, 0 to 1
					var _su = (_d == 0) ? 0.1 + _nx * 0.6 + _drift : 0.95 - _nx * 0.85 - _drift * 0.5;
					var _sv = (_d == 0) ? 0.1 + _ny * 0.6          : 0.95 - _ny * 0.85;
					_su = clamp(_su, 0, 1); _sv = clamp(_sv, 0, 1);
					draw_vertex_texture_color(_cx4[c], _cy4[c], lerp(_nuv[0], _nuv[2], _su), lerp(_nuv[1], _nuv[3], _sv),
						_gc, (_d == 0) ? 0.4 : 0.3);
				}
				draw_primitive_end();
			}
			// 3) the shine: a lighter band along its top third
			var _bx = _wx * 0.7, _by = _wy2 * 0.7;
			var _sc2 = merge_color(_gc, c_white, 0.3);
			draw_primitive_begin(pr_trianglestrip);
			draw_vertex_color(_cx4[0], _cy4[0], _sc2, 0.2);
			draw_vertex_color(_cx4[1], _cy4[1], _sc2, 0.2);
			draw_vertex_color(_cx4[0] + _bx, _cy4[0] + _by, _sc2, 0);
			draw_vertex_color(_cx4[1] + _bx, _cy4[1] + _by, _sc2, 0);
			draw_primitive_end();
			// 4) a crisp cut: a dark hairline along both long edges, and a thin cyan sliver split off one of them,
			// like a colour channel slipping out of line
			gpu_set_blendmode(bm_normal);
			draw_set_alpha(0.7);
			draw_set_color(merge_color(_gc, c_black, 0.65));
			draw_line_width(_cx4[0], _cy4[0], _cx4[1], _cy4[1], 2);
			draw_line_width(_cx4[2], _cy4[2], _cx4[3], _cy4[3], 2);
			gpu_set_blendmode(bm_add);
			draw_set_alpha(0.35);
			draw_set_color(make_color_rgb(40, 160, 200));
			var _cox = lengthdir_x(3, 105), _coy = lengthdir_y(3, 105);
			draw_line_width(_cx4[2] + _cox, _cy4[2] + _coy, _cx4[3] + _cox, _cy4[3] + _coy, 1);
			// 5) pinprick stars caught in it: tiny, sharp points. lots of detail, almost no added light
			for (var k = 0; k < 6; k++) {
				var _along = (scr_hash(_tick * 3.3 + g * 9.1 + k * 1.7) - 0.5) * _gl * 0.9;   // along the bar
				var _acr   = (scr_hash(_tick * 5.1 + g * 2.2 + k * 4.3) - 0.5) * _gw * 0.8;   // across it
				draw_sprite_ext(spr_dot, 0, _gx + lengthdir_x(_along, 15) + lengthdir_x(_acr, 105),
				                _gy + lengthdir_y(_along, 15) + lengthdir_y(_acr, 105), 0.08, 0.08, 0, c_white, 0.8);
			}
			draw_set_alpha(1);
		}
		gpu_set_tex_filter(false);
		gpu_set_blendmode(bm_add);
	}
	
	// the glitch's peak: one near-white frame
	if (t == glitch_at + floor(glitch_len * 0.6)) {
		draw_set_alpha(0.85);
		draw_set_color(make_color_rgb(250, 220, 255));
		draw_rectangle(_vx, _vy, _vx + _vw, _vy + _vh, false);
	}
	draw_set_alpha(1);
}


var _lite  = make_color_rgb(200, 150, 255);
var _seize = clamp((t - birth_at) / seize_len, 0, 1); // the horde is seized the moment the world breaks
var _fill  = 1;

// ---- stages 1 and 2: starlight rises through each body from its feet, making it a window onto her cosmos,
// then the whole window is pulled headfirst into a streak that pours into its star ----
gpu_set_blendmode(bm_normal); // normal, not additive: additive would make the dark cosmos see-through
shader_set(sh_starlit);
shader_set_uniform_f(u_sl_fill, _fill);
shader_set_uniform_f(u_sl_time, current_time / 1000);
shader_set_uniform_f(u_sl_rim, colour_get_red(_lite) / 255, colour_get_green(_lite) / 255, colour_get_blue(_lite) / 255);
with (obj_enemy_parent) {
	if (unmaking <= 0 || sprite_index < 0) continue;
	if (other.t < other.birth_at) continue; // until the world tears, the frozen copy in the snapshot IS this enemy
	if (point_distance(_px, _py, x, y) > _r) continue;
	var _travel = clamp((other.t - other.seize_end) / max(1, unmake_at - other.seize_end), 0, 1);

	// where this frame sits on its texture page, so the shader can tell feet from head and find edges
	var _uv  = sprite_get_uvs(sprite_index, image_index);
	var _tex = sprite_get_texture(sprite_index, image_index);
	shader_set_uniform_f(other.u_sl_uvs, _uv[0], _uv[1], _uv[2], _uv[3]);
	shader_set_uniform_f(other.u_sl_texel, texture_get_texel_width(_tex), texture_get_texel_height(_tex));

	// its four corners standing still. GameMaker trims empty space off sprites on the texture page,
	// and _uv[4..7] say how much, so the corners hug the part that actually gets drawn.
	// a flipped sprite has a negative xscale, which flips these corners too
	var _lx = x + (_uv[4] - sprite_get_xoffset(sprite_index)) * image_xscale;   // the asset's own origin, unscaled:
	var _ty = y + (_uv[5] - sprite_get_yoffset(sprite_index)) * image_yscale;   // sprite_xoffset already has the scale baked in
	var _rx = _lx + sprite_get_width(sprite_index) * _uv[6] * image_xscale;
	var _by = _ty + sprite_get_height(sprite_index) * _uv[7] * image_yscale;
	if (_travel <= 0) {   // standing still: drawn exactly the way the frozen grey one was, so nothing jumps
		draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, c_white, 1);
		continue;
	}

	// where its star is right now, as the sky turns
	var _cx = (_lx + _rx) / 2, _cy = (_ty + _by) / 2;
	var _sl = point_distance(0, 0, star_ox, star_oy);
	var _sa = point_direction(0, 0, star_ox, star_oy) + other.sky_angle;
	var _gx = _px + lengthdir_x(_sl, _sa), _gy = _py + lengthdir_y(_sl, _sa);
	var _dir = point_direction(_cx, _cy, _gx, _gy);

	// head races ahead, feet lag behind: the body stretches out, then both arrive together
	var _uh = clamp(_travel / 0.8, 0, 1);
	var _ut = clamp((_travel - 0.2) / 0.8, 0, 1);
	_uh = _uh * _uh * (3 - 2 * _uh);
	_ut = _ut * _ut * (3 - 2 * _ut);
	var _hh = abs(_by - _ty) / 2;
	var _ax = lengthdir_x(_hh, _dir), _ay = lengthdir_y(_hh, _dir);
	var _hx = lerp(_cx + _ax, _gx, _uh), _hy = lerp(_cy + _ay, _gy, _uh); // head
	var _fx = lerp(_cx - _ax, _gx, _ut), _fy = lerp(_cy - _ay, _gy, _ut); // feet
	var _half = abs(_rx - _lx) / 2 * (1 - _ut) * sign(image_xscale);    // narrows to a thread as it arrives
	var _wx = lengthdir_x(_half, _dir + 90), _wy = lengthdir_y(_half, _dir + 90);

	// over the first quarter of the trip it turns from standing upright to facing its star, so nothing snaps
	var _k = clamp(_travel / 0.25, 0, 1);
	_k = _k * _k * (3 - 2 * _k);
	draw_sprite_pos(sprite_index, image_index,
		lerp(_lx, _hx + _wx, _k), lerp(_ty, _hy + _wy, _k),   // top-left
		lerp(_rx, _hx - _wx, _k), lerp(_ty, _hy - _wy, _k),   // top-right
		lerp(_rx, _fx - _wx, _k), lerp(_by, _fy - _wy, _k),   // bottom-right
		lerp(_lx, _fx + _wx, _k), lerp(_by, _fy + _wy, _k),   // bottom-left
		1);
}
shader_reset();

// toads draw themselves (no sprite for the shader), so they keep a simpler path:
// the body fades as an orb of light gathers, then the orb flies to its star with a tail
with (obj_enemy_parent) {
	if (other.t < other.birth_at) continue;          // until the world breaks, the frozen copy in the snapshot IS this enemy
	if (unmaking <= 0 || sprite_index >= 0) continue;  // only the sprite-less ones (toads)
	if (point_distance(_px, _py, x, y) > _r) continue;
	var _travel = clamp((other.t - other.seize_end) / max(1, unmake_at - other.seize_end), 0, 1);
	gpu_set_blendmode(bm_add);
	var _cx = (bbox_left + bbox_right) / 2, _cy = (bbox_top + bbox_bottom) / 2;
	var _sl = point_distance(0, 0, star_ox, star_oy);
	var _sa = point_direction(0, 0, star_ox, star_oy) +  other.sky_angle;
	var _gx = _px + lengthdir_x(_sl, _sa), _gy = _py + lengthdir_y(_sl, _sa);
	var _uh = _travel * _travel * (3 - 2 * _travel);
	var _ut = max(0, _uh - 0.15);
	var _hx = lerp(_cx, _gx, _uh), _hy = lerp(_cy, _gy, _uh);
	draw_set_alpha(0.7 * _seize);
	draw_circle_color(_hx, _hy, 16 * (1 - 0.75 * _uh), merge_color(_lite, c_white, 0.4), c_black, false);
	if (_travel > 0) draw_line_width_color(lerp(_cx, _gx, _ut), lerp(_cy, _gy, _ut), _hx, _hy, 2, c_black, c_white);
}
gpu_set_blendmode(bm_add);

// ---- stage 3, ignition: the motes meet and a star blooms, flaring big and bright before settling to its size ----
var _il = 18;
for (var i = array_length(ignitions) - 1; i >= 0; i--) {
	var _ig = ignitions[i];
	var _age = t - _ig.t0;
	if (_age > _il) { array_delete(ignitions, i, 1); continue; }
	var _k = _age / _il;
	var _ke = 1 - power(1 - _k, 3); // fast at first, then easing gently into place
	var _gl = point_distance(0, 0, _ig.ox, _ig.oy);
	var _ga = point_direction(0, 0, _ig.ox, _ig.oy) + sky_angle;
	var _gx = _px + lengthdir_x(_gl, _ga), _gy = _py + lengthdir_y(_gl, _ga);
	var _rest = variable_struct_exists(_ig, "s") ? _ig.s : 1.5;
	scr_draw_star_flare(_gx, _gy, _rest * lerp(_ig.big ? 6 : (_ig.merged ? 2.5 : 4), 1, _ke),
	variable_struct_exists(_ig, "c") ? _ig.c : c_white, 1 - _k * 0.6);
}

// ----- 8) the glowing edge of the tear while it's opening or closing ----
if (_open < 1) {
	draw_set_color(HEX_VIOLET);
	draw_set_alpha(0.9);
	draw_primitive_begin(pr_linestrip);
	for (var j = 0; j <= 64; j++) {
		var _ang = j / 64 * 360; 
		var _rr = _r * (1 + 0.05 * sin(j * 2.3 + current_time / 60));
		draw_vertex(_px + lengthdir_x(_rr, _ang), _py + lengthdir_y(_rr, _ang));
	}
	draw_primitive_end();
}

gpu_pop_state();
// her outline, drawn additively so it glows against the dark
gpu_set_blendmode(bm_add);

var _pulse = 0.7 + 0.3 * sin(current_time / 250) + ((pulse_t >= 0 && pulse_t < _fps * 0.6) ? 1 - pulse_t / (_fps * 0.6) : 0);
scr_draw_glow_outline(obj_player, HEX_VIOLET, 2, 0.55 * _pulse);
scr_draw_glow_outline(obj_player, make_color_rgb(230, 200, 255), 1, 0.5 * _pulse);
scr_draw_glow_outline(obj_familiar_controller, HEX_VIOLET, 1, 0.4 * _pulse);
gpu_set_blendmode(bm_normal);

with (obj_player) event_perform(ev_draw, 0);
with (obj_familiar_controller) if (sprite_index != -1) draw_self();

// ---- the impact frame: time stops and the moment is burned into the screen,
// first in negative (white world, black ink), then in positive (black world, white ink) ----
if (hitstop > 0) {
	var _neg = (hitstop > ((impact_kind == 1) ? 3 : 6));   // first half negative, second half positive
	var _ink = _neg ? c_black : c_white;
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	draw_set_color(_neg ? c_white : c_black);
	draw_rectangle(_vx, _vy, _vx + _vw, _vy + _vh, false);
	draw_set_color(_ink);
	if (impact_kind == 0) {
	// a starburst of tapered spikes: thick at the hole, needle-sharp at the tips, a new set every frame
	for (var k = 0; k < 14; k++) {
		var _ra = scr_hash(k * 5.1 + hitstop * 13.7) * 360;
		var _rl = 120 + scr_hash(k * 2.3 + hitstop) * _diag;
		var _rw = 3 + 16 * scr_hash(k * 9.7 + hitstop);                   // half-width at the base
		draw_triangle(impact_x + lengthdir_x(_rw, _ra + 90), impact_y + lengthdir_y(_rw, _ra + 90),
		              impact_x + lengthdir_x(_rw, _ra - 90), impact_y + lengthdir_y(_rw, _ra - 90),
		              impact_x + lengthdir_x(_rl, _ra),      impact_y + lengthdir_y(_rl, _ra), false);
	}
	// the hole at its true size: a solid disc in the negative frames, a hard ring racing out in the positive ones
	var _R = scr_hex_hole_radius(HEX_COLLAPSE_MASS);
	if (_neg) draw_circle(impact_x, impact_y, _R, false);
	else for (var w = 0; w < 3; w++) draw_circle(impact_x, impact_y, _R + (6 - hitstop) * 16 + w, true);
		} else {
		// the ground's impact frame: the crack and its rays burned into the screen
		for (var i = 0; i < tear_n; i++) {
			draw_line_width(tear_x[i], chunks[0].lo[i], tear_x[i + 1], chunks[0].lo[i + 1], 6);
			if (chunks[1].up[i] - chunks[0].lo[i] > 4) draw_line_width(tear_x[i], chunks[1].up[i], tear_x[i + 1], chunks[1].up[i + 1], 6);
		}
		for (var q = 0; q < 36; q++) {
			var _hci  = floor(scr_hash(q * 7.1 + 3) * tear_n);
			var _hcf  = scr_hash(q * 2.9 + 1);
			var _hup  = (q mod 2 == 0);
			var _hbx  = lerp(tear_x[_hci], tear_x[_hci + 1], _hcf);
			var _hby  = _hup ? lerp(chunks[0].lo[_hci], chunks[0].lo[_hci + 1], _hcf) : lerp(chunks[1].up[_hci], chunks[1].up[_hci + 1], _hcf);
			var _hang = (_hup ? 90 : 270) + (scr_hash(q * 5.3) - 0.5) * 50;
			var _hlen = 80 + 260 * scr_hash(q * 3.7);
			var _hw   = 4 + 10 * scr_hash(q * 1.3);
			draw_triangle(_hbx + lengthdir_x(_hw, _hang + 90), _hby + lengthdir_y(_hw, _hang + 90),
			              _hbx - lengthdir_x(_hw, _hang + 90), _hby - lengthdir_y(_hw, _hang + 90),
			              _hbx + lengthdir_x(_hlen, _hang), _hby + lengthdir_y(_hlen, _hang), false);
		}
	}
	// her silhouette, burned into the frame with it
	scr_silhouette_begin(_ink);
	with (obj_player) draw_self();
	with (obj_familiar_controller) if (sprite_index != -1) draw_self();
	shader_reset();
}

draw_set_alpha(1);
draw_set_color(c_white);

