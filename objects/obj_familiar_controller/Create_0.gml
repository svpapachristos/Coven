state = "IDLE";
familiar_move_speed = 10;
can_follow = true;

function familiar_raven_idle(){
	image_xscale = (obj_player.facing_dir_4 == 2) ? -1: 1; // west = flipped
	sprite_index = spr_fam_raven;
	
	if (can_follow){
		state = "FOLLOW";
	}
	
}

function familiar_raven_follow(){
	sprite_index = spr_fam_raven_walk;

	var _behind_dist = 64; //distance behind the player to follow
	var _facing_deg = obj_player.facing_dir_4 * 90; // gets us 0=E, 90=N, 180=W, 270=S
	
	var _target_x = obj_player.x - lengthdir_x(_behind_dist, _facing_deg);
	var _target_y = obj_player.y - lengthdir_y(_behind_dist, _facing_deg);
	
	var _dist = point_distance(x, y, _target_x, _target_y);
	
	if (_dist > 15){
		direction = point_direction(x, y, _target_x, _target_y);
		speed = familiar_move_speed * SPEED_SCALE;
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