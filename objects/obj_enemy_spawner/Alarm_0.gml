if (global.game_state != "PLAYING") {
	alarm[0] = 1;
	exit;
}
var _x = irandom_range(0, room_width);
var _y = irandom_range(0, room_height);

alarm[0] = game_get_speed(gamespeed_fps) * 2; //this repeats the spawner, making it infinite

if (instance_number(obj_enemy_slime) < max_slime_count && max_enemy_count) {
	instance_create_layer(_x, _y, "Instances", obj_enemy_slime);
	global.enemy_count += 1;
	
}