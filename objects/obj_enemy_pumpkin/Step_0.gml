if (global.game_state != "PLAYING") {
	speed = 0;
	exit;
}

var _distance = point_distance(x, y, obj_player.x, obj_player.y);

//move closer if far, move away iff too close, stay still when in firing distance
if (_distance > preferred_distance + distance_margin) {
	direction = point_direction(x, y, obj_player.x, obj_player.y);
	speed = move_speed;
} else if (_distance < preferred_distance - distance_margin) {
	direction = point_direction(x, y, obj_player.x, obj_player.y) + 180;
	speed = move_speed;
} else {
	speed = 0;
}

//Spew a cursed fireball at the players current position
attack_cooldown -= 1;
if (attack_cooldown <= 0) {
	var _aim = point_direction(x, y, obj_player.x, obj_player.y);
	var _fireball = instance_create_layer(x, y, "Instances", obj_enemy_pumpkin_fireball);
	_fireball.direction = _aim;
	_fireball.speed = fireball_speed;
	_fireball.image_angle = _aim;
	
	attack_cooldown = attack_cooldown_max;
}