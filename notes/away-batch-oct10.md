# Away batch (Oct 10, evening): ready-to-type extras outside the Unmaking

Written while Sophia went for dinner. Everything here is **separate from the Unmaking** (Phase 1.1 is still next for that), so you can do these in any order, between sessions, or whenever you want a break from the stars. Each one is self-contained: full code, the why, and exactly where it goes.

**Already done (no need to retype):** magic missiles skip frogs (on cast and on retarget), the beam passes over frogs, killing a hexed enemy turns it into a frog, and missiles have a 3s lifetime.

Suggested order: **1 → 2 → 3** (bugs, quick) → **4, 5** (gameplay, quick) → **6 → 7 → 8** (menus and the title screen, the big ones) → **9** (an entrance bonus).

---

## 1. Bug: toasts in the hideout never show and never fade
**What's wrong:** two things. (a) The HUD exits early in the HUB and STATION states, so "UNLOCKED" and "NOT ENOUGH ESSENCE" are never drawn in the hideout. (b) The toast timer only counts down in PLAYING, so a hideout toast would sit there forever. There's also a typo: the "NOT ENOUGH ESSENCE" toast uses `time:` instead of `timer:`.

**a) scr_menu: a shared toast drawer.** Paste at the bottom of `scr_menu`:
```gml
// the banner across the top (item pickups, unlocks, warnings). shared by the HUD and the hideout screens
function scr_draw_toast() {
	if (is_undefined(global.toast)) return;
	var _i  = global.toast;
	var _gw = display_get_gui_width();
	draw_set_alpha(clamp(_i.timer / 30, 0, 1)); // fades out over its last half second
	draw_set_halign(fa_center);
	draw_set_color(_i.color);
	draw_text_transformed(_gw / 2, 60, _i.text, 2, 2, 0);
	draw_set_color(c_ltgray);
	draw_text(_gw / 2, 92, _i.sub);
	draw_set_halign(fa_left);
	draw_set_color(c_white);
	draw_set_alpha(1);
}
```

**b) HUD → Draw GUI.** Replace the whole `// Item Pickup` block (the `if (!is_undefined(global.toast)) { ... }`) with:
```gml
// Item Pickup
scr_draw_toast();
```

**c) obj_game_controller → Draw GUI.** At the very bottom of the `if (global.game_state == "STATION") { ... }` block (just before its closing `}`), add:
```gml
	scr_draw_toast();   // unlocks and "not enough essence" show here too
```
And change the HUB block to:
```gml
if (global.game_state == "HUB") {
	draw_text(16, 16, "Reagents: " + string(global.reagents));
	scr_draw_toast();
}
```

**d) obj_game_controller → Step.** In the `case "PLAYING":` block, **delete** these four lines:
```gml
		if (!is_undefined(global.toast)) {
			global.toast.timer--;
			if (global.toast.timer <= 0) global.toast = undefined;
		}
```
Then paste this right **above** `switch (global.game_state) {`:
```gml
// toasts count down wherever they can be seen: in a run, in the hideout and at the stations (not while paused or picking a level-up)
if (!is_undefined(global.toast) && (global.game_state == "PLAYING" || global.game_state == "HUB" || global.game_state == "STATION")) {
	global.toast.timer--;
	if (global.toast.timer <= 0) global.toast = undefined;
}
```

**e) The typo.** In `case "STATION":`, in the NOT ENOUGH ESSENCE toast, change `time: game_get_speed(gamespeed_fps) * 2` to `timer: game_get_speed(gamespeed_fps) * 2`.

---

## 2. Cleanup: the doubled hitstop in the Unmaking
**obj_unmaking → Step**, in the black hole loop, delete the second of these two lines (the first already does it):
```gml
	if (_ho.age == HEX_GATHER) { hitstop = 10; impact_kind = 0; }
	if (_ho.age == HEX_GATHER) hitstop = 10;      // <- delete this one
```

