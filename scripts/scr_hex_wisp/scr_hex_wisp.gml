// scr_hex_wisp: the Hex wisp. Her curse drawn as living smoke instead of circles. (notes/hex-wisp.md)
//
// Once a frame, from obj_player's Draw event:
//   1. FIELD   A small picture (the camera's view / HEX_WISP_DIV) holds all of the wisp's light. There are two, swapped every frame.
//   2. FLOW    sh_hex_wisp_flow carries last frame's field forward along a swirling current and fades it a little, so the light her
//              motes leave behind trails away as smoke. It also scrolls with the camera, so the smoke stays put in the world.
//   3. STAMP   every mote stamps soft light into the field where it is now (several stamps along its path when it's fast, so
//              streams stay unbroken). channels: r = smoke, g = core, b = energy flowing home.
//   4. DRAW    sh_hex_wisp_draw turns the field into smoke and light and puts it on screen.
//
// BALLS (slice 1.1): the wisp should read as a ball of magic that is forever collapsing, not smoke that blows away. So anything that
// is "a ball of her magic" (the ball in her hand, the charging orb, what she is holding, a shot in flight) registers itself each
// frame with hex_wisp_att(x, y, radius, strength). Around each one the flow shader calms the wandering current and pulls the smoke
// in along a spiral, eating it at the middle; the draw shader adds inward-turning spiral arms and a dense core. A shot also leaves
// a short wake. The list is cleared after every draw, so a ball that stops being registered simply stops being drawn.
//
// The wisp reads only the motes (x, y, vx, vy, st) and whether her stance is active, so any later Hex effect (the orb in flight,
// an earth rip, a curse) joins the same smoke by stamping into the field (see hex_wisp_stamp). Nothing here changes gameplay.
//
// HEX ORB (slice 2): the default look. Instead of smoke, each ball of her magic is drawn by sh_hex_orb as a small cloud of
// ionized hex energy. Three looks, cycled with O: 0 = hex orb, 1 = smoke wisp, 2 = original circles. P = next palette.

#macro HEX_WISP_DIV 4   // world pixels per field pixel. 4 = a 640 x 360 field for the 2560 x 1440 view. Smaller = finer smoke, slower.
#macro HEX_ORB_PX 2.5    // the hex is drawn in steps of this many world pixels (her sprite art is 4; was 2: a touch chunkier reads better on the grass)

// ---- palettes: five numbers each, 0 to 255 per channel ----
//   smoke = the faint outer cloud, glow = the body, core = the bright heart, spark = the tiny thread dots and the tint of energy
//   flowing home, hot = how white the very brightest part burns (0 to 1)
function hex_wisp_lerp3(_a, _b, _t) {
	return [lerp(_a[0], _b[0], _t), lerp(_a[1], _b[1], _t), lerp(_a[2], _b[2], _t)];
}
function hex_wisp_pal_mix(_name, _a, _b, _t) {
	return {
		name: _name,
		smoke: hex_wisp_lerp3(_a.smoke, _b.smoke, _t),
		glow:  hex_wisp_lerp3(_a.glow,  _b.glow,  _t),
		core:  hex_wisp_lerp3(_a.core,  _b.core,  _t),
		spark: hex_wisp_lerp3(_a.spark, _b.spark, _t),
		hot:   lerp(_a.hot, _b.hot, _t)
	};
}
// an array of 0-255 numbers as a GameMaker color, optionally dimmed
function hex_wisp_col(_c, _mul = 1) {
	return make_color_rgb(clamp(_c[0] * _mul, 0, 255), clamp(_c[1] * _mul, 0, 255), clamp(_c[2] * _mul, 0, 255));
}

