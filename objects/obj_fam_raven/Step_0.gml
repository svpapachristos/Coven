if (global.game_state != "PLAYING") {
	if (speed != 0) {
		saved_speed = speed;
		speed = 0;
	}
	exit
} else if (variable_instance_exists(id, "saved_speed") && saved_speed != 0) {
	speed = saved_speed;
	saved_speed = 0;
}
switch (state) 
{
    case "IDLE":
        familiar_raven_idle();
        break;
        
    case "FOLLOW":
		familiar_raven_follow();
        break;
        
    case "ATTACK":
		
		break;
	
    default:
        state = "IDLE"; // Catch-all safety net
        break;
}

function familiar_raven_idle(){
	image_xscale = obj_player.facing_dir;
	sprite_index = spr_fam_raven;
	
	if (can_follow){
		state = "FOLLOW";
	}
	
}

function familiar_raven_follow(){
	
	sprite_index = spr_fam_raven_walk;

	var _behind_dist = 23; //distance behind the player to follow
	
	var _target_x = obj_player.x - (_behind_dist * obj_player.facing_dir);
	var _target_y = obj_player.y;
	
	var _dist = point_distance(x, y, _target_x, _target_y);
	
	if (_dist > 3){
		direction = point_direction(x, y, _target_x, _target_y);
		speed = familiar_move_speed;
			image_xscale = (lengthdir_x(1, direction) >= 0) ? 1 : -1;
	} else {
		speed = 0;
		sprite_index = spr_fam_raven;
			image_xscale = obj_player.facing_dir;
	}
	if (!can_follow){
		state = "IDLE"
	}
}