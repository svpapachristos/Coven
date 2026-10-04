if (scr_freeze_if_paused()) exit;

life--;
if (life <= 0) { instance_destroy(); exit; }

if (!instance_exists(target)) target = instance_nearest(x, y, obj_enemy_parent);   // retarget if it died
if (instance_exists(target)) {
	var _want = point_direction(x, y, target.x, target.y);
	direction -= clamp(angle_difference(direction, _want), -turn_rate, turn_rate);
	image_angle = direction;
}
if (irandom(1) == 0) part_particles_create(global.ps_sparks, x, y, global.pt_spark, 1);   // little trail