//Makes the lightning lightning-ier
function scr_draw_lightning(_x1, _y1, _x2, _y2, _seed, _glow = make_color_rgb(60, 220, 255)){
	var _dist = point_distance(_x1, _y1, _x2, _y2);
	var _dir = point_direction(_x1, _y1, _x2, _y2);
	var _segs = max(2, floor(_dist / 10));
	var _jit = 7;
	var _tick = floor(current_time / 45);

	// more jagged arcs
	var _px = array_create(_segs + 1);
	var _py = array_create(_segs + 1);
	_px[0] = _x1; _py[0] = _y1;
	_px[_segs] = _x2;  _py[_segs] = _y2;

	for (var i = 1; i < _segs; i++) {
		var t = i / _segs;
		var r = frac(sin((i + _seed) * 12.9898 + _tick * 78.233) * 43758.5453) * 2 -1;
		var off = r * _jit * sin(t * pi); //tapers at both ends
		_px[i] = lerp(_x1, _x2, t) + lengthdir_x(off, _dir + 90);
		_py[i] = lerp(_y1, _y2, t) + lengthdir_y(off, _dir + 90);
	}

	// pass 1: thick cyan glow, pass 2: thin white core
	for (var p = 0; p < 2; p++) {
		var _w   = (p == 0) ? 3 : 1;
		var _col = (p == 0) ? _glow : c_white;
		for (var i = 0; i < _segs; i++) {
			draw_line_width_color(_px[i], _py[i], _px[i+1], _py[i+1], _w, _col, _col);
		}
	}

}