var _prof_d = get_timer();   // PERF PROBE
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
if (gaze) {                                                          // sitting in her universe: it warps open around her, and closes back in on her
	_open = min(_open, clamp((t - birth_at) / (_fps * 0.6), 0, 1));
	if (duration != infinity) _open = min(_open, clamp((duration - t) / (_fps * 0.5), 0, 1));
}
var _ease = 1 - sqr(1 - _open);
var _r = _diag * _ease;
var _neb = power(_ease, 3);
// the backdrop belongs to the old universe: it fades out as everything is crunched, is gone in the void, and the new universe's
// stars come back slowly after the Big Bang, as if their light is only now reaching her
var _bgk = variable_global_exists("hex_mood") ? global.hex_mood.bg : 1;   // the aeon director decides (scr_hex_aeon_step)

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

// ---- the sky's light is gathered off-screen first, in a surface that can hold light brighter than white (16-bit float).
// it reaches the screen at the end through a camera curve (sh_hex_tone), so stacked light rolls off into rich color instead
// of clipping to flat white, and black holes bend the real light behind them on the way (sh_hex_lens).
// until both shaders exist and compile, everything draws straight to the screen like before ----
var _shl = asset_get_index("sh_hex_lens"), _sht = asset_get_index("sh_hex_tone");
var _hdr = (_shl != -1 && _sht != -1 && shader_is_compiled(_shl) && shader_is_compiled(_sht));
var _aw = surface_get_width(application_surface), _ah = surface_get_height(application_surface);
if (_hdr) {
	if (hdr_fmt == -1) hdr_fmt = surface_format_is_supported(surface_rgba16float) ? surface_rgba16float : surface_rgba8unorm;
	if (surface_exists(sky_a) && (surface_get_width(sky_a) != _aw || surface_get_height(sky_a) != _ah)) { surface_free(sky_a); surface_free(sky_b); }
	if (!surface_exists(sky_a)) sky_a = surface_create(_aw, _ah, hdr_fmt);
	if (!surface_exists(sky_b)) sky_b = surface_create(_aw, _ah, hdr_fmt);
	surface_set_target(sky_a);
	draw_clear_alpha(c_black, 1);
	camera_apply(_cam);                                                   // draw in the world's coordinates, as if on screen
}

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
		draw_sprite_ext(nebula, 0, _px + _qx, _py + _qy, _sc, _sc, sky_angle, c_white, _neb / 5 * _bgk);
	}
	gpu_set_tex_filter(false);
}

// ---- 4) the deep field: baked at the cast, turning slowest. two halves twinkle out of step ----
var _far = sky_angle * 0.5;
draw_sprite_ext(dust[0], 0, _px, _py, 1, 1, _far, c_white, (0.75 + 0.25 * sin(current_time / 700)) * _neb * _bgk);
draw_sprite_ext(dust[1], 0, _px, _py, 1, 1, _far, c_white, (0.75 + 0.25 * sin(current_time / 700 + pi)) * _neb * _bgk);

