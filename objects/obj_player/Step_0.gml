if (scr_freeze_if_paused()) exit; // freeze on game pause
var _old_max_hp = max_hp;
max_hp = scr_stat("max_health", base_max_hp);
if (max_hp > _old_max_hp) hp += max_hp - _old_max_hp;

var _old_max_mana = max_mana;
max_mana = scr_stat("max_mana", base_max_mana);
if (max_mana > _old_max_mana) mana += max_mana - _old_max_mana;
mana = min(mana, max_mana);

beam_heat = max(0, beam_heat - 0.01);


if (!is_undefined(witch)) {
	if (ability_cd > 0) ability_cd--;
	// OLD E (toad curse), parked while we test the living curse. Uncomment to restore.
	//if (keyboard_check(ord("E")) && ability_cd <= 0) {
	//	witch.ability.fn(id);
	//	ability_cd = game_get_speed(gamespeed_fps) * scr_stat("ability_cooldown", witch.ability.cooldown);
	//	scr_fire_event("cast", { kind: "ability" });
	//}
	if (keyboard_check_pressed(ord("Q")) && ultimate_charge >= ultimate_charge_max) {
		witch.ultimate.fn(id);
		ultimate_charge = 0;
		scr_fire_event("cast", { kind: "ultimate" });
	}
}
	
	
// ---- E: the living curse ----
// Her curse energy IS the motes: each one is a unit of curse. Hold E and they pour out of her hand one by one toward
// the cursor; when enough have arrived, they act. Spent motes regrow in her hand over time.
//  - enough motes reach a rock or other environment object (hex_cost_lift x its weight) or an enemy (hex_cost_enemy): it's lifted. Release E to throw it.
//  - pressed over nothing: the motes pour into a ball in front of her hand that grows and overcharges.
//    Release to lob it in an arc to the cursor, where it explodes (more motes, bigger boom).
//  - tap E: a quick hand blast from the curse in her palm (hex_blast_cost).
var _ha = point_direction(x, y, mouse_x, mouse_y);
// her off hand (hex_hand in Create). Her sprite and position for this frame aren't final yet (they're set near the
// end of Step), so this is last frame's hand: fine for the motes. The ball itself snaps to the final hand at the end.
var _hp = hex_hand_pos();
var _hx = _hp[0], _hy = _hp[1];
if (hex_held != noone && !instance_exists(hex_held)) hex_held = noone;
// J: show the hand point and nudge it with the arrow keys (sprite pixels). Each nudge prints the line to paste into Create.
if (keyboard_check_pressed(ord("J"))) hex_hand_debug = !hex_hand_debug;
if (hex_hand_debug) {
	var _nx = keyboard_check_pressed(vk_right) - keyboard_check_pressed(vk_left);
	var _ny = keyboard_check_pressed(vk_down) - keyboard_check_pressed(vk_up);
	if (_nx != 0 || _ny != 0) {
		var _sn = sprite_get_name(sprite_index);
		var _p = hex_hand[$ _sn];
		if (is_undefined(_p)) _p = [hex_hand_default[0], hex_hand_default[1]];
		_p[0] += _nx; _p[1] += _ny;
		hex_hand[$ _sn] = _p;
		show_debug_message("hex_hand[$ \"" + _sn + "\"] = [" + string(_p[0]) + ", " + string(_p[1]) + "];");
	}
}
// max curse: an item can raise it through the "max_hex" stat; H adds 8 while testing
if (keyboard_check_pressed(ord("H"))) hex_bonus += 8;
hex_wisp_debug_keys(); // O = next look (hex orb / smoke wisp / old circles), P = next palette (scr_hex_wisp)
var _want = round(scr_stat("max_hex", hex_budget)) + hex_bonus;
while (array_length(hex_motes) < _want) {
	array_push(hex_motes, { x: _hx, y: _hy, vx: 0, vy: 0, ph: random(360), sp: random_range(2, 5), k: 1, st: 0, wait: 0 });
}
var _n = array_length(hex_motes);
var _ox = hex_hx, _oy = hex_hy;

