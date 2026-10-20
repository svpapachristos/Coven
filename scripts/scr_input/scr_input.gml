// scr_input: every player input goes through here. Gameplay code asks these functions what the player wants
// ("which way are they pushing?") and never reads a key directly, so a controller or touch controls (both long-term
// goals) plug in HERE, in one place, and nothing else has to change.
//
// Part 1 (Oct 19): movement. Still to move in: aiming (the mouse), and the buttons (hex stance, casting, E, Q).

#macro INPUT_DEADZONE 0.2   // pushes weaker than this count as standing still (for analog sticks; a key is always 0 or 1)

// which way the player is pushing to move, as [x, y]. Its length is how hard: 0 = not at all, 1 = a full push.
// A keyboard gives full pushes in 8 directions; an analog stick (later) gives any angle and partial pushes.
function input_move() {
	var _x = keyboard_check(ord("D")) - keyboard_check(ord("A"));
	var _y = keyboard_check(ord("S")) - keyboard_check(ord("W"));
	var _len = point_distance(0, 0, _x, _y);
	if (_len > 1) { _x /= _len; _y /= _len; }   // a diagonal is still one full push (not 1.41), so it's no faster
	return [_x, _y];
}

// is the player pushing to move at all?
function input_moving() {
	var _m = input_move();
	return point_distance(0, 0, _m[0], _m[1]) > INPUT_DEADZONE;
}