// ---- 5) scattered stars: a middle layer of small glowing stars in every color, turning a little faster ----
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
	var _tw = (0.6 + 0.4 * sin(current_time / (250 + (m mod 5) * 120) + m * 3)) * _bgk;
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
		(0.75 + 0.25 * sin(current_time / 400 + h * 2)) * _neb * _bgk);
}
// ---- 6b) her haze: lasting wisps of gas left by the dust of everyone she has unmade this run, turning with her sky.
// her nebula, growing from her dead. each wisp spreads and thins as it diffuses (same light, spread wider).
// soot first (it dims what is behind it), then the glowing gas ----
var _hz = global.hex_haze;
var _hn = array_length(_hz);
var _wspr = global.hex_wisp_spr;                          // the textured gas atlas
var _skc = dcos(sky_angle), _sks = dsin(sky_angle);       // her sky's turn, worked out once for every wisp instead of per wisp
var _rr2 = _r * _r;
// soot first: it dims what's behind it. darkens by the tint's brightness, so its black edges darken nothing and it fades out softly
gpu_set_blendmode(bm_subtract);
for (var i = 0; i < _hn; i++) {
	var _hq = _hz[i];
	if (_hq.c != -1 || _hq.f <= 0.01) continue;
	var _hox = _hq.ox, _hoy = _hq.oy;
	if (_hox * _hox + _hoy * _hoy > _rr2) continue;
	var _hdx = _px + _hox * _skc + _hoy * _sks, _hdy = _py + _hoy * _skc - _hox * _sks;  // turned with her sky
	var _thin = sqrt(_hq.s0 / _hq.s);                                                 // thinner as it spreads
	var _hxs = _hq.s * (1 + 0.25 * (1 - _hq.s0 / _hq.s)) * _hq.st / 20, _hys = _hq.s / 20;
	var _hrot = _hq.ang + sky_angle;
	var _hsk = 0.25 * _neb * _hq.f * _thin;
	var _hcs = dcos(_hrot), _hsn = dsin(_hrot), _hhx = 32 * _hxs, _hhy = 32 * _hys;   // draw_sprite_general turns around its corner: keep the middle in place
	var _hcol = merge_color(c_black, c_white, _hsk * _hq.tx);
	draw_sprite_general(_wspr, 0, (_hq.fr mod 4) * 64, (_hq.fr div 4) * 64, 64, 64, _hdx - _hhx * _hcs - _hhy * _hsn, _hdy + _hhx * _hsn - _hhy * _hcs,
		_hxs, _hys, _hrot, _hcol, _hcol, _hcol, _hcol, 1);                            // a dark lane with structure
	if (_hq.tx < 1) draw_sprite_ext(spr_soft, 0, _hdx, _hdy, _hxs, _hys, _hrot, merge_color(c_black, c_white, _hsk * (1 - _hq.tx)), 1);
}
// then the glowing gas
gpu_set_blendmode(bm_add);
for (var i = 0; i < _hn; i++) {
	var _hq = _hz[i];
	if (_hq.c == -1 || _hq.f <= 0.01) continue;
	var _hox = _hq.ox, _hoy = _hq.oy;
	if (_hox * _hox + _hoy * _hoy > _rr2) continue;
	var _hdx = _px + _hox * _skc + _hoy * _sks, _hdy = _py + _hoy * _skc - _hox * _sks;
	var _thin = sqrt(_hq.s0 / _hq.s);
	var _hxs = _hq.s * (1 + 0.25 * (1 - _hq.s0 / _hq.s)) * _hq.st / 20, _hys = _hq.s / 20;
	var _hrot = _hq.ang + sky_angle;
	var _hga = _hq.a * _neb * _hq.f * _thin * _hq.ex;                                // ex: the exposure curve, rich but never white
	var _hcs = dcos(_hrot), _hsn = dsin(_hrot), _hhx = 32 * _hxs, _hhy = 32 * _hys;
	draw_sprite_general(_wspr, 0, (_hq.fr mod 4) * 64, (_hq.fr div 4) * 64, 64, 64, _hdx - _hhx * _hcs - _hhy * _hsn, _hdy + _hhx * _hsn - _hhy * _hcs,
		_hxs, _hys, _hrot, _hq.c, _hq.c, _hq.c, _hq.c, _hga * _hq.tx);               // wisps, threads and tendrils
	if (_hq.tx < 1) draw_sprite_ext(spr_soft, 0, _hdx, _hdy, _hxs, _hys, _hrot, _hq.c, _hga * (1 - _hq.tx)); // still settling: soft
	if (_hq.tr) {                                                                    // falling into a black hole: a fading streak along its curve
		var _tqx = _hq.ox, _tqy = _hq.oy;
		for (var _tk = 1; _tk <= 2; _tk++) {
			var _tox = (_tk == 1) ? _hq.p1x : _hq.p2x, _toy = (_tk == 1) ? _hq.p1y : _hq.p2y;
			var _tln = point_distance(_tox, _toy, _tqx, _tqy);
			if (_tln < 1) break;
			// one soft stamp stretched to span the whole gap between where it was and where it is, so the streak is unbroken
			var _tmx = (_tox + _tqx) * 0.5, _tmy = (_toy + _tqy) * 0.5;
			var _tdx = _px + _tmx * _skc + _tmy * _sks, _tdy = _py + _tmy * _skc - _tmx * _sks;
			var _trot = point_direction(_tox, _toy, _tqx, _tqy) + sky_angle;
			draw_sprite_ext(spr_soft, 0, _tdx, _tdy, (_tln + _hq.s * 0.8) / 20, _hys * (0.8 - 0.15 * _tk), _trot, _hq.c, _hga * 0.5 / _tk);
			_tqx = _tox; _tqy = _toy;
		}
	}
}
// ---- 6c) the peek: births from her old haze ----
for (var n = 0; n < array_length(nurseries); n++) {
	var _nu = nurseries[n];
	if (t < _nu.t0) continue;
	var _nk  = (t - _nu.t0) / nurse_len;
	var _nl  = point_distance(0, 0, _nu.ox, _nu.oy);
	var _na  = point_direction(0, 0, _nu.ox, _nu.oy) + sky_angle;
	var _nsx = _px + lengthdir_x(_nl, _na), _nsy = _py + lengthdir_y(_nl, _na);
	// the dark knot (a Bok globule): cold, dense dust hiding the star forming inside. it thickens and shrinks as it collapses,
	// then the newborn blows it away
	var _ngk = (_nk < 0.7) ? clamp(_nk / 0.4, 0, 1) : max(0, 1 - (_nk - 0.7) / 0.08);
	var _ngs = lerp(22, 11, clamp(_nk / 0.7, 0, 1)) / 20;
	draw_sprite_ext(spr_soft, 0, _nsx, _nsy, _ngs * 1.4, _ngs * 1.4, 0, _nu.gc, 0.22 * _ngk * _neb);       // the cocoon's lit edge
	gpu_set_blendmode(bm_subtract);
	draw_sprite_ext(spr_soft, 0, _nsx, _nsy, _ngs, _ngs, 0, merge_color(c_black, c_white, 0.85 * _ngk * _neb), 1); // its dark heart
	gpu_set_blendmode(bm_add);
	// the protostar: a dim red warmth inside the knot. it can't fuse yet, it's only hot from the gas falling onto it,
	// and it flickers as clumps land
	if (_nk > 0.25 && _nk < 0.7) {
		var _npk = (_nk - 0.25) / 0.45;
		var _nfl = 0.7 + 0.3 * sin(t * 0.7 + _nu.ph) * sin(t * 0.23);
		draw_sprite_ext(spr_soft, 0, _nsx, _nsy, (5 + 8 * _npk) / 20, (5 + 8 * _npk) / 20, 0, make_color_rgb(255, 90, 60), 0.4 * _npk * _nfl * _neb);
		draw_sprite_ext(spr_dot,  0, _nsx, _nsy, (1 + 1.5 * _npk) / 15, (1 + 1.5 * _npk) / 15, 0, make_color_rgb(255, 170, 120), 0.9 * _npk * _nfl * _neb);
	}
	// jets, Herbig-Haro style: the young star's disk seen edge-on as a dark lane, its light escaping in an hourglass around
	// the poles, a bright beam at the base, and bow shocks where each jet's front ploughs into the cloud.
	// the far jet is dimmer and redder: we see it through the cloud
	if (_nk > 0.42 && _nk < 0.95) {
		var _njk = (_nk - 0.42) / 0.53;
		var _nja = ((_njk < 0.75) ? min(1, _njk / 0.1) : 1 - (_njk - 0.75) / 0.25) * _neb;
		var _njb = _nu.jet + sky_angle + 8 * sin(t * 0.05 + _nu.ph);                  // the axis precesses slowly
		for (var _njs = 0; _njs < 2; _njs++) {
			var _njd  = _njb + _njs * 180;
			var _nfar = (_njs == 1) ? 0.5 : 1;
			for (var _nh = 1; _nh <= 5; _nh++) {                                         // the hourglass of escaping light
				var _nhd = _nh * 7;
				draw_sprite_ext(spr_soft, 0, _nsx + lengthdir_x(_nhd, _njd), _nsy + lengthdir_y(_nhd, _njd), (4 + _nh * 3) / 20, (4 + _nh * 3) / 20, 0,
					make_color_rgb(190, 215, 255), 0.07 * _nja * _nfar);
			}
			var _nbl = 22 * min(1, _njk * 4);                                            // the beam, thin and white-hot near the star
			draw_set_alpha(0.7 * _nja * _nfar);
			draw_line_width_color(_nsx, _nsy, _nsx + lengthdir_x(_nbl, _njd), _nsy + lengthdir_y(_nbl, _njd), 1.5,
				make_color_rgb(225, 255, 250), (_njs == 1) ? make_color_rgb(120, 200, 120) : make_color_rgb(90, 200, 230));
			draw_set_alpha(1);
			var _nbf = 75 * sqrt(min(1, _njk * 1.3));                                   // the bow shock: a glowing arrowhead at the front
			var _nbx = _nsx + lengthdir_x(_nbf, _njd), _nby = _nsy + lengthdir_y(_nbf, _njd);
			var _nbc = (_njs == 1) ? make_color_rgb(230, 90, 70) : make_color_rgb(255, 125, 105);
			for (var _nbi = -3; _nbi <= 3; _nbi++) {
				var _nca = _njd + _nbi * 22;
				draw_sprite_ext(spr_soft, 0, _nbx + lengthdir_x(12, _nca) - lengthdir_x(12, _njd), _nby + lengthdir_y(12, _nca) - lengthdir_y(12, _njd),
					5 / 20, 5 / 20, 0, _nbc, 0.24 * _nja * _nfar * (1 - abs(_nbi) / 4));
			}
		}
		gpu_set_blendmode(bm_subtract);                                                  // the disk, edge-on: a dark lane across the star
		draw_sprite_ext(spr_soft, 0, _nsx, _nsy, 24 / 20, 5 / 20, _njb + 90, merge_color(c_black, c_white, 0.7 * _nja), 1);
		gpu_set_blendmode(bm_add);
	}
	// it catches: the gas around it lights up in its color, swelling fast and fading slowly
	if (_nu.lit) {
		var _nlk = (_nk - 0.7) / 0.3;
		var _nla = (_nlk < 0.12) ? _nlk / 0.12 : 1 - (_nlk - 0.12) / 0.88;
		var _nlr = (34 + 4 * sqrt(_nu.m)) * (0.75 + 0.35 * _nlk) / 20;
		draw_sprite_ext(spr_soft, 0, _nsx, _nsy, _nlr, _nlr, 0, _nu.c, 0.3 * _nla * _neb);
		// its first light sweeps outward through the gas as a ring, lighting the cloud as it passes
		if (_nlk < 0.5) {
			var _nfr = 60 * sqrt(_nlk / 0.5), _nfa = 0.3 * (1 - _nlk / 0.5) * _neb;
			for (var _nfi = 0; _nfi < 28; _nfi++) {
				draw_sprite_ext(spr_soft, 0, _nsx + lengthdir_x(_nfr, _nfi * 360 / 28), _nsy + lengthdir_y(_nfr, _nfi * 360 / 28), 7 / 20, 7 / 20, 0, _nu.c, _nfa);
			}
		}
	}
}
// the infall: bright motes swirling down onto each young star, stretched along their path by their speed
for (var i = 0; i < array_length(infall); i++) {
	var _fi  = infall[i];
	var _fil = point_distance(0, 0, _fi.nu.ox, _fi.nu.oy);
	var _fia = point_direction(0, 0, _fi.nu.ox, _fi.nu.oy) + sky_angle;
	var _fid = _fi.a + sky_angle;
	var _fix = _px + lengthdir_x(_fil, _fia) + lengthdir_x(_fi.r, _fid);
	var _fiy = _py + lengthdir_y(_fil, _fia) + lengthdir_y(_fi.r, _fid);
	var _fiw = variable_struct_exists(_fi, "w") ? _fi.w : 1;
	// a little comet: the mote plus a curved trail of where it just was, so the spiral itself shows as it winds in
	var _ftr = clamp(_fiw * 2.5, 3, 30);                                    // how far round the trail reaches, in degrees
	var _fcx = _px + lengthdir_x(_fil, _fia), _fcy = _py + lengthdir_y(_fil, _fia);
	var _fcol = merge_color(_fi.c, c_white, 0.2);
	var _fal  = min(1, _fi.age / 10) * _neb;
	for (var _fk = 0; _fk < 5; _fk++) {
		var _fkr = _fi.r + _fk * (0.6 + 14 / max(_fi.r, 4)) * 2;           // the trail sits a little farther out: it was falling
		var _fkd = _fid - _fk * _ftr / 4 * _fi.nu.spin;
		var _fks = (_fk == 0) ? 0.55 : 0.4;
		draw_sprite_ext(spr_px, 0, _fcx + lengthdir_x(_fkr, _fkd), _fcy + lengthdir_y(_fkr, _fkd), _fks, _fks, 0, _fcol, _fal * (1 - _fk / 5));
	}
}
// the jet knots: pulses of gas streaming out of each pole. white-teal at the base, blue along the jet, shock pink at the tips,
// tracing a gentle S as the axis precesses
for (var i = 0; i < array_length(jbeads); i++) {
	var _jkb = jbeads[i];
	var _jnu = _jkb.nu;
	var _jl0 = point_distance(0, 0, _jnu.ox, _jnu.oy), _ja0 = point_direction(0, 0, _jnu.ox, _jnu.oy) + sky_angle;
	var _jcx = _px + lengthdir_x(_jl0, _ja0), _jcy = _py + lengthdir_y(_jl0, _ja0);
	var _jdir = _jkb.ang + sky_angle;                                   // the way it was fired: knots fly straight out
	var _jwob = _jkb.l;                                                  // how far it has drifted sideways
	var _jbx = _jcx + lengthdir_x(_jkb.d, _jdir) + lengthdir_x(_jwob, _jdir + 90);
	var _jby = _jcy + lengthdir_y(_jkb.d, _jdir) + lengthdir_y(_jwob, _jdir + 90);
	var _jbk = _jkb.d / 80;
	var _jbc = (_jbk < 0.5) ? merge_color(make_color_rgb(215, 255, 250), make_color_rgb(80, 170, 255), _jbk * 2)
	                        : merge_color(make_color_rgb(80, 170, 255), make_color_rgb(255, 110, 120), min(1, (_jbk - 0.5) * 2));
	if (_jkb.sd == 1) _jbc = merge_color(_jbc, make_color_rgb(200, 80, 60), 0.35);  // the far jet, reddened by the cloud
	var _jlif = (_jkb.k == 1) ? 45 : 60;
	var _jlk  = _jkb.age / _jlif;
	var _jba = min(1, _jkb.age / 4) * (1 - _jlk) * ((_jkb.sd == 1) ? 0.5 : 1) * _neb;
	if (_jkb.k == 1) {                                                  // spray: a bright speck at the nozzle that slows and puffs out into mist
		var _jsl = clamp(_jkb.v * 2.5, 1, 9);
		if (_jlk < 0.4) draw_sprite_ext(spr_px, 0, _jbx, _jby, _jsl / 4, 0.45, _jdir, merge_color(_jbc, c_white, 0.3), 0.8 * _jba * (1 - _jlk / 0.4));
		var _jms = (2 + 9 * _jlk) / 20;                                  // the mist grows as it disperses
		draw_sprite_ext(spr_soft, 0, _jbx, _jby, _jms, _jms, 0, _jbc, 0.22 * _jba);
		continue;
	}
	if (_jkb.k == 2) {                                                  // the wide wind: big, faint, pale puffs
		var _jws = (4 + 12 * _jlk) / 20;
		draw_sprite_ext(spr_soft, 0, _jbx, _jby, _jws, _jws, 0, merge_color(_jbc, make_color_rgb(190, 215, 255), 0.5), 0.1 * _jba);
		continue;
	}
	draw_sprite_ext(spr_soft, 0, _jbx, _jby, (5 + _jkb.d * 0.08) / 20, (3 + _jkb.d * 0.03) / 20, _jdir, _jbc, 0.6 * _jba);         // a clump of gas, stretched by its speed
	draw_sprite_ext(spr_soft, 0, _jbx, _jby, 3 / 20, 2 / 20, _jdir, merge_color(_jbc, c_white, 0.5), 0.7 * _jba);                   // its hot bright core
}
// a dying star throbs, swelling and dimming a few times as its outer layers come loose
for (var i = 0; i < array_length(deaths); i++) {
	var _dtt = deaths[i];
	if (t < _dtt.t0) continue;
	var _dtk = (t - _dtt.t0) / death_len;
	var _shl = point_distance(0, 0, _dtt.st.ox, _dtt.st.oy);
	var _sha = point_direction(0, 0, _dtt.st.ox, _dtt.st.oy) + sky_angle;
	var _shx = _px + lengthdir_x(_shl, _sha), _shy = _py + lengthdir_y(_shl, _sha);
	if (_dtt.st.m >= HEX_MASS_GIANT) {                                               // a giant's core failing: faster, harder pulses, burning white-blue
		var _thg = 0.5 + 0.5 * sin(_dtk * _dtk * pi * 14);
		draw_sprite_ext(spr_soft, 0, _shx, _shy, (10 + 22 * _dtk * _thg) / 20, (10 + 22 * _dtk * _thg) / 20, 0, make_color_rgb(200, 220, 255), (0.2 + 0.45 * _thg) * _neb);
		continue;
	}
	var _thr = 0.5 + 0.5 * sin(_dtk * pi * 6);                                      // three throbs
	draw_sprite_ext(spr_soft, 0, _shx, _shy, (8 + 10 * _dtk * _thr) / 20, (8 + 10 * _dtk * _thr) / 20, 0, make_color_rgb(255, 120, 60), (0.15 + 0.3 * _thr) * _neb);
}
// a supernova: a flash that outshines her whole sky, then a shell of forged elements tearing outward in filaments
for (var i = 0; i < array_length(novae); i++) {
	var _nv  = novae[i];
	var _nvk = (t - _nv.t0) / nova_len;
	var _nvl = point_distance(0, 0, _nv.ox, _nv.oy), _nva = point_direction(0, 0, _nv.ox, _nv.oy) + sky_angle;
	var _nvx = _px + lengthdir_x(_nvl, _nva), _nvy = _py + lengthdir_y(_nvl, _nva);
	if (_nvk < 0.15) {                                                               // the flash
		var _nvf = 1 - _nvk / 0.15;
		draw_sprite_ext(spr_soft, 0, _nvx, _nvy, (60 + 400 * _nvk) / 20, (60 + 400 * _nvk) / 20, 0, make_color_rgb(230, 240, 255), 0.9 * _nvf * _neb);
		draw_sprite_ext(spr_soft, 0, _nvx, _nvy, 20 / 20, 20 / 20, 0, c_white, _nvf * _neb);
	}
	var _nvR = 150 * (1 - power(1 - _nvk, 2.2));                                     // blasts out, then slows as it ploughs into the gas
	var _nvA = (1 - 0.7 * _nvk) * _neb;
	for (var _nvj = 0; _nvj < 90; _nvj++) {                                          // filaments: fingers of gas torn outward
		var _nvh = scr_hash(_nv.ph + _nvj * 1.7), _nvh2 = scr_hash(_nv.ph + _nvj * 4.3);
		var _nvd = _nvj * 4 + _nvh2 * 3;
		var _nvc = (_nvh < 0.45) ? make_color_rgb(70, 220, 200) : ((_nvh < 0.8) ? make_color_rgb(255, 200, 90) : make_color_rgb(255, 85, 115));
		var _nr0 = _nvR * (0.72 + 0.18 * _nvh2), _nr1 = _nvR * (1 + 0.1 * _nvh);
		draw_set_alpha(0.7 * _nvA);
		draw_line_width_color(_nvx + lengthdir_x(_nr0, _nvd), _nvy + lengthdir_y(_nr0, _nvd), _nvx + lengthdir_x(_nr1, _nvd), _nvy + lengthdir_y(_nr1, _nvd),
			1.5, c_black, _nvc);
	}
	draw_set_alpha(1);
	for (var _nvj = 0; _nvj < 36; _nvj++) {                                          // the shell's glow
		var _nvh = scr_hash(_nv.ph + _nvj * 3.9);
		var _nvc = (_nvh < 0.45) ? make_color_rgb(70, 220, 200) : ((_nvh < 0.8) ? make_color_rgb(255, 200, 90) : make_color_rgb(255, 85, 115));
		draw_sprite_ext(spr_soft, 0, _nvx + lengthdir_x(_nvR * 0.95, _nvj * 10), _nvy + lengthdir_y(_nvR * 0.95, _nvj * 10), 14 / 20, 14 / 20, 0, _nvc, 0.16 * _nvA);
	}
}
// a planetary nebula puffing out: a ring of glowing gas, red outside and teal inside, around a white-hot core
for (var i = 0; i < array_length(shells); i++) {
	var _sh  = shells[i];
	var _shk = (t - _sh.t0) / shell_len;
	var _shr = 80 * (1 - sqr(1 - _shk));                                            // puffs out fast, then slows
	var _sha = (_shk < 0.15) ? _shk / 0.15 : 1 - 0.6 * (_shk - 0.15) / 0.85;        // flares up, then dims toward the haze it becomes
	var _shl = point_distance(0, 0, _sh.ox, _sh.oy);
	var _scd = point_direction(0, 0, _sh.ox, _sh.oy) + sky_angle;
	var _shx = _px + lengthdir_x(_shl, _scd), _shy = _py + lengthdir_y(_shl, _scd);
	var _shrt = _sh.ang + sky_angle;
	for (var _shj = 0; _shj < 24; _shj++) {
		var _shd = _shj * 15;
		for (var _sri = 0; _sri < 2; _sri++) {
			var _shrr = _shr * ((_sri == 0) ? 1 : 0.7) * (0.9 + 0.2 * scr_hash(_shj * 3.1 + _sh.ang));   // lumpy, like real rings
			var _sx0 = lengthdir_x(_shrr, _shd), _sy0 = lengthdir_y(_shrr, _shd) * _sh.ell;
			draw_sprite_ext(spr_soft, 0, _shx + lengthdir_x(_sx0, _shrt) - lengthdir_y(-_sy0, _shrt), _shy + lengthdir_y(_sx0, _shrt) + lengthdir_x(-_sy0, _shrt),
				12 / 20, 12 / 20, 0, (_sri == 0) ? make_color_rgb(255, 85, 115) : make_color_rgb(70, 220, 200), 0.22 * _sha * _neb);
		}
	}
	draw_sprite_ext(spr_soft, 0, _shx, _shy, 10 / 20, 10 / 20, 0, make_color_rgb(205, 225, 255), 0.35 * _sha * _neb); // the white dwarf lighting its ring
}
// ---- 7) her sky: one star for every enemy she has unmade this run ----
var _stars = global.hex_stars;
var _n = array_length(_stars);
// the finale: a wave runs outward through ONLY this cast's newborn stars, so they pop as the new arrivals
var _wave_len = _fps * 1.1;
var _wave_on  = (pulse_t >= 0 && pulse_t < _wave_len);
var _wave_r   = _wave_on ? _diag * 0.8 * (pulse_t / _wave_len) : -9999;
// gravitational lensing: stars behind a black hole are bent outward around it, crowding into a ring at its edge
var _lens = [];
for (var h = 0; h < array_length(global.hex_holes); h++) {
	var _lh = global.hex_holes[h];
	if (_lh.age < HEX_GATHER) continue;
	var _lhl = point_distance(0, 0, _lh.ox, _lh.oy), _lha = point_direction(0, 0, _lh.ox, _lh.oy) + sky_angle;
	var _lhr = scr_hex_hole_size(_lh);
	array_push(_lens, { x: _px + lengthdir_x(_lhl, _lha), y: _py + lengthdir_y(_lhl, _lha), r: _lhr, re2: sqr(_lhr * 2.1) });
}
var _nlens = _hdr ? 0 : array_length(_lens);                     // with the lens shader, the stars bend along with everything else
for (var i = max(0, _n - 800); i < _n; i++) {
	var _st = _stars[i];
	var _l = point_distance(0, 0, _st.ox, _st.oy);
	if (_l > _r) continue;
	var _a = point_direction(0, 0, _st.ox, _st.oy) + sky_angle;
	var _sx = _px + lengthdir_x(_l, _a), _sy = _py + lengthdir_y(_l, _a);
	var _hidden = false;
	for (var h = 0; h < _nlens; h++) {
		var _lz = _lens[h];
		var _ldx = _sx - _lz.x, _ldy = _sy - _lz.y, _ld2 = _ldx * _ldx + _ldy * _ldy;
		if (_ld2 > sqr(_lz.r * 7)) continue;
		if (_ld2 < sqr(_lz.r)) { _hidden = true; break; }              // right behind the shadow: its light can't reach us
		var _lsk = 1 + _lz.re2 / max(1, _ld2);                           // pushed outward, harder the closer it lies
		_sx = _lz.x + _ldx * _lsk; _sy = _lz.y + _ldy * _lsk;
	}
	if (_hidden) continue;

	// color first, since the wave glow below needs it
	var _sc = scr_hex_star_color(_st.m, _st.ph, _st.hx); // its mass sets its color: red dwarf to blue giant
	var _sgk = 0;                                          // how far into its red giant years it is
	var _sns = (_st[$ "ns"] == true);
	if (_st[$ "wd"] == true) _sc = make_color_rgb(205, 225, 255);              // a white dwarf: the bare core, white-hot and tiny
	else if (_sns) _sc = make_color_rgb(170, 210, 255);                        // a neutron star: a city-sized core, spinning
	else if (_st.m >= HEX_MASS_SUN_MIN) {                                      // sun-like stars swell into red giants, giants into red supergiants
		var _slf = scr_hex_age(_st) / scr_hex_star_life(_st.m);
		_sgk = clamp((_slf - 0.7) / 0.3, 0, 1);                                // the last of a sun-like life: it swells into a red giant
		_sc = merge_color(_sc, make_color_rgb(255, 120, 60), 0.75 * _sgk);
	}
	var _tw = 0.8 + 0.2 * sin(current_time / (300 + (i mod 7) * 90) + _st.ph); // a gentle twinkle that never goes dark
	var _wb = 0;
	if (_wave_on && i >= new_from) {
		var _band = _wave_r - _l;                                   // how far the wavefront has passed this star
		if (_band > 0 && _band < 80) _wb = sin(_band / 80 * pi);    // rises to 1 mid-band and back to 0, no hard edges
	}
	_tw = min(1, _tw + _wb);
	var _ss = _st.s * (1 + 1.5 * _wb); // only newborns swell now, so they can swell harder without whiting out the sky
	_ss *= 1 + 0.9 * _sgk;                                 // red giants are big
		if (_wb > 0) draw_sprite_ext(spr_glow, 0, _sx, _sy, _ss * 7 / 15, _ss * 7 / 15, 0, _sc, 0.6 * _wb);

	if (_st.s > 2.5 || _wb > 0.6) {   // newborns briefly flare with spikes at the crest of the wave
		scr_draw_star_flare(_sx, _sy, _ss, _sc, _tw);
	} else {
		var _core = max(1.2, _ss * 0.8); // never smaller than a crisp pixel, or it vanishes once its flare ends
		if (i >= new_from) draw_sprite_ext(spr_soft, 0, _sx, _sy, (6 + _ss * 3) / 20, (6 + _ss * 3) / 20, 0, _sc, 0.12 * _tw); // this cast's newborns keep a soft halo, so you can see your new stars
		draw_sprite_ext(spr_glow, 0, _sx, _sy, _ss * 3 / 15, _ss * 3 / 15, 0, _sc, 0.5 * _tw);                    // soft glow
		draw_sprite_ext(spr_dot,  0, _sx, _sy, _core / 15, _core / 15, 0, merge_color(_sc, c_white, 0.5), _tw); // white-hot core
	}
	if (_sns) {                                                                 // a pulsar: two beams sweeping round like a lighthouse
		var _pba = current_time * 0.35 + _st.ph * 50;
		draw_set_alpha(0.45 * _tw);
		draw_line_width_color(_sx, _sy, _sx + lengthdir_x(28, _pba), _sy + lengthdir_y(28, _pba), 1.5, make_color_rgb(200, 230, 255), c_black);
		draw_line_width_color(_sx, _sy, _sx + lengthdir_x(28, _pba + 180), _sy + lengthdir_y(28, _pba + 180), 1.5, make_color_rgb(200, 230, 255), c_black);
		draw_set_alpha(1);
	}
}
// ---- 7b) her black holes, turning with her stars ----
var _holes = global.hex_holes;
if (_hdr) {
	// gravitational lensing, for real: every point near a hole shows the sky from where the lens equation says its light came from,
	// so the nebula and stars behind it bend into a ring around it. a star about to collapse already starts to bend light
	surface_reset_target();
	var _lu = array_create(16, 0), _rp = array_create(16, 0), _dk = array_create(16, 0), _rgk = array_create(4, 0), _ln = 0, _rn = 0;
	var _ksx = _aw / _vw, _ksy = _ah / _vh;                                 // world pixels to surface pixels
	for (var h = 0; h < array_length(_holes) && _ln < 4; h++) {
		var _ho = _holes[h];
		var _hl = point_distance(0, 0, _ho.ox, _ho.oy);
		var _ha = point_direction(0, 0, _ho.ox, _ho.oy) + sky_angle;
		// the lens follows the smoothed size (no ringdown, so stars never bounce) but NOT the crunch's swelling horizon (that would
		// magnify the sky into blocks); the director strengthens it gently instead
		var _er = scr_hex_hole_vis(_ho) / (variable_struct_exists(_ho, "ck") ? 1 + 9 * power(_ho.ck, 5) : 1) * 1.3 * _ksx
		        * (variable_global_exists("hex_mood") ? global.hex_mood.lensk : 1);                   // the Einstein radius: where the light behind it smears into a ring
		_lu[_ln * 4]     = (_px + lengthdir_x(_hl, _ha) - _vx) * _ksx;
		_lu[_ln * 4 + 1] = (_py + lengthdir_y(_hl, _ha) - _vy) * _ksy;
		_lu[_ln * 4 + 2] = _er * _er;
		_lu[_ln * 4 + 3] = (_ho.age < HEX_GATHER) ? sqr(_ho.age / HEX_GATHER) : 1;   // space bends harder and harder as the giant collapses
		// its disk, drawn by the shader: the horizon swells into place (overshooting a touch) and the disk lights up after the impact
		var _da = _ho.age - HEX_GATHER;
		var _dg = clamp(_da / (_fps * 0.6), 0, 1);
		_dk[_ln * 4]     = scr_hex_hole_vis(_ho) * scr_hex_ringk(_ho) * (1 + 2.7 * power(_dg - 1, 3) + 1.7 * power(_dg - 1, 2)) * _ksx;   // the shadow rings, the lens doesn't
		_dk[_ln * 4 + 1] = degtorad(_ho.tilt);
		var _dfeed = variable_struct_exists(_ho, "feed") ? _ho.feed : 0;
		var _dsp = clamp(_da / (_fps * 2.5), 0, 1);                           // the disk builds over a couple of seconds as the leftovers spiral in
		_dk[_ln * 4 + 2] = (_da > 0 && _hl <= _r) ? (1 - sqr(1 - _dsp)) * (0.55 + 0.9 * (1 - exp(-_dfeed / 40))) : 0;   // starving: dim and quiet. feeding: blazing
		if (variable_struct_exists(_ho, "qk")) _dk[_ln * 4 + 2] *= 1 + 2.5 * _ho.qk;
		if (variable_struct_exists(_ho, "ck")) _dk[_ln * 4 + 2] *= 1 + 2 * _ho.ck;                   // a quasar: the disk outshines everything
		if (variable_struct_exists(_ho, "evk")) _dk[_ln * 4 + 2] *= max(0, 1 - _ho.evk * 1.4);          // evaporating: its disk is long gone
		// the photon ring ignites first: a flash of light caught circling the new horizon, settling into its hairline
		_rgk[_ln] = (_da > 0 && _hl <= _r) ? min(1, _da / (_fps * 0.12)) * (1 + 2 * exp(-_da / (_fps * 0.25))) : 0;
		if (variable_struct_exists(_ho, "mf") && _ho.mf >= 0) _rgk[_ln] *= 1 + 3 * exp(-_ho.mf / (_fps * 0.3));   // two holes just became one: its ring blazes
		// and a ripple of bent space rolls out from the collapse, through her whole sky
		if (_da > 0 && _da < _fps * 1.4 && _rn < 4) {
			var _rpk = _da / (_fps * 1.4);
			_rp[_rn * 4]     = _lu[_ln * 4];
			_rp[_rn * 4 + 1] = _lu[_ln * 4 + 1];
			_rp[_rn * 4 + 2] = _rpk * 1500 * _ksx;
			_rp[_rn * 4 + 3] = 7 * (1 - _rpk) * _ksx;
			_rn++;
		}
		_dk[_ln * 4 + 3] = frac(_ho.ph * 0.137) * 6.28;
		_ln++;
	}
	// gravitational waves from black holes spiralling together and merging, newest first
	if (variable_global_exists("hex_ripples")) {
		for (var i = array_length(global.hex_ripples) - 1; i >= 0 && _rn < 4; i--) {
			var _rpl = global.hex_ripples[i];
			var _rpq = _rpl.age / _rpl.len;
			var _rpd = point_distance(0, 0, _rpl.ox, _rpl.oy), _rpa = point_direction(0, 0, _rpl.ox, _rpl.oy) + sky_angle;
			_rp[_rn * 4]     = (_px + lengthdir_x(_rpd, _rpa) - _vx) * _ksx;
			_rp[_rn * 4 + 1] = (_py + lengthdir_y(_rpd, _rpa) - _vy) * _ksy;
			_rp[_rn * 4 + 2] = _rpq * 1500 * _ksx;
			_rp[_rn * 4 + 3] = _rpl.amp * (1 - _rpq) * _ksx;
			_rn++;
		}
	}
	surface_set_target(sky_b);
	gpu_set_blendenable(false);
	shader_set(_shl);
	shader_set_uniform_f(shader_get_uniform(_shl, "u_size"), _aw, _ah);
	shader_set_uniform_f_array(shader_get_uniform(_shl, "u_lens"), _lu);
	shader_set_uniform_f_array(shader_get_uniform(_shl, "u_ripple"), _rp);   // ripples through space (merging holes, shockwaves): coming soon
	shader_set_uniform_f_array(shader_get_uniform(_shl, "u_disk"), _dk);
	shader_set_uniform_f(shader_get_uniform(_shl, "u_time"), variable_global_exists("hex_disk_time") ? global.hex_disk_time : t / _fps);
	// the afterglow of creation, mottled like the real cosmic microwave background: hot orange cooling through deep red to dark
	var _cmb = [0, 0, 0, 0];
	if (variable_global_exists("hex_bang") && is_struct(global.hex_bang)) {
		var _cbk = min(1, global.hex_bang.t / (_fps * 8));
		_cmb = [0.42 * sqr(1 - _cbk) * min(1, global.hex_bang.t / (_fps * 0.4)), _cbk, frac(global.hex_aeon.n * 0.37) * 50, 0];
	}
	shader_set_uniform_f(shader_get_uniform(_shl, "u_cmb"), _cmb[0], _cmb[1], _cmb[2], _cmb[3]);
	shader_set_uniform_f(shader_get_uniform(_shl, "u_ringk"), _rgk[0], _rgk[1], _rgk[2], _rgk[3]);
	draw_surface(sky_a, 0, 0);
	shader_reset();
	gpu_set_blendenable(true);
	camera_apply(_cam);
	gpu_set_blendmode(bm_add);
}
// while a star gathers itself to collapse, the rest of her sky dims, as if its light is being drawn in
var _dim = 0;
for (var h = 0; h < array_length(_holes); h++) {
	var _ho = _holes[h];
	if (_ho.age < HEX_GATHER) _dim = max(_dim, sqr(_ho.age / HEX_GATHER));
	else if (_ho.age < HEX_GATHER + _fps) _dim = max(_dim, sqr(1 - (_ho.age - HEX_GATHER) / _fps));   // her sky's light seeps back after the collapse
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
	scr_hex_draw_hole(_ho, _hx, _hy, spr_glow, _hdr);   // with the shader on, the disk, shadow and rings are drawn there
}