// everything the wisp remembers between frames lives in one global struct, built the first time anything asks for it
function hex_wisp_state() {
	if (!variable_global_exists("hex_wisp")) {
		// the original lilac: exactly the colors obj_player drew before the shader (smoke, glow and thread were these three)
		var _coven = { name: "Coven violet-blue", smoke: [14, 0, 86], glow: [41, 7, 175], core: [57, 17, 243], spark: [222, 190, 255], hot: 0.30 };
		var _lilac = { name: "lilac (original)", smoke: [60, 30, 120], glow: [110, 70, 200], core: [200, 175, 255], spark: [200, 175, 255], hot: 0 };
		// the signature blue. Core, glow and smoke use the RGB values Sophia chose for the Wanda-inspired pass
		var _blue  = { name: "blue", smoke: [19, 0, 101], glow: [41, 7, 175], core: [57, 17, 243], spark: [180, 180, 252], hot: 0.30 };
		// the exact middle of the two, tier by tier
		var _mid   = hex_wisp_pal_mix("midpoint", _lilac, _blue, 0.5);
		global.hex_wisp = {
			on: true,
			mode: 0,
			pal: 0,              // which palette
			pals: [_coven, _blue, _mid, _lilac],
			eE: 0.12,
			eR: 9,
			opx: HEX_ORB_PX,     // live tuning (K): the hex's pixel size, 2 or 2.5
			oscale: 1,           // live tuning (L): the orb's size, 1 / 1.5 / 2
			uo: undefined,
			flash: 0,            // frames left to show the palette name above her
			a: -1, b: -1,        // the two fields
			w: 0, h: 0,          // their size, in field pixels
			fmt: -1,             // surface format (16-bit float if the machine has it)
			vx: 0, vy: 0,        // where the camera was last frame
			has_prev: false,
			att: [],             // the balls registered this frame (hex_wisp_att)
			u: undefined,        // shader uniform handles, looked up once
			// the knobs. everything about how the wisp moves and looks is here.
			k: {
				flow: 2.2,       // strength of the wandering current, in field pixels a frame (more = more curling and drifting)
				decay: 0.93,     // how much light survives a frame (0.93 = a trail about 14 frames long; higher = longer trails)
				cell: 26,        // size of the biggest swirl, in field pixels (4 world pixels each)
				smoke_r: 14,     // stamp sizes, in WORLD pixels
				core_r: 6,
				home_r: 10,
				smoke_act: 0.028, smoke_rest: 0.013,   // how much smoke each mote stamps (active stance / at rest)
				core_act: 0.12,   core_rest: 0.06,     // how much core
				home_amt: 0.45,                        // extra for energy flowing home (what makes the return read)
				gain: 1.3,       // how fast density becomes light
				bright: 0.95,    // how opaque the smoke gets
				add: 0.3,        // extra glow the hot part adds on top
				detail: 0.7,     // fine wispy filaments (0 = smooth)
				// the collapse (around each registered ball)
				pull: 1.0,       // how fast smoke falls toward a ball, in field pixels a frame (more = tighter, faster collapse)
				swirl: 0.9,      // how fast it circles the ball as it falls (0 = straight in, more = a tighter spiral)
				eat: 0.12,       // how much light at the middle is swallowed each frame (keeps the core from piling up)
				arms: 0.75,      // how bright the inward-turning spiral arms are (0 = no arms)
				ball: 1.5,       // how dense the ball at the middle is
				spin: 7.0        // how fast the arms turn and fall in (radians a second)
			}
		};
	}
	return global.hex_wisp;
}
function hex_wisp_pal() {
	var _s = hex_wisp_state();
	return _s.pals[_s.pal];
}

// debug keys, called every Step from obj_player
function hex_wisp_debug_keys() {
	var _s = hex_wisp_state();
	if (keyboard_check_pressed(ord("O"))) { _s.mode = (_s.mode + 1) mod 3; _s.on = (_s.mode != 2); _s.flash = 120; }
	if (keyboard_check_pressed(ord("P"))) { _s.pal = (_s.pal + 1) mod array_length(_s.pals); if (_s.mode == 2) _s.mode = 0; _s.on = true; _s.flash = 120; }
	// live tuning while we pick the hex orb's look in game: K = pixel size (2, 3, 4), L = size (1x, 1.5x, 2x)
	if (keyboard_check_pressed(ord("K"))) { _s.opx = (_s.opx == 2) ? 2.5 : 2; _s.flash = 120; }   // 2 or 2.5 (still deciding)
	if (keyboard_check_pressed(ord("L"))) { _s.oscale = (_s.oscale >= 2) ? 1 : _s.oscale + 0.5; _s.flash = 120; }
	if (_s.flash > 0) _s.flash--;
}

