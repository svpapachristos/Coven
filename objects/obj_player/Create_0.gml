
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
hex_grab_r = 64;   // how close the cursor must be to grab something
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
hex_rv_state = 0;     // THE RIVER: 0 none, 1 reaching out, 2 draining into what she holds, 3 flowing home
hex_rv_lo = 0;        // the stretch of the path (0 = her palm, 1 = the target) the river covers right now
hex_rv_hi = 0;
hex_rv_tx = x;        // where it's flowing to
hex_rv_ty = y;
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
//   hex_out       flowing out to her target in the river
//   hex_at        gathered at the target (the forming knot, or the surround around what she holds)
//   hex_orb_amt   in the orb she's charging
//   hex_home      rivers flowing home (from a knot she let go, a thing she threw, a shot that burst)
//   (and whatever rides inside obj_hex_shot instances, as their hex_amt)
// Step moves it along: hand -> river -> target when she reaches, target -> home rivers -> hand when she lets go.
hex_budget = 32;      // her max hex (raised by the "max_hex" stat; H adds 8 while testing)
hex_max = hex_budget;
hex_hand_amt = hex_budget;
hex_out = 0;
hex_at = 0;
hex_need = 0;         // how much the current reach wants at its target (a lift's cost, or hex_reach_cap over open ground)
hex_reach_cap = 14;   // how much gathers when she reaches into open ground
hex_pour = 1;         // how much hex the river carries per frame (out of her hand, and into the target)
hex_orb_amt = 0;
hex_home = [];        // rivers going home: { x, y (where it started), lo, hi (the stretch of the path it covers), amt }

hex_flow_speed = 10; // how fast her hex flows out to where it's going (pixels a frame). Lower = it takes longer to reach
// (Sophia's target: somewhere between waterbending (too slow) and airbending (much too fast); was 7)
hex_return_speed = 11; // ...and back home to her hand (was 9)
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
// send _a hex home from (_x, _y): it becomes a river flowing back along a path into her palm
hex_home_add = function(_x, _y, _a) {
	if (_a <= 0.001) return;
	array_push(hex_home, { x: _x, y: _y, lo: 1, hi: 1, amt: _a });
}
// let go of a reach: whatever gathered at the target flows home from there (the outgoing river turns back on its own, in Step)
hex_let_go = function() {
	hex_home_add(hex_gx, hex_gy, hex_at);
	hex_at = 0;
}
// throw whatever her hex is holding: the hex that held it flows home from where she let go
hex_throw = function() {
	if (hex_held == noone || !instance_exists(hex_held)) { hex_held = noone; hex_kind = ""; return; }
	var _ey = hex_held.y;
	if (hex_kind == "env") {
		_ey -= hex_held.z;
		hex_held.grabbed = false;
		hex_held.vx *= 1.6;
		hex_held.vy *= 1.6;
		hex_held.vz = min(7, 3 + 0.15 * point_distance(0, 0, hex_held.vx, hex_held.vy));   // pops upward (harder throws arc higher), so it lobs and lands instead of skating off
	} else {
		array_push(hex_thrown, { inst: hex_held, vx: hex_hvx * 1.6, vy: hex_hvy * 1.6, hit: [] });
	}
	hex_home_add(hex_held.x, _ey, hex_at);
	hex_at = 0;
	hex_held = noone;
	hex_kind = "";
}
// where a river's path bends: it arcs gently from her palm (_ax, _ay) to (_bx, _by), bowing upward. A river's path is a
// quadratic bezier through this point: (1-f)^2 * palm + 2(1-f)f * bend + f^2 * end, with f from 0 (her palm) to 1 (the end)
function hex_river_bend(_ax, _ay, _bx, _by) {
	var _l = point_distance(_ax, _ay, _bx, _by);
	var _pa = point_direction(_ax, _ay, _bx, _by) + ((_bx >= _ax) ? 90 : -90);   // the side that bows upward
	return [(_ax + _bx) / 2 + lengthdir_x(_l * 0.16, _pa), (_ay + _by) / 2 + lengthdir_y(_l * 0.16, _pa)];
}
// move one river along its path (0 = her palm, 1 = the far end) flowing HOME: the front heads in first, the back follows
// once the stream is long enough (or the front is home). What reaches her palm returns to her hand. Returns true when
// it's all home
function hex_home_flow(_r, _hx, _hy) {
	var _rl = max(16, point_distance(_hx, _hy, _r.x, _r.y) * 1.1);   // about how long the path is
	var _dr = hex_return_speed / _rl;
	_r.lo = max(0, _r.lo - _dr);
	if (_r.lo <= 0 || (_r.hi - _r.lo) * _rl > 70) {
		if (_r.lo <= 0) {
			var _d = _r.amt * min(1, _dr / max(_r.hi, _dr));   // the share of what's left that reaches her this frame
			_r.amt -= _d;
			hex_hand_amt += _d;
		}
		_r.hi = max(_r.lo, _r.hi - _dr);
	}
	if (_r.hi <= 0.001) { hex_hand_amt += _r.amt; _r.amt = 0; return true; }
	return false;
}