if (keyboard_check(ord("E"))) {
	// HEX STANCE: while E is held her curse pours out and swirls around her, ready. Her wand stands down and the
	// mouse casts with the curse instead: hold left click to coalesce an orb in front of her hand (release to fire it),
	// hold right click to coalesce at the cursor and lift what's there (release to throw it).
	var _bcx = (bbox_left + bbox_right) / 2, _bcy = (bbox_top + bbox_bottom) / 2;
	if (!hex_active) {
		hex_active = true;
		hex_tap = 0;
		hex_mode = "";
		hex_charge = 0;
		hex_hx = _bcx; hex_hy = _bcy;
		_ox = _bcx; _oy = _bcy;
	}
	hex_tap++;

	// pour motes out of her hand
	hex_flow_acc += hex_flow;
	while (hex_flow_acc >= 1) {
		hex_flow_acc -= 1;
		for (var _i = 0; _i < _n; _i++) if (hex_motes[_i].st == 0) { hex_motes[_i].st = 1; break; }
	}

	var _lmb = mouse_check_button(mb_left);
	var _rmb = mouse_check_button(mb_right);
	if (hex_mode == "" && mouse_check_button_pressed(mb_left)) { hex_mode = "charge"; hex_charge = 0; }
	if (hex_mode == "" && mouse_check_button_pressed(mb_right)) hex_mode = "grab";

	// where the curse gathers: an orb in front of her hand, the cursor (within her reach), or swirling around her
	var _tx, _ty;
	if (hex_mode == "charge") {
		_tx = _hx + lengthdir_x(hex_ball_dist, _ha);
		_ty = _hy + lengthdir_y(hex_ball_dist, _ha);
	} else if (hex_mode == "grab") {
		var _d = min(point_distance(x, y, mouse_x, mouse_y), hex_reach);
		_tx = x + lengthdir_x(_d, _ha);
		_ty = y + lengthdir_y(_d, _ha);
	} else {
		_tx = _bcx; _ty = _bcy;
	}
	hex_hx = lerp(hex_hx, _tx, 0.7); // snappy: the curse keeps up with the cursor
	hex_hy = lerp(hex_hy, _ty, 0.7);

	// how many have arrived where they're going
	var _ax = (hex_held != noone) ? hex_held.x : hex_hx;
	var _ay = (hex_held != noone) ? hex_held.y : hex_hy;
	hex_arrived = 0;
	for (var _i = 0; _i < _n; _i++) {
		var _m = hex_motes[_i];
		if (_m.st == 1 && point_distance(_m.x, _m.y, _ax, _ay) < hex_ready_r) hex_arrived++;
	}

	if (hex_held == noone && hex_mode == "grab") {
		// is there something here to lift?
		var _target = noone, _kind = "", _cost = 0;
		// the nearest environment object her magic can lift (measured to its edge, so big things are easier to catch)
		var _r = noone, _rd = infinity, _sx = hex_hx, _sy = hex_hy;
		with (obj_env_parent) {
			if (!liftable || !movable || grabbed) continue;
			var _d = point_distance(_sx, _sy, x, y) - r;
			if (_d < _rd) { _rd = _d; _r = id; }
		}
		if (_r != noone && _rd <= hex_grab_r) {
			_target = _r; _kind = "env"; _cost = round(hex_cost_lift * _r.weight);
		} else {
			var _e = instance_nearest(hex_hx, hex_hy, obj_enemy_parent);
			if (_e != noone && !_e.is_boss && _e.curse >= 0 && point_distance(hex_hx, hex_hy, _e.x, _e.y) <= hex_grab_r) {
				_target = _e; _kind = "enemy"; _cost = hex_cost_enemy;
			}
		}
		if (_target != noone && hex_arrived >= _cost) {
			// enough of her curse has reached it: it lifts
			hex_held = _target; hex_kind = _kind; hex_cost = _cost;
			if (_kind == "env") _target.grabbed = true;
		}
	}
	if (hex_mode == "charge") {
		// the orb builds up a mote at a time, up to a full charge (or as much curse as she has out)
		hex_charge++;
		var _out = 0;
		for (var _i = 0; _i < _n; _i++) if (hex_motes[_i].st == 1) _out++;
		hex_orb_n = min(floor(hex_charge * hex_charge_rate), hex_charge_cap, _out);
	} else hex_orb_n = 0;
	if (hex_held != noone && hex_kind == "env") {
		// steer what she holds toward the curse; heavier things follow more sluggishly
		var _wk = 0.5 / max(0.25, hex_held.weight);
		hex_held.vx = lerp(hex_held.vx, (hex_hx - hex_held.x) * _wk, 0.7);
		hex_held.vy = lerp(hex_held.vy, (hex_hy - hex_held.y) * _wk, 0.7);
	}
	// a held enemy is pinned to the curse in End Step, after it has tried to move

	// letting go of a mouse button finishes that spell; the curse stays out around her for the next one
	if (hex_mode == "charge" && !_lmb) {
		if (hex_orb_n >= 2) {
			// fire the orb forward: it flies until it hits something or leaves the screen.
			// every mote in it adds to the boom, and they all find their way back to her afterward
			var _c = hex_orb_n;
			var _b = instance_create_depth(hex_hx, hex_hy, depth, obj_hex_shot);
			_b.vx = lengthdir_x(15, _ha);
			_b.vy = lengthdir_y(15, _ha);
			_b.dmg = round(10 + hex_boom_dmg * _c);
			_b.boom_r = 40 + hex_boom_r * _c;
			_b.size = 0.6 + _c / 16;
			_b.mote_n = hex_spend(_c, 4);
		}
		hex_mode = ""; hex_charge = 0; hex_orb_n = 0;
	}
	if (hex_mode == "grab" && !_rmb) {
		hex_throw();
		hex_mode = "";
	}
} else if (hex_active) {
	// letting go of E: anything held is thrown, a quick tap is a palm blast, and the rest of her curse flows home
	if (hex_held != noone) hex_throw();
	else if (hex_tap <= 10) {
		if (hex_available() >= hex_blast_cost) {
			hex_spend(hex_blast_cost, 4);
			var _b = instance_create_depth(_hx, _hy, depth, obj_hex_shot);
			_b.vx = lengthdir_x(16, _ha);
			_b.vy = lengthdir_y(16, _ha);
			_b.dmg = hex_blast_dmg;
			_b.boom_r = 40;
			_b.size = 0.6;
			_b.mote_n = hex_blast_cost;
		}
	}
	// recall: everything still out streams home one after another
	var _g = 0;
	for (var _i = 0; _i < _n; _i++) {
		if (hex_motes[_i].st == 1) { hex_motes[_i].st = 3; hex_motes[_i].wait = _g * hex_return_gap; _g++; }
	}
	hex_held = noone; hex_kind = ""; hex_active = false; hex_charge = 0; hex_arrived = 0; hex_mode = "";
}
if (!hex_active) {
	hex_hx = _hx;
	hex_hy = _hy;
}
hex_hvx = hex_hx - _ox;
hex_hvy = hex_hy - _oy;

