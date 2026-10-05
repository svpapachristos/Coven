//returns true if enemy dies, false if alive (but probably took damage)
function scr_damage_enemy(_enemy, _amount, _color = c_white, _show_number = true){
	_enemy.hp -= _amount;
	_enemy.hit_flash = 6;
	if (_show_number) scr_spawn_damage_number(_enemy, _amount, _color);
	
	if (_enemy.hp <= 0) {
		if (instance_exists(obj_player)) {
			obj_player.ultimate_charge = min(obj_player.ultimate_charge_max, obj_player.ultimate_charge + scr_stat("ultimate_charge_rate", 1));
		}
		global.kill_count++;
		if (_enemy.is_elite) scr_item_reward(_enemy.x, _enemy.y, _enemy.elite_drop);
		if (_enemy.is_boss) global.boss_down = true;
		scr_try_drop(_enemy);
		if (struct_exists(global.event_listeners, "kill")) scr_fire_event("kill", { enemy: _enemy, x: _enemy.x, y: _enemy.y });
		instance_destroy(_enemy);
		return true;
	}	
	return false;
}