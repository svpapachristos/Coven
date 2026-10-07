function scr_try_drop(_enemy){
	//Health Orbs: chance shrinks based on enemy count so you cant just perma heal
	var _crowd = 1 / (1 + instance_number(obj_enemy_parent) / 300);
	if (random(1) < _enemy.drop_chance * _crowd) {
		instance_create_layer(_enemy.x, _enemy.y, "Instances", obj_pickup_healthorb);
	}

	// Kills drop souls, but combines orbs after 150 orbs so that high enemy counts dont result in
	//thousands of particles on the floor
	var _val = _enemy.soul_value;
	var _near = instance_nearest(_enemy.x, _enemy.y, obj_pickup_soul);
	if (instance_number(obj_pickup_soul) > 150 && _near != noone
	&& point_distance(_enemy.x, _enemy.y, _near.x, _near.y) < 250) {
		_near.value += _val;
	} else {
		var _o = instance_create_layer(_enemy.x, _enemy.y, "Instances", obj_pickup_soul);
		_o.value = _val;
	}
	
}
