function scr_trig_hags_tooth(_ctx, _stacks){
	if (instance_exists(obj_player) && random(1) < 0.05 * _stacks)
		obj_player.hp = min(obj_player.max_hp, obj_player.hp + 5);
}