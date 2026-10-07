gpu_push_state(); // snapshot the gpu settings so nothing the beam does leaks into the rest of the frame

	var _g = beam_line;
	var _half = scr_beam_half(heat);
	var _w = _half * (1 + 0.1 * sin(current_time / 35));
	var _nx = lengthdir_x(1, angle + 90), _ny = lengthdir_y(1, angle + 90); // across the beam
	var _dx = lengthdir_x(1, angle),      _dy = lengthdir_y(1, angle);      // along the beam
	var _time = current_time;

//make heat shift the beam from violet to white hot with the arcane violets still visible
	var _glow = merge_color(make_color_rgb(130, 45, 230), make_color_rgb(165, 55, 255), heat);
	var _mid  = merge_color(make_color_rgb(190, 120, 255), make_color_rgb(225, 150, 255), heat);
	var _core = merge_color(make_color_rgb(235, 200, 255), c_white, heat);
	var _deep = make_color_rgb(95, 25, 190); // saturated violet for crackles so they show up inside the white core

	var _segs = 28; // how many slices the beam is built from (more = smoother flames)

// how wide the beam is at point t (0 = wand, 1 = tip): pinched at the wand, swelling toward the target
	var _width_at = function(_t, _w) {
	var _flare = min(_t / 0.12, 1);
	return _w * lerp(0.08, 1, _flare) * lerp(0.8, 1.3, _t);
};

// cheap repeatable random number from a seed, 0 to 1
	var _hash = function(_s) { return frac(abs(sin(_s * 12.9898) * 43758.5453)); };


// ---- the beam body: three stacked strips, glow / mid / core, with flamey edges ----
for (var i = 0; i < 3; i++) {
	gpu_set_blendmode((i == 0) ? bm_normal : bm_add);
	var _layer = (i == 0) ? 1 : ((i == 1) ? 0.6 : 0.25);
	var _col   = (i == 0) ? _glow : ((i == 1) ? _mid : _core);
	var _a     = (i == 0) ? 0.3 : ((i == 1) ? 0.45 : 0.9);
	var _rough = (i == 0) ? 1 : ((i == 1) ? 0.6 : 0.15); // outer glow licks like fire, the core stays clean

	draw_primitive_begin(pr_trianglestrip);
	for (var s = 0; s <= _segs; s++) {
		var _t  = s / _segs;
		var _px = lerp(_g.x1, _g.x2, _t), _py = lerp(_g.y1, _g.y2, _t);
			var _taper = 1 - 0.5 * sqr(max(0, (_t - 0.85) / 0.15)); // last stretch draws in, coalescing into the star
		var _hw = _width_at(_t, _w) * _layer * _taper;
		var _ramp = min(_t * 4, 1) * _rough; // no flames right at the wand tip

		// two waves per side rolling toward the target, so the edges ripple like flame
		var _up = _hw * (1 + _ramp * (0.16 * sin(_t * 38 - _time / 45)     + 0.09 * sin(_t * 91 - _time / 28)));
		var _dn = _hw * (1 + _ramp * (0.16 * sin(_t * 41 - _time / 50 + 2) + 0.09 * sin(_t * 87 - _time / 33 + 1)));

		draw_vertex_color(_px + _nx * _up, _py + _ny * _up, _col, _a);
		draw_vertex_color(_px - _nx * _dn, _py - _ny * _dn, _col, _a);
	}
	draw_primitive_end();
}


// ---- energy surges: bright pulses racing down the core into the star ----
gpu_set_blendmode(bm_add);
for (var k = 0; k < 3; k++) {
	var _life = frac(k / 3 + _time / 350);
	var _t  = lerp(0.1, 1, _life);
	var _hw = _width_at(_t, _w) * 0.5;
	var _cx = lerp(_g.x1, _g.x2, _t), _cy = lerp(_g.y1, _g.y2, _t);
	var _sl = _w * 2.5; // how long each surge streak is
	var _sa = 0.6 * sin(pi * _life);
	draw_primitive_begin(pr_trianglestrip);
	draw_vertex_color(_cx - _dx * _sl, _cy - _dy * _sl, _core, 0);
	draw_vertex_color(_cx + _nx * _hw, _cy + _ny * _hw, _core, _sa);
	draw_vertex_color(_cx - _nx * _hw, _cy - _ny * _hw, _core, _sa);
	draw_vertex_color(_cx + _dx * _sl * 0.4, _cy + _dy * _sl * 0.4, _core, 0);
	draw_primitive_end();
}


