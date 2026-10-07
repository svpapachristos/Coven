//Our lil witchy
witch = undefined;
wand = undefined;
ability_cd = 0;
ultimate_charge = 0;
ultimate_charge_max = 100;

//witch body
body_radius = 12; // how big the witch is for crowd collision

state = "IDLE";

//HP and Mana
hp = 100;
base_max_hp = 100;
max_hp = base_max_hp;

base_max_mana = 100
max_mana = base_max_mana;
mana = max_mana;
mana_regen = 15; //per second

//Wand Cast
alt_pulse_max = 6; //frames between pulses (6 = 10/sec)
alt_pulse = 0; //countdown to next pulse
alt_drain = 25; //mana drain per second while bolt is connected
alt_pulse_cost = alt_drain * alt_pulse_max / game_get_speed(gamespeed_fps);
alt_regen_delay = game_get_speed(gamespeed_fps) / 2;  // frames before mana regens, so about a half second after casting
alt_pulse_count = 0; 
alt_fire = scr_alt_chain_lightning; // our lightning script


//Witches Wand Arcane Hyperbeam
beam_heat = 0;
beam_hits_prev = 0;


//I-Frames
iframes = 0; //we all know what I-Frames are right?
hit_flash = 0;


//Attack and Directionals
facing_dir = 1;
facing_dir_4 = 0;
can_shoot = true;
can_walk = true;
shoot_timer = 0;

attack_speed = .2 * WORLD_SCALE;
proj_speed = 2.5 * WORLD_SCALE;
move_speed = 2.5 * WORLD_SCALE;

//Camera look-ahead
cam_look_strength = 0.3; //How much of the cursor's distance from screen center to move
cam_look_max = 300; // Max push in pixels
cam_look_smooth = 0.3; // 0.05 will be more floaty, 0.2 will be more snappy, so adjust accordingly
cam_offset_x = 0;
cam_offset_y = 0;

//Player Functions

function movement() {
	//walk functions are for losers
	var _mx = (keyboard_check(ord("D")) - keyboard_check(ord("A"))) * move_speed;
	var _my = (keyboard_check(ord("S")) - keyboard_check(ord("W"))) * move_speed;

	if (_mx != 0 || _my != 0) {
		// collide from the middle of the hitbox, sized to the sprite, not from the sprite's origin
		body_radius = (bbox_right - bbox_left) * 0.45;
		var _cx = (bbox_left + bbox_right) / 2, _cy = (bbox_top + bbox_bottom) / 2;

		var _list = ds_list_create();
		var _n = collision_circle_list(_cx, _cy, body_radius + 64, obj_enemy_parent, false, true, _list, true);
		var _lim = min(_n, 12);

		// two passes so pushing off one enemy can't shove you into the one next to it
		repeat (2) {
			for (var i = 0; i < _lim; i++) {
				var _e  = _list[| i];
				var _ex = (_e.bbox_left + _e.bbox_right) / 2, _ey = (_e.bbox_top + _e.bbox_bottom) / 2;
				var _d  = point_distance(_cx, _cy, _ex, _ey);
				if (_d < 0.01 || _d >= body_radius + _e.body_radius + 2) continue;

				// direction toward the enemy; strip out only the part of our move that pushes into it, keep the slide
				var _nx = (_ex - _cx) / _d, _ny = (_ey - _cy) / _d;
				var _dot = _mx * _nx + _my * _ny;
				if (_dot > 0) { _mx -= _nx * _dot; _my -= _ny * _dot; }
			}
		}
		ds_list_destroy(_list);

		x += _mx;
		y += _my;
	}

	x = clamp(x, 0, room_width - sprite_width);
	y = clamp(y, 0, room_height - sprite_height);
}

// true if stepping to (_nx, _ny) would push us deeper into an enemy
// moving away is always allowed, so you can never get stuck inside one
function body_blocked(_nx, _ny) {
	var _list = ds_list_create();
	var _n = collision_circle_list(_nx, _ny, body_radius + 64, obj_enemy_parent, false, true, _list, false);
	var _blocked = false;
	for (var i = 0; i < _n; i++) {
		var _e = _list[| i];
		var _min = body_radius + _e.body_radius;
		var _dn = point_distance(_nx, _ny, _e.x, _e.y);
		if (_dn < _min && _dn < point_distance(x, y, _e.x, _e.y)) { _blocked = true; break; }
	}
	ds_list_destroy(_list);
	return _blocked;
}


