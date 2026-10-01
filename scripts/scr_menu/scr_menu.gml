// Move the highlight with W/S or the arrow keys; returns the new index
function scr_menu_nav(_index, _count) {
	var _d = (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S")))
	       - (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W")));
	return (_index + _d + _count) mod _count;
}

// Draws a centered title and a list of options, highlighting the selected one
function scr_draw_menu(_title, _options, _index) {
	var _cx = display_get_gui_width() / 2;
	var _cy = display_get_gui_height() / 2;
	draw_set_halign(fa_center);
	draw_set_color(c_white);
	draw_text_transformed(_cx, _cy - 80, _title, 3, 3, 0);
	for (var i = 0; i < array_length(_options); i++) {
		var _sel = (i == _index);
		draw_set_color(_sel ? c_aqua : c_gray);
		draw_text(_cx, _cy + i * 24, (_sel ? "> " : "") + _options[i]);
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