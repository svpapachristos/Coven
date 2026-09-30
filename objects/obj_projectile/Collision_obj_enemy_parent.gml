var _enemy = other;
_enemy.hp -= damage;
_enemy.hit_flash = 6;
scr_spawn_damage_number(_enemy, damage, c_white);

if (_enemy.hp <= 0) {
	global.kill_count++;
	if (_enemy.object_index == obj_enemy_slime) global.slime_kill_count++;
	if (_enemy.object_index == obj_enemy_bat) global.bat_kill_count++;
	if (_enemy.object_index == obj_enemy_pumpkin) global.pumpkin_kill_count++;
	instance_destroy(_enemy);
}

instance_destroy();