// the palette's name and core color, shown above her for a moment after a key press
function hex_wisp_label(_x, _y) {
	var _s = hex_wisp_state();
	if (_s.flash <= 0) return;
	var _p = _s.pals[_s.pal];
	var _t = "old circles";
	if (_s.mode != 2) _t = ((_s.mode == 0) ? "hex orb: " : "smoke wisp: ") + _p.name + "   core " + string(floor(_p.core[0] + 0.5)) + ", " + string(floor(_p.core[1] + 0.5)) + ", " + string(floor(_p.core[2] + 0.5));
	if (_s.mode == 0) _t += "   pixels " + string(_s.opx) + "   size " + string(_s.oscale) + "x";
	var _ha = draw_get_halign(), _va = draw_get_valign();
	draw_set_halign(fa_center);
	draw_set_valign(fa_bottom);
	draw_set_alpha(min(1, _s.flash / 30));
	draw_set_color(c_black);
	draw_text_transformed(_x + 1, _y + 1, _t, 2, 2, 0);
	draw_set_color(c_white);
	draw_text_transformed(_x, _y, _t, 2, 2, 0);
	draw_set_halign(_ha);
	draw_set_valign(_va);
	draw_set_alpha(1);
	draw_set_color(c_white);
}

// register a ball of her magic for this frame. _x, _y in the room, _r its radius in world pixels (the arms reach about 4 radii out),
// _s how strong 0 to 1. _vx, _vy and _wake: a ball in flight that leaves a short trail (its speed in world pixels a frame).
// _oR and _oE are for the hex orb. At most eight balls count. Call before hex_wisp_draw or hex_orb_draw each frame.
// _oM: 0 = an orb, 2 = hex flame (exertion; then _oF is how present it is, 0..1). _oC: how formed an orb's heart is (0..1).
// _oV: how thick the orb's veil is (1 = normal)
function hex_wisp_att(_x, _y, _r, _s, _vx = 0, _vy = 0, _wake = false, _oR = 6, _oE = 0.3, _oF = 0, _oS = 1, _oH = 0, _oM = 0, _oC = 1, _oV = 1) {
	var _l = hex_wisp_state().att;
	if (array_length(_l) >= 8) return;
	array_push(_l, { x: _x, y: _y, r: _r, s: _s, vx: _vx, vy: _vy, wake: _wake, oR: _oR, oE: _oE, oF: _oF, oS: _oS, oH: _oH, oM: _oM, oC: _oC, oV: _oV });   // oH: the radius of something held inside it (0 = none)   // oF: the orb's overflow (0..1, for holding something)
}

// the hex orb shader's uniform handles, looked up once
function hex_orb_uniforms() {
	var _s = hex_wisp_state();
	if (is_undefined(_s.uo)) _s.uo = {
		center: shader_get_uniform(sh_hex_orb, "u_center"), box: shader_get_uniform(sh_hex_orb, "u_box"), R: shader_get_uniform(sh_hex_orb, "u_R"),
		energy: shader_get_uniform(sh_hex_orb, "u_energy"), time: shader_get_uniform(sh_hex_orb, "u_time"), seed: shader_get_uniform(sh_hex_orb, "u_seed"),
		smoke: shader_get_uniform(sh_hex_orb, "u_smoke"), glow: shader_get_uniform(sh_hex_orb, "u_glow"), core: shader_get_uniform(sh_hex_orb, "u_core"),
		spark: shader_get_uniform(sh_hex_orb, "u_spark"), hot: shader_get_uniform(sh_hex_orb, "u_hot"),
		px: shader_get_uniform(sh_hex_orb, "u_px"), veil: shader_get_uniform(sh_hex_orb, "u_veil"), over: shader_get_uniform(sh_hex_orb, "u_over"),
		strand: shader_get_uniform(sh_hex_orb, "u_strand"),
		hollow: shader_get_uniform(sh_hex_orb, "u_hollow"), heart: shader_get_uniform(sh_hex_orb, "u_heart"), rv: shader_get_uniform(sh_hex_orb, "u_rv"), rv2: shader_get_uniform(sh_hex_orb, "u_rv2"), mode: shader_get_uniform(sh_hex_orb, "u_mode"), n: shader_get_uniform(sh_hex_orb, "u_n"), motes: shader_get_uniform(sh_hex_orb, "u_motes")
	};
	return _s.uo;
}

