function scr_apply_pickup(_pickup, _player){
	switch (_pickup.pickup_type) {
		case "HEALTH":
		_player.hp = min(_player.max_hp, _player.hp + _pickup.heal_amount);
		scr_spawn_damage_number(_player, _pickup.heal_amount, c_lime);
		break;
		
		//later: case "MANA":, case "XP":. case "
	}
}