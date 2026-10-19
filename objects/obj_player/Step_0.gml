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
	
	
// ---- SPACE: her living hex ----
// Her hex is one amount (see Create, "HER HEX") that flows out of her hand as a river and gathers where she reaches.
//  - right click: reach. Enough hex reaches a rock (hex_cost_lift x its weight) or an enemy (hex_cost_enemy): it lifts.
//    Let go of right click to throw it. Over open ground it just gathers (hex_reach_cap).
//  - left click: an orb coalesces in front of her hand and grows. Release to fire it (more hex, bigger boom).
//  - tap space: a quick hand blast (hex_blast_cost).
// Whatever she lets go of flows home to her hand as a river.
var _ha = point_direction(x, y, mouse_x, mouse_y);
// her off hand (hex_hand in Create). Her sprite and position for this frame aren't final yet (they're set near the
// end of Step), so this is last frame's hand: fine for the hex logic. The ball itself snaps to the final hand at the end.
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
if (_want > hex_max) hex_hand_amt += _want - hex_max;   // more max hex arrives straight in her hand
hex_max = _want;
var _ox = hex_hx, _oy = hex_hy;

if (keyboard_check(hex_key)) {
	// HEX STANCE: while hex_key (space) is held her hex is ready in her palm. Her wand stands down and the mouse casts with
	// the hex instead: hold left click to coalesce an orb in front of her hand (release to fire it), hold right click to
	// reach out at the cursor and lift what's there (release to throw it).
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

	var _lmb = mouse_check_button(mb_left);
	var _rmb = mouse_check_button(mb_right);
	if (hex_mode == "" && mouse_check_button_pressed(mb_left)) { hex_mode = "charge"; hex_charge = 0; }
	if (hex_mode == "" && mouse_check_button_pressed(mb_right)) hex_mode = "grab";

	// where the hex gathers: an orb in front of her hand, or the cursor (within her reach)
	var _tx = _hx, _ty = _hy;
	if (hex_mode == "charge") {
		_tx = _hx + lengthdir_x(hex_ball_dist, _ha);
		_ty = _hy + lengthdir_y(hex_ball_dist, _ha);
	} else if (hex_mode == "grab") {
		var _d = min(point_distance(x, y, mouse_x, mouse_y), hex_reach);
		_tx = x + lengthdir_x(_d, _ha);
		_ty = y + lengthdir_y(_d, _ha);
	}
	hex_hx = lerp(hex_hx, _tx, 0.7); // snappy: the reach keeps up with the cursor
	hex_hy = lerp(hex_hy, _ty, 0.7);

	if (hex_mode == "grab") {
		// the knot: where her hex gathers. It follows the cursor gently (a new reach starts right at the cursor)
		if (hex_at <= 0.01 && hex_out <= 0.01) { hex_gx = hex_hx; hex_gy = hex_hy; }
		else { hex_gx = lerp(hex_gx, hex_hx, 0.15); hex_gy = lerp(hex_gy, hex_hy, 0.15); }
		if (hex_held == noone) {
			// is there something here to lift? the nearest environment object (measured to its edge), or an enemy
			var _target = noone, _kind = "", _cost = 0;
			var _r = noone, _rd = infinity, _sx = hex_hx, _sy = hex_hy;
			with (obj_env_parent) {
				if (!liftable || !movable || grabbed) continue;
				var _dd = point_distance(_sx, _sy, x, y) - r;
				if (_dd < _rd) { _rd = _dd; _r = id; }
			}
			if (_r != noone && _rd <= hex_grab_r) {
				_target = _r; _kind = "env"; _cost = round(hex_cost_lift * _r.weight);
			} else {
				var _e = instance_nearest(hex_hx, hex_hy, obj_enemy_parent);
				if (_e != noone && !_e.is_boss && _e.curse >= 0 && point_distance(hex_hx, hex_hy, _e.x, _e.y) <= hex_grab_r) {
					_target = _e; _kind = "enemy"; _cost = hex_cost_enemy;
				}
			}
			hex_need = (_target != noone) ? _cost : hex_reach_cap;
			// as her hex gathers under it, the thing starts to stir and rise (obj_env_parent reads hex_gather)
			if (_target != noone && _kind == "env") _target.hex_gather = max(_target.hex_gather, clamp(hex_at / max(1, _cost), 0, 1));
			if (_target != noone && hex_at >= _cost - 0.001) {
				// enough of her hex has reached it: it lifts
				hex_held = _target; hex_kind = _kind; hex_cost = _cost;
				if (_kind == "env") _target.grabbed = true;
			}
		} else hex_need = hex_cost;
		// her hand feeds the river until there's enough out for the job (never more: the rest of her hex stays with her)
		var _p = min(hex_pour, hex_hand_amt, max(0, hex_need - hex_out - hex_at));
		hex_hand_amt -= _p; hex_out += _p;
		// once the river's front has reached the target, it delivers what it carries
		if (hex_rv_hi >= 1) { var _dl = min(hex_out, hex_pour); hex_out -= _dl; hex_at += _dl; }
		// more gathered than the job needs (she moved from open ground onto a light rock): the extra flows home
		if (hex_at > hex_need + 0.5) { hex_home_add(hex_gx, hex_gy, hex_at - hex_need); hex_at = hex_need; }
	}
	if (hex_mode == "charge") {
		// the orb draws hex straight out of her palm, up to a full charge (or as much as she has)
		hex_charge++;
		var _c = max(0, min(hex_charge_rate, hex_hand_amt, hex_charge_cap - hex_orb_amt));
		hex_hand_amt -= _c; hex_orb_amt += _c;
	}
	hex_orb_n = floor(hex_orb_amt);
	if (hex_held != noone && hex_kind == "env") {
		// steer what she holds toward the cursor; heavier things follow more sluggishly
		var _wk = 0.5 / max(0.25, hex_held.weight);
		hex_held.vx = lerp(hex_held.vx, (hex_hx - hex_held.x) * _wk, 0.7);
		hex_held.vy = lerp(hex_held.vy, (hex_hy - hex_held.y) * _wk, 0.7);
	}
	// a held enemy is pinned to the cursor in End Step, after it has tried to move

	// letting go of a mouse button finishes that spell
	if (hex_mode == "charge" && !_lmb) {
		if (hex_orb_amt >= 2) {
			// fire the orb forward: it flies until it hits something or leaves the screen. All the hex in it adds to the
			// boom, and it flows home to her afterward
			var _c = hex_orb_amt;
			var _b = instance_create_depth(hex_hx, hex_hy, depth, obj_hex_shot);
			_b.vx = lengthdir_x(15, _ha);
			_b.vy = lengthdir_y(15, _ha);
			_b.dmg = round(10 + hex_boom_dmg * _c);
			_b.boom_r = 40 + hex_boom_r * _c;
			_b.size = 0.6 + _c / 16;
			_b.hex_amt = _c;
		} else hex_hand_amt += hex_orb_amt;   // too small to fire: it melts back into her palm
		hex_orb_amt = 0;
		hex_mode = ""; hex_charge = 0; hex_orb_n = 0;
	}
	if (hex_mode == "grab" && !_rmb) {
		hex_throw();
		hex_let_go();
		hex_mode = "";
	}
} else if (hex_active) {
	// letting go of space: anything held is thrown, a quick tap is a palm blast, and the rest of her hex flows home
	if (hex_held != noone) hex_throw();
	else if (hex_tap <= 10) {
		if (hex_hand_amt >= hex_blast_cost) {
			hex_hand_amt -= hex_blast_cost;
			var _b = instance_create_depth(_hx, _hy, depth, obj_hex_shot);
			_b.vx = lengthdir_x(16, _ha);
			_b.vy = lengthdir_y(16, _ha);
			_b.dmg = hex_blast_dmg;
			_b.boom_r = 40;
			_b.size = 0.6;
			_b.hex_amt = hex_blast_cost;
		}
	}
	hex_let_go();
	hex_hand_amt += hex_orb_amt; hex_orb_amt = 0;   // an orb she never fired melts back into her palm
	hex_held = noone; hex_kind = ""; hex_active = false; hex_charge = 0; hex_orb_n = 0; hex_mode = "";
}
if (!hex_active) {
	hex_hx = _hx;
	hex_hy = _hy;
}
hex_hvx = hex_hx - _ox;
hex_hvy = hex_hy - _oy;