function hex_orb_draw() {
	var _s = hex_wisp_state(), _pal = _s.pals[_s.pal];
	hex_orb_uniforms();
	var _u = _s.uo, _n = array_length(_s.att);
	if (_n > 0) {
		gpu_push_state(); gpu_set_blendenable(true); gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha); draw_set_alpha(1); shader_set(sh_hex_orb);
		shader_set_uniform_f(_u.time, current_time / 1000);
		shader_set_uniform_f(_u.smoke, _pal.smoke[0] / 255, _pal.smoke[1] / 255, _pal.smoke[2] / 255);
		shader_set_uniform_f(_u.glow, _pal.glow[0] / 255, _pal.glow[1] / 255, _pal.glow[2] / 255);
		shader_set_uniform_f(_u.core, _pal.core[0] / 255, _pal.core[1] / 255, _pal.core[2] / 255);
		shader_set_uniform_f(_u.spark, _pal.spark[0] / 255, _pal.spark[1] / 255, _pal.spark[2] / 255); shader_set_uniform_f(_u.hot, _pal.hot);
		shader_set_uniform_f(_u.px, _s.opx);         // the magic is drawn in steps this many world pixels big (K cycles it)
		for (var _i = 0; _i < _n; _i++) {
			var _b = _s.att[_i], _R = max(3, _b.oR) * _s.oscale, _box = ceil(_R * ((_b.oM == 2) ? 5 : 16) / 2) * 2 + 16, _cx = floor(_b.x), _cy = floor(_b.y);   // (a flame needs far less room than an orb's halo)
			shader_set_uniform_f(_u.mode, _b.oM);
			// (the square reaches 8x the core radius each way: the widest the charged halo gets is about 7x)
			shader_set_uniform_f(_u.center, _b.x, _b.y); shader_set_uniform_f(_u.box, _box, _box); shader_set_uniform_f(_u.R, _R);
			shader_set_uniform_f(_u.energy, clamp(_b.oE, 0, 1)); shader_set_uniform_f(_u.seed, _i + 1);
			shader_set_uniform_f(_u.over, clamp(_b.oF, 0, 1));
			shader_set_uniform_f(_u.strand, _b.oS);
			shader_set_uniform_f(_u.hollow, _b.oH);
			shader_set_uniform_f(_u.heart, _b.oC);
			shader_set_uniform_f(_u.veil, _b.oV);
			draw_rectangle(_cx - _box / 2, _cy - _box / 2, _cx + _box / 2, _cy + _box / 2, false);
		}
		shader_reset(); gpu_pop_state();
	}
	_s.att = [];
}

