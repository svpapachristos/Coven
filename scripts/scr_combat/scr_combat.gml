function scr_homing_target(_x, _y, _dir, _range = 700, _cone = 80) {
	var _best = noone, _bd = _range, _n = instance_number(obj_enemy_parent);
	for (var i = 0; i < _n; i++) {
		var _e = instance_find(obj_enemy_parent, i);
		var _d = point_distance(_x, _y, _e.x, _e.y);
		if (_d >= _bd) continue;
		if (abs(angle_difference(_dir, point_direction(_x, _y, _e.x, _e.y))) > _cone) continue;
		_best = _e;
		_bd = _d;
	}
	return _best;
}

function scr_dist_to_segment(_px, _py, _x1, _y1, _x2, _y2) {
	var _dx = _x2 - _x1, _dy = _y2 - _y1;
	var _len_sq = _dx * _dx + _dy * _dy;
	var _t = (_len_sq == 0) ? 0 : clamp(((_px - _x1) * _dx + (_py - _y1) * _dy) / _len_sq, 0, 1);
	return point_distance(_px, _py, _x1 + _t * _dx, _y1 + _t * _dy);
}

function scr_beam_line(_caster, _heat) {
	var _aim = point_direction(_caster.x + 3, _caster.y + 2, mouse_x, mouse_y);
	var _tx = _caster.x + 3 + lengthdir_x(14, _aim); // 14 is the tuner for how far out the wand tip is
	var _ty = _caster.y + 2 + lengthdir_y(14, _aim);
	var _ang = point_direction(_tx, _ty, mouse_x, mouse_y);
	var _len = lerp(650, scr_stat("beam_length", 1400), _heat); // short when cool, long when hot
	return { x1: _tx, y1: _ty, x2: _tx + lengthdir_x(_len, _ang), y2: _ty + lengthdir_y(_len, _ang), angle: _ang, len: _len };
}