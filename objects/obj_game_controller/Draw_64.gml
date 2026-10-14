if (global.game_state == "MENU") {
	scr_draw_title_backdrop(); // placeholder title screen: her, casting, in the dark (scr_menu)
	scr_draw_menu("COVEN", menu_options, menu_index);
}
if (global.game_state == "STATION") {
	var _titles = ["Choose Your Witch", "Choose Your Wand", "Choose Your Familiar"];
	var _opts = scr_select_options(station_step);
	scr_draw_menu(_titles[station_step], _opts, station_index);
	
	var _db = scr_select_db(station_step);
	var _cx = display_get_gui_width() / 2;
	var _y = display_get_gui_height() / 2 + array_length(_opts) * 28 + 24;
	draw_set_halign(fa_center);
	draw_set_color(c_ltgray);
	draw_text(_cx, _y, _db[station_index].desc);
	draw_set_color(c_dkgray);
	draw_text(_cx, _y + 28, "Esc / Right Click to go Back");
	draw_set_color(make_color_rgb(200, 150, 255));
	draw_text(_cx, _y + 56, "Essence: " + string(global.save.essence));
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

if (global.game_state == "PAUSED") {
	draw_set_alpha(0.55);
	draw_set_color(c_black);
	draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
	draw_set_alpha(1);
	draw_set_color(c_white);
	scr_draw_menu("PAUSED", pause_options, pause_index);
}

if (global.game_state == "LEVELUP") {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_alpha(0.65);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_gw / 2, _gh * 0.12, "LEVEL " + string(global.level), 3, 2, 0);
	
	var _n = array_length(levelup_choices);
	for (var i = 0; i < _n; i++) {
		var _r = scr_card_rect(i, _n);
		var _it = global.item_db[$ levelup_choices[i]];
		var _col = scr_rarity_color(_it.rarity);
		var _sel = (i == levelup_index);
		var _cx = (_r.x1 + _r.x2) / 2;
		
		draw_set_color(c_black);
		draw_set_alpha(0.85);
		draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, false);
		draw_set_alpha(1);
		draw_set_color(_sel ? c_white : _col);
		draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, true);
		if (_sel) draw_rectangle(_r.x1 + 2, _r.y1 + 2, _r.x2 - 2, _r.y2 - 2, true);
		
		draw_set_color(_col);
		draw_text_transformed(_cx, _r.y1 + 30, _it.name, 2, 2, 0);
		draw_set_color(c_gray);
		draw_text(_cx, _r.y1 + 70, string_upper(_it.rarity));
		draw_set_color(c_white);
		draw_text_ext(_cx, _r.y1 + 120, _it.desc, 22, _r.x2 - _r.x1 - 40);
		draw_set_color(c_dkgray);
		draw_text(_cx, _r.y2 - 30, "[" + string(i + 1) + "]");
	}
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}
// THE RUN SUMMARY (edit49, first pass): one ending screen for a death and a victory. the stats count up one after another,
// her Path is named with a line of its own, and what she carried is listed beside them. the menu stays where it was (its click
// targets are measured from the screen's middle), so everything here sits above it
if (global.game_state == "DEAD" || global.game_state == "VICTORY") {
	var _won = (global.game_state == "VICTORY");
	if (!variable_instance_exists(id, "sum_ph") || sum_ph != global.game_state) { sum_ph = global.game_state; sum_t = 0; }
	sum_t++;
	var _gw = display_get_gui_width(), _gh = display_get_gui_height(), _cx = _gw / 2;
	var _in = min(1, sum_t / 20);                                              // the screen fades in
	draw_set_alpha(0.82 * _in);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_alpha(_in);

	// her Path, from her Corruption
	var _cor  = variable_global_exists("corruption") ? global.corruption : 0;
	var _path = (_cor < 25) ? "RADIANT" : ((_cor < 75) ? "WAVERING" : "CONSUMED");
	var _pcol = (_cor < 25) ? make_color_rgb(255, 235, 150) : ((_cor < 75) ? c_white : make_color_rgb(200, 70, 160));
	var _line;
	if (_won) _line = (_cor < 25) ? "Her light held. The dark took nothing from her." : ((_cor < 75) ? "She bent, but she did not break." : "The power answered. Something else answered with it.");
	else if (variable_global_exists("run_abandoned") && global.run_abandoned) _line = "She walked away. The coven will wait for her.";
	else      _line = (_cor < 25) ? "She fell clean. The coven will remember her light." : ((_cor < 75) ? "She fell somewhere between the light and the dark." : "She fell, and what she bargained with walked on.");

	var _y = _gh * 0.09;
	draw_set_halign(fa_center);
	draw_set_color(_won ? make_color_rgb(255, 235, 150) : c_white);
	draw_text_transformed(_cx, _y, _won ? "ACT COMPLETE" : ((variable_global_exists("run_abandoned") && global.run_abandoned) ? "RUN ABANDONED" : ((variable_global_exists("endless") && global.endless) ? "THE HUNT ENDS" : "RUN OVER")), 3, 3, 0);
	draw_set_color(make_color_rgb(190, 170, 220));
	draw_text(_cx, _y + 58, _line);

	// the stats: each counts up in turn
	var _tt = floor(global.run_time), _ts = string(_tt div 60) + ":" + ((_tt mod 60 < 10) ? "0" : "") + string(_tt mod 60);
	if (_tt >= 3600) _ts = string(_tt div 3600) + ":" + (((_tt mod 3600) div 60 < 10) ? "0" : "") + string((_tt mod 3600) div 60) + ":" + ((_tt mod 60 < 10) ? "0" : "") + string(_tt mod 60);
	var _unm = variable_global_exists("hex_unmade") ? global.hex_unmade : 0;
	var _rows = [
		["Time", -1, _ts, c_white],
		["Endless", -1, (variable_global_exists("endless") && global.endless) ? string(floor(global.run_time - global.endless_t0) div 60) + ":" + ((floor(global.run_time - global.endless_t0) mod 60 < 10) ? "0" : "") + string(floor(global.run_time - global.endless_t0) mod 60) : "-", make_color_rgb(255, 140, 120)],
		["Level", global.level, "", c_white],
		["Enemies felled", global.kill_count, "", c_white],
		["Unmade", _unm, "", make_color_rgb(190, 150, 255)],
		["Corruption", round(_cor), "%", _pcol],
		["Essence earned", global.run_total, "", make_color_rgb(200, 150, 255)]
	];
	var _ry = _y + 92;
	for (var i = 0; i < array_length(_rows); i++) {
		var _rw = _rows[i];
		var _k = clamp((sum_t - 15 - i * 9) / 30, 0, 1);                       // this row's count-up
		if (_k <= 0) continue;
		var _ke = 1 - power(1 - _k, 3);
		draw_set_alpha(_in * min(1, _k * 3));
		draw_set_halign(fa_right);
		draw_set_color(c_gray);
		draw_text(_cx - 12, _ry + i * 22, _rw[0]);
		draw_set_halign(fa_left);
		draw_set_color(_rw[3]);
		draw_text(_cx + 12, _ry + i * 22, (_rw[1] < 0) ? _rw[2] : string(round(_rw[1] * _ke)) + _rw[2]);
	}
	// her Path, named once the numbers land
	var _pk = clamp((sum_t - 15 - array_length(_rows) * 9 - 20) / 20, 0, 1);
	if (_pk > 0) {
		draw_set_alpha(_in * _pk);
		draw_set_halign(fa_center);
		draw_set_color(_pcol);
		var _ps = 1.6 + 0.4 * (1 - _pk);                                       // it settles into place
		draw_text_transformed(_cx, _ry + array_length(_rows) * 22 + 12, "PATH: " + _path, _ps, _ps, 0);
	}
	{
		draw_set_halign(fa_center);
		draw_set_color(c_dkgray);
		draw_set_alpha(_in * clamp((sum_t - 15) / 30, 0, 1));
		draw_text(_cx, _ry + array_length(_rows) * 22 + 44, "Essence total  " + string(global.save.essence));
	}

	// what she carried, beside the stats
	var _counts = global.item_counts, _ids = variable_struct_get_names(_counts);
	var _ix = _cx + _gw * 0.22, _iy = _y + 92;
	if (array_length(_ids) > 0) {
		draw_set_halign(fa_left);
		draw_set_alpha(_in);
		draw_set_color(c_gray);
		draw_text(_ix, _iy - 26, "Carried");
		for (var i = 0; i < min(array_length(_ids), 14); i++) {
			var _ik = clamp((sum_t - 20 - i * 3) / 15, 0, 1);
			if (_ik <= 0) continue;
			var _it = global.item_db[$ _ids[i]];
			draw_set_alpha(_in * _ik);
			draw_set_color(scr_rarity_color(_it.rarity));
			draw_text(_ix, _iy + i * 18, _it.name + ((_counts[$ _ids[i]] > 1) ? " x" + string(_counts[$ _ids[i]]) : ""));
		}
		if (array_length(_ids) > 14) { draw_set_color(c_gray); draw_text(_ix, _iy + 14 * 18, "+" + string(array_length(_ids) - 14) + " more"); }
	}
	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_halign(fa_left);
	if (_won) scr_draw_menu("", victory_options, victory_index);
	else      scr_draw_menu("", end_options, end_index);
}

