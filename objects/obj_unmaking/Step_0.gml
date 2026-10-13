var _prof_s = get_timer();   // PERF PROBE
// THE CAPTURE KEY (C, held): stopwatches on every part of the Unmaking. while C is held, each section's time is recorded
// frame by frame; let go and HUD shows the slowest parts during exactly that moment. scr_prof_lap marks each section's end
// (HUD watches the key itself, so letting go after the Unmaking ends still shows the table)
scr_prof_start("Step");
if (!gaze && scr_freeze_if_paused()) exit;   // while gazing the world is frozen on purpose, but her sky keeps living
// diagnostic (cast or stargazing): L hides the fluid gas (its simulation keeps running), so anything still moving is another system
if (keyboard_check_pressed(ord("L"))) global.hex_fluid_hide = !(variable_global_exists("hex_fluid_hide") && global.hex_fluid_hide);
// O: PHYSICS ONLY on/off (legacy systems that reach into the physics switched off: scr_hex_iso)
if (keyboard_check_pressed(ord("O"))) global.hex_iso = !scr_hex_iso();
// T: the clock, full speed (1 second = 1 million years) or half speed (a slower wallpaper)
if (keyboard_check_pressed(ord("T"))) global.hex_time = (scr_hex_time() == 1) ? 0.5 : 1;
// pausing while sitting in her universe: Esc or P holds everything still (G still leaves)
if (gaze) {
	if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(ord("P"))) gaze_paused = !gaze_paused;
	if (keyboard_check_pressed(ord("H"))) {                                 // hide the HUD (and the cursor): nothing but her sky, a living wallpaper
		global.hex_hide_hud = !(variable_global_exists("hex_hide_hud") && global.hex_hide_hud);
		window_set_cursor(global.hex_hide_hud ? cr_none : cr_default);
	}
	if (keyboard_check_pressed(ord("J"))) global.hex_flow_on = !(!variable_global_exists("hex_flow_on") || global.hex_flow_on);   // debug: the currents on/off (compare)
	if (keyboard_check_pressed(ord("Y"))) { scr_hex_fluid_tier(); global.hex_fluid_q = (global.hex_fluid_q + 1) mod 3; }   // the fluid's quality tier: Low, High, HYPERMAX (compare cost and look live)
	if (keyboard_check_pressed(ord("R"))) global.hex_no_ripple = !(variable_global_exists("hex_no_ripple") && global.hex_no_ripple);   // debug: gravitational-wave ripples off/on
	if (keyboard_check_pressed(ord("I"))) global.hex_inspect = !(variable_global_exists("hex_inspect") && global.hex_inspect);   // inspect: name everything in her sky (HUD draws it)
	if (gaze_paused) {
		if (keyboard_check_pressed(ord("G")) && duration == infinity) { gaze_paused = false; duration = t + floor(game_get_speed(gamespeed_fps) * 0.5); }
		exit;
	}
}
if (clean_pending) exit; // the clean frame: draw nothing, so the bare world can be photographed (see Draw GUI Begin)

// hitstop: the impact frame freezes ALL of time for a few frames, then the shockwave lands
if (hitstop > 0) {
	hitstop--;
	if (hitstop == 0) global.shake = max(global.shake, (impact_kind == 1) ? 48 : 24);   // the shockwave lands as time resumes
	exit;
}
t++;
scr_prof_lap("pausing + hitstop");   // (capture key: C)
// the cast's heavy setup, a slice per frame while the entrance plays (Step has almost nothing else to do then):
// each doomed body plans its star and has its pixels read. a few bodies per frame, and at most two fresh sprite reads
// (each one waits on the graphics card), so casting never freezes
if (plan_qi < array_length(plan_queue)) {
	// (sprite pixels are kept for the whole game session, not just this cast: the same slimes never get read twice, and at most one
	// fresh read happens per frame, since each one stalls on the graphics card: that was the 49ms frame at the start of a big cast)
	if (!variable_global_exists("hex_pix_cache")) global.hex_pix_cache = {};
	pix_cache = global.hex_pix_cache;
	var _qn = array_length(plan_queue), _qend = min(_qn, plan_qi + 60), _qpx = 0;
	while (plan_qi < _qend && _qpx < 1) {
		var _qe = plan_queue[plan_qi];
		plan_qi++;
		if (!instance_exists(_qe)) continue;
		scr_hex_plan_star(_qe, sky_angle);
		if (_qe.sprite_index >= 0) {
			var _qkey = string(_qe.sprite_index) + ":" + string(floor(_qe.image_index));
			if (is_undefined(pix_cache[$ _qkey])) { pix_cache[$ _qkey] = scr_hex_sprite_pixels(_qe.sprite_index, floor(_qe.image_index)); _qpx++; }
			_qe.dust_pix = pix_cache[$ _qkey];
		}
	}
}
if (t == shatter_at) { hitstop = 10; impact_kind = 1; }   // the ground's impact frame: time freezes, then BOOM

