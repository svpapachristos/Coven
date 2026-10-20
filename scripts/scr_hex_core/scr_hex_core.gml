// scr_hex_core: THE HEX CORE. Layer 1 of the hex (notes/hex-core-design.md).
// The ONLY code that changes a hex body's amounts, parcels or anchors. Moves (what she does with her hex) call these
// functions; the look (how it's drawn) only reads. Nothing in here knows about obj_player, input, or the Hexweaver.
//
// A HEX BODY is one caster's hex: her hand (home), her parcels (hex out in the world) and her anchors (places hex
// gathers). THE LEDGER: hand + parcels + anchor pools = max, always. hex_core_audit checks it.
//
// PARCELS: { x, y, vx, vy, s (its own pace), ph (its own phase), st, wait, hot, amt, a (its anchor, or undefined) }
// ANCHORS: { kind, x, y, px, py, vx, vy, attach, want, at, out, pool, r, arrive, sink, focus, loose, shape }
// An anchor's SHAPE is how its gathered hex sits: "churn" (circling it: the head, the knot) or "cup" (each parcel settled
// in its own spot in a cup under and around what it holds: the levitation itself)

#macro HEX_ST_FLOW   0   // a parcel flowing out to its anchor (the river)
#macro HEX_ST_GATHER 1   // a parcel that has arrived, churning around its anchor
#macro HEX_ST_HOME   2   // a parcel going home to her hand (a burst is home parcels launched with a kick)
#macro HEX_AUDIT_EPS 0.01  // the ledger may be off by this much (rounding) before the audit complains

// ---- TUNING: every number the hex uses. A caster passes her own values to hex_body_create; any she leaves out use
// these. (The Hexweaver's tuned numbers live in obj_player's Create, in the struct it passes in.)
function hex_tune_defaults() {
	return {
		// the amount
		max: 32,              // her max hex (an item's "max_hex" stat raises it)
		parcel: 0.25,         // how much hex one parcel carries (4 parcels per unit)
		// the river (parcels flowing out)
		pour_n: 2,            // parcels her hand lets out per frame while pouring (2 = half a unit a frame)
		flow: 9,              // how fast a parcel flows out (pixels a frame, each parcel 0.75x..1.25x of this)
		turn: 0.13,           // how quickly a parcel can change direction (lower = wider, lazier curves)
		curl: 0.85,           // how much the drifting currents push parcels around (higher = a wilder, wider river)
		fan: 0.425,           // how widely parcels leave her palm (radians)
		// going home
		return_speed: 20,     // how fast parcels come home, speeding up as they near her palm
		home_spread: 35,      // frames over which released parcels decide, one by one, to head home
		land_r: 14,           // a parcel this close to where her hand is headed is home
		release_jitter: 0.4,  // a little random push each parcel gets as it's released
		burst_speed: 2,       // how fast burst parcels fly out (a shot ending)
		burst_spread: 6,      // how far around the burst point they start
		// the flow (pouring by rate)
		reserve: 0,           // hex the flow never takes from her hand (an emergency reserve for a blast); 0 = none
		flow_spread: 0,       // a free anchor's churn widens by this x the square root of the hex on it (0 = never: a tight knot)
		flow_loose: 1000000,  // a free anchor moving faster than this (pixels a frame) loosens: its gathered hex streams after it
		// anchors
		knot_r: 8,            // a free anchor (the knot): how wide its parcels churn
		knot_arrive: 10,      // ...and how close a flowing parcel must get to count as arrived
		enemy_r: 14,          // how big an enemy counts as, for an anchor riding on it (rocks use their own r)
		hold_pad: 4,          // an anchor on a thing: its parcels churn this far outside the thing's edge
		hold_arrive_pad: 4,   // ...and arrive this much further out still
		hold_sink: 0.25,      // under something held, parcels pool lower by this much of the churn radius
		// the cup (an anchor whose shape is "cup": hex holding something up)
		cup_from: 0.1,        // the cup's arc, as fractions of the half circle under the thing (0 = its right side .. 1 = its left)
		cup_to: 0.9,
		cup_flat: 0.55,       // how flattened the cup is (1 = a half circle; lower = a shallower bowl)
		cup_drop: 0.2,        // how far below the thing's middle the cup sits (x its radius)
		cup_drift: 1.5,       // how much each parcel drifts around its spot (pixels)
		cup_pull: 0.25        // how firmly parcels settle into their spots (higher = tighter, snappier)
	};
}