## 3. Cleanup: a stale comment
**obj_game_controller → Create:** the debug holes comment says F9, but the key is F10 (F9 is boss down). Change it to:
```gml
global.hex_debug_holes = false; // F10: collapse at a tiny mass and any tier, for testing
```

---

## 4. Gameplay: a little more room between frogs
A fully hexed horde stacks up. Frogs are harmless, so just a touch more separation. **obj_toad → Create**, right under `event_inherited();`:
```gml
sep_radius   = 56;    // a touch more room than other enemies (44), so a fully hexed horde doesn't pile into one heap
sep_strength = 0.55;
```

## 5. Gameplay: Danse Macabre gets pricier as she levels
So the Necromancer's ult can't be spammed late in a run. This is built so any witch can opt in later.

**a) scr_loadout_init**, in the witch list, add `charge_per_level: 5` to the Necromancer's ultimate:
```gml
ultimate: { name: "Danse Macabre", charge_needed: 100, charge_per_level: 5, fn: scr_necro_danse } },
```

**b) scr_loadout_init**, paste this new function anywhere at the top level of the script (for example, right above `function scr_apply_loadout()`):
```gml
// what an ultimate costs right now. some ultimates get pricier as she levels (charge_per_level), so they can't be spammed late in a run
function scr_ult_cost(_witch) {
	var _u   = _witch.ultimate;
	var _per = struct_exists(_u, "charge_per_level") ? _u.charge_per_level : 0;
	return _u.charge_needed + _per * (global.level - 1);
}
```

**c) scr_loadout_init → `scr_apply_loadout`:** change `ultimate_charge_max = witch.ultimate.charge_needed;` to:
```gml
		ultimate_charge_max = scr_ult_cost(witch);
```

**d) obj_player → Step:** right **above** `if (keyboard_check_pressed(ord("Q")) && ultimate_charge >= ultimate_charge_max) {`, add:
```gml
	ultimate_charge_max = scr_ult_cost(witch);   // can grow with her level, and the HUD bar follows it
```
At level 1 it's 100 kills. At level 20 it's 195. Tune the 5 to taste.

---

## 6. Menus: a Coven look for every menu
Every menu (title, pause, slots, options, run over, victory, quit) goes through `scr_draw_menu`, so restyling it upgrades them all at once:
- a violet theme,
- a highlight that **slides** to the chosen row,
- a soft glow behind the title,
- small diamonds either side of the choice instead of `> `,
- rows a little wider, so the options sliders (item 7) fit.

**scr_menu:** replace `scr_menu_row` with:
```gml
// Clickable area for menu row i (shared by drawing and clicking, so they always line up)
function scr_menu_row(_i, _y0 = display_get_gui_height() / 2) {
	var _cx = display_get_gui_width() / 2;
	return { x1: _cx - 200, y1: _y0 + _i * 28 - 4, x2: _cx + 200, y2: _y0 + _i * 28 + 24 };
}
```

