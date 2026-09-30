if (global.game_state != "PLAYING") exit;
function movement() {
	//walk functions are for losers
	if (keyboard_check(ord("D"))) { x += move_speed; } 
	if (keyboard_check(ord("A"))) { x -= move_speed; }  
	if (keyboard_check(ord("S"))) { y += move_speed; } 
	if (keyboard_check(ord("W"))) { y -= move_speed; } 
	x = clamp(x, 0, room_width - sprite_width);
	y = clamp(y, 0, room_height - sprite_height);
}
//getting the player to lock in 4 directionals
facing_dir_4 = round(point_direction(x, y, mouse_x, mouse_y) / 90) mod 4; //gives us a clean 0 = East, 1 = North, 2 = West, 3 = South

function update_facing_sprite() {
	var _idle = [spr_player_witch1_idle_right, spr_player_witch1_idle_up, spr_player_witch1_idle_left, spr_player_witch1_idle_down];
	var _walk = [spr_player_witch1_walk_right, spr_player_witch1_walk_up, spr_player_witch1_walk_left, spr_player_witch1_walk_down];
	var _idle_fire = [spr_player_witch1_idle_right_fire, spr_player_witch1_idle_up_fire, spr_player_witch1_idle_left_fire, spr_player_witch1_idle_down_fire];
	var _walk_fire = [spr_player_witch1_walk_right_fire, spr_player_witch1_walk_up_fire, spr_player_witch1_walk_left_fire, spr_player_witch1_walk_down_fire];
	
	var _firing = (state == "ATTACK");
	
	var _move_dir_4 = -1; // -1 means idle
	
	if (keyboard_check(ord("D"))) _move_dir_4 = 0; 	
	else if (keyboard_check(ord("W"))) _move_dir_4 = 1;
	else if (keyboard_check(ord("A"))) _move_dir_4 = 2;
	else if (keyboard_check(ord("S"))) _move_dir_4 = 3;
	
	
	var _moving = (_move_dir_4 != -1);
	
	// Pick which direction value actually determines the sprite this frame
	var _display_dir = _firing ? facing_dir_4 : (_moving ? _move_dir_4 : facing_dir_4);

	image_xscale = 1;
	
	
	if (_firing) {
		sprite_index = _moving ? _walk_fire[_display_dir] : _idle_fire[_display_dir];
	} else {
		sprite_index = _moving ? _walk[_display_dir] : _idle[_display_dir];
	}
}

//Function that makes the player look in the caridnal direction closest to mouse position
update_facing_sprite();

//Our IFrames i think
if (iframes > 0) iframes--;
image_alpha = (iframes > 0 && (iframes div 4) mod 2 == 0) ? 0.4 : 1;

//Our 'available' Mana pool
mana = min(max_mana, mana + mana_regen / game_get_speed(gamespeed_fps));

//Casting our Wand (Rudimentary Alternate Wand Fire Setup), will cost mana
if (alt_fire_cd > 0) alt_fire_cd--;
if (mouse_check_button_pressed(mb_right) && alt_fire_cd <= 0 && mana >= alt_fire_cost) {	
	if (alt_fire()) {
	mana -= alt_fire_cost;
	alt_fire_cd = game_get_speed(gamespeed_fps * 0.4);
	}
}


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

function player_idle(){
	if (keyboard_check(ord("W"))) || (keyboard_check(ord("A"))) || (keyboard_check(ord("S"))) || (keyboard_check(ord("D"))) {
		state = "WALK";
	}
	if (mouse_check_button(mb_left) && can_shoot) {
		state = "ATTACK";
	}
}

function player_walk() {
	movement();
	if (mouse_check_button(mb_left) && can_shoot) {
		state = "ATTACK";
	}
	if (!keyboard_check(ord("W")) && !keyboard_check(ord("A")) && !keyboard_check(ord("S")) && !keyboard_check(ord("D"))) {
    state = "IDLE";
	}
}
	
function player_attack() {
	movement();
	if (can_shoot) {
		//spawn our projectile
		can_shoot = false;
		shoot_timer = game_get_speed(gamespeed_fps) * attack_speed; //fire delay
		
		var _dir = point_direction(x, y, mouse_x, mouse_y);
		var _proj = instance_create_layer(x + 3, y + 2, "Instances", obj_projectile);
		_proj.direction = _dir;
		_proj.speed = proj_speed;
		_proj.image_angle = _dir;
	}

	if (shoot_timer > 0) {
		shoot_timer -= 1;
	} else {
		can_shoot = true;
		if (!mouse_check_button(mb_left)) {
		state = "IDLE";
		}
	}
}

function player_alt_fire() {
	if (mouse_check_button_pressed(mb_right) && mana >= alt_fire_cost) { 
		alt_fire(); 
	}
}
	