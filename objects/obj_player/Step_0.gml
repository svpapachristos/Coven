if (scr_freeze_if_paused()) exit; // freeze on game pause
var _old_max_hp = max_hp;
max_hp = scr_stat("max_health", base_max_hp);
if (max_hp > _old_max_hp) hp += max_hp - _old_max_hp;

var _old_max_mana = max_mana;
max_mana = scr_stat("max_mana", base_max_mana);
if (max_mana > _old_max_mana) mana += max_mana - _old_max_mana;
mana = min(mana, max_mana);

beam_heat = max(0, beam_heat - 0.01);


// is the hex hers? (only witches tagged "hexweaver")
hex_on = (!is_undefined(witch) && array_contains(witch.tags, "hexweaver"));
if (hex_on && !hex_rocks_done) {
	// a few rocks to play with (obj_env_rock: the first environment object)
	hex_rocks_done = true;
	repeat (6) {
		var _a = random(360);
		var _d = random_range(80, 220);
		instance_create_depth(x + lengthdir_x(_d, _a), y + lengthdir_y(_d, _a), depth, obj_env_rock);
	}
}

if (!is_undefined(witch)) {
	if (ability_cd > 0) ability_cd--;
	// E: every witch's own ability. The Hexweaver's is parked (her old toad-curse wave) while her hex lives on Space
	if (!hex_on && input_check("ability") && ability_cd <= 0) {
		witch.ability.fn(id);
		ability_cd = game_get_speed(gamespeed_fps) * scr_stat("ability_cooldown", witch.ability.cooldown);
		scr_fire_event("cast", { kind: "ability" });
	}
	if (input_pressed("ultimate") && ultimate_charge >= ultimate_charge_max) {
		witch.ultimate.fn(id);
		ultimate_charge = 0;
		scr_fire_event("cast", { kind: "ultimate" });
	}
}
	
	
// ---- SPACE: her living hex ----
// Her hex is a hex body (`hex`, see Create and scr_hex_core) that flows out of her hand as a river and gathers where she reaches.
//  - right click: reach. Enough hex reaches a rock (cost_lift x its weight) or an enemy (cost_enemy): it lifts.
//    Let go of right click to throw it. Over open ground it just gathers (reach_cap).
//  - left click: an orb coalesces in front of her hand and grows. Release to fire it (more hex, bigger boom).
//  - tap space: a quick hand blast (blast_cost).
// Whatever she lets go of drifts home to her hand, bit by bit.
var _aim = input_aim();   // where she's aiming (scr_input: the mouse now, a stick later)
var _ha = point_direction(x, y, _aim[0], _aim[1]);
// her off hand (hex_hand in Create). Her sprite and position for this frame aren't final yet (they're set near the
// end of Step), so this is last frame's hand: fine for the hex logic. The ball itself snaps to the final hand at the end.
var _hp = hex_hand_pos();
var _hx = _hp[0], _hy = _hp[1];
if (hex_held != noone && !instance_exists(hex_held)) hex_held = noone;
if (!is_undefined(hex_ra) && hex_ra.attach != noone && !instance_exists(hex_ra.attach)) { hex_anchor_attach(hex, hex_ra, noone); hex_ra.kind = "knot"; }   // (what she held is gone: her reach is a free knot again)
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
hex_core_set_max(hex, round(scr_stat("max_hex", hex.tune.max)) + hex_bonus);   // more max hex arrives straight in her hand
var _ox = hex_hx, _oy = hex_hy;
var _ht = hex.tune;

