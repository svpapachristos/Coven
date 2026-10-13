//Call this at the top of steps to allow pausing to properly freeze things, returns true while paused so the caller can take a break or exit
function scr_freeze_if_paused(){
	// while she is in her universe (the cast, or stargazing), time outside stops: everything but the Unmaking itself waits
	var _held = instance_exists(obj_unmaking) && object_index != obj_unmaking;
	if (!scr_is_live() || _held) {
		if (speed != 0) {
			saved_speed = speed;
			speed = 0;
		}
		return true;
	}
	if (variable_instance_exists(id, "saved_speed") && saved_speed != 0) {
		speed = saved_speed;
		saved_speed = 0;
	}
	return false;
}