// THE BIG BANG, in her sky: a blinding core, and a shell of the universe's first light racing outward across everything
if (variable_global_exists("hex_bang") && is_struct(global.hex_bang)) {
	var _bt = global.hex_bang.t / _fps;
	var _bgd = point_distance(0, 0, global.hex_bang.ox, global.hex_bang.oy), _bga = point_direction(0, 0, global.hex_bang.ox, global.hex_bang.oy) + sky_angle;
	var _bgx = _px + lengthdir_x(_bgd, _bga), _bgy = _py + lengthdir_y(_bgd, _bga);
	gpu_set_blendmode(bm_add);
	if (_bt < 2) {
		var _ck2 = _bt / 2;
		draw_sprite_ext(spr_glow, 0, _bgx, _bgy, 14 * (1 - _ck2) + 2, 14 * (1 - _ck2) + 2, 0, c_white, sqr(1 - _ck2) * 1.5);   // the singularity's light
		draw_sprite_ext(spr_soft, 0, _bgx, _bgy, (60 + 400 * _ck2) / 20, (60 + 400 * _ck2) / 20, 0, make_color_rgb(255, 225, 190), 0.6 * sqr(1 - _ck2));
	}
	if (_bt < 1.8) {
		var _sk = _bt / 1.8;
		var _bsr = 30 + 1900 * (1 - sqr(1 - _sk));                               // the first light, racing out
		for (var w = 0; w < 7; w++) {
			draw_set_alpha((1 - _sk) * (1 - w / 7) * 0.9);
			draw_set_color(merge_color(c_white, make_color_rgb(180, 205, 255), w / 7));
			draw_circle(_bgx, _bgy, max(1, _bsr - w * 5), true);
		}
		draw_set_alpha(1);
	}
}
// the gathered light reaches the screen through the camera curve: rich color that rolls off toward white, never clipping flat
if (_hdr) {
	surface_reset_target();
	gpu_set_blendmode(bm_add);
	shader_set(_sht);
	shader_set_uniform_f(shader_get_uniform(_sht, "u_exposure"), 1);
	var _mdg = variable_global_exists("hex_mood") && variable_struct_exists(global.hex_mood, "gr");   // the aeon's color grade (scr_hex_aeon_step)
	shader_set_uniform_f(shader_get_uniform(_sht, "u_grade"), _mdg ? global.hex_mood.gr : 1, _mdg ? global.hex_mood.gg : 1, _mdg ? global.hex_mood.gb : 1);
	shader_set_uniform_f(shader_get_uniform(_sht, "u_lift"), _mdg ? global.hex_mood.lift * 0.4 : 0, _mdg ? global.hex_mood.lift * 0.6 : 0, _mdg ? global.hex_mood.lift : 0);
	draw_surface_stretched(sky_b, _vx, _vy, _vw, _vh);
	shader_reset();
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
	shader_set_uniform_f(u_ts_desat, _drained ? 0.6 : 0);   // full color until the glitch's white frame
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
		shader_set_uniform_f(u_ts_desat, 0);    // her ingredients keep their color: they're coming with her
		shader_set_uniform_f(u_ts_tint, 1, 1, 1);
		shader_set_uniform_f(u_ts_dark, 0);
		shader_set_uniform_f(u_ts_solid, 0);
		with (obj_enemy_parent) {          // sprite enemies go through the grey shader
			if (unmaking <= 0 || sprite_index < 0) continue;
				draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, image_blend, 1);
	}
		shader_reset();
		// toads are drawn with plain shapes, which the shader can't see, so they drain their own colors (obj_toad Draw)
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
			// like a color channel slipping out of line
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


