//Step
if (scr_freeze_if_paused()) exit;
life--;
if (life <= 0) instance_destroy();