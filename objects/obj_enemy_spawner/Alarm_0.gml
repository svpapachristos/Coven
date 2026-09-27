var _x = irandom_range(0, room_width);
var _y = irandom_range(0, room_height);
instance_create_layer(_x, _y, "Instances", obj_enemy_slime);

alarm[0] = speed * 2; //this repeats the spawner, making it infinite

if (instance_number(obj_enemy_slime) < max_enemy_count && max_slime_count) {
	instance_create_layer(_x, _y, "Instances", obj_enemy_slime);
}