scr_prof_lap("cast setup slices");   // (capture key: C)
// her black holes keep time. while one is gathering, time itself drags: the sky's turning slows to a stop
var _slow = 1;
for (var h = 0; h < array_length(global.hex_holes); h++) {
	var _ho = global.hex_holes[h];
	_ho.age++;
	var _hsz = scr_hex_hole_size(_ho, false);                                 // its drawn size eases toward its true size: no snapping
	_ho.rs = variable_struct_exists(_ho, "rs") ? lerp(_ho.rs, _hsz, variable_struct_exists(_ho, "ck") ? 0.25 : 0.04) : _hsz;
	if (_ho.age == HEX_GATHER) {
		hitstop = 10; impact_kind = 0;
		// fallback: the dead star's outer layers didn't escape. they hang around the newborn hole in a glowing ring and spiral in,
		// building its first disk (the hole's feeding takes it from here)
		var _fbr = scr_hex_hole_size(_ho);
		for (var j = 0; j < 28 && array_length(global.hex_haze) < HEX_HAZE_CAP + 800; j++) {
			var _fbd = random(360), _fbl = _fbr * random_range(2.6, 4.4);
			var _fbs = random_range(9, 14);
			var _fbw = { ox: _ho.ox + lengthdir_x(_fbl, _fbd), oy: _ho.oy + lengthdir_y(_fbl, _fbd), ang: _fbd + 90,
				c: merge_color(make_color_rgb(255, 120, 70), make_color_rgb(255, 200, 150), random(1)),
				s: _fbs, s0: _fbs, smax: _fbs, a: 0.09, at: 0.09, f: 1, ex: 1, st: 1, tx: 1, fr: irandom(3), u: false };
			scr_hex_wisp_norm(_fbw);
			array_push(global.hex_haze, _fbw);
		}
	}
}
scr_prof_lap("hole aging");   // (capture key: C)
// ---- the dance of black holes: they sink toward each other, and two that meet spiral together faster and faster, shaking
// space with gravitational waves, until they merge into one bigger hole (5% of their mass leaves as the waves themselves).
// three holes merged make a supermassive, and her whole sky turns around it: a galaxy ----
var _fpsn = game_get_speed(gamespeed_fps);
if (!variable_global_exists("hex_merge")) { global.hex_merge = undefined; global.hex_ripples = []; global.hex_merge_rush = false; }
if (keyboard_check_pressed(ord("M"))) global.hex_merge_rush = !global.hex_merge_rush;   // debug: black holes rush together
scr_hex_holes_migrate(global.hex_merge_rush ? 2.5 : 0.2);
var _bhl = global.hex_holes;
if (is_undefined(global.hex_merge)) {
	for (var h = 0; h < array_length(_bhl) && is_undefined(global.hex_merge); h++) {
		var _ma = _bhl[h];
		if (_ma.age < HEX_GATHER + _fpsn) continue;
		for (var k = h + 1; k < array_length(_bhl); k++) {
			var _mb = _bhl[k];
			if (_mb.age < HEX_GATHER + _fpsn) continue;
			var _md = point_distance(_ma.ox, _ma.oy, _mb.ox, _mb.oy);
			if (_md > (scr_hex_hole_size(_ma) + scr_hex_hole_size(_mb)) * 1.6) continue;   // close first (migration brings them in), then a tight inspiral, not a wide waltz
			var _hv = (_ma.m >= _mb.m) ? _ma : _mb, _lt = (_ma.m >= _mb.m) ? _mb : _ma;   // the heavier one survives
			var _mcx = (_ma.ox * _ma.m + _mb.ox * _mb.m) / (_ma.m + _mb.m), _mcy = (_ma.oy * _ma.m + _mb.oy * _mb.m) / (_ma.m + _mb.m);
			global.hex_merge = { a: _hv, b: _lt, t: 0, len: _fpsn * 5, d0: _md, cx: _mcx, cy: _mcy,
				ang: point_direction(_mcx, _mcy, _hv.ox, _hv.oy), rip: 0 };
			duration = max(duration, t + _fpsn * 8);
			break;
		}
	}
}
var _mg = global.hex_merge;
if (!is_undefined(_mg)) {
	if (!array_contains(_bhl, _mg.a) || !array_contains(_bhl, _mg.b)) global.hex_merge = undefined;
	else {
		_mg.t++;
		var _mk  = min(1, _mg.t / _mg.len);
		var _sep = _mg.d0 * power(1 - _mk, 0.25);                             // the gap closes ever faster at the end (a real inspiral)
		var _om  = min(14, 0.6 * power(_mg.d0 / max(_sep, 4), 1.5));         // and they whirl round faster and faster: the chirp (capped, so it never strobes)
		_mg.ang += _om;
		var _mmt = _mg.a.m + _mg.b.m;
		_mg.a.ox = _mg.cx + lengthdir_x(_sep * _mg.b.m / _mmt, _mg.ang); _mg.a.oy = _mg.cy + lengthdir_y(_sep * _mg.b.m / _mmt, _mg.ang);
		_mg.b.ox = _mg.cx - lengthdir_x(_sep * _mg.a.m / _mmt, _mg.ang); _mg.b.oy = _mg.cy - lengthdir_y(_sep * _mg.a.m / _mmt, _mg.ang);
		_mg.rip += _om * 2;                                                    // gravitational waves ring at twice the orbit's rhythm
		if (_mg.rip >= 180) {
			_mg.rip -= 180;
			if (array_length(global.hex_ripples) < 12) array_push(global.hex_ripples, { ox: _mg.cx, oy: _mg.cy, age: 0, len: _fpsn * 1.6, amp: 1.5 + 5 * _mk });
		}
		// they become one once the smaller horizon has mostly slipped inside the bigger one (a single, peanut-shaped horizon), not the
		// moment their edges touch: merging at first touch snapped two separate shadows into one
		var _mtouch = (_sep <= max(scr_hex_hole_size(_mg.a), scr_hex_hole_size(_mg.b)) * 0.6);
		if (_mk >= 1 || _mtouch) {                                             // they're one
			var _ga = variable_struct_exists(_mg.a, "gen") ? _mg.a.gen : 0, _gb = variable_struct_exists(_mg.b, "gen") ? _mg.b.gen : 0;
			_mg.a.m   = _mmt * 0.95;
			_mg.a.gen = _ga + _gb + 1;
			// (it stays where it is: snapping it to the center jumped its lens, and the stars around it sprang)
			// the bending of space carries over: the merged hole starts with both lenses' strength combined (Einstein radius squared adds,
			// like mass), then eases to its new size (Draw), so the sky around a merger never springs
			if (variable_struct_exists(_mg.a, "le") && variable_struct_exists(_mg.b, "le")) {
				// the swallowed hole's lens fades out where it was over ~1s (a ghost, Draw) while the survivor's eases up to the combined
				// mass's strength on its own, so no lens ever appears or vanishes in a single frame
				if (!variable_global_exists("hex_lens_ghosts")) global.hex_lens_ghosts = [];
				array_push(global.hex_lens_ghosts, { ox: _mg.b.ox, oy: _mg.b.oy, le: _mg.b.le, k: 1 });
			}
			_mg.a.feed = (variable_struct_exists(_mg.a, "feed") ? _mg.a.feed : 0) + (variable_struct_exists(_mg.b, "feed") ? _mg.b.feed : 0) + 60;
			_mg.a.mf  = 0;                                                     // its photon ring flares (Draw)
			for (var h = array_length(_bhl) - 1; h >= 0; h--) if (_bhl[h] == _mg.b) array_delete(_bhl, h, 1);
			array_push(global.hex_ripples, { ox: _mg.cx, oy: _mg.cy, age: 0, len: _fpsn * 2.4, amp: 18 });   // the biggest wave of all
			global.shake = max(global.shake, 7);                                 // felt, not jarring (it was 18, near the Big Bang's)
			global.hex_merge = undefined;
		}
	}
}
for (var i = array_length(global.hex_ripples) - 1; i >= 0; i--) {
	var _rpl = global.hex_ripples[i];
	_rpl.age++;
	if (_rpl.age > _rpl.len) array_delete(global.hex_ripples, i, 1);
}
for (var h = 0; h < array_length(_bhl); h++) if (variable_struct_exists(_bhl[h], "mf") && _bhl[h].mf >= 0) _bhl[h].mf++;
scr_hex_galaxy_turn(1);
if (gaze && scr_hex_fluid_ok()) scr_hex_orbits();                         // stars and holes orbit in the same gravity as the gas (leapfrog). (during a
                                                                          // cast the choreography owns the sky and the clock waits)
