function scr_alt_chain_lightning(_caster) {
	var _dmg = scr_stat("chain_damage", 8);
	var _cast_range = 400 * WORLD_SCALE; //How far from the witch the first target can be
	var _jump_range = 140 * WORLD_SCALE; //Max gap between arcs
	var _max_targets = floor(scr_stat("chain_targets", 6));
	
	var _n = instance_number(obj_enemy_parent);
	
	// First target: Enemy closest to cursor within reach of the Witch
	var _first = noone;
	var _first_d = infinity;
	for (var i = 0; i < _n; i++) {
		var _e = instance_find(obj_enemy_parent, i);
		if (point_distance(_caster.x, _caster.y, _e.x, _e.y) > _cast_range) continue;
		var _d = point_distance(mouse_x, mouse_y, _e.x, _e.y);
		if (_d < _first_d) {_first_d = _d; _first = _e; }
	}
	//Nothing in reach, no cast, caster spends no mana
	if (_first == noone) return false;
	
	var _targets = [_first];
	var _points = [[_caster.x + 3,_caster. y + 2], [_first.x, _first.y]];
	var _current = _first;
	
	//Keep jumping to the nearest enemy that has not been arc-ed already
	while (array_length(_targets) < _max_targets) {
		var _next = noone;
		var _next_d = _jump_range;
		
		for (var i = 0; i < _n; i++ ) {
			var _e = instance_find(obj_enemy_parent, i);
			
			var _seen = false;
			for (var j = 0; j < array_length(_targets); j++) {
				if (_targets[j] == _e) { _seen = true; break; }
			}
			if (_seen) continue;
		
			var	_d = point_distance(_current.x, _current.y, _e.x, _e.y);
			if (_d < _next_d) { _next_d = _d; _next = _e; }
		
		}
	
	if (_next == noone) break;
	array_push(_targets, _next);
	array_push(_points, [_next.x, _next.y]);
	_current = _next;
	}


	//Records the Bolts path BEFORE damage, since killing an enemy destroys it as an instance
	var _fx = instance_create_layer(_caster.x, _caster.y, "Instances", obj_lightning_bolt);
	_fx.points = _points;

	//Sparks
	for (var p = 0; p < array_length(_points); p++) {
		part_particles_create(global.ps_sparks, _points[p][0], _points[p][1], global.pt_spark, (p == 0) ? 2 : 4);
		if (p > 0) {
			repeat (2) {
				var _t = random(1);
				part_particles_create(global.ps_sparks,
				lerp(_points[p-1][0], _points[p][0], _t),
				lerp(_points[p-1][1], _points[p][1], _t),
				global.pt_spark, 1);
			}
		}
	}

	// Damage
	var _show = (_caster.alt_pulse_count mod 3 == 0);
	for (var k = 0; k < array_length(_targets); k++) {
		scr_damage_enemy(_targets[k], _dmg, c_aqua, _show);
	}
	return true;
}