// ---- stardust (stage 1): the doomed stand in full color, then burn away pixel by pixel from the head down.
// every pixel that goes becomes a mote (Step), so the body really does turn into the dust ----
gpu_set_blendmode(bm_normal);
shader_set(sh_crumble);
shader_set_uniform_f(u_cr_edge, 0.85, 0.65, 1.0);    // the burning edge: her white-violet
with (obj_enemy_parent) {
	if (unmaking <= 0 || sprite_index < 0) continue;
	if (other.t < other.birth_at || !variable_instance_exists(id, "crumble_at")) continue; // until then, the frozen copy IS this enemy
	if (point_distance(_px, _py, x, y) > _r) continue;
	var _ck = clamp((other.t - crumble_at) / other.crumble_len, 0, 1);
	if (_ck >= 1) continue;                                              // nothing left but dust
	var _uv  = sprite_get_uvs(sprite_index, image_index);
	var _tex = sprite_get_texture(sprite_index, image_index);
	shader_set_uniform_f(other.u_cr_uvs, _uv[0], _uv[1], _uv[2], _uv[3]);
	shader_set_uniform_f(other.u_cr_texel, texture_get_texel_width(_tex), texture_get_texel_height(_tex));
	shader_set_uniform_f(other.u_cr_cut, _ck);
	draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, c_white, 1); // white: exactly how it stood frozen, so nothing jumps
}
shader_reset();
gpu_set_blendmode(bm_add);

