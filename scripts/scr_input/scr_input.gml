// scr_input: every player input goes through here. Gameplay code asks these functions what the player WANTS ("is she
// holding her stance?", "which way is she pushing?", "where is she aiming?") and never reads a key, a mouse button or
// the mouse position directly. So a controller or touch controls (both long-term goals) plug in HERE, in one place,
// and no gameplay code has to change.
//
//   ACTIONS   input_check / input_pressed / input_released ("stance", "primary", ...): held, just pressed, just let go
//   MOVE      input_move / input_moving: which way she's pushing, as [x, y] of length 0..1
//   AIM       input_aim: the point in the room she's aiming at
//
// Not in here on purpose: debug keys (F1-F12, H, J, O/P/K/L, R, Insert) stay on the keyboard, they're dev tools.
// Still to move in (part 3): menu navigation (Escape, arrows, Enter, clicking menu items).

#macro INPUT_DEADZONE 0.2   // pushes weaker than this count as standing still (for analog sticks; a key is always 0 or 1)

// ---- THE BINDINGS: what each action is, and every input that triggers it ----
// Each action lists its bindings; any one of them counts. A controller adds { kind: "pad", code: gp_... } entries
// here later, and a rebinding menu edits this table. Nothing else needs to know which key is which.
// (This runs once when the game starts, before any room, so it's always ready.)
global.input_binds = {
	move_right: [ { kind: "key",   code: ord("D") } ],
	move_left:  [ { kind: "key",   code: ord("A") } ],
	move_up:    [ { kind: "key",   code: ord("W") } ],
	move_down:  [ { kind: "key",   code: ord("S") } ],
	primary:    [ { kind: "mouse", code: mb_left } ],    // wand primary fire; in her hex stance, charge an orb
	secondary:  [ { kind: "mouse", code: mb_right } ],   // wand alt fire; in her hex stance, reach out and lift
	stance:     [ { kind: "key",   code: vk_space } ],   // Hexweaver: hold for her hex stance, tap for a palm blast
	ability:    [ { kind: "key",   code: ord("E") } ],   // the witch's own ability
	ultimate:   [ { kind: "key",   code: ord("Q") } ],
	interact:   [ { kind: "key",   code: ord("F") } ]    // use a station in the hideout
};

// one binding's state. _how: 0 = held, 1 = just pressed, 2 = just let go
function input_bind_state(_b, _how) {
	switch (_b.kind) {
		case "key":   return (_how == 0) ? keyboard_check(_b.code) : ((_how == 1) ? keyboard_check_pressed(_b.code) : keyboard_check_released(_b.code));
		case "mouse": return (_how == 0) ? mouse_check_button(_b.code) : ((_how == 1) ? mouse_check_button_pressed(_b.code) : mouse_check_button_released(_b.code));
	}
	return false;
}
// is any binding of this action in that state?
function input_action(_act, _how) {
	var _list = global.input_binds[$ _act];
	if (is_undefined(_list)) { show_debug_message("scr_input: no action called \"" + string(_act) + "\""); return false; }
	for (var _i = 0; _i < array_length(_list); _i++) if (input_bind_state(_list[_i], _how)) return true;
	return false;
}
function input_check(_act)    { return input_action(_act, 0); }   // held down
function input_pressed(_act)  { return input_action(_act, 1); }   // pressed this frame
function input_released(_act) { return input_action(_act, 2); }   // let go this frame

// ---- MOVE ----
// which way the player is pushing to move, as [x, y]. Its length is how hard: 0 = not at all, 1 = a full push.
// A keyboard gives full pushes in 8 directions; an analog stick (later) gives any angle and partial pushes.
function input_move() {
	var _x = input_check("move_right") - input_check("move_left");
	var _y = input_check("move_down") - input_check("move_up");
	var _len = point_distance(0, 0, _x, _y);
	if (_len > 1) { _x /= _len; _y /= _len; }   // a diagonal is still one full push (not 1.41), so it's no faster
	return [_x, _y];
}
// is the player pushing to move at all?
function input_moving() {
	var _m = input_move();
	return point_distance(0, 0, _m[0], _m[1]) > INPUT_DEADZONE;
}

// ---- AIM ----
// the point in the room the player is aiming at, as [x, y]. The mouse now; with a controller (later) this becomes a
// point out from the witch along the right stick, and everything that aims (her wand, her hex, the camera) follows.
function input_aim() {
	return [mouse_x, mouse_y];
}
