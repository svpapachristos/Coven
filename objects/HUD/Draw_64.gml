scr_prof_capture();   // the capture key (C): watched here, since HUD always exists (before any exit below)
//hide the hude while game is paused (can remove if thats how we feel
var _controller = instance_find(obj_game_controller, 0);
// sitting in her universe with the HUD hidden (H): nothing but the sky
if (global.game_state == "GAZE" && variable_global_exists("hex_hide_hud") && global.hex_hide_hud) exit;
// the end of the universe: nothing is left, not even the HUD
if (variable_global_exists("hex_aeon") && global.hex_aeon.phase == "void") exit;

if (global.game_state == "MENU" 
	|| global.game_state == "HUB" 
	|| global.game_state == "STATION"
	|| (global.game_state == "PAUSED"
		&& _controller != noone
		&& _controller.pause_return == "HUB")) {
	exit;
}

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
draw_set_font(-1);

//Act 1 Boss HP Bar
if (instance_exists(obj_boss_act1)) {
	var _b = instance_find(obj_boss_act1, 0);
	var _bw = _gw * 0.5;
	scr_draw_bar((_gw - _bw) / 2, _gh - 70, _bw, 16, _b.hp / _b.max_hp, c_red);
	draw_set_halign(fa_center);
	draw_text(_gw / 2, _gh - 94, _b.boss_name);
	draw_set_halign(fa_left);
}

var _bw = _gw * 0.4;
scr_draw_bar((_gw - _bw) / 2, 12, _bw, 10, global.souls / global.souls_to_next, make_color_rgb(150, 230, 255));
draw_set_halign(fa_center);
draw_text(_gw / 2, 26, "Lvl " + string(global.level));
draw_set_halign(fa_left);

//HP/Mana Bars, Top left for now

if (instance_exists(obj_player)) {
	var _p = obj_player;
	scr_draw_bar(16, 16, 200, 16, _p.hp / _p.max_hp, c_red,
		string(ceil(_p.hp)) + " / " + string(_p.max_hp));
	var _inf = (scr_stat("infinite_mana", 0) > 0);
	var _mana_col = _inf ? merge_color(c_navy, c_fuchsia, 0.5 + 0.5 * sin(current_time / 300)) : c_aqua;
	scr_draw_bar(16, 40, 200, 10, _inf ? 1 : _p.mana / _p.max_mana, _mana_col,
		_inf ? "" : string(floor(_p.mana)) + " / " + string(_p.max_mana));
if (_inf) scr_draw_infinity(236, 45, 10, _mana_col);

if (!is_undefined(_p.witch)) {
	var _cd_max = max(1, game_get_speed(gamespeed_fps) * scr_stat("ability_cooldown", _p.witch.ability.cooldown));
	scr_draw_bar(16, 60, 200, 8, 1 - _p.ability_cd / _cd_max, c_lime,
		_p.witch.ability.name + ((_p.ability_cd <= 0) ? " [E]" : ""));

	var _ready = (_p.ultimate_charge >= _p.ultimate_charge_max);
	var _ult_col = _ready ? merge_color(c_fuchsia, c_white, 0.5 + 0.5 * sin(current_time / 120)) : c_purple;
	scr_draw_bar(16, 80, 200, 8, _p.ultimate_charge / _p.ultimate_charge_max, _ult_col,
		_p.witch.ultimate.name + (_ready ? " [Q]" : ""));
	}
	
	var _cs = scr_corruption_stage();
	scr_draw_bar(16, 104, 200, 8, global.corruption / CORRUPTION_MAX,
	merge_color(make_color_rgb(200, 180, 255), make_color_rgb(180, 30, 120), global.corruption / CORRUPTION_MAX),
	scr_corruption_stage_name(_cs));
	
}


//Run info, Top Right for now
var _t = floor(global.run_time);
var _time = string(_t div 60) + ":" + ((_t mod 60 < 10) ? "0" : "") + string(_t mod 60);
draw_set_halign(fa_right);
draw_text(_gw - 16, 16, _time);
draw_text(_gw - 16, 34, "Kills: " + string(global.kill_count));
draw_set_halign(fa_left);

// (item pickup toasts are drawn by obj_game_controller's Draw GUI now, in every screen: edit52)



//ITEMMSS, Bottom left for now, will eventually display as sprites instead of text
var _counts = global.item_counts;
var _ids = variable_struct_get_names(_counts);
for (var i = 0; i < array_length(_ids); i++) {
	var _it = global.item_db[$ _ids[i]];
	draw_set_color(scr_rarity_color(_it.rarity));
	draw_text(16, _gh - 24 - i * 16,
		_it.name + ((_counts[$ _ids[i]] > 1) ? " x" + string(_counts[$ _ids[i]]) : ""));
}
draw_set_color(c_white);






