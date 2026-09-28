switch (global.game_state) {
    case "START":
        if (keyboard_check_pressed(vk_enter)){
			global.game_state = "PLAYING";
			
			
		}
        break;
        
    case "PLAYING":
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