// THE RIVER OUT: the stretch of the path from her palm (0) to the target (1) that her outgoing hex covers right now
//   1 reaching: the front runs out to the knot     2 holding: it drains into what she lifted     3 she let go: it turns back
var _rs = 0;
if (hex_active && hex_mode == "grab") _rs = (hex_held == noone) ? 1 : 2;
else if (hex_rv_hi > 0.001) _rs = 3;
if (_rs == 1) { hex_rv_tx = hex_gx; hex_rv_ty = hex_gy; }
if (_rs == 2 && instance_exists(hex_held)) { hex_rv_tx = hex_held.x; hex_rv_ty = hex_held.y - ((hex_kind == "env") ? hex_held.z : 0); }
var _rl = max(16, point_distance(_hx, _hy, hex_rv_tx, hex_rv_ty) * 1.1);   // about how long the path is
var _dv = hex_flow_speed / _rl;
if (_rs == 1) { hex_rv_lo = max(0, hex_rv_lo - _dv); hex_rv_hi = min(1, hex_rv_hi + _dv); }
else if (_rs == 2) {
	hex_rv_hi = min(1, hex_rv_hi + _dv);
	if (hex_rv_hi >= 1) hex_rv_lo = min(hex_rv_hi, hex_rv_lo + _dv * 0.8);
	if (hex_rv_lo >= hex_rv_hi) { hex_at += hex_out; hex_out = 0; }   // fully drained in
}
else if (_rs == 3) {
	// what was still in the river flows back into her palm along it
	var _ro = { x: hex_rv_tx, y: hex_rv_ty, lo: hex_rv_lo, hi: hex_rv_hi, amt: hex_out };
	if (hex_home_flow(_ro, _hx, _hy)) { _ro.hi = 0; _ro.lo = 0; }
	hex_rv_lo = _ro.lo; hex_rv_hi = _ro.hi; hex_out = _ro.amt;
}
hex_rv_state = _rs;

// THE RIVERS HOME: from a knot she let go, something she threw, a shot that burst. Each flows back into her palm
for (var _i = array_length(hex_home) - 1; _i >= 0; _i--) {
	if (hex_home_flow(hex_home[_i], _hx, _hy)) array_delete(hex_home, _i, 1);
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
