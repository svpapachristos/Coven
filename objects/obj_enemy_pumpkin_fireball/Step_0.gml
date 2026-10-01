if (scr_freeze_if_paused()) exit;
scr_stop_at_last_frame();
life -= 1;
if (life <= 0) {
	instance_destroy();
}

if (x < 0 || x > room_width || y < 0 || y > room_height) {
    instance_destroy();
}