// spent curse regrows in her hand, one mote at a time
var _spent = noone;
for (var _i = 0; _i < _n; _i++) if (hex_motes[_i].st == 2) { _spent = hex_motes[_i]; break; }
if (_spent != noone) {
	hex_regen_t++;
	if (hex_regen_t >= hex_regen) {
		hex_regen_t = 0;
		_spent.st = 0;
		_spent.x = _hx; _spent.y = _hy;
		_spent.vx = 0; _spent.vy = 0;
	}
} else hex_regen_t = 0;

// Its body: starling motes. At home they curl in her hand (and past hex_ball_max, orbit her as an aura).
// Out in the world they stream to the curse, swirl around it, wrap what it holds, and crush into a knot as it charges.
var _t = current_time / 1000;
// how far she moved, so the motes in her hand and aura travel with her instead of trailing
var _pdx = x - hex_px, _pdy = y - hex_py;
hex_px = x; hex_py = y;
var _cx = (bbox_left + bbox_right) / 2;
var _cy = (bbox_top + bbox_bottom) / 2;
var _knot = (hex_mode == "charge") ? clamp(hex_orb_n / hex_charge_cap, 0, 1) : 0; // how full the charging orb is
var _home_i = 0;
var _orank = 0; // which out-mote this is, so only the first hex_orb_n of them join the orb
for (var _i = 0; _i < _n; _i++) {
	var _m = hex_motes[_i];
	if (_m.st == 2 || _m.st == 4) continue; // spent, or riding inside a shot: not here
	if (_m.st == 3) {
		// flowing home: each mote waits its turn where the curse let go, then races back to her hand at full speed,
		// weaving slightly as it goes, so together they pour home as one living tendril
		if (_m.wait > 0) {
			_m.wait--;
			_m.vx *= 0.85; _m.vy *= 0.85;
			_m.x += _m.vx; _m.y += _m.vy;
			continue;
		}
		var _wa = point_direction(_m.x, _m.y, _hx, _hy) + 90;
		var _wv = sin(_t * 8 + _m.ph) * 1.5;
		_m.vx = (_m.vx + (_hx - _m.x) * 0.14 + lengthdir_x(_wv, _wa)) * 0.82;
		_m.vy = (_m.vy + (_hy - _m.y) * 0.14 + lengthdir_y(_wv, _wa)) * 0.82;
		var _rs = point_distance(0, 0, _m.vx, _m.vy);
		if (_rs > 22) { _m.vx *= 22 / _rs; _m.vy *= 22 / _rs; }
		_m.x += _m.vx;
		_m.y += _m.vy;
		if (point_distance(_m.x, _m.y, _hx, _hy) < 16) _m.st = 0;
		continue;
	}
	var _mx, _my, _pull, _cap = 99;
	if (_m.st == 0) {
		_m.x += _pdx; _m.y += _pdy;
		if (_home_i >= hex_ball_max) {
			// overflow: an aura orbiting her body, always under her control
			var _rad = 38 + 6 * sin(_t * 0.9 + _m.ph);
			var _ang = _m.ph + _t * 40 * (_m.sp / 3.5);
			_mx = _cx + lengthdir_x(_rad, _ang);
			_my = _cy + lengthdir_y(_rad * 0.75, _ang);
			_pull = 0.06;
		} else {
			// a smoky ball of energy cupped in her off hand
			var _rad = 5 + 4 * sin(_t * 1.3 + _m.ph);
			_mx = _hx + lengthdir_x(_rad, _m.ph + _t * 90 * _m.sp);
			_my = _hy + lengthdir_y(_rad, _m.ph + _t * 90 * _m.sp);
			_pull = 0.12;
		}
		_home_i++;
	} else {
		var _gx = hex_hx, _gy = hex_hy, _rad;
		var _in_orb = (hex_mode == "charge" && _orank < hex_orb_n);
		_orank++;
		if (hex_mode == "charge" && !_in_orb) {
			// not in the orb (yet): keep swirling around her
			_gx = (bbox_left + bbox_right) / 2; _gy = (bbox_top + bbox_bottom) / 2;
			_rad = 34;
		} else if (hex_held != noone) {
			_gx = hex_held.x; _gy = hex_held.y;
			if (hex_kind == "env") _gy -= hex_held.z;   // wrap it where it's drawn, lifted off the ground
			_rad = ((hex_kind == "env") ? hex_held.r : 22) + 6;
		} else if (hex_mode == "charge") {
			// the ball: denser and bigger as it fills, pulsing harder as it overcharges
			_rad = 4 + 14 * _knot;
			_rad *= 1 + 0.25 * _knot * sin(hex_charge * 0.5);
		} else _rad = (hex_mode == "") ? 34 : 18; // in her stance, swirling around her
		_rad *= 0.6 + 0.4 * sin(_t * _m.sp + _m.ph); // breathing
		var _ang = _m.ph + _t * (120 + 500 * _knot) * (_m.sp / 3.5);
		_mx = _gx + lengthdir_x(_rad, _ang);
		_my = _gy + lengthdir_y(_rad, _ang);
		if (_i mod hex_trail == 0) {
			// a few stragglers trail behind the clump, so the curse leaves a wake as it moves
			_pull = 0.1;
			_cap = 22;
		} else {
			// the clump: tight on the cursor or what it holds, so it keeps up with every flick
			_pull = 0.35;
			_cap = 60;
		}
	}
	// starling rule: don't crowd your neighbors (checks a few at random each frame)
	repeat (3) {
		var _o = hex_motes[irandom(_n - 1)];
		if (_o.st == 2 || _o.st == 4) continue;
		var _dx = _m.x - _o.x, _dy = _m.y - _o.y;
		var _dd = _dx * _dx + _dy * _dy;
		if (_dd > 0 && _dd < 16) { _m.vx += _dx * 0.08; _m.vy += _dy * 0.08; }
	}
	_m.vx = (_m.vx + (_mx - _m.x) * _pull + random_range(-0.3, 0.3)) * 0.82;
	_m.vy = (_m.vy + (_my - _m.y) * _pull + random_range(-0.3, 0.3)) * 0.82;
	var _ms = point_distance(0, 0, _m.vx, _m.vy);
	if (_ms > _cap) { _m.vx *= _cap / _ms; _m.vy *= _cap / _ms; }
	_m.x += _m.vx;
	_m.y += _m.vy;
}

