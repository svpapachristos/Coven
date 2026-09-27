
//A shooting animation i think
if (mouse_check_button_pressed(mb_left)) {
		sprite_index = spr_player_shoot;
		// make the shots point in the direction you shoot
		var _dir = point_direction(x, y, mouse_x, mouse_y);
		var _proj = instance_create_layer(x + 3, y + 2, "Instances", obj_projectile);
		_proj.direction = _dir;
		_proj.speed = 5;
		_proj.image_angle = _dir;
	} else {
		sprite_index = spr_player;
}
//Simple walking
if (keyboard_check(ord("D"))){
	x += 4;
}
if (keyboard_check(ord("A"))) {
	x -= 4;
}
if (keyboard_check(ord("W"))) {
	y -= 4;
}
if (keyboard_check(ord("S"))) {
	y += 4;
}
//clamps the camera to the player so that it follows you around the map
x = clamp(x, 0, room_width - sprite_width);
y = clamp(y, 0, room_height - sprite_height);