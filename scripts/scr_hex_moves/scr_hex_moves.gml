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
		hvx: 0, hvy: 0,   // how fast that point moved this frame
		hold_vx: 0, hold_vy: 0,   // how a held enemy moved this frame (a throw inherits it)
		gx: _x, gy: _y,   // the knot: where her reaching hex gathers (follows the cursor gently)
		ra: undefined,    // her reach's anchor while reaching: the river's HEAD (follows the cursor)
		ca: undefined,    // the CLAIM: the anchor on the thing her head reached (its hex cups it; when paid, it lifts)
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
	if (!is_undefined(_mv.ca) && !instance_exists(_mv.ca.attach)) hex_move_unclaim(_b);   // (what she claimed is gone: its hex rejoins the river)
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
// the river's HEAD, which follows the cursor; the hex eddies around it, and when she moves it fast the hex streams after
// it. CLAIM: when the head reaches something liftable, it claims it: the head's nearest hex flows onto it, her palm pours
// the rest of its cost straight into it, and that hex cups it (the levitation). When its own hex reaches its cost, it lifts.
// Pull the head away first and the claim lets go (its hex rejoins the river).
function hex_move_reach(_b, _in) {
	var _mv = _b.mv, _ht = _b.tune, _ra = _mv.ra;
	// the head: where her hex is flowing to. It follows the cursor (a new reach starts right at the cursor)
	if (_ra.at <= 0.01 && _ra.out <= 0.01) { _mv.gx = _mv.hx; _mv.gy = _mv.hy; }
	else { _mv.gx = lerp(_mv.gx, _mv.hx, _ht.head_follow); _mv.gy = lerp(_mv.gy, _mv.hy, _ht.head_follow); }
	hex_anchor_move(_ra, _mv.gx, _mv.gy);
	if (_mv.held == noone) {
		// nothing claimed yet: does the head reach something?
		if (is_undefined(_mv.ca)) {
			var _tg = hex_move_find_target(_b, _mv.gx, _mv.gy);
			if (_tg.inst != noone) {
				_mv.ca = hex_anchor_make(_b, "claim", _tg.inst.x, _tg.inst.y, _tg.cost);
				hex_anchor_attach(_b, _mv.ca, _tg.inst);
				_mv.ca.shape = "cup";
				_mv.kind = _tg.kind; _mv.cost = _tg.cost;
				hex_anchor_give(_b, _ra, _mv.ca, _tg.cost);   // the head's nearest hex flows onto it
			}
		}
		if (!is_undefined(_mv.ca)) {
			var _c = _mv.ca.attach;
			if (hex_move_edge_dist(_b, _c, _mv.gx, _mv.gy) > _ht.grab_r * _ht.claim_hold) hex_move_unclaim(_b);   // the head pulled away first: it lets go
			else {
				// as her hex gathers on it, the thing starts to stir and rise (obj_env_parent reads hex_gather)
				if (_mv.kind == "env") _c.hex_gather = max(_c.hex_gather, clamp(_mv.ca.at / max(1, _mv.cost), 0, 1));
				if (_mv.ca.at >= _mv.cost - 0.001) {
					// its own hex has reached its cost: it lifts. The head's leftover hex unravels home (one hold, for now)
					_mv.held = _c;
					if (_mv.kind == "env") _c.grabbed = true;
					_mv.ca.kind = "hold";
					hex_anchor_trim(_b, _ra, 0);
				}
			}
		}
	}
	// her hand pours: into the claim until its cost is there, otherwise into the head (holding something: nothing more)
	if (_mv.held != noone) _ra.want = 0;
	else if (!is_undefined(_mv.ca)) { _ra.want = 0; hex_core_pour(_b, _mv.ca, _in.hand_x, _in.hand_y); }
	else { _ra.want = infinity; hex_core_pour(_b, _ra, _in.hand_x, _in.hand_y, _mv.gx, _mv.gy); }
}

