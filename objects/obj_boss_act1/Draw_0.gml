draw_self();
if (slam_state == 1) {
	var _t = 1 - slam_wind / (game_get_speed(gamespeed_fps) * 1.2);
	draw_set_color(c_red);
	draw_set_alpha(0.25 + 0.25 * _t);
	draw_circle(slam_x, slam_y, slam_radius, false);
	draw_set_alpha(1);
	draw_circle(slam_x, slam_y, slam_radius * _t, true);   // the inner ring grows toward impact
	draw_set_color(c_white);
}