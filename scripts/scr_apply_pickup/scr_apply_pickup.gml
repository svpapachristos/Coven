function scr_apply_pickup(_pickup, _player){
	switch (_pickup.pickup_type) {
		case "HEALTH":
		_player.hp = min(_player.max_hp, _player.hp + _pickup.heal_amount);
		scr_spawn_damage_number(_player, _pickup.heal_amount, c_lime);
		break;
		
		case "ITEM":
		scr_give_item(_pickup.item_id);
		var _it = global.item_db[$ _pickup.item_id];
		global.toast = { text: _it.name, sub: _it.desc, color: scr_rarity_color(_it.rarity), timer: game_get_speed(gamespeed_fps) * 4 };
		part_particles_create(global.ps_sparks, _player.x, _player.y, global.pt_spark, 30);
		break;
		
		case "ESSENCE":
		scr_gain_essence(_pickup.value);
		break;
	}
}