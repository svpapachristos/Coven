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
// her off hand (hex_hand in Create). Her sprite and position for this frame aren't final yet (they're set near the
// end of Step), so this is last frame's hand: fine for the hex logic. The ball itself snaps to the final hand at the end.
var _hp = hex_hand_pos();
var _hx = _hp[0], _hy = _hp[1];
var _hp2 = hex_hand2_pos();
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
if (!hex_on) hex_move_overflow_off(hex);   // (a witch whose hex it isn't never overflows: switching witches lets it go)
// HER MOVES (scr_hex_moves): tell them what she wants this frame, and they do the rest
hex_move_update(hex, {
	stance: hex_on && input_check("stance"),   // (only a witch whose hex it is has a stance)
	primary: input_check("primary"), primary_pressed: input_pressed("primary"),
	secondary: input_check("secondary"), secondary_pressed: input_pressed("secondary"),
	toggle: hex_on && input_pressed("ability"),   // E: in her stance, overflow on / off (the Hexweaver's own E is parked)
	evo_primary: hex_on && input_check("primary"),   // her plain left click (the moves decide: in overflow, hex needles)
	aim_x: _aim[0], aim_y: _aim[1],
	x: x, y: y,
	hand_x: _hx, hand_y: _hy,
	hand2_x: _hp2[0], hand2_y: _hp2[1],   // her other hand (free while overflowing)
	cx: (bbox_left + bbox_right) / 2, cy: (bbox_top + bbox_bottom) / 2,
	depth: depth
});

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
if (input_check("secondary") && mana >= _cost && !hex_move_wand_away(hex)) { // (in her hex stance or overflow, right click belongs to the hex)
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

// her overflow lifts her off the ground (drawn only), bobbing gently; eased, so she settles down instead of dropping
hover_z = lerp(hover_z, hex.mv.over_f * (hex.tune.over_hover + hex.tune.over_bob * sin(current_time / 350)), 0.2);
if (hover_z < 0.05) hover_z = 0;
// her sprite and position are final for this frame now: put the ball exactly in her off hand, so it never trails a
// frame behind a turn or a step
var _hf = hex_hand_pos();
hex_move_rest(hex, _hf[0], _hf[1]);

//Marks: corrupting our witch throughout a run
var _stage = scr_corruption_stage();
image_blend = merge_color(c_white, make_color_rgb(190, 130, 255), 0.18 * _stage);
if (_stage >= 1 && irandom(max(2, 6 - _stage * 2)) == 0) 
	part_particles_create(global.ps_sparks, x + random_range(-10, 10), y + random_range(-14, 10), global.pt_aura, 1);
depth = -bbox_bottom; // no one will stand on each other anymoreas
