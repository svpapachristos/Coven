//Step
if (global.game_state != "PLAYING") exit;
life--;
if (life <= 0) instance_destroy();