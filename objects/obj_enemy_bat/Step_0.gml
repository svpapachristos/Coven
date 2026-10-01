//Freeze the Bat when paused or dead
if (scr_freeze_if_paused()) exit;
event_inherited();

//Chase the player continously at a quick speed
direction = point_direction(x, y, obj_player.x, obj_player.y);
speed = bat_move_speed;