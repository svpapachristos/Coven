function scr_trig_soul_lantern(_ctx, _stacks){
	if (instance_exists(obj_player))
		obj_player.mana = min(obj_player.max_mana, obj_player.mana + obj_player.max_mana * 0.25 * _stacks);
}