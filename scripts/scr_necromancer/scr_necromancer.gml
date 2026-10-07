// The Necromancer: the Commander of an army that grows out of everything you slay

#macro THRALL_HARD_CAP 500 // absolute ceiling so a frenzy doesnt break the game
#macro CORPSE_LIFETIME 12000 // milliseconds that a fallen enemy will stay raisable

function scr_necro_reset() {
	global.necro_corpses = []; 
	global.necro_frenzy = 0;
}	

function scr_is_necromancer() {
	return instance_exists(obj_player) && !is_undefined(obj_player.witch) && obj_player.witch.name == "Necromancer";
}

// the army will scale off of level, so it can get stronger innately, and also be buffed by specific items
function scr_army_cap() {
	return floor(scr_stat("army_cap", 20 + 3 * global.level));
}

function scr_spawn_thrall(_x, _y) {
	if (instance_number(obj_thrall) >= THRALL_HARD_CAP) return noone;
	part_particles_create(global.ps_sparks, _x, _y, global.pt_aura, 3);
	return instance_create_layer(_x, _y, "Instances", obj_thrall);
}

// called from scr_damage_enemy whenever something dies
function scr_necro_on_kill(_enemy) {
	if (!scr_is_necromancer()) return;
	if (!variable_global_exists("necro_corpses")) scr_necro_reset();
	
	// mid frenzy, the dead dont even hit the ground before working for you
	if (global.necro_frenzy > 0) { scr_spawn_thrall(_enemy.x, _enemy.y); return; }
	
	array_push(global.necro_corpses, { x: _enemy.x, y: _enemy.y, t: current_time });
	//forget the oldest fallen so the list cant balloon
	while (array_length(global.necro_corpses) > 0
	&& (array_length(global.necro_corpses) > 500 || global.necro_corpses[0].t < current_time - CORPSE_LIFETIME)) {
		array_delete(global.necro_corpses, 0, 1);
	}
}
	
	// E ABILITY: Raise the Fallen, everything that recently died near you claws its way through the dirt, coming back to serve you
function scr_necro_raise(_caster) {
	if (!variable_global_exists("necro_corpses")) scr_necro_reset();
	var _room = (global.necro_frenzy > 0) ? THRALL_HARD_CAP : scr_army_cap() - instance_number(obj_thrall);
	var _max = min(_room, floor(scr_stat("raise_count", 10 + global.level)));
	var _radius = scr_stat("raise_radius", 260) * WORLD_SCALE;
	var _raised = 0
	
	//newest fallen first
	for (var i = array_length(global.necro_corpses) - 1; i >= 0 && _raised < _max; i--) {
		var _c = global.necro_corpses[i];
		if (_c.t < current_time - CORPSE_LIFETIME) break; // the list is in time order
		if (point_distance(_caster.x, _caster.y, _c.x, _c.y) > _radius) continue;
		scr_spawn_thrall(_c.x, _c.y);
		array_delete(global.necro_corpses, i, 1);
		_raised++;
	}
	
	//no fallen nearby? no problem! the earth still has dead to share
	if (_raised == 0) repeat (min(3, max(0, _room))) {
		scr_spawn_thrall(_caster.x + random_range(-60, 60), _caster.y + random_range(-60, 60));
	}
	
	scr_burst_fx(_caster.x, _caster.y, _radius, make_color_rgb(150, 90, 255));
}

// Q: Danse Macabre, the army frenzies and for a few moments every kill instantly raises a dead to your service
function scr_necro_danse(_caster) {
	if (!variable_global_exists("necro_corpses")) scr_necro_reset();
	global.necro_frenzy = game_get_speed(gamespeed_fps) * scr_stat("frenzy_duration",  8);
	with (obj_thrall) hp = max_hp;
	
	// every fallen on the screen rises at once to start the dance
	var _cam = view_camera[0];
	var _x0 = camera_get_view_x(_cam), _y0 = camera_get_view_y(_cam);
	var _x1 = _x0 + camera_get_view_width(_cam), _y1 = _y0 + camera_get_view_height(_cam);
	for (var i = array_length(global.necro_corpses) - 1; i >= 0; i--) {
		var _c = global.necro_corpses[i];
		if (point_in_rectangle(_c.x, _c.y, _x0, _y0, _x1, _y1)) {
			scr_spawn_thrall(_c.x, _c.y);
			array_delete(global.necro_corpses, i, 1);
		}
	}
	
	scr_burst_fx(_caster.x, _caster.y, 400 * WORLD_SCALE, make_color_rgb(200, 60 , 255), 24);
	global.shake = max(global.shake, 6);
}