Then replace the whole `scr_draw_menu` function with:
```gml
function scr_draw_menu(_title, _options, _index, _y0 = display_get_gui_height() / 2) {
	static _anim = {};                                    // each menu's sliding highlight, remembered between frames
	var _cx     = display_get_gui_width() / 2;
	var _violet = make_color_rgb(170, 90, 255);
	var _lit    = make_color_rgb(230, 210, 255);
	draw_set_halign(fa_center);
	draw_set_valign(fa_top);

	// the title, with a soft violet glow: the same text nudged around it, see-through
	if (_title != "") {
		draw_set_color(_violet);
		draw_set_alpha(0.18);
		for (var k = 0; k < 8; k++) draw_text_transformed(_cx + lengthdir_x(2, k * 45), _y0 - 80 + lengthdir_y(2, k * 45), _title, 3, 3, 0);
		draw_set_alpha(1);
		draw_set_color(c_white);
		draw_text_transformed(_cx, _y0 - 80, _title, 3, 3, 0);
	}

	// the highlight slides toward the chosen row instead of jumping (snapping only when a menu first opens)
	var _r   = scr_menu_row(_index, _y0);
	var _key = _title + "@" + string(_y0);
	var _hy  = _anim[$ _key];
	if (is_undefined(_hy) || abs(_hy - _r.y1) > 160) _hy = _r.y1;
	_hy = lerp(_hy, _r.y1, 0.35);
	_anim[$ _key] = _hy;
	var _hh = _r.y2 - _r.y1;
	draw_set_alpha(0.18 + 0.07 * sin(current_time / 300));  // breathing, very gently
	draw_set_color(_violet);
	draw_rectangle(_r.x1, _hy, _r.x2, _hy + _hh, false);
	draw_set_alpha(0.8);
	draw_set_color(_lit);
	draw_line(_r.x1, _hy, _r.x1, _hy + _hh);                // a bright edge on each side
	draw_line(_r.x2, _hy, _r.x2, _hy + _hh);
	draw_set_alpha(1);

	for (var i = 0; i < array_length(_options); i++) {
		var _sel = (i == _index);
		draw_set_color(_sel ? c_white : make_color_rgb(150, 140, 170));
		draw_text(_cx, _y0 + i * 28, _options[i]);
		if (_sel && _options[i] != "") {                      // small diamonds either side of the choice
			var _w = string_width(_options[i]) / 2 + 14;
			draw_set_color(_lit);
			scr_draw_diamond(_cx - _w, _y0 + i * 28 + 7, 3);
			scr_draw_diamond(_cx + _w, _y0 + i * 28 + 7, 3);
		}
	}
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

// a tiny filled diamond, for menu highlights
function scr_draw_diamond(_x, _y, _r) {
	draw_triangle(_x - _r, _y, _x, _y - _r, _x + _r, _y, false);
	draw_triangle(_x - _r, _y, _x, _y + _r, _x + _r, _y, false);
}
```
Why the `_anim` struct is keyed by title and height: the pause menu and the quit confirm can both draw in the same frame. Each keeps its own sliding highlight, so they don't fight over one.

---

## 7. Options: real sliders for the percent settings
Screen Shake, Damage Numbers and Master Volume get a **slider bar** you can click and drag, in 5% steps. It updates live while you drag and saves when you let go. Left/right now nudges by 5%. The Window setting shows `< Borderless >` style arrows.

**a) scr_save:** in `scr_setting_step`, change the rounding line to 5% steps:
```gml
	var _v = round((global.settings[$ _key] + _step) * 20) / 20;
```

**b) scr_menu:** paste at the bottom:
```gml
// where a percent setting's slider bar sits inside its row (shared by drawing and dragging, so they line up)
function scr_option_slider_rect(_i, _y0 = display_get_gui_height() / 2) {
	var _r = scr_menu_row(_i, _y0);
	return { x1: _r.x1 + 190, y1: _r.y1 + 9, x2: _r.x2 - 56, y2: _r.y1 + 19 };
}

// the options screen: each row draws its own label, then a slider (percent) or arrows (choices)
function scr_draw_options(_index, _y0 = display_get_gui_height() / 2) {
	var _rows = scr_options_rows();
	var _blank = [];
	for (var i = 0; i < array_length(_rows); i++) array_push(_blank, "");   // blank: the rows are drawn below, by hand
	array_push(_blank, "Back");
	scr_draw_menu("Options", _blank, _index, _y0);                          // the title, the sliding highlight and Back

	var _dim = make_color_rgb(150, 140, 170);
	for (var i = 0; i < array_length(_rows); i++) {
		var _row = _rows[i];
		var _r   = scr_menu_row(i, _y0);
		var _sel = (i == _index);
		var _v   = global.settings[$ _row.key];
		draw_set_color(_sel ? c_white : _dim);
		draw_set_halign(fa_left);
		draw_text(_r.x1 + 16, _r.y1 + 4, _row.label);
		draw_set_halign(fa_right);
		if (variable_struct_exists(_row, "choices")) {
			draw_text(_r.x2 - 12, _r.y1 + 4, "<  " + _row.choices[_v] + "  >");
		} else {
			var _s  = scr_option_slider_rect(i, _y0);
			var _kx = lerp(_s.x1, _s.x2, _v);
			draw_set_color(make_color_rgb(40, 30, 60));                                       // the track
			draw_rectangle(_s.x1, _s.y1, _s.x2, _s.y2, false);
			draw_set_color(_sel ? make_color_rgb(200, 150, 255) : make_color_rgb(170, 90, 255)); // the fill
			draw_rectangle(_s.x1, _s.y1, _kx, _s.y2, false);
			draw_set_color(c_white);                                                          // the knob
			draw_rectangle(_kx - 2, _s.y1 - 3, _kx + 2, _s.y2 + 3, false);
			draw_set_color(_sel ? c_white : _dim);
			draw_text(_r.x2 - 12, _r.y1 + 4, string(round(_v * 100)) + "%");
		}
	}
	draw_set_halign(fa_left);
	draw_set_color(c_white);
}
```