// a new hex body for _owner. _tune: her numbers (any left out use hex_tune_defaults)
function hex_body_create(_owner, _tune = {}) {
	var _t = hex_tune_defaults();
	var _keys = variable_struct_get_names(_tune);
	for (var _i = 0; _i < array_length(_keys); _i++) _t[$ _keys[_i]] = _tune[$ _keys[_i]];
	return {
		owner: _owner,
		tune: _t,
		max: _t.max,
		hand: _t.max,         // her hand: home. Hex starts here and everything released comes back here
		parcels: [],
		anchors: [],
		pour_acc: 0,          // (parcels her hand is ready to let out this frame)
		audit_err: 0          // (the last ledger error the audit printed, so it prints once per change)
	};
}

// her max hex changed (an item, the H key): the difference lands in (or leaves) her hand
function hex_core_set_max(_b, _max) {
	if (_max == _b.max) return;
	_b.hand = max(0, _b.hand + (_max - _b.max));
	_b.max = _max;
}

// how much hex she has in hand right now (whole units, for the HUD)
function hex_core_available(_b) {
	return floor(_b.hand + 0.001);
}

// ---- ANCHORS ----

// a new anchor of _kind ("knot", "hold", "orb", "shot", "over") at (_x, _y), asking for _want hex. An anchor with
// keep = true (overflow: hex devoted to her own body) survives hex_core_release_all; only letting it go by name ends it
function hex_anchor_make(_b, _kind, _x, _y, _want) {
	var _a = { kind: _kind, x: _x, y: _y, px: _x, py: _y, vx: 0, vy: 0, attach: noone, want: _want, at: 0, out: 0, pool: 0, focus: 0,
		r: _b.tune.knot_r, arrive: _b.tune.knot_arrive, sink: 0, loose: false, shape: "churn", keep: false };
	array_push(_b.anchors, _a);
	return _a;
}

// put a free anchor somewhere (an attached one follows what it rides on instead)
function hex_anchor_move(_a, _x, _y) {
	_a.x = _x;
	_a.y = _y;
}

// how big an instance is, and how high it's floating, for an anchor riding on it
function hex_core_inst_r(_b, _inst) {
	return (_inst.object_index == obj_env_parent || object_is_ancestor(_inst.object_index, obj_env_parent)) ? _inst.r : _b.tune.enemy_r;
}
function hex_core_inst_z(_inst) {
	return (_inst.object_index == obj_env_parent || object_is_ancestor(_inst.object_index, obj_env_parent)) ? _inst.z : 0;
}

// ride on an instance (a rock, an enemy, a shot), or noone to ride on nothing. Its parcels reshape around it
function hex_anchor_attach(_b, _a, _inst) {
	_a.attach = _inst;
	hex_anchor_fit(_b, _a);
}

// work out an anchor's position and shape from what it rides on
function hex_anchor_fit(_b, _a) {
	var _t = _b.tune;
	if (_a.attach != noone && instance_exists(_a.attach)) {
		_a.x = _a.attach.x;
		_a.y = _a.attach.y - hex_core_inst_z(_a.attach);
		_a.r = hex_core_inst_r(_b, _a.attach) + _t.hold_pad;
		_a.arrive = _a.r + _t.hold_arrive_pad;
		_a.sink = _t.hold_sink;
	} else {
		// a free anchor: the more hex is gathered on it, the wider and looser it eddies (so a lot of hex is a cloud, not a ball)
		_a.r = _t.knot_r + _t.flow_spread * sqrt(max(0, _a.at));
		_a.arrive = _a.r + (_t.knot_arrive - _t.knot_r);
		_a.sink = 0;
	}
}

// hand up to _amt of anchor _from's hex (its parcels nearest _to first) over to anchor _to: they flow to it from where
// they are. (The head reaching something: its nearest hex flows onto it. A claim letting go: its hex rejoins the head)
function hex_anchor_give(_b, _from, _to, _amt) {
	var _list = [];
	for (var _i = 0; _i < array_length(_b.parcels); _i++) {
		var _q = _b.parcels[_i];
		if (_q.a == _from) array_push(_list, { q: _q, d: point_distance(_q.x, _q.y, _to.x, _to.y) });
	}
	array_sort(_list, function(_p, _r) { return _p.d - _r.d; });
	var _given = 0;
	for (var _i = 0; _i < array_length(_list); _i++) {
		var _q = _list[_i].q;
		if (_given + _q.amt > _amt + 0.001) break;
		_q.a = _to;
		_q.st = HEX_ST_FLOW;
		_given += _q.amt;
	}
	return _given;
}

