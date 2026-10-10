//returns true if enemy dies, false if alive (but probably took damage)
function scr_damage_enemy(_enemy, _amount, _color = c_white, _show_number = true){
	if (_enemy.hex < 0 && !_enemy.popping) return false; // toads only burst from their own pop, attacks now pass over them
	if (_enemy.hex > 0) _amount *= 1 + scr_stat("hex_vulnerability", 0.25);
	_enemy.hp -= _amount;
	_enemy.hit_flash = 6;
	if (_show_number) scr_spawn_damage_number(_enemy, _amount, _color);
	
	if (_enemy.hp <= 0) {
		// a cursed enemy that's killed doesn't just die: the curse catches it on the way out and it becomes a frog.
		// the frog carries its souls and drops and pays them out when it pops, so nothing is counted twice
		if (_enemy.hex > 0 && scr_hex_can_toad(_enemy)) {
			scr_hex_toadify(_enemy);
			return true;
		}
		if (instance_exists(obj_player)) {
			obj_player.ultimate_charge = min(obj_player.ultimate_charge_max, obj_player.ultimate_charge + scr_stat("ultimate_charge_rate", 1));
		}
		global.kill_count++;
		if (_enemy.is_elite) {
			if (_enemy.elite_drop == "spread") scr_spread_reward(_enemy.x, _enemy.y);
			else scr_item_reward(_enemy.x, _enemy.y, _enemy.elite_drop);
			global.reagents += 1;
		}
if (_enemy.is_boss) { global.boss_down = true; global.reagents += 3; };
		scr_try_drop(_enemy);
		if (struct_exists(global.event_listeners, "kill")) scr_fire_event("kill", { enemy: _enemy, x: _enemy.x, y: _enemy.y });
		scr_necro_on_kill(_enemy);
		scr_essence_on_kill(_enemy);
		instance_destroy(_enemy);
		return true;
	}	
	return false;
}