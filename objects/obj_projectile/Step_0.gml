if (scr_freeze_if_paused()) exit;
if (x < 0 || x > room_width || y < 0 || y > room_height) {
	instance_destroy();
	exit;
}

if (homing > 0) {
	if (homing_delay > 0) {
		homing_delay--; // still flying straight
	} else {
		if (!instance_exists(target)) target = pick_target();
		if (instance_exists(target)) {
			var _want = point_direction(x, y, target.x, target.y);
			direction -= clamp(angle_difference(direction, _want), -homing, homing);
			image_angle = direction;
		}
	}
}

if (element == "arcane" && irandom(1) == 0) part_particles_create(global.ps_sparks, x, y, global.pt_arcane, 1);