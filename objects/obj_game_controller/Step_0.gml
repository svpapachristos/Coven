//Quit Confirmation will take priority
if (quit_confirm) {
	if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(ord("Y"))) {
		game_end();
	} else if (keyboard_check_pressed(vk_anykey)) {
		quit_confirm = false; // no other key will confirm quit
	}
	exit; //pauses the game while prompted to quit
}
//On first Q press while game state is not playing AKA while paused
if (global.game_state != "PLAYING" && keyboard_check_pressed(ord("Q"))){
	quit_confirm = true;
	exit;
}

switch (global.game_state) {
    case "START":
        if (keyboard_check_pressed(vk_enter)){
			global.game_state = "PLAYING";
			
			
		}
        break;
        
    case "PLAYING":
	global.run_time += 1 / game_get_speed(gamespeed_fps); // run time in seconds
		if (keyboard_check_pressed(vk_escape)){
			global.game_state = "PAUSED";
			
		}
        break;
        
    case "PAUSED":
		if (keyboard_check_pressed(vk_escape)){
			global.game_state = "PLAYING";
		break;
		}
	case "DEAD":
		if (keyboard_check_pressed(vk_enter)){
				room_restart();
		}
		break;
		
}