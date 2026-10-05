function scr_magic_missile(_caster) {
	var _count = floor(scr_stat("missile_count", 3));
	var _range = 500 * WORLD_SCALE;
	var _dmg = scr_stat("missile_damage", 35);
	var _n = instance_number(obj_enemy_parent);

	// enemies in reach, closest to the cursor first
	var _cands = [];
	for (var i = 0; i < _n; i++) {
		var _e = instance_find(obj_enemy_parent, i);
		if (point_distance(_caster.x, _caster.y, _e.x, _e.y) <= _range)
			array_push(_cands, { e: _e, d: point_distance(mouse_x, mouse_y, _e.x, _e.y) });
	}
	if (array_length(_cands) == 0) return false;   // nothing in reach: no cast, no mana
	array_sort(_cands, function(a, b) { return a.d - b.d; });

	// one dart per target, and extra darts double up on the closest
	var _color = scr_element_color(_caster.wand.element);
	for (var i = 0; i < _count; i++) {
		var _t = _cands[i mod array_length(_cands)].e;
		var _m = instance_create_layer(_caster.x + 3, _caster.y + 2, "Instances", obj_magic_missile);
		_m.target = _t;
		_m.damage = _dmg;
		_m.element = _caster.wand.element;
		_m.image_blend = _color;
		_m.direction = point_direction(_caster.x, _caster.y, _t.x, _t.y) + random_range(-70, 70);   // burst out, then curve in
		_m.image_angle = _m.direction;
	}
	return true;
}