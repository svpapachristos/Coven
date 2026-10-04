function scr_elements_init(){
	global.element_db = {
		arcane: { name: "Arcane", color: make_color_rgb(200, 140, 255), status: undefined },
		fire:	{ name: "Fire", color: make_color_rgb(255, 140, 40), status: "burn" },
		ice:	{ name: "Ice", color: make_color_rgb(140, 220, 255), status: "chill" },
		storm:	{ name: "Storm", color: make_color_rgb(115, 145, 255), status: undefined },
		earth:	{ name: "Earth", color: make_color_rgb(50, 163, 90), status: "stagger" },
		air:	{ name: "Air", color: make_color_rgb(200, 255, 220), status: "knockback" },
	};
}

function scr_element_color(_element) {
	if (is_undefined(_element) || !struct_exists(global.element_db, _element)) return make_color_rgb(60, 220, 255);
	return global.element_db[$ _element].color;
}

//Applies an elements status to an enemy (does nothing if und)
function scr_apply_element(_enemy, _element, _power = 1) {
	if (is_undefined(_element) || !struct_exists(global.element_db, _element)) return;
	var _status = global.element_db[$ _element].status;
	if (is_undefined(_status)) return;
	
	var _fps = game_get_speed(gamespeed_fps);
	switch (_status) {
		
		case "burn":
			_enemy.burn_timer = _fps * scr_stat("burn_duration", 3);
			_enemy.burn_dps = max(_enemy.burn_dps, scr_stat("burn_damage", 30) * _power);
			break;
			
		case "chill":
			_enemy.chill_timer = _fps * scr_stat("chill_duration", 2);
			_enemy.chill_slow = clamp(scr_stat("chill_slow", 0.4) * _power, 0, 0.8);
			break;
		
		case "stagger":
			_enemy.stun_timer = _fps * 0.6;
			break;	
			
		case "knockback":
			if (instance_exists(obj_player)) {
				var _dir = point_direction(obj_player.x, obj_player.y, _enemy.x, _enemy.y);
				_enemy.knock_x += lengthdir_x(14 * _power, _dir);
				_enemy.knock_y += lengthdir_y(14 * _power, _dir);
			}
			break;
	}
}