//debug (f1)
if (global.debug_hud) {
	draw_text(16, 200, "Enemies Alive: " + string(instance_number(obj_enemy_parent)));
	// the FPS counter is an average, so it hides hitches. the worst single frame in the last second shows them:
	// 16.7ms is a smooth 60; anything well above that is a stutter you can feel even when FPS still says 60
	if (!variable_global_exists("ft_worst")) { global.ft_worst = 0; global.ft_shown = 0; global.ft_tick = 0; }
	global.ft_worst = max(global.ft_worst, delta_time / 1000);
	if (++global.ft_tick >= 60) { global.ft_shown = global.ft_worst; global.ft_worst = 0; global.ft_tick = 0; }
	draw_text(16, 217, "FPS: " + string(fps) + "   (could run " + string(floor(fps_real)) + ")   worst frame " + string_format(global.ft_shown, 1, 1) + "ms");
	draw_text(16, 234, "Target: " + string(floor(scr_director_target(global.run_time))) + " Alive: " + string(instance_number(obj_enemy_parent)));
	if (instance_exists(obj_player)) draw_text(16, 183, "iframes: " + string(obj_player.iframes));
	// the fluid's books: how much gas it holds, how much the game's ledger says there should be, and how fast it's being thinned to match
	if (variable_global_exists("hex_fluid") && variable_struct_exists(global.hex_fluid, "F")) {
		var _hf = global.hex_fluid;
		// the MASS BUDGET: gas -> stars -> gas. gas in the fluid, what's in star clusters now, what they've handed back, and the sum
		// (the sum only drops where gas leaves the edge of her sky or falls into a black hole). 1 unit = HEX_SIGMA_UNIT x 480 pc squared
		var _sfg = variable_struct_exists(_hf, "sf_gas") ? _hf.sf_gas : 0, _sfn = variable_struct_exists(_hf, "sf_n") ? _hf.sf_n : 0;
		var _rtg = variable_struct_exists(_hf, "ret_gas") ? _hf.ret_gas : 0, _bhg = variable_struct_exists(_hf, "bh_gas") ? _hf.bh_gas : 0;
		draw_text(16, 251, "Gas " + string_format(_hf.F, 1, 1) + "   in clusters " + string_format(_sfg - _rtg, 1, 1) + " (" + string(_sfn) + " formed)"
			+ "   returned " + string_format(_rtg, 1, 1) + "   swallowed by holes " + string_format(_bhg, 1, 1)
			+ "   total " + string_format(_hf.F + _sfg - _rtg + _bhg, 1, 1)
			+ "   (1 = " + string_format(HEX_SIGMA_UNIT * HEX_SAMPLE_PC * HEX_SAMPLE_PC / 1000000, 1, 1) + " million suns)"
			+ (variable_struct_exists(_hf, "myr") ? "   age " + string(floor(_hf.myr)) + " Myr, " + string(_hf.fbn) + " bubbles" : "")
			+ (variable_struct_exists(_hf, "rgas") ? "   gas radius " + string_format(_hf.rgas, 1, 2) + " kpc" : "")
			+ (variable_struct_exists(_hf, "rstar") ? ", clusters " + string_format(_hf.rstar, 1, 2) + " kpc" : "")
			+ ((variable_global_exists("hex_fluid_hide") && global.hex_fluid_hide) ? "   [fluid HIDDEN: L]" : "   (L hides it)"));
		// the heart: the supermassive black hole's mass and how hard it's feeding (share of its Eddington limit), quasar above 10^45 erg/s
		var _hsm = scr_hex_find_smbh();
		if (!is_undefined(_hsm) && variable_struct_exists(_hsm, "mdsm"))
			draw_text(16, 269, "Heart " + string_format(scr_hex_pop_msun(_hsm.m) / 1000000, 1, 2) + " million suns   feeding " + string_format(_hsm.mdot, 1, 0)
				+ " suns/Myr (" + string_format(100 * _hsm.edd, 1, 1) + "% of Eddington)   " + ((_hsm.mdsm >= HEX_QSO_MDOT) ? "QUASAR" : "quasar at " + string(HEX_QSO_MDOT)));
		// the universe: its age against its Friedmann lifetime (set by all its matter), and its baryons (in her sky + the reservoir)
		if (variable_global_exists("hex_cosmo") && variable_struct_exists(_hf, "myr")) {
			var _hcs = global.hex_cosmo;
			draw_text(16, 287, "Universe " + string(floor(_hf.myr)) + " / " + string(floor(_hcs.T)) + " Myr (crunch in " + string_format(max(0, _hcs.T - HEX_CRUNCH_MYR - _hf.myr) / 60, 1, 1)
				+ " min at full speed)   matter " + string_format(_hcs.B, 1, 0) + " (reservoir " + string_format(_hcs.R, 1, 0) + ")   star formation " + string_format(_hcs.sfr, 1, 2) + "/Myr");
		}
	}
}

scr_prof_draw();   // the capture key's table (hold C during the Unmaking, let go to see where the time went)

