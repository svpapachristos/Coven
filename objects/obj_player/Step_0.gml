if (global.game_state != "PLAYING") exit;
function movement() {
	//walk functions are for losers
	if (keyboard_check(ord("D"))) { x += move_speed; facing_dir = 1; image_xscale = 1; } 
	if (keyboard_check(ord("A"))) { x -= move_speed; facing_dir = -1; image_xscale = -1; }  
	if (keyboard_check(ord("S"))) { y += move_speed; } 
	if (keyboard_check(ord("W"))) { y -= move_speed; } 
	x = clamp(x, 0, room_width - sprite_width);
	y = clamp(y, 0, room_height - sprite_height);
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
	sprite_index = spr_player;
	if (keyboard_check(ord("W"))) || (keyboard_check(ord("A"))) || (keyboard_check(ord("S"))) || (keyboard_check(ord("D"))) {
		state = "WALK";	
	}
	if (mouse_check_button_pressed(mb_left) && can_shoot) {
		state = "ATTACK";
}
}

function player_walk() {
	movement();
	if (mouse_check_button_pressed(mb_left) && can_shoot) {
		state = "ATTACK";
}

}
	
function player_attack() {
	movement();
	if (can_shoot) {
		sprite_index = spr_player_shoot;
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
		state = "IDLE";
	}
}