// keep only _keep hex on anchor _a (gathered hex first, then hex still on its way); the rest of its parcels let go and
// drift home. (A lift that had more hex on it than it costs: the extra unravels home instead of orbiting the thing)
function hex_anchor_trim(_b, _a, _keep) {
	var _t = _b.tune, _kept = 0;
	for (var _pass = 0; _pass < 2; _pass++) {
		var _st = (_pass == 0) ? HEX_ST_GATHER : HEX_ST_FLOW;
		for (var _i = 0; _i < array_length(_b.parcels); _i++) {
			var _q = _b.parcels[_i];
			if (_q.a != _a || _q.st != _st) continue;
			if (_kept + _q.amt <= _keep + 0.001) { _kept += _q.amt; continue; }
			_q.st = HEX_ST_HOME;
			_q.a = undefined;
			_q.wait = irandom(_t.home_spread);
			_q.vx += random_range(-_t.release_jitter, _t.release_jitter);
			_q.vy += random_range(-_t.release_jitter, _t.release_jitter);
		}
	}
}

// let an anchor go. Its parcels head home, each on its own time, with a push of (_vx, _vy) (what she threw was
// moving). Its pool: "burst" = blasts out from where it is as parcels that drift home; "melt" = straight back into
// her hand. The anchor is gone afterward.
function hex_anchor_release(_b, _a, _how = "burst", _vx = 0, _vy = 0) {
	var _t = _b.tune;
	for (var _i = 0; _i < array_length(_b.parcels); _i++) {
		var _q = _b.parcels[_i];
		if (_q.a != _a) continue;
		_q.st = HEX_ST_HOME;
		_q.a = undefined;
		_q.wait = irandom(_t.home_spread);
		_q.vx += _vx + random_range(-_t.release_jitter, _t.release_jitter);
		_q.vy += _vy + random_range(-_t.release_jitter, _t.release_jitter);
	}
	if (_a.pool > 0) {
		if (_how == "melt") _b.hand += _a.pool;
		else hex_core_burst(_b, _a.x, _a.y, _a.pool);
		_a.pool = 0;
	}
	_a.at = 0; _a.out = 0;
	for (var _i = array_length(_b.anchors) - 1; _i >= 0; _i--) if (_b.anchors[_i] == _a) array_delete(_b.anchors, _i, 1);
}

// let every anchor go except shots in flight (they end on their own) and kept anchors (hex devoted to her body). What a
// caster does when she drops her hex
function hex_core_release_all(_b) {
	for (var _i = array_length(_b.anchors) - 1; _i >= 0; _i--) {
		var _a = _b.anchors[_i];
		if (_a.kind != "shot" && !_a.keep) hex_anchor_release(_b, _a, "melt");
	}
}

// ---- MOVING HEX ----

// her hand lets hex out as parcels flowing to anchor _a, from her palm (_fx, _fy), at pour_n parcels a frame, until what's
// on its way plus what's there reaches what it wants (infinity = for as long as she pours), and never into her reserve.
// Parcels leave aimed at (_ax, _ay) (default: the anchor)
function hex_core_pour(_b, _a, _fx, _fy, _ax = undefined, _ay = undefined) {
	var _t = _b.tune;
	if (is_undefined(_ax)) { _ax = _a.x; _ay = _a.y; }
	_b.pour_acc = min(_b.pour_acc + _t.pour_n, _t.pour_n);
	while (_b.pour_acc >= 1 && _a.out + _a.at < _a.want - 0.001 && _b.hand - _t.parcel >= _t.reserve - 0.001) {
		_b.pour_acc -= 1;
		_b.hand -= _t.parcel;
		_a.out += _t.parcel;
		var _ang = arctan2(_ay - _fy, _ax - _fx) + random_range(-0.5, 0.5) * _t.fan * 2;
		var _s = _t.flow * random_range(0.75, 1.25);
		array_push(_b.parcels, { x: _fx + random_range(-1.5, 1.5), y: _fy + random_range(-1.5, 1.5), vx: cos(_ang) * _s, vy: sin(_ang) * _s,
			s: _s, ph: random(6.28), st: HEX_ST_FLOW, wait: 0, hot: (random(1) < 0.35), amt: _t.parcel, a: _a });
	}
}