**c) obj_game_controller → Create:** under `options_return = "MENU";`, add:
```gml
options_drag   = -1;     // which slider is being dragged (-1 = none)
```

**d) obj_game_controller → Draw GUI:** in the OPTIONS block, replace these two lines:
```gml
	var _olabels = scr_options_labels();
	scr_draw_menu("Options", _olabels, options_index);
```
with:
```gml
	var _olabels = scr_options_labels();   // still used below, to place the hint under the last row
	scr_draw_options(options_index);
```
And change the hint text to: `"Drag the sliders, or Left / Right to adjust   -   Esc to go back"`.

**e) obj_game_controller → Step:** replace the whole `case "OPTIONS":` block, up to its `break;` before `case "HUB":`, with:
```gml
	case "OPTIONS":
		var _rows = scr_options_rows();
		var _ocount = array_length(_rows) + 1; // the settings plus Back
		if (options_drag == -1) options_index = scr_menu_nav(options_index, _ocount);
		if (keyboard_check_pressed(vk_escape) || mouse_check_button_pressed(mb_right)) { options_drag = -1; global.game_state = options_return; io_clear(); break; }

		// sliders: press on a bar and drag. it follows the mouse in 5% steps, changes live, and saves when you let go
		var _gmx = device_mouse_x_to_gui(0), _gmy = device_mouse_y_to_gui(0);
		if (mouse_check_button_pressed(mb_left)) {
			for (var i = 0; i < array_length(_rows); i++) {
				if (variable_struct_exists(_rows[i], "choices")) continue;
				var _sr = scr_option_slider_rect(i);
				if (point_in_rectangle(_gmx, _gmy, _sr.x1 - 6, _sr.y1 - 8, _sr.x2 + 6, _sr.y2 + 8)) { options_drag = i; options_index = i; }
			}
		}
		if (options_drag != -1) {
			var _sd = scr_option_slider_rect(options_drag);
			var _dk = _rows[options_drag].key;
			global.settings[$ _dk] = round(clamp((_gmx - _sd.x1) / (_sd.x2 - _sd.x1), 0, 1) * 20) / 20;
			scr_settings_apply();                                                   // hear and feel it change while dragging
			if (!mouse_check_button(mb_left)) { scr_settings_write(); options_drag = -1; io_clear(); } // let go: save it
			break;                                                                  // a drag never also counts as picking the row
		}

		// left / right nudges the highlighted setting: percent settings by 5%, choice settings to the next choice
		if (options_index < array_length(_rows)) {
			var _row = _rows[options_index];
			var _adj = (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D")))
			         - (keyboard_check_pressed(vk_left)  || keyboard_check_pressed(ord("A")));
			if (_adj != 0) {
				if (variable_struct_exists(_row, "choices")) scr_setting_cycle(_row.key, _adj, array_length(_row.choices));
				else scr_setting_step(_row.key, _adj * 0.05, false);
			}
		}

		var _opt_pick = scr_menu_pick(options_index, _ocount);
		if (_opt_pick != -1) {
			if (_opt_pick == array_length(_rows)) {
				global.game_state = options_return; // Back
			} else {
				var _picked = _rows[_opt_pick];
				if (variable_struct_exists(_picked, "choices")) scr_setting_cycle(_picked.key, 1, array_length(_picked.choices));
				else scr_setting_step(_picked.key, 0.1, true);
			}
			io_clear();
		}
		break;
```

