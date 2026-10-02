if (scr_freeze_if_paused()) exit; // freeze on game pause
max_mana = scr_stat("max_mana", base_max_mana); //so that items can raise it

if (!is_undefined(witch)) {
	if (ability_cd > 0) ability_cd--;
	if (keyboard_check_pressed(ord("E")) && ability_cd = 0) {
		witch.ability.fn(id);
		ability_cd = game_get_speed(gamespeed_fps) * scr_stat("ability_cooldown", witch.ability.cooldown);
	}
	if (keyboard_check_pressed(ord("Q")) && ultimate_charge >= ultimate_charge_max) {
		witch.ultimate.fn(id);
		ultimate_charge = 0;
	}
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
	mana = min(max_mana, mana + mana_regen / game_get_speed(gamespeed_fps));
}

//Channel alt fire while holding m2
var _cost = scr_stat("chain_drain", alt_drain) * alt_pulse_max / game_get_speed(gamespeed_fps); 
if (mouse_check_button(mb_right) && mana >= _cost) {
	if (alt_pulse > 0) {
		alt_pulse--;
	} else {
		alt_pulse = alt_pulse_max;
		if (alt_fire(id)) { //gives false if no enemys to latch onto
			mana -= _cost;
			alt_regen_delay = game_get_speed(gamespeed_fps) * 0.75;
			alt_pulse_count++;
		}
	}
} else {
	alt_pulse = 0; //so the pulse is instant when you press
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
	