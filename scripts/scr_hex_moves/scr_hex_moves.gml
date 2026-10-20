// scr_hex_moves: HEX MOVES. Layer 2 of the hex (notes/hex-core-design.md).
// What a caster DOES with her hex: reach, lift, hold, throw, charge, fire, palm blast, let go. Moves are built only from
// scr_hex_core calls; they never touch parcels, amounts or anchors directly, never read input, and never read the
// caster's variables. Everything they need about the caster arrives each frame as an INTENT (see hex_move_update), so
// the same moves can be driven by the player, an AI, a familiar or a replay.
//
// A body's move state lives in body.mv (hex_move_init). Her tuning lives in body.tune.

// give a hex body its move state (call once, right after hex_body_create). (_x, _y): where the caster starts
function hex_move_init(_b, _x, _y) {
	_b.mv = {
		active: false,    // her hex stance is up (stance held)
		tap: 0,           // frames the stance has been held this press (short = a tap: a palm blast)
		mode: "",         // "grab" (secondary: reach out and lift) or "charge" (primary: an orb in front of her hand)
		hx: _x, hy: _y,   // where her hex is working: the cursor while reaching, in front of her hand while charging, her hand otherwise
		hvx: 0, hvy: 0,   // how fast that point moved this frame (a throw inherits it)
		gx: _x, gy: _y,   // the knot: where her reaching hex gathers (follows the cursor gently)
		ra: undefined,    // her reach's anchor while reaching (the knot, then what she lifts)
		oa: undefined,    // the orb's anchor while charging
		held: noone,      // the thing her hex is holding
		kind: "",         // "env" (an environment object: a rock...) or "enemy"
		cost: 0,          // what the held thing cost
		charge: 0,        // frames spent charging
		orb_n: 0,         // whole units in the charging orb (for sizing it)
		thrown: [],       // enemies flying through the air after a throw: { inst, vx, vy, hit }
		cd: { blast: 0 }  // COOLDOWNS: frames left before each move can be used again (hex_move_ready / hex_move_cool)
	};
}

// ---- COOLDOWNS: every move's timer lives in body.mv.cd, by name; its length is body.tune.<name>_cd (frames) ----
// can the move called _name be used right now?
function hex_move_ready(_b, _name) {
	var _v = _b.mv.cd[$ _name];
	return is_undefined(_v) || _v <= 0;
}
// the move called _name was just used: start its cooldown
function hex_move_cool(_b, _name) {
	var _len = _b.tune[$ _name + "_cd"];
	if (is_undefined(_len)) { show_debug_message("hex: no cooldown length \"" + _name + "_cd\" in her tuning"); _len = 0; }
	_b.mv.cd[$ _name] = _len;
}
// every cooldown ticks down once a frame (hex_move_update calls this)
function hex_move_tick(_b) {
	var _cd = _b.mv.cd, _names = variable_struct_get_names(_cd);
	for (var _i = 0; _i < array_length(_names); _i++) if (_cd[$ _names[_i]] > 0) _cd[$ _names[_i]] -= 1;
}

