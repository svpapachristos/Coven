
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
cam_look_strength = 0.15; //How much of the cursor's distance from screen center to move
cam_look_max = 175; // Max push in pixels
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
		
		// your own thralls as necro, able to shoulder through them but still them make way for you
		var _tl = ds_list_create();
		var _tn = collision_circle_list(_cx, _cy, body_radius + 48, obj_thrall, false, true, _tl, true);
		var _tlim = min(_tn, 8);
		for (var i = 0; i < _tlim; i++) {
			var _t = _tl[| i];
			if (_t.rise < 1) continue; // cant bump if its still digging out of the ground
			var _tx = (_t.bbox_left + _t.bbox_right) / 2, _ty = (_t.bbox_top + _t.bbox_bottom) / 2;
			var _d = point_distance(_cx, _cy, _tx, _ty);
			if (_d < 0.01 || _d >= body_radius + _t.body_radius + 2) continue;
			var _nx = (_tx - _cx) / _d, _ny = (_ty - _cy) / _d;
			var _dot = _mx * _nx + _my * _ny;
			if (_dot > 0) { _mx -= _nx * _dot * 0.5; _my -= _ny * _dot * 0.5; } // half speed into them instead of a wall
		}
		ds_list_destroy(_tl);
		
		//enemy collision: solid, slide right off a horde of enemies
		var _list = ds_list_create();
		var _n = collision_circle_list(_cx, _cy, body_radius + 64, obj_enemy_parent, false, true, _list, true);
		var _lim = min(_n, 12);
		// two passes so pushing off one enemy can't shove you into the one next to it
		repeat (2) {
			for (var i = 0; i < _lim; i++) {
				var _e  = _list[| i];
				if (_e.curse < 0) continue; // toads are not solid so you can go right through them
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
	if (hex_active && hex_mode != "") _display_dir = facing_dir_4;   // casting her hex: she faces where she's casting, even while walking the other way
	image_xscale = 1;
	// channeling the arcane beam: hold the wand-raised pose (frame 2 of the fire sprite)
	var _channel = instance_exists(obj_arcane_beam);
	if (_channel) {
		_firing = true;
		_display_dir = facing_dir_4;
	}
	if (_firing) {
		sprite_index = _moving ? _walk_fire[_display_dir] : _idle_fire[_display_dir];
	} else {
		sprite_index = _moving ? _walk[_display_dir] : _idle[_display_dir];
	}
	if (_channel) {
		image_index = 1;
		image_speed = 0;
		beam_pose = true;
	} else if (beam_pose) {
		image_speed = 1; // let her animate again once the beam ends
		beam_pose = false;
	}
}
function player_idle(){
	if (keyboard_check(ord("W"))) || (keyboard_check(ord("A"))) || (keyboard_check(ord("S"))) || (keyboard_check(ord("D"))) {
		state = "WALK";
	}
	if (mouse_check_button(mb_left) && can_shoot && !hex_active) { // (in her curse stance, left click belongs to the curse)
		state = "ATTACK";
	}
}
function player_walk() {
	movement();
	if (mouse_check_button(mb_left) && can_shoot && !hex_active) { // (in her curse stance, left click belongs to the curse)
		state = "ATTACK";
	}
	if (!keyboard_check(ord("W")) && !keyboard_check(ord("A")) && !keyboard_check(ord("S")) && !keyboard_check(ord("D"))) {
    state = "IDLE";
	}
}
function player_attack() {
	if (hex_active) { state = "IDLE"; can_shoot = true; return; } // her wand stands down in her curse stance
	movement();
	if (can_shoot) {
		can_shoot = false;
		var _p = (!is_undefined(wand) && struct_exists(wand, "primary")) ? wand.primary
			: { count: 1, spread: 0, pierce: 0, delay: 1, dmg: 1, speed: 1, homing: 0 };
		shoot_timer = game_get_speed(gamespeed_fps) * attack_speed * _p.delay / scr_stat("attack_speeed", 1);
		
		var _dir = point_direction(x, y, mouse_x, mouse_y);
		var _count = _p.count + floor(scr_stat("primary_count", 0));
		var _volley = []; // shared by every bolt in this shot so they spread across targets
		for (var i = 0; i < _count; i++) {
			var _spread = max(_p.spread, 6 * (_count - 1)); // extra bolts always fan out a little, even from a no-spread wand
			var _off = (_count == 1) ? 0 : lerp(-_spread, _spread, i / (_count - 1));
			var _proj = instance_create_layer(x + 3, y + 2, "Instances", obj_projectile);
			_proj.direction = _dir + _off;
			_proj.image_angle = _dir + _off;
			if (struct_exists(_p, "sprite")) _proj.sprite_index = _p.sprite;
			_proj.speed = proj_speed * _p.speed;
			_proj.damage *= _p.dmg;
			_proj.pierce = _p.pierce + floor(scr_stat("pierce", 0));
			_proj.homing = _p.homing + scr_stat("homing", 0);
			_proj.volley = _volley;
			_proj.homing_delay = (_count > 1) ? 5 : 0; //multi bolt volleys shoot in a fan pattern in a straight line for a brief moment before targeting
			_proj.homing *= random_range(0.7, 1.4); // each bolt has a slightly different curve
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

// ---- E: the living curse (rudimentary) ----
hex_held = noone;  // the world object her curse is holding
hex_reach = 4000;  // how far from her the curse can reach (4000 = the whole screen)
hex_grab_r = 80;   // how close the cursor must be to something for her hex to go for it (was 64)
// a few rocks to play with (obj_env_rock: the first environment object)
repeat (6) {
	var _a = random(360);
	var _d = random_range(80, 220);
	instance_create_depth(x + lengthdir_x(_d, _a), y + lengthdir_y(_d, _a), depth, obj_env_rock);
}

// The living curse itself: a thing with a position that leaves her hand, travels, grabs and throws.
hex_active = false;  // true while E is held and the curse is out in the world
hex_hx = x;          // where the curse is
hex_hy = y;
hex_hvx = 0;         // how it's moving (a throw inherits this)
hex_hvy = 0;
hex_speed = 9;       // how fast it travels to the cursor
hex_kind = "";       // "env" (an environment object: a rock...) or "enemy": what it's holding
hex_charge = 0;      // frames spent balled up with nothing to hold
hex_thrown = [];     // enemies currently flying through the air
hex_px = x;          // her position last frame, so the ball and aura move with her
hex_py = y;
beam_pose = false;   // true while she holds the beam-channeling pose

// Where her off hand (the one without the wand) is in each sprite, in that sprite's own pixels, measured from its
// origin (the middle of the 64x64 frame): [right, down]. Her wand is always in the hand on the right of the image,
// so the off hand is always on the left. Read from the art on Oct 18; fine-tune in game with J (see hex_hand_debug).
// A sprite missing here uses hex_hand_default. A new witch only needs her own rows.
hex_hand = {};
hex_hand[$ "spr_player_witch1_idle_down"]       = [-18, 20];
hex_hand[$ "spr_player_witch1_idle_down_fire"]  = [-22, 21];
hex_hand[$ "spr_player_witch1_walk_down"]       = [-21, 22];
hex_hand[$ "spr_player_witch1_walk_down_fire"]  = [-22, 21];
hex_hand[$ "spr_player_witch1_idle_left"]       = [-22, 20];
hex_hand[$ "spr_player_witch1_idle_left_fire"]  = [-22, 16];
hex_hand[$ "spr_player_witch1_walk_left"]       = [-21, 20];
hex_hand[$ "spr_player_witch1_walk_left_fire"]  = [-19, 18];
hex_hand[$ "spr_player_witch1_idle_right"]      = [-17, 18];
hex_hand[$ "spr_player_witch1_idle_right_fire"] = [-17, 16];
hex_hand[$ "spr_player_witch1_walk_right"]      = [-22, 20];
hex_hand[$ "spr_player_witch1_walk_right_fire"] = [-22, 21];
hex_hand[$ "spr_player_witch1_idle_up"]         = [-22, 25];
hex_hand[$ "spr_player_witch1_idle_up_fire"]    = [-22, 25];
hex_hand[$ "spr_player_witch1_walk_up"]         = [-22, 24];
hex_hand[$ "spr_player_witch1_walk_up_fire"]    = [-22, 25];
hex_hand_default = [-20, 20];
// the two orbs that grow in and dissolve out instead of popping (eased in obj_player Draw)
hex_gR = 0;           // the knot gathering where her reaching hex arrives (0..1)
hex_gx = x; hex_gy = y;
hex_wR = 0;           // the wrap around what she holds (0..1); it rides along with it and dissolves after she lets go
hex_hand_f = 0;       // her palm: 0 = the orb (resting) .. 1 = channeling (an erratic pocket of hex), eased between
hex_hand_e = 0.8;     // how hard she's channeling (how erratic her palm is), eased
hex_wobj = noone;
hex_wkind = "";
hex_hand_debug = false; // J toggles: a marker on the hand point, and the arrow keys nudge it for the current sprite

// where her off hand is in the room right now, as [x, y]. Call it after her sprite and position are final
// for the frame (the end of Step), or the ball trails a frame behind her turns.
function hex_hand_pos() {
	var _p = hex_hand[$ sprite_get_name(sprite_index)];
	if (is_undefined(_p)) _p = hex_hand_default;
	return [x + _p[0] * image_xscale, y + _p[1] * image_yscale];
}
// ---- HER HEX: one amount, always somewhere ----
// Her hex is a single quantity (hex_max units) that moves between a few places. Every visual reads these numbers, so
// what you see is always where her hex actually is: nothing pops in, nothing vanishes.
//   hex_hand_amt  in her hand (what she can use right now; the HUD shows this)
//   hex_par       out in the world: PARCELS, small bits of hex (HEX_PARCEL each) that each move on their own.
//                 st 0 = flowing out, 1 = gathered at the target (churning in the knot, or around what she holds),
//                 2 = going home. hex_out and hex_at are just the sums of the st 0 and st 1 parcels, counted each Step.
//   hex_orb_amt   in the orb she's charging
//   (and whatever rides inside obj_hex_shot instances, as their hex_amt)
// Step moves it along: hand -> parcels out -> gathered when she reaches; gathered -> parcels home -> hand when she lets go.
// Because every parcel finds its own way, the river braids and wanders on its own, and going home it disperses and drifts
// back bit by bit, instead of one shape stretching out and retracting.
hex_budget = 32;      // her max hex (raised by the "max_hex" stat; H adds 8 while testing)
hex_max = hex_budget;
hex_hand_amt = hex_budget;
hex_out = 0;
hex_at = 0;
hex_need = 0;         // how much the current reach wants at its target (a lift's cost, or hex_reach_cap over open ground)
hex_reach_cap = 6;    // how much gathers when she reaches into open ground (was 14: it read as a glob)
hex_orb_amt = 0;
hex_par = [];         // her hex out in the world, as parcels: { x, y, vx, vy, s (its own pace), ph (its own phase), st, wait, hot, amt }
#macro HEX_PARCEL 0.25   // how much hex one parcel carries (4 parcels per unit)
hex_pour_n = 2;       // parcels her hand lets out per frame while reaching (2 = half a unit a frame)
hex_pour_acc = 0;
hex_par_turn = 0.13;  // how quickly a parcel can change direction (lower = wider, lazier curves)
hex_par_curl = 0.85;   // how much the drifting currents push parcels around (higher = a wilder, wider river)
hex_par_fan = 0.425;    // how widely parcels leave her palm (radians)
hex_home_spread = 35; // frames over which the gathered parcels decide, one by one, to head home (higher = a slower, longer drift back)

hex_flow_speed = 9;   // how fast a parcel flows out to where it's going (pixels a frame, each parcel a little different)
// (was 10 for the old motes; the parcel river looked right at 6 in the prototype)
hex_return_speed = 20; // ...and back home to her hand, speeding up as it nears her palm (was 11 for the old motes)
hex_cost = 0;         // what the thing she's holding cost
hex_cost_lift = 8;    // hex it takes to lift an environment object, per unit of its weight (a rock is 1)
hex_cost_enemy = 14;  // hex it takes to lift an enemy
hex_mode = "";        // "grab" (right click: reach out and lift) or "charge" (left click: an orb in front of her hand)
hex_ball_dist = 30;   // how far in front of her hand the charging ball gathers
hex_boom_dmg = 10;     // damage per unit of hex in the charged orb (plus a base of 10)
hex_boom_r = 5;       // blast radius per unit of hex (plus a base of 40)
hex_blast_cost = 4;   // a tap of Space Bar: a quick hand blast
hex_blast_dmg = 10;
hex_key = vk_space;   // hold for her hex stance, tap for a palm blast (was E; space frees a finger for WASD)
hex_tap = 0;          // frames the stance key has been held this press (short = a tap)
cam_hex_settle = 0;   // frames left that the camera stays settled on her for the hex
cam_hex_linger = 30;  // how long the camera stays settled after a hold of E ends
hex_charge_cap = 24;  // the most hex one charged orb can hold
hex_charge_rate = 0.5; // hex added to a charging orb per frame (0.5 = full in about 0.8s)
hex_orb_n = 0;        // (whole units in the charging orb, for sizing it)
hex_bonus = 0;        // extra max hex (debug: press H in a run for +8)

// how much hex she has in hand right now (whole units)
hex_available = function() {
	return floor(hex_hand_amt + 0.001);
}
// let out one parcel of hex from her palm (_x, _y), heading toward (_tx, _ty)
hex_par_emit = function(_x, _y, _tx, _ty) {
	var _a = arctan2(_ty - _y, _tx - _x) + random_range(-0.5, 0.5) * hex_par_fan * 2;
	var _s = hex_flow_speed * random_range(0.75, 1.25);
	array_push(hex_par, { x: _x + random_range(-1.5, 1.5), y: _y + random_range(-1.5, 1.5), vx: cos(_a) * _s, vy: sin(_a) * _s, s: _s, ph: random(6.28), st: 0, wait: 0, hot: (random(1) < 0.35), amt: HEX_PARCEL });
}
// send _a hex home from (_x, _y): it breaks into parcels that each head home on their own time (a shot that burst)
hex_home_add = function(_x, _y, _a) {
	while (_a > 0.001) {
		var _k = min(HEX_PARCEL, _a);
		var _ang = random(6.28);
		array_push(hex_par, { x: _x + random_range(-6, 6), y: _y + random_range(-6, 6), vx: cos(_ang) * 2, vy: sin(_ang) * 2, s: hex_flow_speed * random_range(0.75, 1.25), ph: random(6.28), st: 2, wait: irandom(hex_home_spread), hot: (random(1) < 0.35), amt: _k });
		_a -= _k;
	}
}
// everything out in the world (flowing out, or gathered) heads home, each parcel deciding on its own when.
// _vx, _vy: a push they all get first (what she threw was moving)
hex_let_go = function(_vx = 0, _vy = 0) {
	for (var _i = 0; _i < array_length(hex_par); _i++) {
		var _q = hex_par[_i];
		if (_q.st == 2) continue;
		_q.st = 2;
		_q.wait = irandom(hex_home_spread);
		_q.vx += _vx + random_range(-0.4, 0.4);
		_q.vy += _vy + random_range(-0.4, 0.4);
	}
}
// throw whatever her hex is holding: the hex that held it lets go and drifts home from where it was
hex_throw = function() {
	if (hex_held == noone || !instance_exists(hex_held)) { hex_held = noone; hex_kind = ""; return; }
	if (hex_kind == "env") {
		hex_held.grabbed = false;
		hex_held.vx *= 1.6;
		hex_held.vy *= 1.6;
		hex_held.vz = min(7, 3 + 0.15 * point_distance(0, 0, hex_held.vx, hex_held.vy));   // pops upward (harder throws arc higher), so it lobs and lands instead of skating off
		hex_let_go(hex_held.vx * 0.5, hex_held.vy * 0.5);
	} else {
		array_push(hex_thrown, { inst: hex_held, vx: hex_hvx * 1.6, vy: hex_hvy * 1.6, hit: [] });
		hex_let_go(hex_hvx * 0.8, hex_hvy * 0.8);
	}
	hex_held = noone;
	hex_kind = "";
}
