if (scr_freeze_if_paused()) exit;


var _list = ds_list_create();
var _n = collision_circle_list(x, y, sep_radius, obj_enemy_parent, false, true, _list, false);

for (var i = 0; i < _n; i++) {
	var _o = _list[| i];
	var _d = point_distance(x, y, _o.x, _o.y);
	if (_d >= sep_radius) continue; //bbox touched the circle but not too close
	// exactly stacked? picked a random direction so they can split
	var _push = (_d < 0.01) ? irandom(359) : point_direction(_o.x, _o.y, x, y);
	var _amt = min((sep_radius - _d) * sep_strength, 3);
	
	x += lengthdir_x(_amt, _push);
	y += lengthdir_y(_amt, _push);
}
ds_list_destroy(_list);