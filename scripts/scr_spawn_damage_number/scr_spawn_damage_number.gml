function scr_spawn_damage_number(_target, _amount, _color) {
	if (random(1) > global.settings.damage_numbers) return noone;
	if (instance_number(obj_damage_number) > 120) return noone;   // never flood the screen
	var _number = instance_create_layer(_target.x, _target.y, "Instances", obj_damage_number);
	_number.x = (_target.bbox_left + _target.bbox_right) * 0.5;
	_number.y = _target.bbox_top - 4;
	_number.dmg_amount = _amount;
	_number.number_color = _color;
	return _number;
}