if (quit_confirm) {
	var _gui_w = display_get_gui_width();
	var _gui_h = display_get_gui_height();
	var _cx = _gui_w / 2;
	var _cy = _gui_h / 2;
	
	//Dim the game and menu behind the dialog.
	draw_set_alpha(0.7);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gui_w, _gui_h, false);
	draw_set_alpha(1);
	
	//Draw the confirmation panel
	draw_set_color(c_dkgray);
	draw_rectangle(_cx - 230, _cy - 125, _cx + 230, + _cy + 125, false);
	draw_set_color(c_white);
	draw_rectangle(_cx - 230, _cy - 125, _cx + 230, + _cy + 125, true);
	
	// Reuse the existing menu drawing and click targets
	scr_draw_menu( 
		"ARE YOU SURE?",
		quit_confirm_options,
		quit_confirm_index,
		_cy + 5
	);
}


// THE HIDEOUT'S PURSE (edit51): essence and reagents as tickers, top left. a dark see-through box with a border in the currency's
// own color, its symbol, and the number right beside it. (they belong to the hideout: a run never needs to show them)
if (global.game_state == "HUB") {
	var _rows2 = [[make_color_rgb(30, 235, 184), global.save.essence, 0], [make_color_rgb(150, 230, 110), global.reagents, 1]];
	var _bh = 30, _bx = 16;
	for (var i = 0; i < 2; i++) {
		var _y2 = 16 + i * (_bh + 6), _col = _rows2[i][0], _str = string(_rows2[i][1]);
		var _bw = max(70, 40 + string_width(_str) + 12);
		draw_set_alpha(0.55);
		draw_set_color(c_black);
		draw_rectangle(_bx, _y2, _bx + _bw, _y2 + _bh, false);              // the see-through fill
		draw_set_alpha(1);
		draw_set_color(_col);
		draw_rectangle(_bx, _y2, _bx + _bw, _y2 + _bh, true);               // the border
		if (_rows2[i][2] == 0) draw_sprite_ext(spr_essence, 0, _bx - 10, _y2 - 9, 0.85, 0.85, 0, c_white, 1);   // (its symbol sits at 17..42, 19..47 of a 64px frame)
		else {                                                               // reagents have no sprite yet: a little flask, drawn in code
			var _fx = _bx + 15, _fy = _y2 + 18;
			draw_circle_color(_fx, _fy, 6, _col, merge_color(_col, c_black, 0.4), false);
			draw_rectangle(_fx - 2, _fy - 12, _fx + 2, _fy - 5, false);
			draw_set_color(c_white); draw_set_alpha(0.6); draw_circle(_fx - 2, _fy - 2, 1.5, false); draw_set_alpha(1);
		}
		draw_set_color(_col);
		draw_text(_bx + 36, _y2 + 7, _str);                                  // the number, right beside its symbol
	}
	draw_set_color(c_white);
}

