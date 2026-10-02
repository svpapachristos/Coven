if (pending_run_start) {
	pending_run_start = false;
	scr_start_run(); //waits a frame so the player can exist
}


// Handles quit confirmation before regular menus
if (quit_confirm) {
	if (keyboard_check_pressed(vk_escape)) {
		quit_confirm = false;
		io_clear();
	} else {
		quit_confirm_index = scr_menu_nav (
			quit_confirm_index,
			array_length(quit_confirm_options)
		);
		
		var _quit_pick = scr_menu_pick( 
			quit_confirm_index,
			array_length(quit_confirm_options)
		);
		
		if (_quit_pick != -1) {
			quit_confirm_index = _quit_pick;
			
			if (quit_confirm_index == 0) { 
				game_end();
			} else {
				quit_confirm = false;
			}
			
			io_clear();
		}
	}
	
	exit
}

//open up a debug hud
if (keyboard_check_pressed(vk_f1)) global.debug_hud = !global.debug_hud;




switch (global.game_state) {
    case "MENU":
		menu_index = scr_menu_nav(menu_index, array_length(menu_options));
		var _pick = scr_menu_pick(menu_index, array_length(menu_options));
		if(_pick != -1) {
			menu_index = _pick;
			if (menu_options[menu_index] == "Start Run") { 
				global.game_state = "SELECT"; 
				select_step = 0;
				select_index = 0;
			} else if (menu_options[menu_index] == "Quit") { 
				quit_confirm = true; 
				quit_confirm_index = 1; 
			}
			io_clear();
		}
		break;
		
	case "SELECT":
		var _keys = ["witch", "wand", "familiar"];
		var _opts = scr_select_options(select_step);
		select_index = scr_menu_nav(select_index, array_length(_opts));
		
		var _pick = scr_menu_pick(select_index,  array_length(_opts));
		if (_pick != -1) {
			global.loadout[$ _keys[select_step]] = _pick;
			select_step++;
			select_index = 0;
			if (select_step > 2) scr_start_run();
			io_clear();
		}
		else if (keyboard_check_pressed(vk_escape) || mouse_check_button_pressed(mb_right)) {
			if (select_step == 0) global.game_state = "MENU";
			else {
				select_step--;
				select_index = global.loadout[$ _keys[select_step]];
			}
			io_clear();
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
			var _pick = scr_menu_pick(pause_index, array_length(pause_options));
			if (_pick != -1) {
				pause_index = _pick
				switch (pause_options[pause_index]) {
					case "Resume":		 global.game_state = "PLAYING"; break;
					case "Quit to Menu": room_restart(); break; 
					case "Quit to Desktop":
					quit_confirm = true;
					quit_confirm_index = 1;
					break;
					
				}
			}
		break;
	case "DEAD":
		end_index = scr_menu_nav(end_index, array_length(end_options));
		var _end_pick = scr_menu_pick(end_index, array_length(end_options));
		
		if (_end_pick != -1) {
			end_index = _end_pick;
			
			switch (end_index) {
				case 0: // new run
					global.start_run_after_restart = true;
					room_restart();
					break;
					
				case 1: // back to menu
					global.start_run_after_restart = false;
					room_restart();
					break;
				
				case 2: // quit game
					quit_confirm = true;
					quit_confirm_index = 1;
					break;
			}
		}
		break;
		
}