---

## 8. A real title screen
Right now the title is the word COVEN over the hideout. This makes it a proper cover, all drawn in code (no art needed):
- a deep violet night sky,
- slow nebula clouds,
- twinkling, drifting stars,
- **the hex sigil turning slowly behind the title,**
- violet embers rising,
- **COVEN** with a breathing glow and a subtitle,
- the restyled menu below,
- small print, and a fade in from black when the game opens.

**a) New script asset: `scr_title`.** Right-click Scripts → Create → Script, name it `scr_title`, and replace its contents with:
```gml
// ---- the title screen: a night sky, her sigil turning, embers rising, and COVEN ----

// where the menu sits on the title screen. the Step (clicks) and the Draw both use this, so they always line up
function scr_title_menu_y() { return display_get_gui_height() * 0.64; }

function scr_draw_title(_options, _index, _t) {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	var _cx = _gw / 2;
	var _sec = _t / game_get_speed(gamespeed_fps);       // seconds since the title appeared
	gpu_push_state();

	// 1) the night: deep violet, darkest at the top
	draw_set_alpha(1);
	draw_rectangle_color(0, 0, _gw, _gh, make_color_rgb(6, 4, 16), make_color_rgb(6, 4, 16),
		make_color_rgb(26, 12, 40), make_color_rgb(26, 12, 40), false);
	gpu_set_blendmode(bm_add);

	// 2) slow nebula clouds drifting behind everything, in her two families of color
	for (var i = 0; i < 6; i++) {
		var _nx = (scr_hash(i * 4.1) * 1.4 - 0.2) * _gw + sin(_sec * 0.05 + i) * 60;
		var _ny = scr_hash(i * 7.3 + 1) * 0.8 * _gh + cos(_sec * 0.04 + i * 2) * 30;
		var _nc = (i mod 2 == 0) ? make_color_rgb(90, 30, 140) : make_color_rgb(20, 60, 110);
		draw_set_alpha(0.10);
		draw_circle_color(_nx, _ny, 260 + 120 * scr_hash(i * 2.2), _nc, c_black, false);
	}

	// 3) stars: twinkling, drifting slowly sideways (each at its own speed, for depth)
	for (var i = 0; i < 160; i++) {
		var _sx = frac(scr_hash(i * 11.3) + _sec * 0.004 * (0.5 + scr_hash(i * 3.3))) * _gw;
		var _sy = scr_hash(i * 17.9 + 2) * _gh * 0.85;
		var _tw = 0.5 + 0.5 * sin(_sec * (1 + 2 * scr_hash(i * 5.1)) + i);
		var _ss = (scr_hash(i * 9.7) > 0.9) ? 2 : 1;
		draw_set_alpha(0.3 + 0.7 * _tw);
		draw_set_color((i mod 7 == 0) ? make_color_rgb(200, 170, 255) : c_white);
		draw_rectangle(_sx, _sy, _sx + _ss - 1, _sy + _ss - 1, false);
	}

	// 4) her sigil, turning slowly behind the title
	var _ty = _gh * 0.3;
	scr_draw_title_sigil(_cx, _ty, min(_gw, _gh) * 0.22, _sec * 6, 0.35 + 0.1 * sin(_sec * 1.5));

	// 5) embers rising from the bottom of the screen
	draw_set_color(make_color_rgb(200, 130, 255));
	for (var i = 0; i < 40; i++) {
		var _life = frac(_sec * (0.08 + 0.06 * scr_hash(i * 1.7)) + scr_hash(i * 6.6));
		var _ex = scr_hash(i * 2.9) * _gw + sin(_sec + i) * 12;
		var _ey = _gh * (1.05 - _life * 0.9);
		draw_set_alpha(sin(_life * pi) * 0.8);
		draw_rectangle(_ex, _ey, _ex + 1, _ey + 1, false);
	}

	// 6) COVEN, with a glow that breathes
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	var _glow = 0.6 + 0.4 * sin(_sec * 1.2);
	draw_set_color(make_color_rgb(170, 90, 255));
	draw_set_alpha(0.12 * _glow);
	for (var k = 0; k < 12; k++) draw_text_transformed(_cx + lengthdir_x(4, k * 30), _ty + lengthdir_y(4, k * 30), "COVEN", 7, 7, 0);
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(1);
	draw_set_color(make_color_rgb(245, 235, 255));
	draw_text_transformed(_cx, _ty, "COVEN", 7, 7, 0);
	draw_set_color(make_color_rgb(170, 150, 200));
	draw_text_transformed(_cx, _ty + 62, "a witch-survivors roguelite", 1.5, 1.5, 0);
	draw_set_valign(fa_top);
	gpu_pop_state();

	// 7) the menu, then the small print
	scr_draw_menu("", _options, _index, scr_title_menu_y());
	draw_set_halign(fa_center);
	draw_set_color(make_color_rgb(110, 100, 130));
	draw_text(_cx, _gh - 34, "W / S or mouse to choose   -   Enter or click to select");
	draw_set_halign(fa_right);
	draw_text(_gw - 12, _gh - 22, "v0.1 vertical slice");
	draw_set_halign(fa_left);
	draw_set_color(c_white);

	// 8) fade in from black when the title first appears
	var _fade = 1 - clamp(_sec / 1.5, 0, 1);
	if (_fade > 0) {
		draw_set_alpha(_fade);
		draw_set_color(c_black);
		draw_rectangle(0, 0, _gw, _gh, false);
		draw_set_alpha(1);
		draw_set_color(c_white);
	}
}

// the Hexweaver's sigil, drawn in code: three rings, two triangles turning opposite ways, and six rune marks
function scr_draw_title_sigil(_x, _y, _r, _ang, _a) {
	draw_set_color(make_color_rgb(170, 90, 255));
	draw_set_alpha(_a);
	draw_circle(_x, _y, _r, true);
	draw_circle(_x, _y, _r * 0.92, true);
	draw_circle(_x, _y, _r * 0.55, true);
	for (var k = 0; k < 2; k++) {                          // the hexagram: two triangles, one turning each way
		var _base = _ang * ((k == 0) ? 1 : -1) + k * 60;
		for (var j = 0; j < 3; j++) {
			var _a1 = _base + j * 120, _a2 = _base + (j + 1) * 120;
			draw_line_width(_x + lengthdir_x(_r * 0.92, _a1), _y + lengthdir_y(_r * 0.92, _a1),
			                _x + lengthdir_x(_r * 0.92, _a2), _y + lengthdir_y(_r * 0.92, _a2), 2);
		}
	}
	for (var j = 0; j < 6; j++) {                          // rune marks between the rings, and beads on the inner ring
		var _ta = _ang + j * 60 + 30;
		draw_line_width(_x + lengthdir_x(_r * 0.92, _ta), _y + lengthdir_y(_r * 0.92, _ta),
		                _x + lengthdir_x(_r, _ta), _y + lengthdir_y(_r, _ta), 3);
		draw_circle(_x + lengthdir_x(_r * 0.55, _ta), _y + lengthdir_y(_r * 0.55, _ta), 3, false);
	}
	draw_set_alpha(1);
}
```

