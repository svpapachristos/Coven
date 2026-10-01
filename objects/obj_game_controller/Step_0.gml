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

//open up a debug hud
if (keyboard_check_pressed(vk_f1)) global.debug_hud = !global.debug_hud;


switch (global.game_state) {
    case "MENU":
		menu_index = scr_menu_nav(menu_index, array_length(menu_options));
		
		if(keyboard_check_pressed(vk_enter)) {
			if (menu_options[menu_index] == "Start Run") global.game_state = "PLAYING";
			else if (menu_options[menu_index] == "Quit") quit_confirm = true;
		}
		break;
		
    case "PLAYING":
	global.run_time += 1 / game_get_speed(gamespeed_fps); // run time in seconds
	if (keyboard_check_pressed(vk_f3)) scr_give_random_item();
		if (keyboard_check_pressed(vk_escape)){
			global.game_state = "PAUSED";
			pause_index = 0;
			
		}
        break;
        
    case "PAUSED":
		if (keyboard_check_pressed(vk_escape)){ global.game_state = "PLAYING"; break; }
			pause_index = scr_menu_nav(pause_index, array_length(pause_options));
			if (keyboard_check_pressed(vk_enter)) {
				switch (pause_options[pause_index]) {
					case "Resume":		 global.game_state = "PLAYING"; break;
					case "Quit to Menu": room_restart(); break; 
					case "Quit to Desktop":    quit_confirm = true; break;
				}
			}
		break;
	case "DEAD":
		if (keyboard_check_pressed(vk_enter)){
				room_restart();
		}
		break;
		
}