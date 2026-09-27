function familiar_movement(){
	
	
	
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
	sprite_index = spr_fam_raven;
	if (can_follow){
		state = "FOLLOW";
	}
	
}

function familiar_raven_follow(){
	
	var _target_x = obj_player.x - 55; //an attempt to shift where the ravens target location is
	var _target_y = obj_player.y - 20;
	
	var _dist = point_distance(x, y, _target_x, _target_y);
	
	if (_dist > 3){
		direction = point_direction(x, y, _target_x, _target_y);
		speed = familiar_move_speed;
	} else {
		speed = 0;
	}
	if (!can_follow){
		state = "IDLE"
	}
}