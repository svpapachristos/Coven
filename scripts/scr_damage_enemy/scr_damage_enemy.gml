//returns true if enemy dies, false if alive (but probably took damage)
function scr_damage_enemy(_enemy, _amount, _color = c_white){
	_enemy.hp -= _amount;
	_enemy.hit_flash = 6;
	scr_spawn_damage_number(_enemy, _amount, _color);
	
	if (_enemy.hp <= 0) {
		global.kill_count++;
		if (_enemy.object_index == obj_enemy_slime) global.slime_kill_count++;
		if (_enemy.object_index == obj_enemy_bat) global.bat_kill_count++;
		if (_enemy.object_index == obj_enemy_pumpkin) global.pumpkin_kill_count++;
		scr_try_drop(_enemy);
		instance_destroy(_enemy);
		return true;
	}	
	return false;
}