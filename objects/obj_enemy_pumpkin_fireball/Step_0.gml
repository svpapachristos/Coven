if (scr_freeze_if_paused()) exit;
scr_stop_at_last_frame();
life -= 1;
if (life <= 0) {
	instance_destroy();
}

if (x < 0 || x > room_width || y < 0 || y > room_height) {
    instance_destroy();
}

// "smash" into the necromancers ranks, fireball bursts and blasts a hole in your thralls
if (instance_exists(obj_thrall)) {
	var _list = ds_list_create();
	var _n = collision_circle_list(x, y, 12, obj_thrall, false, true, _list, false);
	for (var i = 0; i < _n && thralls_torn < tear_limit; i++) {
		var _t = _list[| i];
		if (_t.rise < 1) continue; // thralls still climbing out of the ground are safe
		part_particles_create(global.ps_sparks, _t.x, _t.y, global.pt_aura, 6);
		scr_burst_fx(_t.x, _t.y, 18, make_color_rgb(255, 140, 40), 6);
		instance_destroy(_t);
		thralls_torn++;
		global.shake = max(global.shake, 1.5);
	}
	ds_list_destroy(_list);

	// out of momentum: one last burst that kills a couple more and wounds everyone around it
	if (thralls_torn >= tear_limit) {
		var _blast = 55;
		var _bl = ds_list_create();
		var _bn = collision_circle_list(x, y, _blast, obj_thrall, false, true, _bl, true); // nearest first
		var _killed = 0;
		for (var i = 0; i < _bn; i++) {
			var _t = _bl[| i];
			if (_t.rise < 1) continue;
			if (_killed < 2) { _t.hp = 0; _killed++; }
			else _t.hp -= _t.max_hp * 0.5;
			if (_t.hp <= 0) {
				part_particles_create(global.ps_sparks, _t.x, _t.y, global.pt_aura, 4);
				instance_destroy(_t);
			}
		}
		ds_list_destroy(_bl);

		scr_burst_fx(x, y, _blast, make_color_rgb(255, 140, 40), 16);
		global.shake = max(global.shake, 3);
		instance_destroy();
	}
}