function update_facing_sprite() {
	var _idle = [spr_player_witch1_idle_right, spr_player_witch1_idle_up, spr_player_witch1_idle_left, spr_player_witch1_idle_down];
	var _walk = [spr_player_witch1_walk_right, spr_player_witch1_walk_up, spr_player_witch1_walk_left, spr_player_witch1_walk_down];
	var _idle_fire = [spr_player_witch1_idle_right_fire, spr_player_witch1_idle_up_fire, spr_player_witch1_idle_left_fire, spr_player_witch1_idle_down_fire];
	var _walk_fire = [spr_player_witch1_walk_right_fire, spr_player_witch1_walk_up_fire, spr_player_witch1_walk_left_fire, spr_player_witch1_walk_down_fire];
	var _firing = (state == "ATTACK");
	var _move_dir_4 = -1; // -1 means idle
	if (keyboard_check(ord("D"))) _move_dir_4 = 0; 	
	else if (keyboard_check(ord("W"))) _move_dir_4 = 1;
	else if (keyboard_check(ord("A"))) _move_dir_4 = 2;
	else if (keyboard_check(ord("S"))) _move_dir_4 = 3;
	var _moving = (_move_dir_4 != -1);
	// Pick which direction value actually determines the sprite this frame
	var _display_dir = _firing ? facing_dir_4 : (_moving ? _move_dir_4 : facing_dir_4);
	image_xscale = 1;
	if (_firing) {
		sprite_index = _moving ? _walk_fire[_display_dir] : _idle_fire[_display_dir];
	} else {
		sprite_index = _moving ? _walk[_display_dir] : _idle[_display_dir];
	}
}
function player_idle(){
	if (keyboard_check(ord("W"))) || (keyboard_check(ord("A"))) || (keyboard_check(ord("S"))) || (keyboard_check(ord("D"))) {
		state = "WALK";
	}
	if (mouse_check_button(mb_left) && can_shoot) {
		state = "ATTACK";
	}
}
function player_walk() {
	movement();
	if (mouse_check_button(mb_left) && can_shoot) {
		state = "ATTACK";
	}
	if (!keyboard_check(ord("W")) && !keyboard_check(ord("A")) && !keyboard_check(ord("S")) && !keyboard_check(ord("D"))) {
    state = "IDLE";
	}
}
function player_attack() {
	movement();
	if (can_shoot) {
		can_shoot = false;
		var _p = (!is_undefined(wand) && struct_exists(wand, "primary")) ? wand.primary
			: { count: 1, spread: 0, pierce: 0, delay: 1, dmg: 1, speed: 1, homing: 0 };
		shoot_timer = game_get_speed(gamespeed_fps) * attack_speed * _p.delay / scr_stat("attack_speeed", 1);
		
		var _dir = point_direction(x, y, mouse_x, mouse_y);
		var _count = _p.count + floor(scr_stat("primary_count", 0));
		for (var i = 0; i < _count; i++) {
			var _off = (_count == 1) ? 0 : lerp(-_p.spread, _p.spread, i / (_count - 1));
			var _proj = instance_create_layer(x + 3, y + 2, "Instances", obj_projectile);
			_proj.direction = _dir + _off;
			_proj.image_angle = _dir + _off;
			if (struct_exists(_p, "sprite")) _proj.sprite_index = _p.sprite;
			_proj.speed = proj_speed * _p.speed;
			_proj.damage *= _p.dmg;
			_proj.pierce = _p.pierce + floor(scr_stat("pierce", 0));
			_proj.homing = _p.homing + scr_stat("homing", 0);
			if (!is_undefined(wand)) {
				_proj.element = wand.element;
				_proj.image_blend = scr_element_color(wand.element);
			}
		}
	}
	if (shoot_timer > 0) {
		shoot_timer -= 1;
	} else {
		can_shoot = true;
		if (!mouse_check_button(mb_left)) state = "IDLE";
	}
}