if (global.game_state == "SPREAD") {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_alpha(0.7);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_gw / 2, _gh * 0.1, (spread_mode == "reading") ? "THE READING" : "THE CAULDRON", 3, 3, 0);
	draw_text(_gw / 2, _gh * 0.1 + 60, (spread_mode == "reading")
		? "Click a card to turn it. Reversed: stronger, but it costs Corruption.  R to redraw, Esc to close."
		: "Click a card to reroll it (1 reagent).  Reagents: " + string(global.reagents));

	var _n = array_length(global.spread);
	var _foot = ["Elite I - 4:00", "Elite II - 8:00", "Elite III - 11:00"];
	if (_n == 0) draw_text(_gw / 2, _gh / 2, "Draw a reading first.");
	for (var i = 0; i < _n; i++) {
		scr_draw_card(scr_card_rect(i, _n), scr_spread_card_id(i), i == spread_index,
			_foot[i] + (global.spread_rev[i] ? "  [REVERSED]" : ""));
	}
	draw_set_halign(fa_left);
}

if (global.game_state == "SLOTS") {
	scr_draw_slots_backdrop(); // placeholder save screen: Munin, the saves, and her casting (scr_menu)
	scr_draw_menu("Choose a Save", slot_labels, slot_index);
	var _cx = display_get_gui_width() / 2;
	var _y = display_get_gui_height() / 2 + array_length(slot_labels) * 28 + 24;
	draw_set_halign(fa_center);
	draw_set_color(make_color_rgb(150, 140, 175));   // readable on the dark screen
	draw_text(_cx, _y, "Enter to play   -   Delete twice to erase   -   Esc to go back");
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

if (global.game_state == "OPTIONS") {
	// its own screen, not a layer over the game: the same backdrop as the save slots
	scr_draw_slots_backdrop();
	draw_set_alpha(1);
	var _olabels = scr_options_labels();
	scr_draw_menu("Options", _olabels, options_index);
	var _cx = display_get_gui_width() / 2;
	var _y = display_get_gui_height() / 2 + array_length(_olabels) * 28 + 24;
	draw_set_halign(fa_center);
	draw_set_color(c_dkgray);
	draw_text(_cx, _y, "Left / Right to adjust   -   Esc to go back");
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

if (global.game_state == "DEBUG_ITEMS") {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	draw_set_alpha(0.75);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_alpha(1);

	var _cx = _gw / 2, _top = 60;
	draw_set_halign(fa_center);
	draw_set_color(c_yellow);
	draw_text(_cx, _top, "DEBUG: ADD ITEM");
	draw_set_color(c_white);
	draw_text(_cx, _top + 28, "Search: " + debug_filter + "_");

	var _dcount = array_length(debug_items);
	if (_dcount == 0) {
		draw_set_color(c_gray);
		draw_text(_cx, _top + 70, "No items match");
	} else {
		// show a window of rows that scrolls to keep the highlight in view
		var _rows = 14;
		var _start = clamp(debug_index - _rows div 2, 0, max(0, _dcount - _rows));
		var _tags = scr_loadout_tags();
		for (var i = _start; i < min(_dcount, _start + _rows); i++) {
			var _id = debug_items[i];
			var _it = global.item_db[$ _id];
			var _ry = _top + 64 + (i - _start) * 24;
			var _fits = scr_item_fits_loadout(_it, _tags);
			var _owned = struct_exists(global.item_counts, _id) ? global.item_counts[$ _id] : 0;
			var _label = _it.name + "   (" + _it.rarity + ")";
			if (_owned > 0) _label += "   x" + string(_owned);
			if (!_fits) _label += "   [not your loadout]";

			if (i == debug_index) {
				draw_set_alpha(0.25);
				draw_set_color(c_aqua);
				draw_rectangle(_cx - 260, _ry - 3, _cx + 260, _ry + 21, false);
			}
			draw_set_alpha(_fits ? 1 : 0.45);
			draw_set_color(scr_rarity_color(_it.rarity));
			draw_text(_cx, _ry, ((i == debug_index) ? "> " : "") + _label);
		}
		draw_set_alpha(1);

		// the highlighted item's description
		var _sel = global.item_db[$ debug_items[debug_index]];
		draw_set_color(c_ltgray);
		draw_text(_cx, _top + 64 + _rows * 24 + 12, _sel.desc);
	}

	draw_set_color(c_dkgray);
	draw_text(_cx, _gh - 40, "Type to search   -   Up / Down to choose   -   Enter to add   -   Esc to close");
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

// TOASTS (edit52): pickups, unlocks, settings. drawn last, on top of every screen and menu, so they stay up for their whole
// moment even if the menu that made them has already closed
if (variable_global_exists("toast") && !is_undefined(global.toast)) {
	var _ti = global.toast, _tgw = display_get_gui_width();
	draw_set_alpha(clamp(_ti.timer / 30, 0, 1));                                  // fades in its last half second
	draw_set_halign(fa_center);
	draw_set_color(_ti.color);
	draw_text_transformed(_tgw / 2, 60, _ti.text, 2, 2, 0);
	draw_set_color(c_ltgray);
	draw_text(_tgw / 2, 92, _ti.sub);
	draw_set_halign(fa_left);
	draw_set_color(c_white);
	draw_set_alpha(1);
}