if (hex_on && input_check("stance")) {
	// HEX STANCE: while her "stance" action (Space, scr_input) is held her hex is ready in her palm. Her wand stands down and the mouse casts with
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

	var _lmb = input_check("primary");
	var _rmb = input_check("secondary");
	if (hex_mode == "" && input_pressed("primary")) { hex_mode = "charge"; hex_charge = 0; hex_oa = hex_anchor_make(hex, "orb", hex_hx, hex_hy, _ht.charge_cap); }
	if (hex_mode == "" && input_pressed("secondary")) { hex_mode = "grab"; hex_ra = hex_anchor_make(hex, "knot", hex_hx, hex_hy, _ht.reach_cap); }

	// where the hex gathers: an orb in front of her hand, or the cursor (within her reach)
	var _tx = _hx, _ty = _hy;
	if (hex_mode == "charge") {
		_tx = _hx + lengthdir_x(_ht.ball_dist, _ha);
		_ty = _hy + lengthdir_y(_ht.ball_dist, _ha);
	} else if (hex_mode == "grab") {
		var _d = min(point_distance(x, y, _aim[0], _aim[1]), _ht.reach_max);
		_tx = x + lengthdir_x(_d, _ha);
		_ty = y + lengthdir_y(_d, _ha);
	}
	hex_hx = lerp(hex_hx, _tx, 0.7); // snappy: the reach keeps up with the cursor
	hex_hy = lerp(hex_hy, _ty, 0.7);

	if (hex_mode == "grab") {
		// the knot: where her hex gathers. It follows the cursor gently (a new reach starts right at the cursor)
		if (hex_ra.at <= 0.01 && hex_ra.out <= 0.01) { hex_gx = hex_hx; hex_gy = hex_hy; }
		else { hex_gx = lerp(hex_gx, hex_hx, 0.15); hex_gy = lerp(hex_gy, hex_hy, 0.15); }
		if (hex_ra.attach == noone) hex_anchor_move(hex_ra, hex_gx, hex_gy);   // (until it lifts something, her reach's anchor IS the knot)
		if (hex_held == noone) {
			// is there something here to lift? the nearest environment object (measured to its edge), or an enemy
			var _target = noone, _kind = "", _cost = 0;
			var _r = noone, _rd = infinity, _sx = hex_hx, _sy = hex_hy;
			with (obj_env_parent) {
				if (!liftable || !movable || grabbed) continue;
				var _dd = point_distance(_sx, _sy, x, y) - r;
				if (_dd < _rd) { _rd = _dd; _r = id; }
			}
			if (_r != noone && _rd <= _ht.grab_r) {
				_target = _r; _kind = "env"; _cost = round(_ht.cost_lift * _r.weight);
			} else {
				var _e = instance_nearest(hex_hx, hex_hy, obj_enemy_parent);
				if (_e != noone && !_e.is_boss && _e.curse >= 0 && point_distance(hex_hx, hex_hy, _e.x, _e.y) <= _ht.grab_r) {
					_target = _e; _kind = "enemy"; _cost = _ht.cost_enemy;
				}
			}
			hex_ra.want = (_target != noone) ? _cost : _ht.reach_cap;
			// as her hex gathers under it, the thing starts to stir and rise (obj_env_parent reads hex_gather)
			if (_target != noone && _kind == "env") _target.hex_gather = max(_target.hex_gather, clamp(hex_ra.at / max(1, _cost), 0, 1));
			if (_target != noone && hex_ra.at >= _cost - 0.001) {
				// enough of her hex has reached it: it lifts, and her reach's anchor rides on it now
				hex_held = _target; hex_kind = _kind; hex_cost = _cost;
				if (_kind == "env") _target.grabbed = true;
				hex_anchor_attach(hex, hex_ra, _target);
				hex_ra.kind = "hold";
			}
		} else hex_ra.want = hex_cost;
		// her hand lets hex out as a steady trickle of parcels until there's enough out for the job (never more: the rest
		// of her hex stays with her). (They leave her palm aimed at the knot; the m20 latch, fixed in step 5)
		hex_core_pour(hex, hex_ra, _hx, _hy, hex_gx, hex_gy);
		// (more gathered than the job needs, say she moved from open ground onto a light rock: it stays, and feeds the hold.
		// The extra makes her scoop stronger, in Draw, instead of drifting around on its own)
	}
	if (hex_mode == "charge") {
		// the orb draws hex straight out of her palm, up to a full charge (or as much as she has)
		hex_charge++;
		hex_anchor_move(hex_oa, hex_hx, hex_hy);
		hex_core_feed(hex, hex_oa, _ht.charge_rate);
	}
	hex_orb_n = is_undefined(hex_oa) ? 0 : floor(hex_oa.pool);
	if (hex_held != noone && hex_kind == "env") {
		// steer what she holds toward the cursor; heavier things follow more sluggishly
		var _wk = 0.5 / max(0.25, hex_held.weight);
		hex_held.vx = lerp(hex_held.vx, (hex_hx - hex_held.x) * _wk, 0.7);
		hex_held.vy = lerp(hex_held.vy, (hex_hy - hex_held.y) * _wk, 0.7);
	}
	// a held enemy is pinned to the cursor in End Step, after it has tried to move

	// letting go of a mouse button finishes that spell
	if (hex_mode == "charge" && !_lmb) {
		if (hex_oa.pool >= 2) {
			// fire the orb forward: it flies until it hits something or leaves the screen. All the hex in it adds to the
			// boom, and it flows home to her afterward. The orb's anchor BECOMES the shot's (it rides on the shot now)
			var _c = hex_oa.pool;
			var _b = instance_create_depth(hex_hx, hex_hy, depth, obj_hex_shot);
			_b.vx = lengthdir_x(15, _ha);
			_b.vy = lengthdir_y(15, _ha);
			_b.dmg = round(10 + _ht.boom_dmg * _c);
			_b.boom_r = 40 + _ht.boom_r * _c;
			_b.size = 0.6 + _c / 16;
			hex_oa.kind = "shot";
			hex_anchor_attach(hex, hex_oa, _b);
			_b.hex_body = hex; _b.hex_anchor = hex_oa;
		} else hex_anchor_release(hex, hex_oa, "melt");   // too small to fire: it melts back into her palm
		hex_oa = undefined;
		hex_mode = ""; hex_charge = 0; hex_orb_n = 0;
	}
	if (hex_mode == "grab" && !_rmb) {
		hex_throw();
		if (!is_undefined(hex_ra)) { hex_anchor_release(hex, hex_ra, "melt"); hex_ra = undefined; }   // (nothing held: it just drifts home)
		hex_mode = "";
	}
} else if (hex_active) {
	// letting go of space: anything held is thrown, a quick tap is a palm blast, and the rest of her hex flows home
	if (hex_held != noone) hex_throw();
	else if (hex_tap <= 10) {
		if (hex.hand >= _ht.blast_cost) {
			var _b = instance_create_depth(_hx, _hy, depth, obj_hex_shot);
			_b.vx = lengthdir_x(16, _ha);
			_b.vy = lengthdir_y(16, _ha);
			_b.dmg = _ht.blast_dmg;
			_b.boom_r = 40;
			_b.size = 0.6;
			var _sa = hex_anchor_make(hex, "shot", _hx, _hy, _ht.blast_cost);   // the blast carries its hex in its own anchor
			hex_core_feed(hex, _sa, _ht.blast_cost);
			hex_anchor_attach(hex, _sa, _b);
			_b.hex_body = hex; _b.hex_anchor = _sa;
		}
	}
	hex_core_release_all(hex);   // the rest of her hex flows home (an orb she never fired melts back into her palm)
	hex_ra = undefined; hex_oa = undefined;
	hex_held = noone; hex_kind = ""; hex_active = false; hex_charge = 0; hex_orb_n = 0; hex_mode = "";
}
if (!hex_active) {
	hex_hx = _hx;
	hex_hy = _hy;
}
hex_hvx = hex_hx - _ox;
hex_hvy = hex_hy - _oy;

// HER HEX OUT IN THE WORLD: every parcel moves on its own, anchors follow what they ride on (scr_hex_core)
// how far she moved last frame. Hex going home aims where her hand is headed and adds her motion to its own, so it can
// always catch up (its speed near her hand is capped to stop overshooting, and that cap alone was slower than her walk)
var _mvx = x - hex_px, _mvy = y - hex_py;
hex_px = x; hex_py = y;
if (point_distance(0, 0, _mvx, _mvy) > 40) { _mvx = 0; _mvy = 0; }   // a jump (a new room), not a walk
hex_core_step(hex, _hx, _hy, _mvx, _mvy);
if (variable_global_exists("debug_hud") && global.debug_hud) hex_core_audit(hex);   // F1: the ledger check (prints to the output window if hex goes missing)

//getting the player to lock in 4 directionals
facing_dir_4 = round(point_direction(x, y, _aim[0], _aim[1]) / 90) mod 4; //gives us a clean 0 = East, 1 = North, 2 = West, 3 = South

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
if (input_check("secondary") && mana >= _cost && !hex_active) { // (in her curse stance, right click belongs to the curse)
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
