// a little hexed frog that hops and flashes before it bursts
var _fade = 1 - unmaking;                                  // fades out while being unmade
var _hop  = (hop_t > 0) ? sin(hop_t / 12 * pi) * 12 : 0;   // how high it is mid-hop
var _warn = (life < game_get_speed(gamespeed_fps) * 2) ? 0.5 + 0.5 * sin(current_time / 40) : 0;

// its shadow stays on the ground while it hops
draw_set_alpha(0.4 * _fade);
draw_set_color(c_black);
draw_ellipse(x - 18, y + 9, x + 18, y + 18, false);
draw_set_alpha(1);

// the frog, lifted by the hop
draw_sprite_ext(sprite_index, 0, x, y - _hop, image_xscale, image_yscale, 0, c_white, _fade);

// about to burst: it flashes white. fog paints the sprite as one solid colour, so this is a white silhouette on top
if (_warn > 0) {
	gpu_set_fog(true, c_white, 0, 1);
	draw_sprite_ext(sprite_index, 0, x, y - _hop, image_xscale, image_yscale, 0, c_white, 0.6 * _warn * _fade);
	gpu_set_fog(false, c_white, 0, 1);
}