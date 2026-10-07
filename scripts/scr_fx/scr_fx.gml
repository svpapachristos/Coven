// A ring of light that expands outward to _radius, for novas and blasts
function scr_burst_fx(_x, _y, _radius, _color, _life = 14) {
	if (instance_number(obj_burst_fx) > 750) return noone;
	var _f = instance_create_layer(_x, _y, "Instances", obj_burst_fx);
	_f.radius = _radius;
	_f.color = _color;
	_f.life_max = _life;
	_f.life = _life;
	return _f;

}