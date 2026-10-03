//Freeze the Zombie when paused or dead
if (scr_freeze_if_paused()) exit;
event_inherited();

//Shamble at the player continously at a shmedium speed
direction = point_direction(x, y, obj_player.x, obj_player.y);
speed = zombie_move_speed;