scr_hex_flow_step();                                                    // the currents carry her settled gas (the flow field)
scr_hex_aeon_step();                                                    // the ages of her universe: galaxy, quasar, twilight, evaporation, dawn
time_scale = lerp(time_scale, _slow, 0.15); // ease into and out of the slowdown instead of snapping
if (!scr_hex_iso()) sky_angle += spin * time_scale / game_get_speed(gamespeed_fps);   // (physics only: the view doesn't spin)
scr_prof_lap("mergers, galaxy turn, aeon");   // (capture key: C)
// ---- the peek: births from her old haze. the gas gathers into a dark knot, matter spirals in, the young star fires
// jets from its poles, then catches, blows its cocoon away and lights up the gas around it ----
_fpsn = game_get_speed(gamespeed_fps);
if (t mod 10 == 0) scr_hex_haze_expose(0.25);           // the exposure curve keeps up as new gas lands: rich, never white
// B (debug): a giant cloud of gas (~30 million suns) drops in at the mouse, already orbiting like all new gas. dense enough to
// collapse: watch it form star clusters, light up, and blow superbubbles
if (keyboard_check_pressed(ord("B")) && instance_exists(obj_player) && variable_global_exists("hex_fluid") && variable_struct_exists(global.hex_fluid, "ret")) {
	var _dbl = point_distance(obj_player.x, obj_player.y, mouse_x, mouse_y);
	var _dba = point_direction(obj_player.x, obj_player.y, mouse_x, mouse_y) - sky_angle;   // into her sky's own frame
	var _dbx = lengthdir_x(_dbl, _dba), _dby = lengthdir_y(_dbl, _dba);
	var _dbr = max(1, point_distance(0, 0, _dbx, _dby)), _dbv = HEX_GAL_VC * HEX_FLUID_CS * _dbr / sqrt(_dbr * _dbr + HEX_GAL_R0 * HEX_GAL_R0);
	var _dbc = [make_color_rgb(255, 85, 115), make_color_rgb(210, 110, 255), make_color_rgb(255, 85, 115)];
	for (var k = 0; k < 3; k++) array_push(global.hex_fluid.ret, [_dbx + lengthdir_x(22, k * 120 + 30), _dby + lengthdir_y(22, k * 120 + 30), 2, 46, _dbc[k],
		_dbv * _dby / _dbr, -_dbv * _dbx / _dbr]);
	scr_hex_toast("B: a giant gas cloud (" + string_format(6 * HEX_SIGMA_UNIT * HEX_SAMPLE_PC * HEX_SAMPLE_PC / 1000000, 1, 0) + " million suns) dropped in");
}
// X (debug): the gas at the mouse becomes a young giant star cluster at once (scr_hex_fluid_sinks): its light, then its superbubble
if (keyboard_check_pressed(ord("X")) && instance_exists(obj_player) && variable_global_exists("hex_fluid")) {
	var _xl = point_distance(obj_player.x, obj_player.y, mouse_x, mouse_y);
	var _xa = point_direction(obj_player.x, obj_player.y, mouse_x, mouse_y) - sky_angle;
	global.hex_fluid.force_sf = [lengthdir_x(_xl, _xa), lengthdir_y(_xl, _xa)];
}
if (keyboard_check_pressed(ord("N"))) {                     // debug: a minute of cosmic time passes in an instant
	for (var i = 0; i < array_length(global.hex_stars); i++) {
		var _ast = global.hex_stars[i];
		_ast.age = scr_hex_age(_ast) + 60;
	}
	if (array_length(deaths) == 0) {
		var _dth = scr_hex_find_death();
		if (!is_undefined(_dth)) {
			_dth.dying = true;
			array_push(deaths, { st: _dth, t0: t });
			duration = max(duration, t + death_len + max(shell_len, nova_len) + _fpsn);
		}
	}
}
scr_prof_lap("births (peek)");   // (capture key: C)
// V (debug): a giant appears at the mouse, already at the end of its life. it glows as a red supergiant for a moment,
// then its core fails: a supernova right there (or, with F10 on, a collapse into a black hole)
if (keyboard_check_pressed(ord("V")) && instance_exists(obj_player)) {
	var _vl = point_distance(obj_player.x, obj_player.y, mouse_x, mouse_y);
	var _va = point_direction(obj_player.x, obj_player.y, mouse_x, mouse_y) - sky_angle;   // into her sky's own frame
	var _vst = { ox: lengthdir_x(_vl, _va), oy: lengthdir_y(_vl, _va), s: 2.4, ph: random(1000), hx: false, big: false, m: 40, age: 0 };
	_vst.age = scr_hex_star_life(40) * 1.01;
	_vst.dying = true;
	array_push(global.hex_stars, _vst);
	array_push(deaths, { st: _vst, t0: t + floor(_fpsn * 1.5) });
	duration = max(duration, t + floor(_fpsn * 1.5) + death_len + nova_len + _fpsn);
}
// a sun-like star lets go: its outer layers puff off into a ring, and its bare core is left behind, a white dwarf
for (var i = array_length(deaths) - 1; i >= 0; i--) {
	var _dtt = deaths[i];
	if (t < _dtt.t0 + death_len) continue;                  // it throbs first (Draw)
	var _ast = _dtt.st;
	_ast.dying = false;
	array_delete(deaths, i, 1);
	if (_ast.m >= HEX_MASS_GIANT) {
		// a giant's core gives way. heavy enough, and her ascension allows it: it collapses into a black hole (the gather, the impact)
		var _need = global.hex_debug_holes ? 15 : HEX_COLLAPSE_MASS;
		var _p3 = (_ast[$ "p3"] == true);                                      // a first star of a new aeon: born to become a black hole
		// ...unless it's one of the very heaviest. a pair-instability supernova: its core gets so hot that light turns into matter
		// and antimatter, the pressure holding it up collapses, and the runaway burning blows the whole star apart. nothing is
		// left behind, not even a black hole, and every bit of it goes back into the sky as gas
		if (_p3 && _ast.m > 60) {
			array_push(novae, { ox: _ast.ox, oy: _ast.oy, t0: t, ph: random(1000), pisn: true });
			scr_hex_flow_kick(_ast.ox, _ast.oy, 520, 1.6);                      // its shockwave stirs the currents
			for (var j = array_length(global.hex_stars) - 1; j >= 0; j--) if (global.hex_stars[j] == _ast) { array_delete(global.hex_stars, j, 1); break; }
			var _pvl = point_distance(0, 0, _ast.ox, _ast.oy), _pva = point_direction(0, 0, _ast.ox, _ast.oy) + sky_angle;
			impact_x = obj_player.x + lengthdir_x(_pvl, _pva); impact_y = obj_player.y + lengthdir_y(_pvl, _pva);
			hitstop = 8; impact_kind = 2;
			global.shake = max(global.shake, 14);
			duration = max(duration, t + nova_len + _fpsn);
			continue;
		}
		if ((_p3 || (_ast.m >= _need && (global.hex_debug_holes || scr_hex_tier() >= 4))) && scr_hex_hole_room(_ast.ox, _ast.oy)) {
			array_push(global.hex_holes, { ox: _ast.ox, oy: _ast.oy, m: _ast.m, s: _ast.s, age: 0, ph: random(1000), tilt: random_range(-12, 12), feed: 0 });
			for (var j = array_length(global.hex_stars) - 1; j >= 0; j--) if (global.hex_stars[j] == _ast) { array_delete(global.hex_stars, j, 1); break; }
			duration = max(duration, t + HEX_GATHER + _fpsn * 3);
			continue;
		}
		// otherwise a supernova: the loudest light in her sky. a shell of the elements it forged blasts out, and a neutron star is left
		_ast.ns = true;
		_ast.s  = 0.6;
		_ast.m  = 2;
		array_push(novae, { ox: _ast.ox, oy: _ast.oy, t0: t, ph: random(1000) });
		scr_hex_flow_kick(_ast.ox, _ast.oy, 380, 1.1);                         // its shockwave stirs the currents
		var _nvl = point_distance(0, 0, _ast.ox, _ast.oy), _nva = point_direction(0, 0, _ast.ox, _ast.oy) + sky_angle;
		impact_x = obj_player.x + lengthdir_x(_nvl, _nva); impact_y = obj_player.y + lengthdir_y(_nvl, _nva);
		hitstop = 8; impact_kind = 2;                         // its own impact frame: time stops on the flash
		duration = max(duration, t + nova_len + _fpsn);
		continue;
	}
	_ast.wd = true;
	_ast.s  = 0.7;
	_ast.m  = max(1, _ast.m * 0.3);                        // most of its mass goes back into her nebula
	array_push(shells, { ox: _ast.ox, oy: _ast.oy, t0: t, ang: random(180), ell: random_range(0.7, 1) }); // real rings are a little oval
	scr_hex_flow_kick(_ast.ox, _ast.oy, 200, 0.4);                           // a gentle puff through the currents
	array_push(ignitions, { ox: _ast.ox, oy: _ast.oy, t0: t, big: false, s: 1.6, merged: false, c: make_color_rgb(205, 225, 255) });
}
// a supernova remnant settles into her nebula: filaments of oxygen teal, sulphur and iron gold, and hydrogen red. food for new stars,
// and colors her kills alone could never make
for (var i = array_length(novae) - 1; i >= 0; i--) {
	var _nv = novae[i];
	if (t < _nv.t0 + nova_len) continue;
	var _nvpi = (_nv[$ "pisn"] == true);                    // a pair-instability supernova returns a whole monster star: twice the shell
	var _nvn = _nvpi ? 96 : 48;
	for (var _nvj = 0; _nvj < _nvn; _nvj++) {
		var _nvh = scr_hash(_nv.ph + _nvj * 2.3);
		var _nvr = (_nvpi ? 240 : 150) * random_range(0.82, 1.05), _nvd = _nvj * (360 / _nvn) + random_range(-3, 3);
		scr_hex_haze_add({ ox: _nv.ox + lengthdir_x(_nvr, _nvd), oy: _nv.oy + lengthdir_y(_nvr, _nvd), ang: _nvd + 90,
			c: (_nvh < 0.45) ? make_color_rgb(70, 220, 200) : ((_nvh < 0.8) ? make_color_rgb(255, 200, 90) : make_color_rgb(255, 85, 115)),
			s: 16, s0: 16, smax: 34, a: 0.03, f: 1, at: 0.13, tx: 1, fr: 4 + irandom(3), ex: 1, st: 1.6, u: false });
	}
	array_delete(novae, i, 1);
}
// the ring puffs out, then settles into lasting haze: red hydrogen outside, teal oxygen inside. food for new stars
for (var i = array_length(shells) - 1; i >= 0; i--) {
	var _sh = shells[i];
	if (t < _sh.t0 + shell_len) continue;
	for (var _shj = 0; _shj < 18; _shj++) {
		var _shd = _shj * 20;
		for (var _shk = 0; _shk < 2; _shk++) {
			var _shr = ((_shk == 0) ? 80 : 56) * (0.9 + 0.2 * scr_hash(_shj * 7.3 + _sh.ang)); // lumpy, like real rings
			var _sx0 = lengthdir_x(_shr, _shd), _sy0 = lengthdir_y(_shr, _shd) * _sh.ell;      // a point on the oval
			var _shx = _sh.ox + lengthdir_x(_sx0, _sh.ang) - lengthdir_y(-_sy0, _sh.ang);       // turned to the ring's angle
			var _shy = _sh.oy + lengthdir_y(_sx0, _sh.ang) + lengthdir_x(-_sy0, _sh.ang);
			scr_hex_haze_add({ ox: _shx, oy: _shy, ang: random(360),
				c: (_shk == 0) ? make_color_rgb(255, 85, 115) : make_color_rgb(70, 220, 200),
				s: 14, s0: 14, smax: 30, a: 0.03, f: 1, at: 0.12 });                               // it fades up as the ring's light fades down
		}
	}
	array_delete(shells, i, 1);
}
for (var n = array_length(nurseries) - 1; n >= 0; n--) {
	var _nu = nurseries[n];
	if (t < _nu.t0) continue;
	var _nk = (t - _nu.t0) / nurse_len;
	if (_nk >= 1) { array_delete(nurseries, n, 1); continue; }
	var _nw = _nu.ws;
	// the jets switch on and decide what becomes of the knot's gas: the star swallows some, a little stays as its pocket,
	// and the jets throw the rest far out along its poles, where it settles as long streaks. the garden trims itself
	if (_nk >= 0.42 && !_nu.jetgo) {
		_nu.jetgo = true;
		for (var j = 0; j < array_length(_nw); j++) {
			var _q = _nw[j];
			var _roll = random(1);
			if (_roll < HEX_STAR_KEEP) _q.jr = 1;                                   // falls into the star
			else if (_roll < 1 - HEX_POCKET_KEEP) {                                  // thrown out along a jet
				_q.jr = 2;
				var _side = (random(1) < 0.5) ? 0 : 180;
				var _jdd  = random_range(30, 90);                                     // a young star is small: its outflow is short
				var _jlat = random_range(-14, 14);
				_q.jx  = _nu.ox + lengthdir_x(_jdd, _nu.jet + _side) + lengthdir_x(_jlat, _nu.jet + 90);
				_q.jy  = _nu.oy + lengthdir_y(_jdd, _nu.jet + _side) + lengthdir_y(_jlat, _nu.jet + 90);
				_q.ang = _nu.jet;
				_q.fr  = 4 + irandom(3);                                              // a thread, not a puff
				_q.st  = random_range(2, 3);                                          // stretched along the jet: a streak, not a puff
				if (_q.c != -1) _q.c = merge_color(_q.c, make_color_rgb(255, 120, 110), 0.35); // shocked gas glows pink-orange, like real HH objects
			}
			else _q.jr = 0;                                                           // stays: the pocket around the newborn
		}
	}
	for (var j = 0; j < array_length(_nw); j++) {
		var _q  = _nw[j];
		var _jr = _q[$ "jr"];
		if (is_undefined(_jr)) _jr = -1;
		if (_jr == 1) {                                                               // swallowed: pulled in, and gone
			_q.ox += (_nu.ox - _q.ox) * 0.08;
			_q.oy += (_nu.oy - _q.oy) * 0.08;
			_q.f = max(0, _q.f - 0.025);
		} else if (_jr == 2) {                                                        // carried out on the jet
			_q.ox += (_q.jx - _q.ox) * 0.05;
			_q.oy += (_q.jy - _q.oy) * 0.05;
			_q.f = max(0.8, _q.f - 0.003);                                         // it stays visible: the streak is where the jet's gas landed
		} else if (!_nu.lit) {                                                        // gravity pulls the knot in: slowly, then faster and faster
			var _npull = 0.003 + 0.025 * _nk;
			_q.ox += (_nu.ox - _q.ox) * _npull;
			_q.oy += (_nu.oy - _q.oy) * _npull;
			_q.s = max(_q.s0 * 0.5, _q.s - 0.3);                                      // denser, so it glows brighter
		} else if (j < array_length(_nu.pvx)) {                                       // the pocket: pushed back into a little bubble, thinning
			_q.ox += _nu.pvx[j]; _q.oy += _nu.pvy[j];
			_nu.pvx[j] *= 0.94;  _nu.pvy[j] *= 0.94;
			_q.f = max(0.4, _q.f - 0.012);
		}
	}
	// the jets fire knots of gas out of both poles, in pulses
	if (_nk >= 0.42 && _nk < 0.88) {
		// each knot keeps the direction it was fired in. the axis slowly precesses, so the trail of knots freezes into a gentle S,
		// the way real jets do, instead of the whole jet waving like a rope
		var _jaim = _nu.jet + 8 * sin(t * 0.05 + _nu.ph);
		var _jpow = (_nk < 0.6) ? 1 : 1 - (_nk - 0.6) / 0.28;         // it blasts hardest as the star switches on, then dies down
		for (var _js = 0; _js < 2; _js++) {
			// knots: blobs of gas fired in pulses, with gaps between them
			if (sin(t * 0.55 + _nu.ph) > 0.55) array_push(jbeads, { nu: _nu, sd: _js, d: 3, v: random_range(2, 2.6), age: 0, ang: _jaim + _js * 180 + random_range(-2, 2), k: 0, l: 0, lv: 0 });
			// spray: gas and dust blasted out in a tight core, like an aerosol: fast at the nozzle, then slowing, spreading
			// sideways and puffing out into mist as it hits the cloud
			repeat (round(4 * _jpow)) array_push(jbeads, { nu: _nu, sd: _js, d: random(4), v: random_range(2.5, 5), age: 0, ang: _jaim + _js * 180 + random_range(-6, 6), k: 1, l: 0, lv: random_range(-0.25, 0.25) });
			// the wide wind: a broad, slow, faint cone of gas around the jet (it is what carves the hourglass)
			repeat (round(2 * _jpow)) array_push(jbeads, { nu: _nu, sd: _js, d: random(4), v: random_range(1.2, 2.4), age: 0, ang: _jaim + _js * 180 + random_range(-28, 28), k: 2, l: 0, lv: 0 });
		}
	}
	if (!_nu.lit) {
		// matter streams in from its gas on spiralling paths
		if (_nk < 0.62) {
			repeat ((_nk < 0.45) ? 2 : 1) {
				var _nsrc = _nw[irandom(array_length(_nw) - 1)];
				var _nsr  = max(35, point_distance(_nu.ox, _nu.oy, _nsrc.ox, _nsrc.oy) + random_range(10, 45)); // from out in the cloud, so the spiral has room to show
				array_push(infall, { nu: _nu, r: _nsr, a: point_direction(_nu.ox, _nu.oy, _nsrc.ox, _nsrc.oy) + random_range(-25, 25),
				                     c: (_nsrc.c == -1) ? _nu.gc : _nsrc.c, age: 0 });
			}
		}
		// it catches
		if (_nk >= 0.7) {
			_nu.lit = true;
			var _nss = min(2.6, 0.7 + sqrt(_nu.m) * 0.3);
			array_push(global.hex_stars, { ox: _nu.ox, oy: _nu.oy, s: _nss, ph: _nu.ph, hx: false, big: false, m: _nu.m, p3: (_nu[$ "p3"] == true) });
			array_push(ignitions, { ox: _nu.ox, oy: _nu.oy, t0: t, big: (_nu.m >= 12), s: _nss, merged: false, c: _nu.c });
			// its light and wind push the gas left around it outward: a bubble opens around the newborn
			for (var j = 0; j < array_length(_nw); j++) {
				var _q = _nw[j];
				var _nbd = (point_distance(_nu.ox, _nu.oy, _q.ox, _q.oy) > 0.5) ? point_direction(_nu.ox, _nu.oy, _q.ox, _q.oy) : random(360);
				var _nbp = random_range(2, 3.5);
				array_push(_nu.pvx, lengthdir_x(_nbp, _nbd));
				array_push(_nu.pvy, lengthdir_y(_nbp, _nbd));
			}
			// a faint glow in its color stays behind: young stars sit in little glowing pockets of their nebula
			scr_hex_haze_add({ ox: _nu.ox, oy: _nu.oy, ang: random(360), c: _nu.c, s: 16, s0: 16, smax: 40, a: 0.05, f: 1, u: true });
		}
	}
}
scr_prof_lap("deaths, remnants, rings, nurseries");   // (capture key: C)
// the jet knots fly out and slow as they plough into the cloud
for (var i = array_length(jbeads) - 1; i >= 0; i--) {
	var _jb = jbeads[i];
	_jb.d += _jb.v;
	_jb.v *= (_jb.k == 1) ? 0.95 : ((_jb.k == 2) ? 0.96 : 0.97);   // the spray slows hardest: it spends itself quickly
	_jb.l += _jb.lv;                                                   // and drifts sideways as it slows, dispersing
	_jb.age++;
	if (_jb.age > ((_jb.k == 1) ? 45 : 60)) { jbeads[i] = jbeads[array_length(jbeads) - 1]; array_pop(jbeads); }
}
scr_prof_lap("jet knots");   // (capture key: C)
// ---- sitting in her universe (G): it keeps living while she watches. a second of watching is a second of cosmic time ----
if (gaze) {
	if (keyboard_check_pressed(ord("G")) && t > birth_at + 10 && duration == infinity) duration = t + floor(_fpsn * 0.5); // warp back out: the sky closes in on her
	if (t mod _fpsn == 0) {
		var _gage = (variable_global_exists("hex_aeon") && global.hex_aeon.phase == "twilight") ? 4 : 1;   // in the twilight, the old stars hurry toward their ends
		for (var i = 0; i < array_length(global.hex_stars); i++) { var _gst = global.hex_stars[i]; _gst.age = scr_hex_age(_gst) + _gage; } // stars age
		if (array_length(deaths) == 0) {                                   // and when one's time is up, it dies where she can see it
			var _gdth = scr_hex_find_death();
			if (!is_undefined(_gdth)) { _gdth.dying = true; array_push(deaths, { st: _gdth, t0: t }); }
		}
	}
	// (stars are born from the gas itself now: scr_hex_fluid_sinks. the old timed births from wisps are gone)
}
scr_prof_lap("G-mode living (aging)");   // (capture key: C)
// ---- black holes feed on her gas. near a hole, a cloud is torn apart by the difference in pull between its near and far side
// (tidal shredding): it breaks into smaller pieces, the inner ones orbit faster than the outer ones, and the cloud shears into a
// curved spiral arm instead of moving as one stiff stick. the pieces sink into the disk's plane, heat up as they fall, and are
// swallowed at the edge. the hole grows with everything it eats ----
var _fhl = global.hex_holes;
if (array_length(_fhl) > 0) {
	var _fhz = global.hex_haze;
	var _ftr = (t mod 4 == 0);                                                // every few frames each falling piece remembers where it was: its trail
	var _fwarm = make_color_rgb(255, 150, 80), _fhot = make_color_rgb(255, 222, 188);
	for (var h = 0; h < array_length(_fhl); h++) {
		var _fho = _fhl[h];
		if (_fho.age < HEX_GATHER + _fpsn) continue;                         // let it be born first
		if (variable_struct_exists(_fho, "evk")) continue;                  // evaporating: it no longer feeds or throws gas out, it only radiates
		var _fhr = scr_hex_hole_size(_fho);
		if (!variable_struct_exists(_fho, "feed")) _fho.feed = 0;
		_fho.feed *= 0.995;                                                   // how hard it's feeding right now: the disk blazes while it eats, and dims when it starves
		var _ftc = dcos(_fho.tilt - sky_angle), _fts = dsin(_fho.tilt - sky_angle);   // the disk's tilt is on screen; the gas lives in her turning sky
		var _fsplit = 0;                                                      // shreds made this frame (a few at a time, so it never spikes)
		if (!variable_struct_exists(_fho, "out")) _fho.out = 0;
		var _fsm = scr_hex_is_smbh(_fho);
		// most gas that reaches a black hole's disk never crosses the horizon: it's heated and blown back out along the poles
		// and in winds. a supermassive keeps only a sliver (ours swallows well under 1%); a small hole keeps more
		var _fkeep = _fsm ? 0.9 : 0.35;
		var _fro = min(scr_hex_is_smbh(_fho) ? 700 : 300, _fhr * 7), _fro2 = _fro * _fro;   // how far its pull reaches: further for a heavier hole
		var _fn0 = array_length(_fhz);                                        // pieces torn off this frame start moving next frame
		for (var i = 0; i < _fn0; i++) {
			var _fq = _fhz[i];
			if (_fq.f <= 0.01 || _fq.fl) continue;                         // gas it's throwing out isn't pulled back in mid-flight
			var _fdx = _fq.ox - _fho.ox, _fdy = _fq.oy - _fho.oy;
			var _fd2 = _fdx * _fdx + _fdy * _fdy;
			if (_fd2 > _fro2) continue;
			var _fd = max(1, sqrt(_fd2));
			if (_fd < _fhr * 1.3) { _fho.feed += _fq.f; _fq.f = 0; _fq.tr = false; _fho.m += 0.04; continue; }   // across the edge: swallowed
			// the pull fades in smoothly from the edge of its reach, so far gas just drifts a little and keeps its shape.
			// only gas that comes close is really caught: torn apart, stretched along its orbit, leaving a trail
			var _fk = clamp((_fro - _fd) / max(1, _fro - _fhr * 3), 0, 1);
			var _fwt = _fk * _fk * (3 - 2 * _fk);
			var _fin = (_fd < _fhr * 4.5);
			if (_fin && !_fq.tr) { _fq.tr = true; _fq.fz = 1; _fq.p1x = _fq.ox; _fq.p1y = _fq.oy; _fq.p2x = _fq.ox; _fq.p2y = _fq.oy; _fq.smax = _fq.s; } // caught: it stops spreading
			// tidal shredding: a big cloud close in tears into three, spread inward and outward along the pull
			if (_fin && _fq.s > 11 && _fsplit < 4 && !_fq.u && array_length(_fhz) < HEX_HAZE_CAP + 800) {   // room to spare: tearing never pushes other gas out of her sky
				_fsplit++;
				_fq.s *= 0.58; _fq.s0 *= 0.58; _fq.smax = _fq.s;                // three pieces at 0.58 size carry the same light as one whole
				var _frx = _fdx / _fd, _fry = _fdy / _fd;
				for (var _fkk = -1; _fkk <= 1; _fkk += 2) {
					var _fo = _fq.s * 0.9 * _fkk;
					var _fp = { ox: _fq.ox + _frx * _fo - _fry * random_range(-3, 3), oy: _fq.oy + _fry * _fo + _frx * random_range(-3, 3),
						ang: _fq.ang, c: _fq.c, s: _fq.s, s0: _fq.s0, smax: _fq.s, a: _fq.a, at: _fq.at, f: _fq.f, ex: _fq.ex,
						st: _fq.st, tx: 1, fr: irandom(3), u: false };                  // soft billows, not threads: torn gas, not strings
					scr_hex_wisp_norm(_fp);
					array_push(_fhz, _fp);                                              // added past the cap on purpose: scr_hex_haze_add would overwrite the oldest gas elsewhere
					_fp.tr = true; _fp.fz = _fq.fz; _fp.p1x = _fp.ox; _fp.p1y = _fp.oy; _fp.p2x = _fp.ox; _fp.p2y = _fp.oy;
				}
			}
			if (_fq.tr && _ftr) { _fq.p2x = _fq.p1x; _fq.p2y = _fq.p1y; _fq.p1x = _fq.ox; _fq.p1y = _fq.oy; }
			// into the hole's own frame: along its disk (_flx) and across it (_fly). a caught cloud's orbit starts out round (tilted
			// toward us) and slowly lines up with the spinning disk, flattening into its nearly edge-on plane (0.12, as sh_hex_lens draws it).
			// real gas orbits get dragged into line with a spinning black hole's disk the same way (the Bardeen-Petterson effect)
			if (_fq.tr) _fq.fz = max(0.12, _fq.fz - 0.004);
			var _fzz = _fq.tr ? _fq.fz : 1;
			var _flx = _fdx * _ftc - _fdy * _fts, _fly = _fdx * _fts + _fdy * _ftc;
			var _fpy = _fly / _fzz;                                               // in the plane of its orbit
			var _fpd = max(1, sqrt(_flx * _flx + _fpy * _fpy));
			var _fw  = min(3, 250 / power(_fpd, 1.2)) * _fwt;                       // it orbits faster as it closes in: inner pieces pull ahead
			var _fc  = dcos(_fw), _fs = dsin(_fw);
			var _fnx = _flx * _fc - _fpy * _fs, _fnp = _flx * _fs + _fpy * _fc;
			var _fnd = max(_fhr, _fpd - (0.05 + 40 / _fpd) * _fwt) / _fpd;          // and falls faster the closer it gets
			_fnx *= _fnd; _fnp *= _fnd;
			var _fny = _fnp * _fzz;
			_fq.ox = _fho.ox + _fnx * _ftc + _fny * _fts;                           // back out of the hole's frame
			_fq.oy = _fho.oy - _fnx * _fts + _fny * _ftc;
			// it turns smoothly to lie along its orbit (never snapping, and never pointing at the hole like a spoke)
			var _fvx = -_fnp, _fvy = _fnx * _fzz;
			var _fta = point_direction(0, 0, _fvx * _ftc + _fvy * _fts, -_fvx * _fts + _fvy * _ftc);
			_fq.ang += angle_difference(_fta, _fq.ang) * (_fq.tr ? 0.12 : 0.02 * _fwt);
			if (_fq.tr) {
				// stretched gently along its orbit as it's sheared, never longer than a small part of the curve
				_fq.st += (clamp(0.3 * _fd / (3.2 * _fq.s), 1, 2.2) - _fq.st) * 0.05;
				if (_fd < _fhr * 4.5) { var _flose = _fq.f * ((_fd < _fhr * 3) ? 0.06 : 0.025); _fq.f -= _flose; _fho.feed += _flose; _fho.out += _flose * _fkeep; if (_fsm) _fho.meal = (variable_struct_exists(_fho, "meal") ? _fho.meal : 0) + _flose; }   // close in, the cloud becomes part of the disk itself (sh_hex_lens)
				// heating up as it falls: its own color far out, glowing orange closer in, white-gold only right at the disk
				if (_fq.c != -1) {
					if (_fd < _fhr * 2.5) _fq.c = merge_color(_fq.c, _fhot, 0.03);
					else _fq.c = merge_color(_fq.c, _fwarm, 0.01);
				}
			}
		}
		// the outflow: hot gas thrown out of the poles in jets (and, from a supermassive, a broad wind too). it flies far across the
		// garden, cools and slows, and settles as fresh gas where new stars can form (real: jets trigger star birth where they hit)
		_fho.out = min(_fho.out, 30);
		var _femit = 0;
		// it comes out in fits, not a steady stream: real outflows are clumpy and flicker. most frames a puff or two, sometimes nothing,
		// and every so often a burst: a whole clump flung out at once in one direction
		// bursts are rarer but never the same twice: any size from a handful to a real eruption, a tight spurt or a wide spray,
		// slow or fast. and the jets precess (their axis slowly wobbles, like the real jets of SS 433), so nothing repeats
		var _fburst = (_fho.out >= 4 && random(1) < 0.015);
		var _fmax = _fburst ? irandom_range(4, 7) + floor(14 * power(random(1), 2)) : ((random(1) < 0.55) ? irandom_range(1, 2) : 0);
		var _fprec = 18 * sin(current_time / 1900 + _fho.ph) + 7 * sin(current_time / 730 + _fho.ph * 2.3);
		var _fbang = _fho.tilt - sky_angle + 90 + 180 * irandom(1) + _fprec + random_range(-35, 35);   // the burst's direction
		var _fbsp = random_range(6, 30), _fbv = random_range(0.9, 1.8);                              // its spread and its force
		if (_fburst) scr_hex_fluid_kick(_fho.ox + lengthdir_x(_fhr * 2.2, _fbang), _fho.oy + lengthdir_y(_fhr * 2.2, _fbang), _fhr * 2.5, 0.5 * _fbv, make_color_rgb(200, 215, 255));   // a burst stirs the fluid
		while (_fho.out >= 0.6 && _femit < _fmax && array_length(_fhz) < HEX_HAZE_CAP + 800 && array_length(global.hex_flow) < 700) {
			_fho.out -= 0.6; _femit++;
			var _fwide = _fsm && random(1) < 0.4;
			var _fpole = _fho.tilt - sky_angle + 90 + 180 * irandom(1) + _fprec; // square to the disk, either pole (from screen into her sky)
			var _fang  = _fburst ? _fbang + random_range(-_fbsp, _fbsp)
			           : (_fpole + (_fwide ? random_range(-60, 60) : random_range(-9, 9) + random_range(-9, 9) * random(1)));
			var _fvel  = (_fwide ? random_range(2.5, 4.5) : random_range(4, 9)) * (_fsm ? (_fwide ? 1.4 : 2.1) : 1) * (0.7 + 0.6 * power(random(1), 2)) * (_fburst ? _fbv : 1);
			var _fsz   = random_range(6, 14) + 10 * power(random(1), 3);       // mostly small puffs, now and then a big one
			// what it's made of: mostly hot hydrogen glowing blue-white, but each puff cools to the light of its own element:
			// oxygen teal, hydrogen red, iron gold (the colors astronomers see in real outflows and remnants)
			var _fel = random(1);
			var _fcool = (_fel < 0.45) ? make_color_rgb(170, 140, 255) : ((_fel < 0.65) ? make_color_rgb(80, 215, 200) : ((_fel < 0.85) ? make_color_rgb(255, 95, 120) : make_color_rgb(255, 195, 95)));
			// the disk's spin goes with it: the wind leaves with a little twist
			var _ftw = random_range(0.3, 1.1) * ((_fho.tilt mod 2 < 1) ? 1 : -1);
			var _fow = { ox: _fho.ox + lengthdir_x(_fhr * 1.4, _fang), oy: _fho.oy + lengthdir_y(_fhr * 1.4, _fang), ang: _fang,
				c: make_color_rgb(205, 220, 255), s: _fsz, s0: _fsz, smax: _fsz * random_range(1.8, 3), a: random_range(0.035, 0.07), at: 0.05, f: 1, ex: 1, st: 1.3, tx: 1,
				fr: irandom(3), u: false, vx: lengthdir_x(_fvel, _fang) + lengthdir_x(_ftw, _fang + 90), vy: lengthdir_y(_fvel, _fang) + lengthdir_y(_ftw, _fang + 90) };
			scr_hex_wisp_norm(_fow);
			_fow.fl = true; _fow.cool = _fcool;
			_fow.dmp = random_range(0.93, 0.98);                               // each puff ploughs through its own drag: they land scattered
			array_push(_fhz, _fow);
			array_push(global.hex_flow, _fow);
		}
	}
}
scr_prof_lap("feeding + outflow");   // (capture key: C)
// gas thrown out by black holes flies on, slowing and cooling from blue-white to her violet, then settles into the garden
if (!variable_global_exists("hex_flow")) global.hex_flow = [];
var _flyon = [], _flvio = make_color_rgb(165, 95, 210);
for (var i = 0; i < array_length(global.hex_flow); i++) {
	var _fl = global.hex_flow[i];
	_fl.ox += _fl.vx; _fl.oy += _fl.vy;
	var _fdm = 0.985;
	if (variable_struct_exists(_fl, "dmp")) { _fdm = _fl.dmp; _fl.dmp = lerp(_fl.dmp, 0.985, 0.08); }   // the Big Bang's inflation: heavy drag relaxing
	_fl.vx *= _fdm;  _fl.vy *= _fdm;
	var _flv = abs(_fl.vx) + abs(_fl.vy);
	_fl.ang = point_direction(0, 0, _fl.vx, _fl.vy);
	_fl.st  = 1 + min(0.8, _flv * 0.15) * (variable_struct_exists(_fl, "cool") ? 0 : 1);   // a little drawn out by its speed, not a streak
	if (_fl.s < _fl.smax) _fl.s += 0.05;
	_fl.c   = merge_color(_fl.c, variable_struct_exists(_fl, "cool") ? _fl.cool : _flvio, 0.008);
	if (_fl.f <= 0.01 || _flv < 0.3) _fl.fl = false;                       // landed
	else array_push(_flyon, _fl);
}
global.hex_flow = _flyon;                                                  // rebuilt in one pass: far cheaper than deleting one by one
scr_prof_lap("gas in flight");   // (capture key: C)
// every couple of seconds, gas that's been eaten or faded to nothing is swept out, so there's always room for new gas
if (t mod 120 == 0) {
	var _sw = global.hex_haze, _swk = [];
	for (var i = 0; i < array_length(_sw); i++) if (_sw[i].f > 0.01) array_push(_swk, _sw[i]);
	if (array_length(_swk) < array_length(_sw)) { global.hex_haze = _swk; global.hex_haze_i = 0; }
}
scr_prof_lap("dead-gas sweep");   // (capture key: C)
// a supermassive tears apart a star that strays too close (a tidal disruption event): about half of it is flung out in a
// glowing stream, the rest spirals in, and its disk flares
var _tsm = scr_hex_find_smbh();
if (!is_undefined(_tsm) && _tsm.age > HEX_GATHER + _fpsn * 3) {
	tde_tick--;
	if (tde_tick <= 0) {
		tde_tick = irandom_range(_fpsn * 12, _fpsn * 22);
		var _tr = scr_hex_hole_size(_tsm);
		var _tbest = undefined, _tbd = _tr * 10;
		for (var i = 0; i < array_length(global.hex_stars); i++) {
			var _tst = global.hex_stars[i];
			if (_tst.s <= 0 || _tst[$ "dying"] == true) continue;
			var _td = point_distance(_tst.ox, _tst.oy, _tsm.ox, _tsm.oy);
			if (_td < _tbd && _td > _tr * 1.5) { _tbd = _td; _tbest = _tst; }
		}
		if (!is_undefined(_tbest)) {
			var _tc  = scr_hex_star_color(_tbest.m, _tbest.ph, _tbest.hx);
			var _ta0 = point_direction(_tsm.ox, _tsm.oy, _tbest.ox, _tbest.oy);
			for (var j = 0; j < 22 && array_length(global.hex_haze) < HEX_HAZE_CAP + 800; j++) {
				var _tk  = j / 21;
				var _tang = _ta0 - 50 * _tk;                                    // stretched along its orbit into an arc
				var _tdd  = _tbd * (0.85 + 0.3 * _tk);
				var _tsz  = random_range(6, 10);
				var _tw = { ox: _tsm.ox + lengthdir_x(_tdd, _tang), oy: _tsm.oy + lengthdir_y(_tdd, _tang), ang: _tang - 90,
					c: merge_color(_tc, make_color_rgb(255, 210, 170), 0.4), s: _tsz, s0: _tsz, smax: _tsz * 2, a: 0.1, at: 0.1, f: 1,
					ex: 1, st: 1.8, tx: 1, fr: 4 + irandom(3), u: false };
				scr_hex_wisp_norm(_tw);
				if (j mod 2 == 0) {                                             // half is unbound: flung outward
					var _tv = random_range(4, 7);
					_tw.vx = lengthdir_x(_tv, _tang - 70); _tw.vy = lengthdir_y(_tv, _tang - 70); _tw.fl = true;
					array_push(global.hex_flow, _tw);
				}
				array_push(global.hex_haze, _tw);
			}
			array_push(ignitions, { ox: _tbest.ox, oy: _tbest.oy, t0: t, big: true, s: 3, merged: false, c: _tc });
			if (!variable_global_exists("hex_marks")) global.hex_marks = [];   // Inspect names it for a few seconds
			array_push(global.hex_marks, { ox: _tbest.ox, oy: _tbest.oy, txt: "tidal disruption: a star torn apart", t: _fpsn * 5 });
			if (array_length(global.hex_marks) > 12) array_delete(global.hex_marks, 0, 1);   // (only counted down while Inspect is on)
			_tsm.m += _tbest.m * 0.5;
			_tsm.feed = (variable_struct_exists(_tsm, "feed") ? _tsm.feed : 0) + 40;
			_tbest.s = 0;
			for (var j = array_length(global.hex_stars) - 1; j >= 0; j--) if (global.hex_stars[j] == _tbest) { array_delete(global.hex_stars, j, 1); break; }
		}
	}
}
scr_prof_lap("tidal disruption");   // (capture key: C)
// the infall: the closer it gets, the faster it goes round and the faster it falls, like a planet close to its sun
for (var i = array_length(infall) - 1; i >= 0; i--) {
	var _fi = infall[i];
	var _fw = min(14, 160 / power(max(_fi.r, 4), 1.2));
	_fi.a += _fw * _fi.nu.spin;
	_fi.r -= 0.2 + 14 / max(_fi.r, 4);                    // slow enough that you can watch it wind in
	_fi.age++;
	_fi.w = _fw;                                                            // Draw stretches it by how fast it's going round
	if (_fi.r <= 3) { infall[i] = infall[array_length(infall) - 1]; array_pop(infall); }
}
scr_prof_lap("infall");   // (capture key: C)
// ---- stardust: the quiet part. the doomed crumble head first, every pixel becoming a mote of its own color.
// each mote has a fate: most is cloud dust that drifts like smoke and eases to rest around where its star is forming,
// thinning into the dark or staying as haze (her nebula, growing from her dead). the rest is star dust: bright threads
// that stream into the star and condense into its color. a body's star catches when its last thread lands ----
if (t >= birth_at && instance_exists(obj_player)) {
	var _fpsd = game_get_speed(gamespeed_fps);

	// 1) shed: every pixel that crumbles off becomes a mote, the color of that exact pixel, and gets its fate
	with (obj_enemy_parent) {
		if (unmaking <= 0 || !variable_instance_exists(id, "crumble_at")) continue;
		var _ck   = clamp((other.t - crumble_at) / other.crumble_len, 0, 1);
		var _want = floor(_ck * dust_n);
		while (dust_out < _want) {
			var _mx, _my, _c0;
			if (!is_undefined(dust_pix) && array_length(dust_pix.px) > 0) {
				// a real pixel from the crumbling band, in crumble order, so motes come off where the body is breaking
				var _list = dust_pix.px;
				var _pk = _list[min(array_length(_list) - 1, floor((dust_out + random(1)) / dust_n * array_length(_list)))];
				_mx = x + (_pk.u + 0.5 - sprite_get_xoffset(sprite_index)) * image_xscale;
				_my = y + (_pk.v + 0.5 - sprite_get_yoffset(sprite_index)) * image_yscale;
				_c0 = _pk.c;
			} else {   // no sprite to read: a spot in its box, in her violet
				_mx = random_range(bbox_left, bbox_right);
				_my = lerp(bbox_top, bbox_bottom, dust_out / dust_n);
				_c0 = HEX_VIOLET;
			}
			var _cg = scr_hex_gas_color(_c0);
			if (_cg != -1 && random(1) < 0.25) _cg = merge_color(_cg, make_color_rgb(255, 85, 115), 0.5); // every cloud is mostly hydrogen

			// its fate: star dust is spread evenly through the body (so exactly dust_stream of them stream), the rest settles
			var _strm = (floor((dust_out + 1) * dust_stream / dust_n) > floor(dust_out * dust_stream / dust_n));
			if (_strm) other.streams_live++;
			// cloud dust comes to rest somewhere around the region where this body's star is forming: a stellar nursery
			var _srr = 30 + power(random(1), 0.7) * 110, _sa = random(360);

			array_push(other.motes, {
				mx: _mx - obj_player.x, my: _my - obj_player.y,      // stored relative to her, like her sky
				vx: random_range(-0.5, 0.5), vy: random_range(-1, 0), // a little puff as it comes loose
				age: 0, d: 999, e: id, p: star_plan,
				strm: _strm,                                          // true: streams into its star. false: settles into cloud
				sox: star_plan.ox + lengthdir_x(_srr, _sa),           // where cloud dust comes to rest, in her sky's own frame
				soy: star_plan.oy + lengthdir_y(_srr, _sa),
				sp: 0, fd: 1, st: 0,                                  // how settled it looks, its fade, and 1 once it has come to rest
				re: random_range(18, 36), ae: random_range(0.08, 0.16), // it puffs out into a big, faint glow as it settles: gas is volume, so dense spots glow brighter as they overlap
				sd: random(100),                                      // its own seed, so every mote wobbles differently
				ps: abs(image_xscale),                                // one of its pixels, at the size it's drawn: the chunk that breaks off
				rot: random(360), spin: random_range(-9, 9),          // the chunk tumbles as it falls
				c0: _c0,                                              // its creature's color
				dk: (_cg == -1),                                      // dark dust: soot
				cg: (_cg == -1) ? make_color_rgb(55, 40, 50) : _cg,   // the gas it glows as
				cs: scr_hex_star_color(star_plan.mp, star_plan.ph, star_hexed) // the star it will become (star dust only)
			});
			dust_out++;
		}
	}
	var _births = [];   // stars that caught this frame: they blow the gas around them outward (below)
	var _mkc = dcos(sky_angle), _mks = dsin(sky_angle);   // her sky's turn, worked out once for every mote this frame
	// 2) fly: tumble, then steer. each frame it turns a little toward where it wants to go, so its path curves
	for (var i = array_length(motes) - 1; i >= 0; i--) {
		var _mt = motes[i];
		_mt.age++;

		// already at rest: it thins away into the dark, drifting the last little bit
		if (_mt.st == 1) {
			_mt.fd -= 1 / (_fpsd * 2.5);             // the rest of the cloud spreads out and thins slowly, never just vanishing
			_mt.vx *= 0.9; _mt.vy *= 0.9;
			_mt.mx += _mt.vx; _mt.my += _mt.vy;
			if (_mt.fd <= 0) { motes[i] = motes[array_length(motes) - 1]; array_pop(motes); }
			continue;
		}

		// where it's headed right now, as her sky turns: its star (star dust) or its resting place (cloud dust)
		var _cnd = _mt.strm;
		var _gox = _cnd ? _mt.p.ox : _mt.sox, _goy = _cnd ? _mt.p.oy : _mt.soy; // until then, star dust drifts with the cloud toward the nursery
		var _tx = _gox * _mkc + _goy * _mks - _mt.mx, _ty = _goy * _mkc - _gox * _mks - _mt.my;   // turned with her sky
		var _d  = max(0.01, sqrt(_tx * _tx + _ty * _ty));
		_mt.d = _d;                                                           // Draw uses it to blend its look as it arrives

		if (_cnd) {
			// star dust landed (or out of time): its protostar grows, and if it was its body's last thread, that star catches
			if (_d < 3 + abs(_mt.vx) + abs(_mt.vy) || _mt.age > dust_life) {
				_mt.p.landed++;
				if (_mt.p.landed == 1) array_push(protos, _mt.p);
				if (instance_exists(_mt.e)) {
					_mt.e.dust_left--;
					if (_mt.e.dust_left <= 0) {
						_mt.e.unmake_at = t;                         // the enemy's own Step sees this and ignites its star
						if (_mt.p.idx < 0 && !_mt.p.lit) {                // a brand new star, and its light hasn't gone off yet
							_mt.p.lit = true;
							array_push(_births, { bx: _mt.mx + _tx, by: _mt.my + _ty,
								c: scr_hex_star_color(_mt.p.mp, _mt.p.ph), m: _mt.p.mp });
						}
					}
				}
				streams_live--;
				motes[i] = motes[array_length(motes) - 1];          // move the last mote into this slot and drop the end:
				array_pop(motes);                                    // far cheaper than array_delete with thousands of motes
				continue;
			}
		} else if (!_mt.strm) {
			// cloud dust: the closer it gets to its resting place, the more it softens into a round, dim glow
			_mt.sp = clamp(1 - _d / 90, 0, 1);     // starts puffing out well before it arrives, like smoke slowing and spreading
			if (_d < 4 && abs(_mt.vx) + abs(_mt.vy) < 0.5) {
				// at rest. by now it's drawn exactly like a wisp, so some of it stays as lasting haze with no pop
				if (random(1) < wisp_keep) {
					var _hzl = point_distance(0, 0, _mt.mx, _mt.my);
					var _hza = point_direction(0, 0, _mt.mx, _mt.my) - sky_angle;     // into her sky's own frame, so it turns with the stars
					var _hzw = { ox: lengthdir_x(_hzl, _hza), oy: lengthdir_y(_hzl, _hza), ang: random(360),
					             c: _mt.dk ? -1 : _mt.cg, s: _mt.re, s0: _mt.re, smax: _mt.re * random_range(1.8, 2.8), a: _mt.ae, f: 1,
					             at: _mt.ae * 2.4,                           // fewer wisps are kept now, so each grows brighter: same nebula, fewer draws
					             tx: 0, fr: irandom(7), ex: 1, st: 1, u: false }; // tx: its texture fades in, so a round puff of settling dust grows wisps with no pop
					scr_hex_haze_add(_hzw);
					motes[i] = motes[array_length(motes) - 1];
					array_pop(motes);
					continue;
				}
				_mt.st = 1;                                          // the rest thins away into the dark
				_mt.sp = 1;
				continue;
			}
			if (_mt.age > settle_life) {                             // never found rest: some still stays as haze right where it is, the rest thins away
				if (random(1) < wisp_keep) {
					var _hzl = point_distance(0, 0, _mt.mx, _mt.my);
					var _hza = point_direction(0, 0, _mt.mx, _mt.my) - sky_angle;
					var _hzs = lerp(4, _mt.re, _mt.sp);                 // as big as it looks right now, so nothing pops
					scr_hex_haze_add({ ox: lengthdir_x(_hzl, _hza), oy: lengthdir_y(_hzl, _hza), ang: random(360),
					                   c: _mt.dk ? -1 : _mt.cg, s: _hzs, s0: _hzs, smax: _mt.re * random_range(1.8, 2.8), a: _mt.ae * max(0.3, _mt.sp), f: 1,
					                   at: _mt.ae * 2.4, tx: 0, fr: irandom(7), ex: 1, st: 1, u: false });
					motes[i] = motes[array_length(motes) - 1];
					array_pop(motes);
					continue;
				}
				_mt.st = 1; continue;
			}
		}

		// once her hold has it, each mote only re-steers every other frame (alternating halves of the swarm) and just coasts in between.
		// the curves come out the same, at half the cost
		if (_mt.age > dust_fall + _fpsd * 0.5 && ((i + t) & 1)) { _mt.mx += _mt.vx; _mt.my += _mt.vy; continue; }
		var _grip = clamp((_mt.age - dust_fall) / (_fpsd * 0.5), 0, 1); // 0 while it drifts down like ash, then her hold builds
		var _sk   = (_mt.age > dust_fall + _fpsd * 0.5) ? 1.9 : 1;          // a steering frame now covers two frames' worth of turning
		_mt.vy += 0.07 * (1 - _grip);                                     // ash falling
		if (_grip > 0) {
			var _mr  = max(0.01, sqrt(_mt.mx * _mt.mx + _mt.my * _mt.my));
			var _tnx = _mt.my / _mr, _tny = -_mt.mx / _mr;                // sideways around her, the way her sky turns (no trig needed)
			var _sp, _swv, _wx, _wy;
			if (_cnd) {
				_sp  = min(10, 1.5 + _d * 0.05);                       // star dust: farther = faster, so threads arrive around together
				_swv = dust_swirl * 8 * min(1, _d / 150);                 // the swirl fades as it closes in, so it can land
				_wx  = _tx / _d * _sp + (_swv * _tnx);
				_wy  = _ty / _d * _sp + (_swv * _tny);
				_mt.vx += (_wx - _mt.vx) * 0.09 * _grip * _sk;                 // a firm hold: smooth curves, never a snap
				_mt.vy += (_wy - _mt.vy) * 0.09 * _grip * _sk;
			} else {
				_sp  = min(3.5, _d * 0.035);                             // cloud dust: slows to a stop as it reaches its place (it settles, it never lands)
				_swv = dust_swirl * 4 * min(1, _d / 200);                 // a gentler swirl
				_wx  = _tx / _d * _sp + (_swv * _tnx) + sin(_mt.age * 0.07 + _mt.sd) * 0.25;  // and a lazy wobble, like smoke
				_wy  = _ty / _d * _sp + (_swv * _tny) + cos(_mt.age * 0.06 + _mt.sd) * 0.25;
				_mt.vx += (_wx - _mt.vx) * 0.05 * _grip * _sk;                 // a softer hold: it drifts more than it steers
				_mt.vy += (_wy - _mt.vy) * 0.05 * _grip * _sk;
			}
		}
		_mt.mx += _mt.vx;
		_mt.my += _mt.vy;
	}
	
	// 2b) each newborn star's light and wind blow the gas around it outward: a little bubble opens in the cloud,
	// then the settling dust drifts back toward its place. the clearest sign in a real nursery that a star was just born
	for (var b = 0; b < array_length(_births); b++) {
		var _bpx = _births[b].bx, _bpy = _births[b].by;
		for (var j = 0; j < array_length(motes); j++) {
			var _bq = motes[j];
			if (_bq.strm) continue;                                    // only gas, not threads still streaming in
			var _bqx = _bq.mx - _bpx, _bqy = _bq.my - _bpy;
			var _bqd = point_distance(0, 0, _bqx, _bqy);
			if (_bqd > 90 || _bqd < 0.01) continue;
			var _bqk = (1 - _bqd / 90) * 2.5;                          // strongest right beside the star
			_bq.vx += _bqx / _bqd * _bqk;
			_bq.vy += _bqy / _bqd * _bqk;
		}
	}

	// 3) lasting wisps keep diffusing slowly: spreading out and thinning, the way gas does
	var _hz = global.hex_haze;
	for (var i = 0; i < array_length(_hz); i++) {
		var _hq = _hz[i];
		if (_hq.s < _hq.smax) _hq.s += (_hq.tx < 1) ? 0.3 : 0.08;   // fresh gas billows out quickly as it settles, then keeps slowly spreading
		if (_hq.a < _hq.at) _hq.a += 0.003;   // fresh haze slowly brightens, taking over the light of the dust fading around it
		if (_hq.tx < 1) _hq.tx = min(1, _hq.tx + 0.008);
		if (_hq.u && _hq.st > 1.2) { _hq.st -= 0.002; if (_hq.st <= 1.2) _hq.u = false; }   // a birth's jet streaks slowly loosen and rejoin the garden
	}

	// 4) every body crumbled and every thread of star dust landed: the finale, with time after it for the sky to settle
	if (finale_at == infinity && t > crumble_end && streams_live <= 0) {
		finale_at = t + floor(_fpsd * 0.15);
		duration  = max(duration, finale_at + floor(_fpsd * 2.5));
	}
}
scr_prof_lap("stardust motes");   // (capture key: C)
// the finale: once every star is lit, one great pulse
if (!pulsed && t >= finale_at) {
	pulsed = true;
	pulse_t = 0;
	global.shake = max(global.shake, 10);
}
if (pulse_t >= 0) pulse_t++;
// (the old accretion, newborn stars merging into black holes by script, is deleted: legacy #3)
if (t >= duration) {
	if (!gaze && instance_exists(obj_player)) scr_hex_return(obj_player.x, obj_player.y);   // no shockwave after just watching
	instance_destroy();
}
if (t == 1) global.shake = max(global.shake, 5);	//time locks
if (t >= glitch_at && t < still_at) global.shake = max(global.shake, 3); //reality glitches
if (t >= tear_at && t < tear_at + tear_len) global.shake = max(global.shake, 4);   // the ground rumbles as it splits
if (t >= still_at && t < tear_at) global.shake = 0;	 //total stillness:
if (t >= tear_at + tear_len && t < shatter_at) global.shake = max(global.shake, 1 + 4 * sqr((t - tear_at - tear_len) / gape_len)); // pressure building
scr_prof_lap("finale");   // (capture key: C)
// PERF PROBE: the first few frames, and then once a second, print how long this Step took
if (prof_frames < 6 || t mod 60 == 0) show_debug_message("[UNMAKING] t " + string(t) + " step " + string((get_timer() - _prof_s) / 1000) + " ms | motes " + string(array_length(motes)) + " | haze " + string(array_length(global.hex_haze)));