// THE RIVER: a stream of her hex along a path from her palm (_ax, _ay) to (_bx, _by), bending through (_cx, _cy) (a
// quadratic bezier). Only the stretch _lo.._hi of it is there (0 = her palm, 1 = the far end). _amt is how much hex it's
// carrying (more = a wider, brighter river); _dir 1 = flowing out from her, -1 = flowing home to her. Drawn with the hex
// shader's river mode (u_mode 3): a dark body of hex smoke with bright strands of light running through it, like Wanda's
// hex pouring out of her. Draw it BEFORE hex_orb_draw.
function hex_river_draw(_ax, _ay, _bx, _by, _cx, _cy, _lo, _hi, _amt, _dir) {
	if (_hi - _lo <= 0.001) return;
	var _s = hex_wisp_state(), _pal = _s.pals[_s.pal], _u = hex_orb_uniforms();
	var _w = 2.5 + 4 * sqrt(clamp(_amt, 0, 24) / 14);                  // half-width of the smoke body, in world pixels
	var _fx = floor(_ax), _fy = floor(_ay);
	var _pad = _w * 2 + 12;
	var _x0 = min(_ax, _bx, _cx) - _pad, _y0 = min(_ay, _by, _cy) - _pad, _x1 = max(_ax, _bx, _cx) + _pad, _y1 = max(_ay, _by, _cy) + _pad;
	gpu_push_state(); gpu_set_blendenable(true); gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha); draw_set_alpha(1); shader_set(sh_hex_orb);
	shader_set_uniform_f(_u.mode, 3);
	shader_set_uniform_f(_u.rv, _bx - _fx, _by - _fy, _cx - _fx, _cy - _fy);
	shader_set_uniform_f(_u.rv2, _lo, _hi, _w, _dir);
	shader_set_uniform_f(_u.time, current_time / 1000); shader_set_uniform_f(_u.seed, 5);
	shader_set_uniform_f(_u.center, _fx, _fy); shader_set_uniform_f(_u.px, _s.opx);
	shader_set_uniform_f(_u.smoke, _pal.smoke[0] / 255, _pal.smoke[1] / 255, _pal.smoke[2] / 255);
	shader_set_uniform_f(_u.glow, _pal.glow[0] / 255, _pal.glow[1] / 255, _pal.glow[2] / 255);
	shader_set_uniform_f(_u.core, _pal.core[0] / 255, _pal.core[1] / 255, _pal.core[2] / 255);
	shader_set_uniform_f(_u.spark, _pal.spark[0] / 255, _pal.spark[1] / 255, _pal.spark[2] / 255); shader_set_uniform_f(_u.hot, _pal.hot);
	draw_rectangle(_x0, _y0, _x1, _y1, false);
	shader_reset(); gpu_pop_state();
}

// stamp soft light into the field. _x, _y in field pixels, _r the radius in field pixels, _col the amounts (r = smoke, g = core,
// b = energy flowing home). a soft round blob: full strength in the middle, fading to nothing at the edge. only call this while
// the field is the draw target and additive blending is on (hex_wisp_draw does both).
function hex_wisp_stamp(_x, _y, _r, _col) {
	draw_circle_colour(_x, _y, _r, _col, c_black, false);
}