// the liftable thing nearest (_x, _y) within grab_r, measured to its edge: a rock (liftable, movable, not held) or an
// enemy (not a boss, not a toad). Every candidate counts, so one that can't be lifted never hides one that can.
// Returns { inst, kind, cost } (inst = noone: nothing)
function hex_move_find_target(_b, _x, _y) {
	var _ht = _b.tune, _best = noone, _bd = _ht.grab_r, _kind = "";
	with (obj_env_parent) {
		if (!liftable || !movable || grabbed) continue;
		var _d = point_distance(_x, _y, x, y) - r;
		if (_d <= _bd) { _bd = _d; _best = id; _kind = "env"; }
	}
	var _l = ds_list_create();
	var _n = collision_circle_list(_x, _y, _ht.grab_r + _ht.enemy_r, obj_enemy_parent, false, true, _l, false);
	for (var _i = 0; _i < _n; _i++) {
		var _e = _l[| _i];
		if (_e.is_boss || _e.curse < 0) continue;
		var _d = point_distance(_x, _y, _e.x, _e.y) - _ht.enemy_r;
		if (_d <= _bd) { _bd = _d; _best = _e; _kind = "enemy"; }
	}
	ds_list_destroy(_l);
	var _cost = 0;
	if (_best != noone) _cost = (_kind == "env") ? round(_ht.cost_lift * _best.weight) : _ht.cost_enemy;
	return { inst: _best, kind: _kind, cost: _cost };
}

// how far (_x, _y) is from the edge of _inst
function hex_move_edge_dist(_b, _inst, _x, _y) {
	return point_distance(_x, _y, _inst.x, _inst.y) - hex_core_inst_r(_b, _inst);
}

// let go of a claim that hasn't lifted (or whose thing is gone): its hex rejoins the river's head (or goes home if
// she isn't reaching any more)
function hex_move_unclaim(_b) {
	var _mv = _b.mv;
	if (is_undefined(_mv.ca)) return;
	if (!is_undefined(_mv.ra)) hex_anchor_give(_b, _mv.ca, _mv.ra, infinity);
	hex_anchor_release(_b, _mv.ca, "melt");
	_mv.ca = undefined;
	_mv.held = noone; _mv.kind = ""; _mv.cost = 0;
}

// (_vx, _vy) no longer than _max, as [vx, vy]
function hex_move_cap(_vx, _vy, _max) {
	var _l = point_distance(0, 0, _vx, _vy);
	if (_l > _max) { _vx *= _max / _l; _vy *= _max / _l; }
	return [_vx, _vy];
}

// steer what she holds toward the cursor; heavier things follow more sluggishly, and nothing she holds moves faster
// than hold_speed (it has weight: no flicking it across the world). (A held enemy is moved in hex_move_end_step instead,
// after it has tried to move)
function hex_move_steer(_b) {
	var _mv = _b.mv, _ht = _b.tune, _h = _mv.held;
	if (_h == noone || _mv.kind != "env") return;
	var _wk = 0.5 / max(0.25, _h.weight);
	var _tv = hex_move_cap((_mv.hx - _h.x) * _wk, (_mv.hy - _h.y) * _wk, _ht.hold_speed / max(1, _h.weight));
	_h.vx = lerp(_h.vx, _tv[0], 0.7);
	_h.vy = lerp(_h.vy, _tv[1], 0.7);
}

// REACH ENDS (secondary let go): throw what's held, or if nothing, the reach just drifts home
function hex_move_reach_end(_b) {
	var _mv = _b.mv;
	hex_move_throw(_b);
	hex_move_unclaim(_b);   // (a claim that never lifted)
	if (!is_undefined(_mv.ra)) { hex_anchor_release(_b, _mv.ra, "melt"); _mv.ra = undefined; }   // the river unravels home
	_mv.mode = "";
}