// THE STANCE, once a frame. _in is the caster's intent this frame:
//   stance, primary, primary_pressed, secondary, secondary_pressed   (what the player is pressing, from scr_input)
//   aim_x, aim_y      where she's aiming          x, y        where the caster is
//   hand_x, hand_y    her palm                    cx, cy      the middle of her body (where the stance gathers first)
//   depth             the depth to create shots at
function hex_move_update(_b, _in) {
	var _mv = _b.mv, _ht = _b.tune;
	hex_move_tick(_b);
	var _ha = point_direction(_in.x, _in.y, _in.aim_x, _in.aim_y);
	if (_mv.held != noone && !instance_exists(_mv.held)) _mv.held = noone;
	if (!is_undefined(_mv.ra) && _mv.ra.attach != noone && !instance_exists(_mv.ra.attach)) { hex_anchor_attach(_b, _mv.ra, noone); _mv.ra.kind = "knot"; }   // (what she held is gone: her reach is a free knot again)
	var _ox = _mv.hx, _oy = _mv.hy;

	if (_in.stance) {
		// HEX STANCE: while the stance is held her hex is ready in her palm. Her wand stands down and primary / secondary
		// cast with the hex instead: hold primary to coalesce an orb in front of her hand (release to fire it), hold
		// secondary to reach out at the cursor and lift what's there (release to throw it).
		if (!_mv.active) {
			_mv.active = true;
			_mv.tap = 0;
			_mv.mode = "";
			_mv.charge = 0;
			_mv.hx = _in.cx; _mv.hy = _in.cy;
			_ox = _in.cx; _oy = _in.cy;
		}
		_mv.tap++;
		if (_mv.mode == "" && _in.primary_pressed) { _mv.mode = "charge"; _mv.charge = 0; _mv.oa = hex_anchor_make(_b, "orb", _mv.hx, _mv.hy, _ht.charge_cap); }
		if (_mv.mode == "" && _in.secondary_pressed) { _mv.mode = "grab"; _mv.ra = hex_anchor_make(_b, "knot", _mv.hx, _mv.hy, _ht.reach_cap); }

		// where the hex gathers: an orb in front of her hand, or the cursor (within her reach)
		var _tx = _in.hand_x, _ty = _in.hand_y;
		if (_mv.mode == "charge") {
			_tx = _in.hand_x + lengthdir_x(_ht.ball_dist, _ha);
			_ty = _in.hand_y + lengthdir_y(_ht.ball_dist, _ha);
		} else if (_mv.mode == "grab") {
			var _d = min(point_distance(_in.x, _in.y, _in.aim_x, _in.aim_y), _ht.reach_max);
			_tx = _in.x + lengthdir_x(_d, _ha);
			_ty = _in.y + lengthdir_y(_d, _ha);
		}
		_mv.hx = lerp(_mv.hx, _tx, 0.7); // snappy: the reach keeps up with the cursor
		_mv.hy = lerp(_mv.hy, _ty, 0.7);

		if (_mv.mode == "grab") hex_move_reach(_b, _in);
		if (_mv.mode == "charge") hex_move_charge(_b);
		_mv.orb_n = is_undefined(_mv.oa) ? 0 : floor(_mv.oa.pool);
		hex_move_steer(_b);

		// letting go of a button finishes that spell
		if (_mv.mode == "charge" && !_in.primary) hex_move_charge_end(_b, _ha, _in.depth);
		if (_mv.mode == "grab" && !_in.secondary) hex_move_reach_end(_b);
	} else if (_mv.active) {
		// letting go of the stance: anything held is thrown, a quick tap is a palm blast, and the rest of her hex flows home
		if (_mv.held != noone) hex_move_throw(_b);
		else if (_mv.tap <= _ht.tap_frames) hex_move_blast(_b, _in.hand_x, _in.hand_y, _ha, _in.depth);
		hex_move_let_go(_b);
	}
	if (!_mv.active) {
		_mv.hx = _in.hand_x;
		_mv.hy = _in.hand_y;
	}
	_mv.hvx = _mv.hx - _ox;
	_mv.hvy = _mv.hy - _oy;
}

// REACH (each frame while secondary is held): SHE POURS. Her hand lets hex out at a steady rate, down to her reserve, to
// the river's head, which follows the cursor; the hex eddies around it, and when she moves it fast the hex streams after
// it. If enough gathers near something liftable, it lifts (and any extra beyond its cost unravels home)
function hex_move_reach(_b, _in) {
	var _mv = _b.mv, _ht = _b.tune, _ra = _mv.ra;
	// the head: where her hex is flowing to. It follows the cursor (a new reach starts right at the cursor)
	if (_ra.at <= 0.01 && _ra.out <= 0.01) { _mv.gx = _mv.hx; _mv.gy = _mv.hy; }
	else { _mv.gx = lerp(_mv.gx, _mv.hx, _ht.head_follow); _mv.gy = lerp(_mv.gy, _mv.hy, _ht.head_follow); }
	if (_ra.attach == noone) hex_anchor_move(_ra, _mv.gx, _mv.gy);   // (until it lifts something, her reach's anchor IS the head)
	if (_mv.held == noone) {
		// is there something here to lift? the nearest environment object (measured to its edge), or an enemy
		var _target = noone, _kind = "", _cost = 0;
		var _r = noone, _rd = infinity, _sx = _mv.hx, _sy = _mv.hy;
		with (obj_env_parent) {
			if (!liftable || !movable || grabbed) continue;
			var _dd = point_distance(_sx, _sy, x, y) - r;
			if (_dd < _rd) { _rd = _dd; _r = id; }
		}
		if (_r != noone && _rd <= _ht.grab_r) {
			_target = _r; _kind = "env"; _cost = round(_ht.cost_lift * _r.weight);
		} else {
			var _e = instance_nearest(_mv.hx, _mv.hy, obj_enemy_parent);
			if (_e != noone && !_e.is_boss && _e.curse >= 0 && point_distance(_mv.hx, _mv.hy, _e.x, _e.y) <= _ht.grab_r) {
				_target = _e; _kind = "enemy"; _cost = _ht.cost_enemy;
			}
		}
		_ra.want = infinity;   // she pours for as long as she reaches (her reserve is the only limit)
		// as her hex gathers under it, the thing starts to stir and rise (obj_env_parent reads hex_gather)
		if (_target != noone && _kind == "env") _target.hex_gather = max(_target.hex_gather, clamp(_ra.at / max(1, _cost), 0, 1));
		if (_target != noone && _ra.at >= _cost - 0.001) {
			// enough of her hex has reached it: it lifts, and her reach's anchor rides on it now
			_mv.held = _target; _mv.kind = _kind; _mv.cost = _cost;
			if (_kind == "env") _target.grabbed = true;
			hex_anchor_attach(_b, _ra, _target);
			_ra.kind = "hold";
			hex_anchor_trim(_b, _ra, _cost);   // it holds exactly its cost; the rest unravels home (nothing extra orbits it)
		}
	} else _ra.want = _mv.cost;
	// her hand pours a steady stream of parcels at the head (holding something: only until its cost is there)
	hex_core_pour(_b, _ra, _in.hand_x, _in.hand_y, _mv.gx, _mv.gy);
}

