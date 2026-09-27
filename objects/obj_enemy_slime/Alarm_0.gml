//A Dashy-ier movement
var _dir = point_direction(x, y, obj_player.x, obj_player.y);
direction = _dir;
speed = 0.85; //dash speed
alarm[1] = game_get_speed(gamespeed_fps) * 0.5; //dash length