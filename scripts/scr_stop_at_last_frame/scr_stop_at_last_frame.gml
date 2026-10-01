/// Call from Step. Freezes the animation on its final frame
/// Returns true when finished so you can add possible effects
function scr_stop_at_last_frame(){
	if (image_index >= image_number - 1) {
		image_index = image_number -1;
		image_speed = 0;
		return true;
	}
	return false;
}