// sitting in her universe (G): a small readout of what age it's in and how full it is (hidden with H, above)
if (global.game_state == "GAZE" && instance_exists(obj_unmaking)) {
	// what a debug key just did (scr_hex_toast), for a few seconds above the readout
	if (variable_global_exists("hex_toast") && is_struct(global.hex_toast) && global.hex_toast.t > 0) {
		global.hex_toast.t--;
		draw_set_halign(fa_center); draw_set_valign(fa_bottom);
		draw_set_alpha(min(1, global.hex_toast.t / 30)); draw_set_color(make_color_rgb(190, 230, 220));
		draw_text(display_get_gui_width() / 2, display_get_gui_height() - 70, global.hex_toast.txt);
		draw_set_alpha(1); draw_set_halign(fa_left); draw_set_valign(fa_top);
	}
	if (variable_global_exists("hex_inspect") && global.hex_inspect) scr_hex_inspect_draw();   // I: name everything in her sky
	// each age of her universe announces itself: a title card fades in at the top when the age changes
	if (!variable_global_exists("hex_card_ph")) { global.hex_card_ph = ""; global.hex_card_t = 999; }
	var _aph = variable_global_exists("hex_aeon") ? global.hex_aeon.phase : "dawn";
	if (_aph != global.hex_card_ph) { global.hex_card_ph = _aph; global.hex_card_t = 0; }
	global.hex_card_t++;
	var _ct = global.hex_card_t;
	var _cfp = game_get_speed(gamespeed_fps), _cts = _ct / _cfp;
	if (_cts < 4.5 && _aph != "void") {
		var _cnames = { dawn: ["DAWN", "the first stars kindle"], galaxy: ["THE GALAXY", "the garden turns around its heart"],
			quasar: ["QUASAR", "the heart ignites"], twilight: ["TWILIGHT", "the long dimming"], crunch: ["THE CRUNCH", "all things return"] };
		var _cn = _cnames[$ _aph];
		if (!is_undefined(_cn)) {
			var _ca = min(1, _cts / 0.6) * min(1, (4.5 - _cts) / 1.2);
			var _cgw = display_get_gui_width(), _cy0 = display_get_gui_height() * 0.14;
			var _ctl = "";                                                     // letter-spaced, like an engraving
			for (var i = 1; i <= string_length(_cn[0]); i++) _ctl += string_char_at(_cn[0], i) + ((i < string_length(_cn[0])) ? " " : "");
			draw_set_halign(fa_center); draw_set_valign(fa_middle);
			draw_set_color(make_color_rgb(170, 90, 255)); draw_set_alpha(0.35 * _ca);
			for (var _o = 0; _o < 4; _o++) draw_text_transformed(_cgw / 2 + lengthdir_x(2, _o * 90), _cy0 + lengthdir_y(2, _o * 90), _ctl, 2.4, 2.4, 0);
			draw_set_color(make_color_rgb(240, 228, 255)); draw_set_alpha(_ca);
			draw_text_transformed(_cgw / 2, _cy0, _ctl, 2.4, 2.4, 0);
			draw_set_color(make_color_rgb(200, 180, 240)); draw_set_alpha(0.8 * _ca);
			draw_text(_cgw / 2, _cy0 + 30, "aeon " + string(variable_global_exists("hex_aeon") ? global.hex_aeon.n : 0) + "  ·  " + _cn[1]);
			draw_set_alpha(1); draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_color(c_white);
		}
	}
	var _rgw = display_get_gui_width(), _rgh = display_get_gui_height();
	var _rae = variable_global_exists("hex_aeon") ? global.hex_aeon : { phase: "dawn", n: 0, t: 0 };
	var _rsm = scr_hex_find_smbh();
	var _rml = (!is_undefined(_rsm) && variable_struct_exists(_rsm, "edd")) ? string_format(100 * _rsm.edd, 1, 1) + "% Eddington" : "-";
	var _rnf = variable_global_exists("hex_flow") ? array_length(global.hex_flow) : 0;
	var _rtx = ((variable_global_exists("hex_no_ripple") && global.hex_no_ripple) ? "[ripples OFF]   " : "")
	         + ((variable_global_exists("hex_flow_on") && !global.hex_flow_on) ? "[currents OFF]   " : "") + (scr_hex_fluid_ok() ? "[fluid " + scr_hex_fluid_tier()[3] + "]   " + (scr_hex_iso() ? "[PHYSICS ONLY]   " : "[+ legacy]   ") + "[" + string(HEX_MYR_PER_S * scr_hex_time()) + " Myr/s]   " : ((global.hex_fluid_why != "") ? "[fluid OFF: " + global.hex_fluid_why + "]   " : "")) + "aeon " + string(_rae.n) + ": " + _rae.phase + " " + string(floor(_rae.t / game_get_speed(gamespeed_fps))) + "s   |   holes " + string(array_length(global.hex_holes))
	         + "   |   gas " + string(array_length(global.hex_haze)) + " (" + string(_rnf) + " flying)   |   heart " + _rml
	         + "\nV giant  B gas cloud  X young cluster  N +1 min  M rush holes  K next age  I inspect  R ripples  J currents  Y fluid quality  L hide fluid  O physics only  T speed  H hide HUD  P pause  G leave";
	draw_set_halign(fa_right); draw_set_valign(fa_bottom);
	draw_set_alpha(0.75);
	draw_set_color(make_color_rgb(220, 205, 255));
	draw_text(_rgw - 16, _rgh - 12, _rtx);
	draw_set_alpha(1);
	draw_set_halign(fa_left); draw_set_valign(fa_top);
}
