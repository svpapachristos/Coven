max_enemy_count = 1000;

spawn_table = [
	{ obj: obj_enemy_slime, cap: 600, start_time: 0, end_time: 60000 },
	{ obj: obj_enemy_zombie, cap: 500, start_time: 15, end_time: 60000 },
	{ obj: obj_enemy_bat, cap: 400, start_time: 35, end_time: 15000 },
	{ obj: obj_enemy_pumpkin, cap: 8, start_time: 90, end_time: 30000 },
];

// formations the director can drop. fn(enemy_obj, count) will spawn our packs
pack_types = [
	{ name: "single", weight: 40, min_time: 0, max_time: 900, min: 1, max: 1, fn: scr_pack_scatter },
	{ name: "double", weight: 30, min_time: 0, max_time: 900, min: 2, max: 2, fn: scr_pack_scatter },
	{ name: "triple", weight: 25, min_time: 0, max_time: 900, min: 3, max: 3, fn: scr_pack_scatter },
	{ name: "blob", weight: 35, min_time: 45, max_time: 30000, min: 3, max: 12, fn: scr_pack_blob },
	{ name: "line", weight: 20, min_time: 30, max_time: 30000, min: 6, max: 20, fn: scr_pack_line },
	{ name: "pincer", weight: 15, min_time: 60, max_time: 30000, min: 10, max: 40, fn: scr_pack_pincer },
	{ name: "ring", weight: 15, min_time: 90, max_time: 30000, min: 16, max: 60, fn: scr_pack_ring },
];

director_timer = 0;
// 