// her hand feeds anchor _a's pool directly (a charging orb, overflow): up to _rate a frame, never past what it wants,
// and never taking her hand below _floor (overflow passes her reserve; an orb may spend everything)
function hex_core_feed(_b, _a, _rate, _floor = 0) {
	var _c = max(0, min(_rate, _b.hand - _floor, _a.want - _a.pool));
	_b.hand -= _c;
	_a.pool += _c;
}

// _amt hex blasts out from (_x, _y) as parcels that drift home on their own time (a shot ending)
function hex_core_burst(_b, _x, _y, _amt) {
	var _t = _b.tune;
	while (_amt > 0.001) {
		var _k = min(_t.parcel, _amt);
		var _ang = random(6.28);
		array_push(_b.parcels, { x: _x + random_range(-_t.burst_spread, _t.burst_spread), y: _y + random_range(-_t.burst_spread, _t.burst_spread),
			vx: cos(_ang) * _t.burst_speed, vy: sin(_ang) * _t.burst_speed, s: _t.flow * random_range(0.75, 1.25), ph: random(6.28),
			st: HEX_ST_HOME, wait: irandom(_t.home_spread), hot: (random(1) < 0.35), amt: _k, a: undefined });
		_amt -= _k;
	}
}

// ---- ONCE A FRAME ----