**b) obj_game_controller → Create:** under `menu_index = 0;`, add:
```gml
title_t = 0;   // frames since the title screen appeared (drives its fade in, drifting stars and turning sigil)
```

**c) obj_game_controller → Step:** in `case "MENU":`, replace its first two lines:
```gml
		menu_index = scr_menu_nav(menu_index, array_length(menu_options));
		var _pick = scr_menu_pick(menu_index, array_length(menu_options));
```
with:
```gml
		title_t++;
		menu_index = scr_menu_nav(menu_index, array_length(menu_options), scr_title_menu_y());
		var _pick = scr_menu_pick(menu_index, array_length(menu_options), scr_title_menu_y());
```
(The menu now sits lower, under the logo, so the clicks need the same height as the drawing.)

**d) obj_game_controller → Draw GUI:** replace the MENU block with:
```gml
if (global.game_state == "MENU") {
	scr_draw_title(menu_options, menu_index, title_t);
}
```

**A note on the font:** COVEN uses GameMaker's default font scaled up, so it looks chunky. A pixel font (or a logo your girlfriend draws) would be the next big upgrade. When there is one, only the "COVEN" lines in step 6 change.

---

## 9. Entrance bonus: dust kicked up as the crack runs
From the entrance polish queue. As the crack races in, each stretch of ground puffs grey dust the instant the crack reaches it. The dust rises out of the split and thins away, so the crack feels like it's tearing through real earth.

