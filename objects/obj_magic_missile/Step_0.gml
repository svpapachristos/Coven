if (scr_freeze_if_paused()) exit;

life--;
if (life <= 0) { instance_destroy(); exit; }

if (!instance_exists(target)) {                     // its target died: find the nearest enemy that isn't a frog
	target = noone;
	var _best = infinity;
	with (obj_enemy_parent) {
		if (object_index == obj_toad) continue;
		var _d = point_distance(x, y, other.x, other.y);
		if (_d < _best) { _best = _d; other.target = id; }
	}
}
if (instance_exists(target)) {
	var _want = point_direction(x, y, target.x, target.y);
	direction -= clamp(angle_difference(direction, _want), -turn_rate, turn_rate);
	image_angle = direction;
}
if (irandom(1) == 0) part_particles_create(global.ps_sparks, x, y, global.pt_spark, 1);   // little trail