//A placeholder til someone (probably izzy) makes a sprite for each item (thank you very much izzy)
var _yoff = sin(degtorad(bob_t)) * 3;
var _pulse = 1 + 0.15 * sin(degtorad(bob_t * 2));
var _blink = expires && (life < game_get_speed(gamespeed_fps) * 5) && ((life div 6) mod 2 == 0);
if (!_blink) {
	draw_set_color(pickup_color);
	draw_set_alpha(0.3);
	draw_circle(x, y + _yoff, 14 * _pulse, false);
	draw_set_alpha(1);
	draw_circle(x, y + _yoff, 7, false);
	draw_set_color(c_white);
	draw_circle(x, y + _yoff, 3, false);
}

if (!_blink) {
	draw_set_color(pickup_color);
	draw_circle(x, y + _yoff, 4, false);
	draw_set_color(c_white);
	draw_circle(x - 1, y + _yoff - 1, 1, false);
}
//when we have a sprite, the draw line below can replace the 4 above to keep the bobbing

	//draw_sprite(sprite_index, image_index, x, y + _yoff);
	//if you are reading this, thank you, i would like to work for you