draw_set_font(-1);
draw_text(10, 50, "Time: " + string(floor(global.run_time)));
draw_text(10, 10, "Kills: " + string(global.kill_count));
draw_text(10, 25, "Slime Kills: " + string(global.slime_kill_count));
draw_text(270, 15, "Enemies Alive: " + string(instance_number(obj_enemy_parent)));

// Our first Health Bar!

if (instance_exists(obj_player)) {
	var _hp_pct = clamp(obj_player.hp / obj_player.max_hp, 0, 1);
	
	draw_set_color(c_dkgray);
	draw_rectangle(10, 70, 110, 82, false); //background
	draw_set_color(c_red);
	draw_rectangle(10, 70, 10 + 100 * _hp_pct, 82, false); // current health
	draw_set_color(c_white)
	draw_text(115, 70, string(ceil(obj_player.hp)) + " / " + string(obj_player.max_hp));
	draw_text(10, 90, "iframes: " + string(obj_player.iframes));
}