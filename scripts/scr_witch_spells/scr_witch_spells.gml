//Placeholder Witch with Placeholder Spells

//Placeholder ability: do a burst of damage around the witch
function scr_flame_nova(_caster) {
	var _cx = _caster.x, _cy = _caster.y;
	var _radius = 220 * WORLD_SCALE;
	var _dmg = scr_stat("ability_damage", 40);
	
	with (obj_enemy_parent) {
		if (point_distance(_cx, _cy, x, y) <= _radius) scr_damage_enemy(id, _dmg, c_lime);
	}
	repeat(40) {
		var _a = random(360), _r = random(_radius);
		part_particles_create(global.ps_sparks, _cx + lengthdir_x(_r, _a), _cy + lengthdir_y(_r, _a), global.pt_spark, 1);
	}
	
	var _sun = struct_exists(global.item_counts, "tarot_sun") || struct_exists(global.item_counts, "tarot_sun_rev");
	scr_burst_fx(_cx, _cy, _radius, _sun ? make_color_rgb(255, 200, 70) : make_color_rgb(255, 130, 60));
}

// Placeholder ultimate: hits every enemy on the screen
function scr_ultimate_place_holder(_caster) {
	var _cam = view_camera[0];
	var _x0 = camera_get_view_x(_cam), _y0 = camera_get_view_y(_cam);
	var _x1 = _x0 + camera_get_view_width(_cam), _y1 = _y0 + camera_get_view_height(_cam);
	var _dmg = scr_stat("ultimate_damage", 500);
	
	with (obj_enemy_parent) {
		if (point_in_rectangle(x, y, _x0, _y0, _x1, _y1)) {
			part_particles_create(global.ps_sparks, x, y, global.pt_spark, 12);
			scr_damage_enemy(id, _dmg, c_fuchsia);
		}
	}
}