if (!instance_exists(obj_player)) exit;
near = (global.game_state == "HUB") && point_distance(x, y, obj_player.x, obj_player.y) < interact_range;
if (near && input_pressed("interact")) interact();