// steer what she holds toward the cursor; heavier things follow more sluggishly (a held enemy is pinned in
// hex_move_end_step instead, after it has tried to move)
function hex_move_steer(_b) {
	var _mv = _b.mv;
	if (_mv.held == noone || _mv.kind != "env") return;
	var _wk = 0.5 / max(0.25, _mv.held.weight);
	_mv.held.vx = lerp(_mv.held.vx, (_mv.hx - _mv.held.x) * _wk, 0.7);
	_mv.held.vy = lerp(_mv.held.vy, (_mv.hy - _mv.held.y) * _wk, 0.7);
}

// REACH ENDS (secondary let go): throw what's held, or if nothing, the reach just drifts home
function hex_move_reach_end(_b) {
	var _mv = _b.mv;
	hex_move_throw(_b);
	if (!is_undefined(_mv.ra)) { hex_anchor_release(_b, _mv.ra, "melt"); _mv.ra = undefined; }   // (nothing held: it just drifts home)
	_mv.mode = "";
}

// THROW whatever her hex is holding: the hex that held it (her reach's anchor) lets go and drifts home from where it
// was, carried along a little by the throw
function hex_move_throw(_b) {
	var _mv = _b.mv, _h = _mv.held;
	if (_h == noone || !instance_exists(_h)) { _mv.held = noone; _mv.kind = ""; return; }
	var _pvx, _pvy;
	if (_mv.kind == "env") {
		_h.grabbed = false;
		_h.vx *= 1.6;
		_h.vy *= 1.6;
		_h.vz = min(7, 3 + 0.15 * point_distance(0, 0, _h.vx, _h.vy));   // pops upward (harder throws arc higher), so it lobs and lands instead of skating off
		_pvx = _h.vx * 0.5; _pvy = _h.vy * 0.5;
	} else {
		array_push(_mv.thrown, { inst: _h, vx: _mv.hvx * 1.6, vy: _mv.hvy * 1.6, hit: [] });
		_pvx = _mv.hvx * 0.8; _pvy = _mv.hvy * 0.8;
	}
	if (!is_undefined(_mv.ra)) { hex_anchor_release(_b, _mv.ra, "melt", _pvx, _pvy); _mv.ra = undefined; }
	_mv.held = noone;
	_mv.kind = "";
}

// CHARGE (each frame while primary is held): the orb draws hex straight out of her palm, up to a full charge (or as
// much as she has)
function hex_move_charge(_b) {
	var _mv = _b.mv;
	_mv.charge++;
	hex_anchor_move(_mv.oa, _mv.hx, _mv.hy);
	hex_core_feed(_b, _mv.oa, _b.tune.charge_rate);
}

