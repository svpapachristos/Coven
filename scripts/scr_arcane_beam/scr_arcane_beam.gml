function scr_arcane_beam(_caster){
	var _step = _caster.alt_pulse_max; //frames between ticks
	var _tick = _step / game_get_speed(gamespeed_fps); //seconds per tick
	
	_caster.beam_heat = min(1, _caster.beam_heat + 0.1 *  (_step / 6)); // heats up at the same speed regardless of tick rate
	var _heat = _caster.beam_heat;
	var _beam = scr_beam_line(_caster, _heat);
	var _half = scr_beam_half(_heat);
	
	//beam damage is damage per second and each tick deals its share
	var _dps = scr_stat("alt_damage", scr_stat("beam_damage", 180)) * (1 + 2 * _heat);
	var _dmg = _dps * _tick
	var _col = make_color_rgb(220, 160, 255);
	
	var _chunk = 10;
	var _chance = clamp(14 / max(1, _caster.beam_hits_prev), 0.15, 1);
	var _hit_count = 0;
	
	with (obj_enemy_parent) {
		var _reach = _half + max(sprite_width, sprite_height) * 0.35; // bigger enemies are easier to hit
		if (scr_dist_to_segment(x, y, _beam.x1, _beam.y1, _beam.x2, _beam.y2) < _reach) {
			_hit_count++;
			
			// more damage per second = more numbers, then bigger ones
			beam_acc = min(beam_acc + _dmg, _chunk * 3);
			if (random(1) < _chance) {
				var _shown = 0;
				while (beam_acc >= _chunk && _shown < 2) {
					var _num = scr_spawn_damage_number(id, _chunk, _col);
					if (_num != noone) {
						_num.x += random_range(-14, 14);
						_num.y += random_range(-10, 0);
					}
					beam_acc -= _chunk;
					_shown++;
				}
			}
			if (irandom(2) == 0) part_particles_create(global.ps_sparks, x, y, global.pt_spark, 1);
			scr_apply_element(id, _caster.wand.element);
			scr_damage_enemy(id, _dmg, _col, false); 
			//part_particles_create(global.ps_sparks, x, y, global.pt_spark, 1);
		}
	}
	_caster.beam_hits_prev = _hit_count;
	
	//keep the visible beam alive
	var _b = instance_exists(obj_arcane_beam) ? instance_find(obj_arcane_beam, 0) : instance_create_layer(_beam.x1, _beam.y1, "Instances", obj_arcane_beam);
	_b.life = max(9, _step * 3 + 3);
	_b.heat = _heat;
	return true;
}

function scr_beam_half(_heat) { return 14 + 30 * _heat; } //beams halfwidth in pixels