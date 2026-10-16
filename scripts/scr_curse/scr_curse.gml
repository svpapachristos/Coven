// Hexweaver curse and frog mechanics.
#macro CURSE_VIOLET make_color_rgb(170, 90, 255)

function scr_curse_init() {
	global.curse_unmade = 0;
}

function scr_curse_tier() {
	var _count = variable_global_exists("curse_unmade") ? global.curse_unmade : 0;
	return 1 + (_count >= 50) + (_count >= 200) + (_count >= 600);
}

function scr_curse_ripen_time() {
	var _times = [4, 3, 2, 1];
	return scr_stat("curse_ripen_time", _times[scr_curse_tier() - 1]);
}

function scr_curse_apply(_enemy, _amount) {
	if (_enemy.curse < 0) return;
	_enemy.curse = min(1, max(_enemy.curse, 0) + _amount);
}

function scr_curse_can_toad(_enemy) {
	var _tier = scr_curse_tier();
	if (_enemy.is_boss) return _tier >= 4;
	if (_enemy.is_elite) return _tier >= 3;
	return true;
}

function scr_curse_toadify(_enemy) {
	var _toad = instance_create_layer(_enemy.x, _enemy.y, "Instances", obj_curse_toad);
	_toad.soul_value = _enemy.soul_value;
	_toad.drop_chance = _enemy.drop_chance;
	_toad.is_elite = _enemy.is_elite;
	_toad.is_boss = _enemy.is_boss;
	_toad.elite_drop = _enemy.elite_drop;
	global.curse_unmade += 1;
	part_particles_create(global.ps_sparks, _enemy.x, _enemy.y, global.pt_aura, 5);
	instance_destroy(_enemy);
}

function scr_curse_toad_pop(_toad) {
	var _x = _toad.x, _y = _toad.y;
	var _tier = scr_curse_tier();
	var _spread = scr_stat("curse_spread", (_tier >= 2) ? 1 : 0);
	var _radius = (15 + 8 * _tier) * WORLD_SCALE;
	if (_spread > 0) {
		var _list = ds_list_create();
		var _count = collision_circle_list(_x, _y, _radius, obj_enemy_parent, false, true, _list, false);
		for (var i = 0; i < _count; i++) scr_curse_apply(_list[| i], scr_stat("curse_splash", 0.5) * _spread);
		ds_list_destroy(_list);
		scr_burst_fx(_x, _y, _radius, CURSE_VIOLET, 10);
	} else {
		scr_burst_fx(_x, _y, 12 * WORLD_SCALE, make_color_rgb(110, 180, 80), 6);
	}
	_toad.popping = true;
	scr_damage_enemy(_toad, _toad.hp + 1, CURSE_VIOLET, false);
}

// E: Hex, a wave that spreads the curse and damages enemies.
function scr_curse_wave(_caster) {
	var _radii = [120, 150, 190, 240];
	var _wave = instance_create_layer(_caster.x, _caster.y, "Instances", obj_curse_wave);
	_wave.max_r = scr_stat("curse_radius", _radii[scr_curse_tier() - 1]) * WORLD_SCALE;
	_wave.curse_amt = scr_stat("curse_strength", 0.35);
	_wave.dmg = scr_stat("ability_damage", 20);
	global.shake = max(global.shake, 2);
}

// Placeholder progression: curse transformations own curse tiers until the kit has its full progression system.
function scr_curse_add_progress(_amount) {
	if (!variable_global_exists("curse_unmade")) global.curse_unmade = 0;
	global.curse_unmade += _amount;
}

// Q: a screen-wide curse pulse.
function scr_curse_pulse(_caster) {
	var _view_w = camera_get_view_width(view_camera[0]);
	var _view_h = camera_get_view_height(view_camera[0]);
	var _cx = camera_get_view_x(view_camera[0]) + _view_w * 0.5;
	var _cy = camera_get_view_y(view_camera[0]) + _view_h * 0.5;
	var _radius = point_distance(_cx, _cy, camera_get_view_x(view_camera[0]), camera_get_view_y(view_camera[0])) + 64;
	var _list = ds_list_create();
	var _count = collision_circle_list(_cx, _cy, _radius, obj_enemy_parent, false, true, _list, false);
	for (var i = 0; i < _count; i++) {
		var _enemy = _list[| i];
		if (instance_exists(_enemy) && _enemy.curse >= 0) {
			scr_curse_apply(_enemy, 1);
			if (_enemy.curse >= 1 && scr_curse_can_toad(_enemy)) scr_curse_toadify(_enemy);
		}
	}
	ds_list_destroy(_list);
	global.shake = max(global.shake, 8);
}
