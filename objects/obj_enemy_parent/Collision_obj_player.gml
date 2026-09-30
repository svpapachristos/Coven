if (global.game_state == "PLAYING" && other.iframes <= 0) {
	other.hp -= contact_damage;
	other.iframes = game_get_speed(gamespeed_fps) * 0.75;
	scr_spawn_damage_number(other, contact_damage, c_red);
	
	if (other.hp <= 0) {
		global.game_state = "DEAD"
	}
}

instance_destroy();