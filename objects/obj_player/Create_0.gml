
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
	var _in = input_move();   // which way the player is pushing (scr_input: keyboard now, a controller or touch later)
	var _mx = _in[0] * move_speed;
	var _my = _in[1] * move_speed;

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
	if (input_moving()) {
		// face along whichever way she's pushing harder (a dead-even diagonal faces sideways)
		var _in = input_move();
		if (abs(_in[0]) >= abs(_in[1])) _move_dir_4 = (_in[0] > 0) ? 0 : 2;
		else _move_dir_4 = (_in[1] < 0) ? 1 : 3;
	}
	var _moving = (_move_dir_4 != -1);
	// Pick which direction value actually determines the sprite this frame
	var _display_dir = _firing ? facing_dir_4 : (_moving ? _move_dir_4 : facing_dir_4);
	if (hex.mv.active && hex.mv.mode != "") _display_dir = facing_dir_4;   // casting her hex: she faces where she's casting, even while walking the other way
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
	if (input_moving()) {
		state = "WALK";
	}
	if (input_check("primary") && can_shoot && !hex.mv.active) { // (in her curse stance, left click belongs to the curse)
		state = "ATTACK";
	}
}
function player_walk() {
	movement();
	if (input_check("primary") && can_shoot && !hex.mv.active) { // (in her curse stance, left click belongs to the curse)
		state = "ATTACK";
	}
	if (!input_moving()) {
    state = "IDLE";
	}
}
function player_attack() {
	if (hex.mv.active) { state = "IDLE"; can_shoot = true; return; } // her wand stands down in her curse stance
	movement();
	if (can_shoot) {
		can_shoot = false;
		var _p = (!is_undefined(wand) && struct_exists(wand, "primary")) ? wand.primary
			: { count: 1, spread: 0, pierce: 0, delay: 1, dmg: 1, speed: 1, homing: 0 };
		shoot_timer = game_get_speed(gamespeed_fps) * attack_speed * _p.delay / scr_stat("attack_speeed", 1);
		
		var _aim = input_aim();
		var _dir = point_direction(x, y, _aim[0], _aim[1]);
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
		if (!input_check("primary")) state = "IDLE";
	}
}

// ---- HER HEX (Space) ----
// her hex belongs to witches tagged "hexweaver" (set every Step from her witch, which is chosen after Create and can
// change in the hideout). Every other witch keeps her own E and never sees the hex
hex_on = false;
hex_rocks_done = false; // a few rocks to play with (obj_env_rock), spawned the first time the hex is hers

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
// ---- HER HEX: a hex body (scr_hex_core; the whole structure is in notes/hex-core-design.md) ----
// All of her hex lives in ONE struct, `hex`: her hand (home), her parcels (hex out in the world, each finding its own
// way, so the river braids) and her anchors (where hex gathers: the knot she reaches into, what she holds, the orb she
// charges, a shot in flight). THE LEDGER: hand + parcels + anchor pools = max, always (with F1 on, the audit checks it
// every frame). Only scr_hex_core changes those; everything here just asks it to.
// HER TUNING: every number her hex uses, in one place (anything left out uses hex_tune_defaults in scr_hex_core).
hex = hex_body_create(id, {
	// the amount
	max: 32,              // her max hex (raised by the "max_hex" stat; H adds 8 while testing)
	parcel: 0.25,         // how much hex one parcel carries (4 parcels per unit)
	// the river
	pour_n: 2,            // parcels her hand lets out per frame while reaching (2 = half a unit a frame)
	flow: 9,              // how fast a parcel flows out to where it's going (was 10 for the old motes; 6 in the prototype)
	turn: 0.13,           // how quickly a parcel can change direction (lower = wider, lazier curves)
	curl: 0.85,           // how much the drifting currents push parcels around (higher = a wilder, wider river)
	fan: 0.425,           // how widely parcels leave her palm (radians)
	return_speed: 20,     // ...and back home to her hand, speeding up as it nears her palm (was 11 for the old motes)
	home_spread: 35,      // frames over which the gathered parcels decide, one by one, to head home (higher = a slower, longer drift back)
	land_r: 14,           // a parcel this close to where her hand is headed is home (was 6: too narrow to land while she walks)
	// the flow (holding right click: she pours)
	reserve: 4,           // hex the flow never takes: her emergency reserve (one palm blast); her palm always keeps a core
	head_follow: 0.3,     // how quickly the river's head follows the cursor (0..1; was 0.15)
	flow_spread: 3,       // the more hex at the head, the wider it eddies (radius grows by this x the square root of the hex there)
	flow_loose: 6,        // the head moving faster than this (pixels a frame): its gathered hex streams after it as a river
	// her moves
	reach_max: 4000,      // how far from her the hex can reach (4000 = the whole screen)
	grab_r: 80,           // how close the river's head must be to something's edge to claim it (was 64)
	claim_hold: 1.5,      // a claim lets go if the head pulls further than this x grab_r away before it lifts
	hold_follow: 0.25,    // how quickly a held thing follows the cursor (0..1; was 0.85: it snapped)
	hold_speed: 14,       // the fastest a held thing can move (pixels a frame): it has weight (heavier rocks: this / weight)
	throw_mult: 1.6,      // a throw flings it at this x the speed it had in her hold
	throw_max: 22,        // ...but never faster than this (pixels a frame)
	reach_cap: 6,         // (the knot's look: how much hex makes it read as fully gathered; the flow itself is no longer capped)
	cost_lift: 8,         // hex it takes to lift an environment object, per unit of its weight (a rock is 1)
	cost_enemy: 14,       // hex it takes to lift an enemy
	ball_dist: 30,        // how far in front of her hand the charging orb gathers
	charge_cap: 24,       // the most hex one charged orb can hold
	charge_rate: 0.5,     // hex added to a charging orb per frame (0.5 = full in about 0.8s)
	charge_min: 6,        // an orb needs at least this much to fire (less melts back: a quick tap of left click is no shot)
	boom_dmg: 10,         // damage per unit of hex in the charged orb (plus a base of 10)
	boom_r: 5,            // blast radius per unit of hex (plus a base of 40)
	blast_cost: 4,        // a tap of Space: a quick palm blast
	blast_dmg: 10,
	blast_cd: 30,         // frames before she can palm blast again (30 = half a second)
	tap_frames: 10        // a press of Space this short (frames) is a tap: a palm blast, not a stance
});
hex_move_init(hex, x, y);   // her move state (scr_hex_moves): stance, what she's holding, the knot, the orb...
// (her stance is the "stance" action in scr_input: Space. Hold for her hex stance, tap for a palm blast)
cam_hex_settle = 0;   // frames left that the camera stays settled on her for the hex
cam_hex_linger = 30;  // how long the camera stays settled after a hold of E ends
hex_bonus = 0;        // extra max hex (debug: press H in a run for +8)

