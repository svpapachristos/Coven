y -= rise_speed;
life -= 1;
alpha = life / (game_get_speed(gamespeed_fps) * 0.6); //fades as the texts life runs down

if (life <= 0) {
	instance_destroy();
}