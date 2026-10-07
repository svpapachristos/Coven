// a risen thrall, fights for the necromancer until it falls again
sprite_index = spr_enemy_zombie;
max_hp = scr_stat("thrall_health", 40 + 5 * global.level);
hp = max_hp;
target = noone;
retarget = irandom(14);         // staggered so hundreds of thralls don't all think on the same frame
hit_cd = irandom(10);
rise = 0;                       // 0 to 1 while it claws out of the ground
orbit = random(360);            // its spot in the swarm around the witch
orbit_r = random_range(40, 110);
flip = 1;
sep_radius = 18;                // personal space from other thralls
reach = 26;                     // how close it has to be to bite

// swap targets and keep every enemy's claim count honest
set_target = function(_e) {
	if (_e == target) return;
	if (instance_exists(target)) target.thrall_claims--;
	target = _e;
	if (instance_exists(target)) target.thrall_claims++;
};

// pick who to fight: close to me, close to the witch, and not already swarmed by other thralls
pick_target = function() {
	var _p = obj_player;
	var _list = ds_list_create();
	var _n = collision_circle_list(x, y, 220, obj_enemy_parent, false, true, _list, true); // nearest first
	var _best = noone, _best_score = infinity;
	var _lim = min(_n, 16);
	for (var i = 0; i < _lim; i++) {
		var _e = _list[| i];
		var _to_witch = point_distance(_p.x, _p.y, _e.x, _e.y);
		if (_to_witch > 700) continue;
		var _claims = _e.thrall_claims - ((_e == target) ? 1 : 0); // don't count ourselves
		var _score = point_distance(x, y, _e.x, _e.y) + _to_witch * 0.5 + _claims * 70; // THESE ARE OUR TWO TUNING KNOBS, _claims MEANS HOW MANY ENEMIES ARE WILLING TO PILE UP ON 1 GUY, HIGHER NUMBER = MORE THRALLS STACKING ONE DUDE
		if (_score < _best_score) { _best_score = _score; _best = _e; } // _to_witch: CLOSER to 1 = THRALLS WILL HUG YOU, LOWER WILL CAUSE THEM TO SPREAD AND WANDER CLOSE TO THE CROWDS THE BITE
	}
	ds_list_destroy(_list);

	// nothing close by? go for whatever is nearest the witch so the army still pushes out
	if (_best == noone) {
		var _near = instance_nearest(_p.x, _p.y, obj_enemy_parent);
		if (_near != noone && point_distance(_p.x, _p.y, _near.x, _near.y) <= 700) _best = _near;
	}
	set_target(_best);
};