//getting the player to lock in 4 directionals
facing_dir_4 = round(point_direction(x, y, mouse_x, mouse_y) / 90) mod 4; //gives us a clean 0 = East, 1 = North, 2 = West, 3 = South

//Function that makes the player look in the caridnal direction closest to mouse position
update_facing_sprite();

//Our IFrames i think
if (iframes > 0) iframes--;
image_alpha = (iframes > 0 && (iframes div 4) mod 2 == 0) ? 0.4 : 1;

//Mana Regen, paused briefly after casting
if (alt_regen_delay > 0 ) {
	alt_regen_delay--;
} else { 
	mana = min(max_mana, mana + scr_stat("mana_regen", mana_regen) / game_get_speed(gamespeed_fps));
}

//Channel alt fire while holding m2
var _cost = scr_stat("alt_drain", alt_drain) * alt_pulse_max / game_get_speed(gamespeed_fps); 
if (mouse_check_button(mb_right) && mana >= _cost && !hex_active) { // (in her curse stance, right click belongs to the curse)
	if (alt_pulse > 0) {
		alt_pulse--;
	} else {
		alt_pulse = alt_pulse_max;
		if (alt_fire(id)) { //gives false if no enemys to latch onto
			mana -= _cost;
			alt_regen_delay = game_get_speed(gamespeed_fps) * 0.75;
			alt_pulse_count++;
			scr_fire_event("cast", { kind: "alt" });
		}
	}
} else {
	alt_pulse = max(alt_pulse - 1, 0);	//cooldown runs regardless of keyhold to prevent tap firing to bypass the CD
}
if (scr_stat("infinite_mana", 0) > 0) mana = max_mana;


//Determine the players current state
switch (state) 
{
    case "IDLE":
        player_idle();
        break;
        
    case "WALK":
		player_walk();
        break;
        
    case "ATTACK":
		player_attack();
		break;
	
    default:
        state = "IDLE"; // Catch-all safety net
        break;
}

// her sprite and position are final for this frame now: put the ball exactly in her off hand, so it never trails a
// frame behind a turn or a step
if (!hex_active) {
	var _hf = hex_hand_pos();
	hex_hx = _hf[0];
	hex_hy = _hf[1];
}

//Marks: corrupting our witch throughout a run
var _stage = scr_corruption_stage();
image_blend = merge_color(c_white, make_color_rgb(190, 130, 255), 0.18 * _stage);
if (_stage >= 1 && irandom(max(2, 6 - _stage * 2)) == 0) 
	part_particles_create(global.ps_sparks, x + random_range(-10, 10), y + random_range(-14, 10), global.pt_aura, 1);
depth = -bbox_bottom; // no one will stand on each other anymoreas
