max_enemy_count = 100;
max_slime_count = 20;
global.kill_count = 0;
global.slime_kill_count = 0;
global.enemy_count = 0;
global.game_state = "PLAYING";

alarm[0] = game_get_speed(gamespeed_fps) * 4; //spawns every 4s