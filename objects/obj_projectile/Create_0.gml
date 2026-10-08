//Create event of the projectile
speed = 28 * SPEED_SCALE;
damage = scr_stat("wand_damage", 100);
element = undefined;

pierce = 0;
hit_list = [];
homing = 0;
target = noone;

volley = []; // targets claimed by this bolts siblings
homing_delay = 0; //frames of a straight flight before it homes in

// find something ahead of the bolt that no sibling has already targeted
pick_target = function() {
	var _list = ds_list_create();
	var _n = collision_circle_list(x, y, 500, obj_enemy_parent, false, true, _list, true); // nearest first
	var _pick = noone;
	var _lim = min(_n, 20);
	for (var i = 0; i < _lim; i++) {
		var _e = _list[| i];
		if (abs(angle_difference(direction, point_direction(x, y, _e.x, _e.y))) > 75) continue; //picks a target that is roughly infront of it
		if (scr_array_has(volley, _e)) continue; //a sibling bolt already called this target
		_pick = _e;
		break;
	}
	ds_list_destroy(_list);
	if (_pick == noone) _pick = scr_homing_target(x, y, direction); //doubles up only when no other targets are suitable
	if (_pick != noone) array_push(volley, _pick);
	return _pick;
};