**obj_unmaking → Draw**, in the tear block: find the end of the pebbles loop, these lines (about line 424):
```gml
			draw_triangle(_ax, _ay, _bx, _by, _grx, _gry, false);
		}
		draw_set_alpha(1);
```
Paste this right **after** that `draw_set_alpha(1);`:
```gml
		// dust kicked up as the crack runs: each column puffs the instant the crack reaches it, then the dust rises and thins
		var _fps2 = game_get_speed(gamespeed_fps);
		draw_set_color(make_color_rgb(150, 140, 165));                         // drained grey, like the frozen world
		for (var i = 0; i < tear_n; i++) {
			var _rq = (tear_n - i - 1) / tear_n;                               // how far the crack had run when it reached this column
			var _tq = tear_at + (1 - sqrt(max(0, 1 - _rq))) * tear_len;         // the frame it got here (undoing the crack's ease-out)
			var _da = (t - _tq) / (_fps2 * 0.9);                               // 0 when it bursts, 1 when it's gone
			if (_da < 0 || _da >= 1) continue;
			for (var k = 0; k < 3; k++) {                                      // three puffs per column
				var _dh  = scr_hash(i * 3.7 + k * 1.9);
				var _dpx = lerp(tear_x[i], tear_x[i + 1], _dh) + (_dh - 0.5) * 10 * _da;            // drifting apart a little
				var _dpy = lerp(chunks[0].lo[i], chunks[0].lo[i + 1], _dh) - _da * (14 + 18 * _dh); // rising out of the crack
				var _dr  = 6 + _da * (16 + 14 * _dh);                                                // spreading as it rises
				draw_set_alpha(0.35 * sqr(1 - _da));
				draw_circle(_dpx, _dpy, _dr, false);
			}
		}
		draw_set_alpha(1);
```
How it works: Draw doesn't remember anything between frames, so instead of spawning particles it **works out when** the crack reached each column (by undoing the crack's ease-out curve), then draws each puff by its age. It costs nothing when no dust is alive.

---

## Checklist
- [ ] 1 Toasts show and fade in the hideout (plus the `timer:` typo)
- [ ] 2 Doubled hitstop line removed
- [ ] 3 F10 comment
- [ ] 4 Frog spacing
- [ ] 5 Danse Macabre cost scales with level
- [ ] 6 Menu restyle (wider rows, sliding highlight, diamonds, title glow)
- [ ] 7 Options sliders (needs 6 first, for the wider rows)
- [ ] 8 Title screen (needs 6 first, for the menu look)
- [ ] 9 Crack dust (entrance polish)

After each group, Ctrl+S and tell Claude: it'll check the files before you run.
