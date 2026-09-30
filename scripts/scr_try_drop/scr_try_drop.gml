function scr_try_drop(_enemy){
	if (random(1) < _enemy.drop_chance) {
		instance_create_layer(_enemy.x, _enemy.y, "Instances", obj_pickup_health_orb);
	}
}