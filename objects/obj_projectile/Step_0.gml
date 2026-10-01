if (scr_freeze_if_paused()) exit;
if (x < 0 || x > room_width || y < 0 || y > room_height) {
	instance_destroy();
}