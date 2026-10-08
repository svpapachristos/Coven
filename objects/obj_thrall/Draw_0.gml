var _col = make_color_rgb(170, 140, 255); // ghostly violet
if (global.necro_frenzy > 0) _col = merge_color(_col, make_color_rgb(255, 120, 255), 0.5 + 0.5 * sin(current_time / 80 + orbit));

if (rise < 1) {
	// work out where the feet are no matter where the sprite's origin is
	var _sw   = sprite_get_width(sprite_index), _sh = sprite_get_height(sprite_index);
	var _left = x - sprite_get_xoffset(sprite_index);
	var _feet = y - sprite_get_yoffset(sprite_index) + _sh;
	var _cx   = _left + _sw / 2;

	// the open grave at its feet, opening up then closing behind it
	var _hole = sin(rise * pi);
	draw_set_color(make_color_rgb(35, 22, 18));
	draw_set_alpha(0.85 * _hole);
	draw_ellipse(_cx - _sw * 0.6 * _hole, _feet - 3, _cx + _sw * 0.6 * _hole, _feet + 4, false);
	
	// the body climbs out head first: only the part above ground is drawn, shaking as it pulls itself up
	var _shake = random_range(-1, 1) * (1 - rise);
	var _show  = max(1, floor(_sh * rise));
	draw_set_alpha(1);
	draw_sprite_part_ext(sprite_index, image_index, 0, 0, _sw, _show, _left + _shake, _feet - _show, 1, 1, _col, 0.9);
	

	// dirt flung out as it claws its way up: chunky clods plus a fine spray of dust
	for (var i = 0; i < 16; i++) {
		var _lt = clamp((rise - i * 0.04) / 0.35, 0, 1); // each clod's own flight, launched one after another
		if (_lt <= 0 || _lt >= 1) continue;

		var _a    = orbit + i * 137.5;                                   // golden angle, spreads evenly all around the hole
		var _out  = _sw * 0.3 + _lt * (_sw * 0.5 + 6 + (i mod 4) * 5);   // starts at the hole's edge, lands clear of the body
		var _arc  = sin(_lt * pi) * (10 + (i mod 3) * 7);               // up, then back down
		var _dx   = _cx + lengthdir_x(_out, _a);
		var _dy   = _feet + lengthdir_y(_out * 0.4, _a) - _arc;
		var _size = 1.5 + (i mod 3) * 0.75;                              // mix of small, medium and big clods

		draw_set_alpha(min(1, (1 - _lt) * 4));         // stays solid in the air, fades as it lands
		draw_set_color(make_color_rgb(70, 45, 30));    // dark underside
		draw_circle(_dx, _dy + 1, _size, false);
		draw_set_color(make_color_rgb(140, 100, 65));  // lit top so it pops against the grass
		draw_circle(_dx, _dy, max(1, _size - 0.5), false);

		// a little dust kicked up behind each clod
		draw_set_color(make_color_rgb(110, 85, 60));
		draw_set_alpha(0.5 * (1 - _lt));
		draw_circle(_dx - lengthdir_x(4, _a), _dy + 2, 1, false);
		draw_circle(_dx - lengthdir_x(7, _a + 20), _dy + 3, 1, false);
	}

	draw_set_alpha(1);
	draw_set_color(c_white);
	exit;
}

draw_sprite_ext(sprite_index, image_index, x, y, flip, 1, 0, _col, 0.9);

// thralls have hp too yaknow!, but it only shows once they get hurt
if (hp < max_hp) {
	var _bx = x + flip * (sprite_get_width(sprite_index) / 2 - sprite_get_xoffset(sprite_index));
	var _by = bbox_top - 5;
	var _bw = 18;
	var _bh = 5;
	draw_set_color(make_color_rgb(30, 15, 40));
	draw_rectangle(_bx - _bw / 2 - 1, _by - 1, _bx + _bw / 2 + 1, _by + _bh + 2, false);
	draw_set_color(make_color_rgb(170, 140, 255));
	draw_rectangle(_bx - _bw / 2, _by, _bx - _bw / 2 + _bw * (hp / max_hp), _by + _bh + 1, false);
	draw_set_color(c_white);
}