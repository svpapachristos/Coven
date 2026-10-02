// Clickable area for menu row 1 (shared by drawing and clicking, so they always line up)
function scr_menu_row(_i, _y0 = display_get_gui_height() / 2) {
	var _cx = display_get_gui_width() / 2;
	return { x1: _cx - 140, y1: _y0 + _i * 28 - 4, x2: _cx + 140, y2: _y0 + _i * 28 + 24 };
}

// returns the row that was chosen per frame (Enter on the highlight or click on a row, or return -1
function scr_menu_pick(_index, _count, _y0 = display_get_gui_height() / 2) {
	if (keyboard_check_pressed(vk_enter)) return _index;
	if (mouse_check_button_pressed(mb_left)) {
		var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
		for (var i = 0; i < _count; i++) {
			var _r = scr_menu_row(i, _y0);
			if (point_in_rectangle(_mx, _my, _r.x1, _r.y1, _r.x2, _r.y2)) return i;
		}
	}
	return -1;
}

/// Keyboard moves the highlight; so does hovering the mouse over a row (only once the mouse actually moves)
function scr_menu_nav(_index, _count, _y0 = display_get_gui_height() / 2) {
	static _last_mx = -1;
	static _last_my = -1;

	var _d = (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S")))
	       - (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W")));
	_index = (_index + _d + _count) mod _count;

	var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
	if (_mx != _last_mx || _my != _last_my) {
		for (var i = 0; i < _count; i++) {
			var _r = scr_menu_row(i, _y0);
			if (point_in_rectangle(_mx, _my, _r.x1, _r.y1, _r.x2, _r.y2)) _index = i;
		}
		_last_mx = _mx;
		_last_my = _my;
	}
	return _index;
}

function scr_draw_menu(_title, _options, _index, _y0 = display_get_gui_height() / 2) {
	var _cx = display_get_gui_width() / 2;
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_cx, _y0 - 80, _title, 3, 3, 0);
	for (var i = 0; i < array_length(_options); i++) {
		var _sel = (i == _index);
		if (_sel) {
			var _r = scr_menu_row(i, _y0);
			draw_set_alpha(0.25);
			draw_set_color(c_aqua);
			draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, false);
			draw_set_alpha(1);
		}
		draw_set_color(_sel ? c_aqua : c_gray);
		draw_text(_cx, _y0 + i * 28, (_sel ? "> " : "") + _options[i]);
	}
	draw_set_color(c_white);
	draw_set_halign(fa_left);
}

function scr_draw_bar(_x, _y, _w, _h, _pct, _col, _label = "") {
	_pct = clamp(_pct, 0, 1);
	draw_set_color(c_black);  draw_rectangle(_x - 2, _y - 2, _x + _w + 2, _y + _h + 2, false);
	draw_set_color(c_dkgray); draw_rectangle(_x, _y, _x + _w, _y + _h, false);
	draw_set_color(_col);     draw_rectangle(_x, _y, _x + _w * _pct, _y + _h, false);
	if (_label != "") {
		draw_set_color(c_white);
		draw_set_valign(fa_middle);
		draw_text(_x + _w + 8, _y + _h / 2, _label);
		draw_set_valign(fa_top);
	}
	draw_set_color(c_white);
}

function scr_draw_infinity(_x, _y, _size, _col) {
	draw_set_color(_col);
	var _steps = 40;
	var _px = _x + _size, _py = _y;
	for (var i = 1; i <= _steps; i++) {
		var _t = (i / _steps) * 2 * pi;
		var _d = 1 + sqr(sin(_t));
		var _nx = _x + _size * cos(_t) / _d;
		var _ny = _y + _size * sin(_t) * cos(_t) / _d;
		draw_line_width(_px, _py, _nx, _ny, 2);
		_px = _nx; _py = _ny;
	}
	draw_set_color(c_white);
}