// ---- core spills: wisps of core energy breaking off the center line and spilling out into the cone ----
	var _fn = 10; // points per wisp
	var _fx_arr = array_create(_fn + 1), _fy_arr = array_create(_fn + 1);
for (var k = 0; k < 10; k++) {
	var _phase = k * 0.6180339 + _time / 650;
	var _cycle = floor(_phase);   // each time a wisp burns out, it breaks off somewhere new
	var _life  = frac(_phase);
	var _hs    = _cycle * 31 + k * 7;
	var _t0    = lerp(0.12, 0.85, _hash(_hs));
	var _side  = (k mod 2 == 0) ? 1 : -1;          // alternate sides so both halves of the cone get them
	var _size  = 0.7 + 0.6 * _hash(_hs + 0.25);

	var _base  = _width_at(_t0, _w);
	var _bx    = lerp(_g.x1, _g.x2, _t0), _by = lerp(_g.y1, _g.y2, _t0);
	var _erupt = sin(min(_life * 1.8, 1) * pi * 0.5); // shoots out fast, then hangs
	var _reach = _base * 0.9 * _size * _erupt;       // how far out it gets, stays inside the cone
	var _sweep = _base * 1.4 * _size * (0.4 + 0.6 * _life); // swept along toward the target
	var _fa    = 0.85 * (1 - _life);

	// spine starts dead center and curves outward as it gets carried along the beam
	for (var j = 0; j <= _fn; j++) {
		var _u   = j / _fn;
		var _out = _reach * sin(_u * pi * 0.5);
		var _wob = sin(_u * 9 - _time / 60 + k) * _base * 0.08 * _u;
		_fx_arr[j] = _bx + _dx * _sweep * _u + _nx * _side * (_out + _wob);
		_fy_arr[j] = _by + _dy * _sweep * _u + _ny * _side * (_out + _wob);
	}

	// thin strip: hot core-white at the root, cooling to violet as it thins out
	draw_primitive_begin(pr_trianglestrip);
	for (var j = 0; j <= _fn; j++) {
		var _u  = j / _fn;
		var _ja = max(j - 1, 0), _jb = min(j + 1, _fn);
		var _tx = _fx_arr[_jb] - _fx_arr[_ja], _ty = _fy_arr[_jb] - _fy_arr[_ja];
		var _tl = max(point_distance(0, 0, _tx, _ty), 0.001);
		var _th = _base * 0.12 * _size * (1 - _u);
		var _px2 = -_ty / _tl * _th, _py2 = _tx / _tl * _th;
		var _c  = merge_color(_core, _mid, _u);
		draw_vertex_color(_fx_arr[j] + _px2, _fy_arr[j] + _py2, _c, _fa * (1 - _u * 0.6));
		draw_vertex_color(_fx_arr[j] - _px2, _fy_arr[j] - _py2, _c, _fa * (1 - _u * 0.6));
	}
	draw_primitive_end();
}

// ---- cosmic twinkles: little four-point stars flickering along the beam ----
for (var k = 0; k < 14; k++) {
	var _life = frac(k * 0.6180339 + _time / 600);
	var _t    = lerp(0.12, 0.95, frac(k * 0.7548777));
	var _side = frac(k * 0.4142136) * 2 - 1;
	var _hw   = _width_at(_t, _w);
	var _cx = lerp(_g.x1, _g.x2, _t) + _nx * _side * _hw * 1.3;
	var _cy = lerp(_g.y1, _g.y2, _t) + _ny * _side * _hw * 1.3;
	var _s  = _w * (0.25 + 0.35 * frac(k * 0.31)) * sin(pi * _life);
	draw_set_color(_core);
	draw_set_alpha(0.9 * sin(pi * _life));
	draw_line_width(_cx - _s, _cy, _cx + _s, _cy, 1);
	draw_line_width(_cx, _cy - _s, _cx, _cy + _s, 1);
	draw_set_alpha(0.5 * sin(pi * _life));
	draw_circle(_cx, _cy, max(1, _s * 0.2), false);
}


