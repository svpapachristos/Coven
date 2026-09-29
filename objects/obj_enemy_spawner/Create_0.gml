max_enemy_count = 1000;

spawn_table = [
	{ obj: obj_enemy_slime, cap: 20, start_time: 0, end_time: 60 },
	{ obj: obj_enemy_bat, cap: 50, start_time: 15, end_time: 150 },
	{ obj: obj_enemy_pumpkin, cap: 100, start_time: 30, end_time: 300 },
];
alarm[0] = game_get_speed(gamespeed_fps) * 2; //spawns every 2s