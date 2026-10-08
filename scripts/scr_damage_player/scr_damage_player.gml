//function scr_damage_player(player, amount)
//description applies damage to a player, respecting their invulnerability frames.
//returns true when damage was applied, otherwise false.
function scr_damage_player(_player, _amount) {
	if (global.game_state != "PLAYING") return false;
	if (_player.iframes > 0) return false;

	_player.hp -= _amount;
	_player.iframes = game_get_speed(gamespeed_fps) * 0.75;
	scr_spawn_damage_number(_player, _amount, c_red);

	if (_player.hp <= 0) {
		global.game_state = "DEAD";
		scr_essence_bank_run();
	}

	return true;
}