// move everything along. (_hx, _hy): her palm; (_mvx, _mvy): how far she moved last frame, so hex coming home aims where
// her hand is headed and can always catch up to her
function hex_core_step(_b, _hx, _hy, _mvx, _mvy) {
	var _t = _b.tune, _time = current_time / 1000;
	// anchors follow what they ride on (an attached thing that's gone: the anchor stays where it was, free; a pool it
	// carried, like a shot's, bursts there). A free anchor moving fast is LOOSE this frame: its gathered hex streams after it
	for (var _i = 0; _i < array_length(_b.anchors); _i++) {
		var _a = _b.anchors[_i];
		if (_a.attach != noone && !instance_exists(_a.attach)) {
			_a.attach = noone;
			if (_a.pool > 0) { hex_core_burst(_b, _a.x, _a.y, _a.pool); _a.pool = 0; }
		}
		hex_anchor_fit(_b, _a);
		_a.vx = _a.x - _a.px; _a.vy = _a.y - _a.py;   // how it moved this frame (the cup moves with what it holds)
		_a.loose = (_a.attach == noone && point_distance(0, 0, _a.vx, _a.vy) > _t.flow_loose);
		_a.px = _a.x; _a.py = _a.y;
	}
	// every parcel moves on its own
	//   flow: steers toward its anchor at its own pace, pushed around by drifting currents (so the river braids)
	//   gather: churns around its anchor (pooling a little underneath anything held)
	//   home: waits its own moment, loosens and drifts, then is drawn back to her palm, faster as it nears
	for (var _i = array_length(_b.parcels) - 1; _i >= 0; _i--) {
		var _q = _b.parcels[_i];
		if (_q.st != HEX_ST_HOME && is_undefined(_q.a)) { _q.st = HEX_ST_HOME; _q.wait = 0; }   // (safety: no anchor, go home)
		if (_q.st == HEX_ST_HOME) {
			if (_q.wait > 0) {
				_q.wait--;
				_q.vx *= 0.93; _q.vy *= 0.93; _q.vy -= 0.02;   // loosening, drifting up a touch
			} else {
				var _hhx = _hx + _mvx, _hhy = _hy + _mvy;   // where her hand is headed
				var _dg = point_distance(_q.x, _q.y, _hhx, _hhy);
				if (_dg < _t.land_r) { _b.hand += _q.amt; array_delete(_b.parcels, _i, 1); continue; }   // home: back in her hand
				var _dr = (hex_vn(_q.x * 0.03 + _time * 0.7 + 9, _q.y * 0.03 + _q.ph) - 0.5) * _t.curl * min(1, _dg / 60);
				var _ang = arctan2(_hhy - _q.y, _hhx - _q.x) + _dr;
				var _s = min(_t.return_speed * (_q.s / _t.flow) * (1 + 1.5 * max(0, 1 - _dg / 80)), _dg * 0.5 + 1);
				_q.vx += (cos(_ang) * _s + _mvx - _q.vx) * _t.turn;   // (+ her motion: closing in on her, not on where she was)
				_q.vy += (sin(_ang) * _s + _mvy - _q.vy) * _t.turn;
			}
		} else {
			var _a = _q.a;
			if (_q.st == HEX_ST_GATHER && _a.loose) _q.st = HEX_ST_FLOW;   // her hex moved on fast: this bit streams after it
			var _dg = point_distance(_q.x, _q.y, _a.x, _a.y);
			if (_q.st == HEX_ST_FLOW) {
				var _dr = (hex_vn(_q.x * 0.025 + _time * 0.6, _q.y * 0.025 + _q.ph) - 0.5) * _t.curl;
				var _ang = arctan2(_a.y - _q.y, _a.x - _q.x) + _dr;
				var _s = min(_q.s, _dg * 0.25 + 1);
				// flowing to something that moves (a claim on a bat): add its motion, so the hex closes in on where it's going
				// (its speed near the target is capped to stop overshooting, and that cap alone was slower than a bat)
				var _avx = (_a.attach != noone) ? _a.vx : 0, _avy = (_a.attach != noone) ? _a.vy : 0;
				_q.vx += (cos(_ang) * _s + _avx - _q.vx) * _t.turn;
				_q.vy += (sin(_ang) * _s + _avy - _q.vy) * _t.turn;
				if (_dg < _a.arrive) _q.st = HEX_ST_GATHER;
			} else if (_a.shape == "cup") {
				// THE CUP: each parcel holds its own spot under and around what the anchor holds (its spot comes from its
				// phase), drifting a little. Together they're the levitation: no circling, no orbiting blob
				var _ang = pi * lerp(_t.cup_from, _t.cup_to, frac(_q.ph / 6.28));
				var _sx = _a.x + cos(_ang) * _a.r + _t.cup_drift * sin(_time * 1.7 + _q.ph * 3);
				var _sy = _a.y + sin(_ang) * _a.r * _t.cup_flat + _a.r * _t.cup_drop + _t.cup_drift * cos(_time * 1.3 + _q.ph * 2);
				_q.vx += ((_sx - _q.x) * _t.cup_pull + _a.vx - _q.vx) * 0.4;   // (+ the thing's own motion: the cup moves WITH it,
				_q.vy += ((_sy - _q.y) * _t.cup_pull + _a.vy - _q.vy) * 0.4;   //  instead of trailing behind)
			} else {
				var _r0 = _a.r + 4 * sin(_q.ph + _time * 2);
				var _gy2 = _a.y + _a.r * _a.sink;   // under something held, it pools a little lower
				var _d2 = max(point_distance(_q.x, _q.y, _a.x, _gy2), 0.01);
				var _ta = arctan2(_gy2 - _q.y, _a.x - _q.x) + 1.9;
				var _pl = (_d2 - _r0) * 0.08;
				_q.vx += (cos(_ta) * 1.3 + (_a.x - _q.x) / _d2 * _pl - _q.vx) * 0.15;
				_q.vy += (sin(_ta) * 1.3 + (_gy2 - _q.y) / _d2 * _pl - _q.vy) * 0.15;
			}
		}
		_q.x += _q.vx;
		_q.y += _q.vy;
	}
	// count what's on each anchor: gathered on it (at) and on its way (out), from its own parcels only
	for (var _i = 0; _i < array_length(_b.anchors); _i++) { _b.anchors[_i].at = 0; _b.anchors[_i].out = 0; }
	for (var _i = 0; _i < array_length(_b.parcels); _i++) {
		var _q = _b.parcels[_i];
		if (_q.st == HEX_ST_FLOW) _q.a.out += _q.amt;
		else if (_q.st == HEX_ST_GATHER) _q.a.at += _q.amt;
	}
}

// THE LEDGER: hand + parcels + anchor pools must equal max. Returns the error (0 = balanced) and prints it to the output
// window the frame it changes, so a change that loses or duplicates hex is caught the moment it happens
function hex_core_audit(_b) {
	var _sum = _b.hand;
	for (var _i = 0; _i < array_length(_b.parcels); _i++) _sum += _b.parcels[_i].amt;
	for (var _i = 0; _i < array_length(_b.anchors); _i++) _sum += _b.anchors[_i].pool;
	var _err = _sum - _b.max;
	if (abs(_err) <= HEX_AUDIT_EPS) _err = 0;
	if (_err != _b.audit_err) {
		if (_err != 0) show_debug_message("HEX LEDGER OFF by " + string(_err) + " (hand " + string(_b.hand) + ", parcels " + string(array_length(_b.parcels)) + ", anchors " + string(array_length(_b.anchors)) + ", max " + string(_b.max) + ")");
		else show_debug_message("hex ledger balanced again");
		_b.audit_err = _err;
	}
	return _err;
}