// ---- cosmic bubbles boiling off the edges ----
for (var k = 0; k < 18; k++) {
	var _life = frac(k * 0.381966 + _time / 900);
	var _t    = lerp(0.1, 0.95, frac(k * 0.2360679));
	var _side = (k mod 2 == 0) ? 1 : -1;
	var _hw   = _width_at(_t, _w);
	var _push = _hw * (1.05 + 0.6 * _life);
	var _cx = lerp(_g.x1, _g.x2, _t) + _dx * _life * 20 + _nx * _side * _push;
	var _cy = lerp(_g.y1, _g.y2, _t) + _dy * _life * 20 + _ny * _side * _push;
	var _r  = _w * (0.05 + 0.1 * frac(k * 0.7071)) * sin(pi * _life);
	draw_set_color(_mid);
	draw_set_alpha(0.7 * sin(pi * _life));
	draw_circle(_cx, _cy, _r, false);
}


// ---- crackles: short arcs popping in all along the core, re-rolling constantly ----
var _tick = floor(_time / 50);
var _an = 10; // points per arc
var _ax = array_create(_an + 1), _ay = array_create(_an + 1);
for (var a = 0; a < 5; a++) {
	var _seed = a * 17 + _tick * 3;
	var _ta = lerp(0.05, 0.8, _hash(_seed));
	var _tb = min(_ta + 0.12 + 0.2 * _hash(_seed + 0.5), 0.98);

	for (var j = 0; j <= _an; j++) {
		var _u   = j / _an;
		var _t   = lerp(_ta, _tb, _u);
		var _r   = _hash(j + _seed * 7.1) * 2 - 1;
		var _off = _r * _width_at(_t, _w) * 0.22 * sin(_u * pi); // stays inside the core, pinned at both ends
		_ax[j] = lerp(_g.x1, _g.x2, _t) + _nx * _off;
		_ay[j] = lerp(_g.y1, _g.y2, _t) + _ny * _off;
	}

	// deep violet stroke so it reads against the white core, thin white thread on top
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(0.85);
	for (var j = 0; j < _an; j++) draw_line_width_color(_ax[j], _ay[j], _ax[j + 1], _ay[j + 1], 2, _deep, _deep);
	gpu_set_blendmode(bm_add);
	draw_set_alpha(0.6);
	for (var j = 0; j < _an; j++) draw_line_width_color(_ax[j], _ay[j], _ax[j + 1], _ay[j + 1], 1, _mid, _mid);
}


//a small, bright gathering of concentrated arcane energy at the tip of the wand
draw_set_color(_mid);
draw_set_alpha(0.6);
draw_circle(_g.x1, _g.y1, 4 + 10 * heat, false);
draw_set_alpha(1);
draw_set_color(_core);
draw_circle(_g.x1, _g.y1, 2 + 4 * heat, false);


// ---- the star: sized to swallow the end of the beam, with a hot center the core flows into ----
var _endw  = _width_at(1, _w);
var _pulse = 0.9 + 0.1 * sin(current_time / 60);
draw_set_alpha(1);
draw_circle_color(_g.x2, _g.y2, _endw * 1.9 * _pulse, _glow, c_black, false);
draw_circle_color(_g.x2, _g.y2, _endw * 1.1 * _pulse, _mid,  c_black, false);
draw_circle_color(_g.x2, _g.y2, _endw * 0.55 * _pulse, _core, c_black, false);
draw_set_color(c_white);
draw_set_alpha(0.9);
draw_circle(_g.x2, _g.y2, max(2, _endw * 0.25 * _pulse), false);

// long four-point star rays, slowly turning, plus short flickering diagonals
var _spin = current_time / 25;
for (var _ri = 0; _ri < 4; _ri++) {
	var _ra2 = _spin + _ri * 90;
	var _rl  = _endw * 2.6 * _pulse;
	draw_set_color(_mid);
	draw_set_alpha(0.8);
	draw_line_width(_g.x2, _g.y2, _g.x2 + lengthdir_x(_rl, _ra2), _g.y2 + lengthdir_y(_rl, _ra2), 2);
	draw_set_color(_core);
	draw_set_alpha(1);
	draw_line_width(_g.x2, _g.y2, _g.x2 + lengthdir_x(_rl * 0.6, _ra2), _g.y2 + lengthdir_y(_rl * 0.6, _ra2), 1);

	var _rd = _ra2 + 45;
	draw_set_color(_mid);
	draw_set_alpha(0.5 + 0.3 * sin(current_time / 40 + _ri));
	draw_line_width(_g.x2, _g.y2, _g.x2 + lengthdir_x(_rl * 0.45, _rd), _g.y2 + lengthdir_y(_rl * 0.45, _rd), 1);
}

draw_set_alpha(1);
draw_set_color(c_white);
gpu_pop_state(); // put the gpu settings back exactly how we found them