// THROW whatever her hex is holding: the hex that held it (her reach's anchor) lets go and drifts home from where it
// was, carried along a little by the throw
function hex_move_throw(_b) {
	var _mv = _b.mv, _h = _mv.held;
	if (_h == noone || !instance_exists(_h)) { _mv.held = noone; _mv.kind = ""; return; }
	var _pvx, _pvy;
	var _ht = _b.tune;
	if (_mv.kind == "env") {
		_h.grabbed = false;
		var _tv = hex_move_cap(_h.vx * _ht.throw_mult, _h.vy * _ht.throw_mult, _ht.throw_max);
		_h.vx = _tv[0];
		_h.vy = _tv[1];
		_h.vz = min(7, 3 + 0.15 * point_distance(0, 0, _h.vx, _h.vy));   // pops upward (harder throws arc higher), so it lobs and lands instead of skating off
		_pvx = _h.vx * 0.5; _pvy = _h.vy * 0.5;
	} else {
		// thrown with the motion it actually had in her hold (not the cursor's last jump), capped
		var _tv = hex_move_cap(_mv.hold_vx * _ht.throw_mult, _mv.hold_vy * _ht.throw_mult, _ht.throw_max);
		array_push(_mv.thrown, { inst: _h, vx: _tv[0], vy: _tv[1], hit: [] });
		_pvx = _tv[0] * 0.5; _pvy = _tv[1] * 0.5;
	}
	if (!is_undefined(_mv.ca)) { hex_anchor_release(_b, _mv.ca, "melt", _pvx, _pvy); _mv.ca = undefined; }   // the cup lets go, carried along by the throw
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
	_mv.ra = undefined; _mv.oa = undefined; _mv.ca = undefined;
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

// END STEP (after everything has tried to move): a held enemy follows the hex (with weight: smoothly, never faster than
// hold_speed), and thrown enemies fly: they slam into the horde, then land hard
function hex_move_end_step(_b) {
	var _mv = _b.mv, _ht = _b.tune;
	_mv.hold_vx = 0; _mv.hold_vy = 0;
	if (_mv.held != noone && instance_exists(_mv.held) && _mv.kind == "enemy") {
		var _h = _mv.held;
		var _tv = hex_move_cap((_mv.hx - _h.x) * _ht.hold_follow, (_mv.hy - _h.y) * _ht.hold_follow, _ht.hold_speed);
		_h.x += _tv[0];
		_h.y += _tv[1];
		_mv.hold_vx = _tv[0]; _mv.hold_vy = _tv[1];
	}
	if (global.game_state != "PLAYING") return;
	for (var _i = array_length(_mv.thrown) - 1; _i >= 0; _i--) {
		var _th = _mv.thrown[_i];
		if (!instance_exists(_th.inst)) { array_delete(_mv.thrown, _i, 1); continue; }
		_th.inst.x += _th.vx;
		_th.inst.y += _th.vy;
		_th.vx *= _ht.throw_drag;
		_th.vy *= _ht.throw_drag;
		var _s = point_distance(0, 0, _th.vx, _th.vy);
		var _l = ds_list_create();
		collision_circle_list(_th.inst.x, _th.inst.y, 16, obj_enemy_parent, false, true, _l, false);
		for (var _j = 0; _j < ds_list_size(_l); _j++) {
			var _o = _l[| _j];
			if (_o == _th.inst || array_contains(_th.hit, _o)) continue;
			array_push(_th.hit, _o);
			scr_damage_enemy(_o, round(4 + _s * _ht.throw_hit), make_color_rgb(150, 110, 255));
			if (instance_exists(_o)) { _o.x += _th.vx * 0.6; _o.y += _th.vy * 0.6; }
		}
		ds_list_destroy(_l);
		if (_s < 1.5) {
			if (instance_exists(_th.inst)) scr_damage_enemy(_th.inst, 8, make_color_rgb(150, 110, 255));
			array_delete(_mv.thrown, _i, 1);
		}
	}
}
