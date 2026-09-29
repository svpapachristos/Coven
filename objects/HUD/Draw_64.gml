draw_set_font(-1);
draw_text(10, 50, "Time: " + string(floor(global.run_time)));
draw_text(10, 10, "Kills: " + string(global.kill_count));
draw_text(10, 25, "Slime Kills: " + string(global.slime_kill_count));
draw_text(270, 15, "Enemies Alive: " + string(instance_number(obj_enemy_parent)));