// ---- stardust (stage 2): protostars. inside the cloud, a cocoon of glowing gas gathers around each star that's forming,
// and its core brightens with every thread of dust that lands, until it catches ----
for (var i = 0; i < array_length(protos); i++) {
	var _pg = protos[i];
	if (_pg.idx >= 0) continue;                                          // born: her sky draws it from here on
	var _pgl = point_distance(0, 0, _pg.ox, _pg.oy);
	var _pga = point_direction(0, 0, _pg.ox, _pg.oy) + sky_angle;
	var _pgx = _px + lengthdir_x(_pgl, _pga), _pgy = _py + lengthdir_y(_pgl, _pga);
	var _pgs = min(3, 0.6 + sqrt(_pg.landed) * 0.5);                     // grows with every thread that lands
	var _pgc = scr_hex_star_color(_pg.mp, _pg.ph);
	draw_sprite_ext(spr_soft, 0, _pgx, _pgy, (8 + _pgs * 6) / 20, (8 + _pgs * 6) / 20, 0, merge_color(_pgc, c_black, 0.3), 0.3); // the cocoon
	draw_sprite_ext(spr_glow, 0, _pgx, _pgy, _pgs * 3 / 15, _pgs * 3 / 15, 0, _pgc, 0.5);                          // the forming star
}