// the whole wisp (the old smoke-wisp look, O). _motes = an array of motes (empty now: her hex is one amount), _active = hex_active (her stance is up). Call from a Draw event, in the room's
// coordinates, BEFORE any additive extras (it sets and restores its own GPU state).
function hex_wisp_draw(_motes, _active) {
	var _s = hex_wisp_state();
	var _k = _s.k;
	var _cam = view_camera[0];
	var _vx = camera_get_view_x(_cam), _vy = camera_get_view_y(_cam);
	var _vw = camera_get_view_width(_cam), _vh = camera_get_view_height(_cam);
	var _w = max(8, ceil(_vw / HEX_WISP_DIV)), _h = max(8, ceil(_vh / HEX_WISP_DIV));

	if (_s.fmt == -1) _s.fmt = surface_format_is_supported(surface_rgba16float) ? surface_rgba16float : surface_rgba8unorm;

	// (re)build the fields if they were lost (alt-tab, window changes) or the view changed size
	if (!surface_exists(_s.a) || !surface_exists(_s.b) || _s.w != _w || _s.h != _h) {
		if (surface_exists(_s.a)) surface_free(_s.a);
		if (surface_exists(_s.b)) surface_free(_s.b);
		_s.a = surface_create(_w, _h, _s.fmt);
		_s.b = surface_create(_w, _h, _s.fmt);
		_s.w = _w; _s.h = _h;
		surface_set_target(_s.a); draw_clear_alpha(c_black, 0); surface_reset_target();
		surface_set_target(_s.b); draw_clear_alpha(c_black, 0); surface_reset_target();
		_s.has_prev = false;
	}

	// how far the camera moved since last frame, in field pixels (so the smoke stays where it was in the world)
	var _dx = 0, _dy = 0;
	if (_s.has_prev) { _dx = (_vx - _s.vx) / HEX_WISP_DIV; _dy = (_vy - _s.vy) / HEX_WISP_DIV; }
	_s.vx = _vx; _s.vy = _vy; _s.has_prev = true;
	if (abs(_dx) > _w * 0.5 || abs(_dy) > _h * 0.5) {   // the camera jumped (a room change): start the smoke fresh
		surface_set_target(_s.a); draw_clear_alpha(c_black, 0); surface_reset_target();
		_dx = 0; _dy = 0;
	}

	// shader handles, looked up once
	if (is_undefined(_s.u)) {
		_s.u = {
			f_texel: shader_get_uniform(sh_hex_wisp_flow, "u_texel"),
			f_uvmax: shader_get_uniform(sh_hex_wisp_flow, "u_uvmax"),
			f_size:  shader_get_uniform(sh_hex_wisp_flow, "u_size"),
			f_org:   shader_get_uniform(sh_hex_wisp_flow, "u_org"),
			f_shift: shader_get_uniform(sh_hex_wisp_flow, "u_shift"),
			f_time:  shader_get_uniform(sh_hex_wisp_flow, "u_time"),
			f_flow:  shader_get_uniform(sh_hex_wisp_flow, "u_flow"),
			f_decay: shader_get_uniform(sh_hex_wisp_flow, "u_decay"),
			f_cut:   shader_get_uniform(sh_hex_wisp_flow, "u_cut"),
			f_cell:  shader_get_uniform(sh_hex_wisp_flow, "u_cell"),
			f_att:   shader_get_uniform(sh_hex_wisp_flow, "u_att"),
			f_pull:  shader_get_uniform(sh_hex_wisp_flow, "u_pull"),
			f_swirl: shader_get_uniform(sh_hex_wisp_flow, "u_swirl"),
			f_eat:   shader_get_uniform(sh_hex_wisp_flow, "u_eat"),
			d_uvmax: shader_get_uniform(sh_hex_wisp_draw, "u_uvmax"),
			d_size:  shader_get_uniform(sh_hex_wisp_draw, "u_size"),
			d_org:   shader_get_uniform(sh_hex_wisp_draw, "u_org"),
			d_time:  shader_get_uniform(sh_hex_wisp_draw, "u_time"),
			d_gain:  shader_get_uniform(sh_hex_wisp_draw, "u_gain"),
			d_bright: shader_get_uniform(sh_hex_wisp_draw, "u_bright"),
			d_detail: shader_get_uniform(sh_hex_wisp_draw, "u_detail"),
			d_hot:   shader_get_uniform(sh_hex_wisp_draw, "u_hot"),
			d_add:   shader_get_uniform(sh_hex_wisp_draw, "u_add"),
			d_smoke: shader_get_uniform(sh_hex_wisp_draw, "u_smoke"),
			d_glow:  shader_get_uniform(sh_hex_wisp_draw, "u_glow"),
			d_core:  shader_get_uniform(sh_hex_wisp_draw, "u_core"),
			d_spark: shader_get_uniform(sh_hex_wisp_draw, "u_spark"),
			d_att:   shader_get_uniform(sh_hex_wisp_draw, "u_att"),
			d_arms:  shader_get_uniform(sh_hex_wisp_draw, "u_arms"),
			d_ball:  shader_get_uniform(sh_hex_wisp_draw, "u_ball"),
			d_spin:  shader_get_uniform(sh_hex_wisp_draw, "u_spin")
		};
	}
	var _u = _s.u;
	var _tex = surface_get_texture(_s.a);
	var _tw = texture_get_texel_width(_tex), _th = texture_get_texel_height(_tex);   // (not 1 / size if the driver padded the texture)
	var _t = current_time / 1000;
	var _pal = _s.pals[_s.pal];

	// the registered balls, as four (x, y, radius, strength) in field pixels from the view's top-left. unused slots have strength 0.
	var _att = array_create(16, 0);
	for (var _i = 0; _i < 4; _i++) _att[_i * 4 + 2] = 1;
	var _na = array_length(_s.att);
	for (var _i = 0; _i < min(_na, 4); _i++) {
		var _b = _s.att[_i];
		_att[_i * 4]     = (_b.x - _vx) / HEX_WISP_DIV;
		_att[_i * 4 + 1] = (_b.y - _vy) / HEX_WISP_DIV;
		_att[_i * 4 + 2] = max(1, _b.r / HEX_WISP_DIV);
		_att[_i * 4 + 3] = clamp(_b.s, 0, 1);
	}

	gpu_push_state();
	gpu_set_tex_filter(true);   // smooth the field (the game itself is set to crisp pixels)
	draw_set_alpha(1);          // (additive stamps scale with the draw alpha, so make sure nothing left it dimmed)

	// ---- 1. FLOW: last frame's field, carried along the current, into the other surface ----
	surface_set_target(_s.b);
	gpu_set_blendenable(false);   // replace what's there, don't blend with it
	shader_set(sh_hex_wisp_flow);
	shader_set_uniform_f(_u.f_texel, _tw, _th);
	shader_set_uniform_f(_u.f_uvmax, _w * _tw, _h * _th);
	shader_set_uniform_f(_u.f_size, _w, _h);
	shader_set_uniform_f(_u.f_org, _vx / HEX_WISP_DIV, _vy / HEX_WISP_DIV);
	shader_set_uniform_f(_u.f_shift, _dx, _dy);
	shader_set_uniform_f(_u.f_time, _t);
	shader_set_uniform_f(_u.f_flow, _k.flow);
	shader_set_uniform_f(_u.f_decay, _k.decay);
	shader_set_uniform_f(_u.f_cut, (_s.fmt == surface_rgba16float) ? 0 : 1.5 / 255);   // (8-bit surfaces need a nudge so faint light fully dies)
	shader_set_uniform_f(_u.f_cell, _k.cell);
	shader_set_uniform_f_array(_u.f_att, _att);
	shader_set_uniform_f(_u.f_pull, _k.pull);
	shader_set_uniform_f(_u.f_swirl, _k.swirl);
	shader_set_uniform_f(_u.f_eat, _k.eat);
	draw_surface_ext(_s.a, 0, 0, 1, 1, 0, c_white, 1);
	shader_reset();

	// ---- 2. STAMP: every mote leaves light where it is ----
	gpu_set_blendenable(true);
	gpu_set_blendmode(bm_add);
	var _sa = _active ? _k.smoke_act : _k.smoke_rest;
	var _ca = _active ? _k.core_act : _k.core_rest;
	var _n = array_length(_motes);
	for (var _i = 0; _i < _n; _i++) {
		var _m = _motes[_i];
		if (_m.st == 2 || _m.st == 4) continue;   // spent, or riding inside a shot: no light here
		var _sp = point_distance(0, 0, _m.vx, _m.vy);
		var _ns = clamp(ceil(_sp / (HEX_WISP_DIV * 3)), 1, 6);   // fast motes stamp along their path so streams stay unbroken (and burn a little brighter)
		// (stamp strengths are whole 0-255 steps, so they are never divided up per stamp: that would round them unevenly)
		var _cs = make_color_rgb(round(255 * _sa), 0, 0);
		var _cc = make_color_rgb(0, round(255 * _ca), 0);
		var _ch = make_color_rgb(0, 0, round(255 * _k.home_amt));
		for (var _j = 0; _j < _ns; _j++) {
			var _fr = (_ns == 1) ? 0 : _j / (_ns - 1);
			var _px = (_m.x - _m.vx * _fr - _vx) / HEX_WISP_DIV;
			var _py = (_m.y - _m.vy * _fr - _vy) / HEX_WISP_DIV;
			hex_wisp_stamp(_px, _py, _k.smoke_r / HEX_WISP_DIV, _cs);
			hex_wisp_stamp(_px, _py, _k.core_r / HEX_WISP_DIV, _cc);
			if (_m.st == 3) hex_wisp_stamp(_px, _py, _k.home_r / HEX_WISP_DIV, _ch);
		}
	}
	// a ball in flight leaves a short wake: stamps along the way it came this frame
	for (var _i = 0; _i < _na; _i++) {
		var _b = _s.att[_i];
		if (!_b.wake) continue;
		var _wn = clamp(ceil(point_distance(0, 0, _b.vx, _b.vy) / (HEX_WISP_DIV * 3)), 1, 6);
		var _wsm = make_color_rgb(clamp(round(255 * _sa * 1.5), 0, 255), 0, 0);
		var _wco = make_color_rgb(0, clamp(round(255 * _ca * 0.8), 0, 255), 0);
		for (var _j = 0; _j < _wn; _j++) {
			var _wf = (_wn == 1) ? 0 : _j / (_wn - 1);
			var _wx = (_b.x - _b.vx * _wf - _vx) / HEX_WISP_DIV;
			var _wy = (_b.y - _b.vy * _wf - _vy) / HEX_WISP_DIV;
			hex_wisp_stamp(_wx, _wy, _k.smoke_r / HEX_WISP_DIV, _wsm);
			hex_wisp_stamp(_wx, _wy, _k.core_r / HEX_WISP_DIV, _wco);
		}
	}
	surface_reset_target();

	// the stamped surface is now the current field
	var _tmp = _s.a; _s.a = _s.b; _s.b = _tmp;

	// ---- 3. DRAW: the field, as smoke and light, over the whole view ----
	gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha);   // premultiplied: smoke keeps its color over bright ground
	shader_set(sh_hex_wisp_draw);
	shader_set_uniform_f(_u.d_uvmax, _w * _tw, _h * _th);
	shader_set_uniform_f(_u.d_size, _w, _h);
	shader_set_uniform_f(_u.d_org, _vx / HEX_WISP_DIV, _vy / HEX_WISP_DIV);
	shader_set_uniform_f(_u.d_time, _t);
	shader_set_uniform_f(_u.d_gain, _k.gain);
	shader_set_uniform_f(_u.d_bright, _k.bright);
	shader_set_uniform_f(_u.d_detail, _k.detail);
	shader_set_uniform_f(_u.d_hot, _pal.hot);
	shader_set_uniform_f(_u.d_add, _k.add);
	shader_set_uniform_f_array(_u.d_att, _att);
	shader_set_uniform_f(_u.d_arms, _k.arms);
	shader_set_uniform_f(_u.d_ball, _k.ball);
	shader_set_uniform_f(_u.d_spin, _k.spin);
	shader_set_uniform_f(_u.d_smoke, _pal.smoke[0] / 255, _pal.smoke[1] / 255, _pal.smoke[2] / 255);
	shader_set_uniform_f(_u.d_glow,  _pal.glow[0]  / 255, _pal.glow[1]  / 255, _pal.glow[2]  / 255);
	shader_set_uniform_f(_u.d_core,  _pal.core[0]  / 255, _pal.core[1]  / 255, _pal.core[2]  / 255);
	shader_set_uniform_f(_u.d_spark, _pal.spark[0] / 255, _pal.spark[1] / 255, _pal.spark[2] / 255);
	draw_surface_stretched(_s.a, _vx, _vy, _vw, _vh);
	shader_reset();

	gpu_pop_state();
	_s.att = [];   // the balls are re-registered every frame
}