// CHARGE ENDS (primary let go): fire the orb in direction _dir, or if it's too small (under charge_min: a quick tap),
// it melts back into her palm. (A quick tap of primary in the stance is free for a future move)
function hex_move_charge_end(_b, _dir, _depth) {
	var _mv = _b.mv, _ht = _b.tune, _oa = _mv.oa;
	if (_oa.pool >= _ht.charge_min) {
		// fire the orb forward: it flies until it hits something or leaves the screen. All the hex in it adds to the
		// boom, and it flows home to her afterward. The orb's anchor BECOMES the shot's (it rides on the shot now)
		var _c = _oa.pool;
		var _s = instance_create_depth(_mv.hx, _mv.hy, _depth, obj_hex_shot);
		_s.vx = lengthdir_x(15, _dir);
		_s.vy = lengthdir_y(15, _dir);
		_s.dmg = round(10 + _ht.boom_dmg * _c);
		_s.boom_r = 40 + _ht.boom_r * _c;
		_s.size = 0.6 + _c / 16;
		_oa.kind = "shot";
		hex_anchor_attach(_b, _oa, _s);
		_s.hex_body = _b; _s.hex_anchor = _oa;
	} else hex_anchor_release(_b, _oa, "melt");   // too small to fire: it melts back into her palm
	_mv.oa = undefined;
	_mv.mode = ""; _mv.charge = 0; _mv.orb_n = 0;
}

// PALM BLAST (a tap of the stance): a small shot from her palm (_x, _y) in direction _dir, carrying blast_cost hex.
// Her any-moment burst of energy, on a cooldown (blast_cd)
function hex_move_blast(_b, _x, _y, _dir, _depth) {
	var _ht = _b.tune;
	if (_b.hand < _ht.blast_cost || !hex_move_ready(_b, "blast")) return;
	hex_move_cool(_b, "blast");
	var _s = instance_create_depth(_x, _y, _depth, obj_hex_shot);
	_s.vx = lengthdir_x(16, _dir);
	_s.vy = lengthdir_y(16, _dir);
	_s.dmg = _ht.blast_dmg;
	_s.boom_r = 40;
	_s.size = 0.6;
	var _sa = hex_anchor_make(_b, "shot", _x, _y, _ht.blast_cost);   // the blast carries its hex in its own anchor
	hex_core_feed(_b, _sa, _ht.blast_cost);
	hex_anchor_attach(_b, _sa, _s);
	_s.hex_body = _b; _s.hex_anchor = _sa;
}

// LET GO (the stance ends): the rest of her hex flows home (an orb she never fired melts back into her palm)
function hex_move_let_go(_b) {
	var _mv = _b.mv;
	hex_core_release_all(_b);
	_mv.ra = undefined; _mv.oa = undefined;
	_mv.held = noone; _mv.kind = ""; _mv.active = false; _mv.charge = 0; _mv.orb_n = 0; _mv.mode = "";
}

// at the end of the caster's Step, once her sprite and position are final: her hex rests exactly in her palm (_hx, _hy),
// so the orb never trails a frame behind a turn or a step
function hex_move_rest(_b, _hx, _hy) {
	var _mv = _b.mv;
	if (_mv.active) return;
	_mv.hx = _hx;
	_mv.hy = _hy;
}

// END STEP (after everything has tried to move): pin a held enemy to the hex, and fly thrown enemies: they slam into
// the horde, then land hard
function hex_move_end_step(_b) {
	var _mv = _b.mv;
	if (_mv.held != noone && instance_exists(_mv.held) && _mv.kind == "enemy") {
		_mv.held.x = lerp(_mv.held.x, _mv.hx, 0.85);
		_mv.held.y = lerp(_mv.held.y, _mv.hy, 0.85);
	}
	if (global.game_state != "PLAYING") return;
	for (var _i = array_length(_mv.thrown) - 1; _i >= 0; _i--) {
		var _th = _mv.thrown[_i];
		if (!instance_exists(_th.inst)) { array_delete(_mv.thrown, _i, 1); continue; }
		_th.inst.x += _th.vx;
		_th.inst.y += _th.vy;
		_th.vx *= 0.93;
		_th.vy *= 0.93;
		var _s = point_distance(0, 0, _th.vx, _th.vy);
		var _l = ds_list_create();
		collision_circle_list(_th.inst.x, _th.inst.y, 16, obj_enemy_parent, false, true, _l, false);
		for (var _j = 0; _j < ds_list_size(_l); _j++) {
			var _o = _l[| _j];
			if (_o == _th.inst || array_contains(_th.hit, _o)) continue;
			array_push(_th.hit, _o);
			scr_damage_enemy(_o, round(4 + _s * 1.5), make_color_rgb(150, 110, 255));
			if (instance_exists(_o)) { _o.x += _th.vx * 0.6; _o.y += _th.vy * 0.6; }
		}
		ds_list_destroy(_l);
		if (_s < 1.5) {
			if (instance_exists(_th.inst)) scr_damage_enemy(_th.inst, 8, make_color_rgb(150, 110, 255));
			array_delete(_mv.thrown, _i, 1);
		}
	}
}