// ---- stardust (stage 3): the motes. each is born a solid chunk of the body, the exact color of its pixel, tumbling as it falls,
// then burns down into glowing dust in the color of its gas. star dust streams in as long bright threads, condensing into its
// star's color. cloud dust melts into gas: its streak fades out as a soft, edgeless glow fades in, drawn exactly like the haze it
// may leave, so coming to rest is invisible. passes: streaks, soft gas, soot, cores, chunks (one sprite each, so each stays one batch) ----
var _mn = array_length(motes);
for (var i = 0; i < _mn; i++) {                                                 // the streaks: every mote in flight
	var _mt  = motes[i];
	if (_mt.strm || _mt.age <= gas_time + 1) {                                  // its color only changes while it burns into gas (or condenses into its star)
		var _mcol = merge_color(_mt.c0, _mt.cg, clamp(_mt.age / gas_time, 0, 1)); // its creature's color, glowing into its gas
		if (_mt.strm) _mcol = merge_color(_mcol, _mt.cs, clamp(1 - _mt.d / 80, 0, 1)); // star dust condenses into its star's color
		_mt.col = _mcol;
	}
	var _col = _mt.col;
	_mt.lit = (_mt.age >= chunk_time) ? 1 : clamp((_mt.age - chunk_time * 0.3) / (chunk_time * 0.7), 0, 1);   // the glow grows in as the chunk burns down
	var _ssp = _mt.strm ? 0 : _mt.sp;                                           // how settled it is (cloud dust only)
	if (_ssp >= 0.99 || _mt.fd <= 0.01) continue;                               // settled into gas: no streak left to draw
	var _msp = point_distance(0, 0, _mt.vx, _mt.vy);
	var _glx = _mt.strm ? 4 + _msp * 3 : 3.5 + _msp * 1.5;                      // star dust: long, thin threads. cloud dust: short streaks
	var _gly = _mt.strm ? 2.2 : 3;
	var _ga  = _mt.strm ? 0.85 : (_mt.dk ? 0.18 : 0.5);
	draw_sprite_ext(spr_glow, 0, _px + _mt.mx, _py + _mt.my, _glx / 15, _gly / 15,
		point_direction(0, 0, _mt.vx, _mt.vy), _col, _ga * _mt.lit * _mt.fd * (1 - _ssp));   // fading out as it settles
}
for (var i = 0; i < _mn; i++) {                                                 // the soft gas: cloud dust melting into a glow with no edges
	var _mt = motes[i];
	if (_mt.strm || _mt.dk || _mt.sp <= 0) continue;
	var _gsa = lerp(4, _mt.re, _mt.sp);                                         // it puffs out as it slows
	draw_sprite_ext(spr_soft, 0, _px + _mt.mx, _py + _mt.my, _gsa / 20, _gsa / 20, 0, _mt.col, _mt.ae * _mt.sp * _mt.lit * _mt.fd);
}
gpu_set_blendmode(bm_subtract);                                                 // soot settles as darkness, the same way the soot haze is drawn
for (var i = 0; i < _mn; i++) {
	var _mt = motes[i];
	if (_mt.strm || !_mt.dk || _mt.sp <= 0) continue;
	var _gsa = lerp(4, _mt.re, _mt.sp);
	draw_sprite_ext(spr_soft, 0, _px + _mt.mx, _py + _mt.my, _gsa / 20, _gsa / 20, 0,
		merge_color(c_black, c_white, 0.25 * _neb * _mt.sp * _mt.fd), 1);
}
gpu_set_blendmode(bm_add);
for (var i = 0; i < _mn; i++) {                                                 // the hot cores, fading out as cloud dust settles
	var _mt = motes[i];
	var _ca = (_mt.dk ? 0.6 : 1) * _mt.lit * _mt.fd * (1 - (_mt.strm ? 0 : _mt.sp));
	if (_ca <= 0.01) continue;
	draw_sprite_ext(spr_dot, 0, _px + _mt.mx, _py + _mt.my, 1.4 / 15, 1.4 / 15, 0,
		_mt.dk ? _mt.col : merge_color(_mt.col, c_white, 0.45), _ca);
}
gpu_set_blendmode(bm_normal);                                                   // the chunks are solid pieces of the body, not light
for (var i = 0; i < _mn; i++) {
	var _mt = motes[i];
	if (_mt.age >= chunk_time) continue;                                        // burned down to dust already
	var _kk = _mt.age / chunk_time;
	var _sz = _mt.ps * (1 - 0.7 * _kk) / 4;                                     // spr_px is 4 pixels wide: this makes it one body pixel, shrinking
	draw_sprite_ext(spr_px, 0, _px + _mt.mx, _py + _mt.my, _sz, _sz, _mt.rot + _mt.spin * _mt.age,
		merge_color(_mt.c0, c_white, 0.35 * _kk), 1 - _kk * _kk);              // heating toward white as it breaks down, then gone
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
// warping in (and out): streaks of light rush past her as her universe opens, outward going in, inward coming back
if (gaze && _open < 1) {
	var _wout = (duration == infinity);                              // opening: streaks fly outward. closing: they rush back in
	for (var _wk = 0; _wk < 56; _wk++) {
		var _wh  = scr_hash(_wk * 3.7), _wh2 = scr_hash(_wk * 9.1 + 2);
		var _wang = _wh * 360;
		var _wu  = frac(_wh2 + (_wout ? 1 : -1) * current_time / 400); // each streak loops along its line
		var _wd0 = _diag * 0.6 * (_wout ? _wu : 1 - _wu), _wd1 = _wd0 + 30 + 90 * _wh;
		draw_set_alpha(0.7 * (1 - _open) * sin(_wu * pi));
		draw_line_width_color(_px + lengthdir_x(_wd0, _wang), _py + lengthdir_y(_wd0, _wang), _px + lengthdir_x(_wd1, _wang), _py + lengthdir_y(_wd1, _wang),
			1.5, merge_color(HEX_VIOLET, c_white, 0.6), c_black);
	}
	draw_set_alpha(1);
}

gpu_pop_state();
// her outline, drawn additively so it glows against the dark
gpu_set_blendmode(bm_add);

var _pulse = 0.7 + 0.3 * sin(current_time / 250) + ((pulse_t >= 0 && pulse_t < _fps * 0.6) ? 1 - pulse_t / (_fps * 0.6) : 0);
scr_draw_glow_outline(obj_player, HEX_VIOLET, 2, 0.55 * _pulse);
scr_draw_glow_outline(obj_player, make_color_rgb(230, 200, 255), 1, 0.5 * _pulse);
scr_draw_glow_outline(obj_familiar_controller, HEX_VIOLET, 1, 0.4 * _pulse);
gpu_set_blendmode(bm_normal);
// the end of the universe and the first instant of the next, also in the world itself, so nothing can hide them
if (variable_global_exists("hex_mood") && global.hex_mood.dark > 0.003) {
	draw_set_color(c_black); draw_set_alpha(min(1, global.hex_mood.dark));
	draw_rectangle(_vx - 8, _vy - 8, _vx + _vw + 8, _vy + _vh + 8, false);
	draw_set_alpha(1);
}
if (variable_global_exists("hex_bang") && is_struct(global.hex_bang) && global.hex_bang.t < _fps * 1.4) {
	var _wt = global.hex_bang.t / _fps;
	draw_set_color(make_color_rgb(255, 250, 240)); draw_set_alpha((_wt < 0.25) ? 1 : sqr(1 - (_wt - 0.25) / 1.15));
	draw_rectangle(_vx - 8, _vy - 8, _vx + _vw + 8, _vy + _vh + 8, false);
	draw_set_alpha(1);
}

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
	if (impact_kind == 0 || impact_kind == 2) {   // 0: a black hole is born. 2: a supernova
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
	var _R = scr_hex_hole_radius(HEX_COLLAPSE_MASS) * ((impact_kind == 2) ? 0.4 : 1);   // a supernova's core is a point of light, not a hole
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
// PERF PROBE: the first few frames, and then once a second, print how long this Draw took
if (prof_frames < 6 || t mod 60 == 0) show_debug_message("[UNMAKING] t " + string(t) + " draw " + string((get_timer() - _prof_d) / 1000) + " ms | fps " + string(fps_real));
prof_frames++;
