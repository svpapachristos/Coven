if (scr_freeze_if_paused()) exit;
if (clean_pending) exit; // the clean frame: draw nothing, so the bare world can be photographed (see Draw GUI Begin)

// hitstop: the impact frame freezes ALL of time for a few frames, then the shockwave lands
if (hitstop > 0) {
	hitstop--;
	if (hitstop == 0) global.shake = max(global.shake, (impact_kind == 1) ? 48 : 24);   // the shockwave lands as time resumes
	exit;
}
t++;
if (t == shatter_at) { hitstop = 10; impact_kind = 1; }   // the ground's impact frame: time freezes, then BOOM

// her black holes keep time. while one is gathering, time itself drags: the sky's turning slows to a stop
var _slow = 1;
for (var h = 0; h < array_length(global.hex_holes); h++) {
	var _ho = global.hex_holes[h];
	_ho.age++;
	if (_ho.age == HEX_GATHER) { hitstop = 10; impact_kind = 0; }
	if (_ho.age == HEX_GATHER) hitstop = 10;
}
time_scale = lerp(time_scale, _slow, 0.15); // ease into and out of the slowdown instead of snapping
sky_angle += spin * time_scale / game_get_speed(gamespeed_fps);
// the finale: once every star is lit, one great pulse
if (!pulsed && t >= finale_at) {
	pulsed = true;
	pulse_t = 0;
	global.shake = max(global.shake, 10);
}
if (pulse_t >= 0) pulse_t++;
if (pulse_t >= 0) scr_hex_accrete(new_from); // after the finale, the newborn stars settle into each other
if (t >= duration) {
	if (instance_exists(obj_player)) scr_hex_return(obj_player.x, obj_player.y);
	instance_destroy();
}
if (t == 1) global.shake = max(global.shake, 5);	//time locks
if (t >= glitch_at && t < still_at) global.shake = max(global.shake, 3); //reality glitches
if (t >= tear_at && t < tear_at + tear_len) global.shake = max(global.shake, 4);   // the ground rumbles as it splits
if (t >= still_at && t < tear_at) global.shake = 0;	 //total stillness:
if (t >= tear_at + tear_len && t < shatter_at) global.shake = max(global.shake, 1 + 4 * sqr((t - tear_at - tear_len) / gape_len)); // pressure building