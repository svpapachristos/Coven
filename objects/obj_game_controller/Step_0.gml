if (pending_run_start) { pending_run_start = false; scr_start_run(); }
if (pending_hub_setup) { pending_hub_setup = false; scr_apply_loadout(); scr_spawn_familiar(); }

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
			if (menu_options[menu_index] == "Play") { 
				global.game_state = "HUB";
				global.boot_done = true;
			} else if (menu_options[menu_index] == "Quit") { 
				quit_confirm = true; 
				quit_confirm_index = 1; 
			}
			io_clear();
		}
		break;
	
	case "HUB":
		if (keyboard_check_pressed(vk_escape)) {
			pause_return = "HUB";
			global.game_state = "PAUSED";
			pause_index = 0;
			io_clear();
		}
		break;
		
	case "STATION":
		var _keys = ["witch", "wand", "familiar"];
		var _opts = scr_select_options(station_step);
		station_index = scr_menu_nav(station_index, array_length(_opts));
		
		var _spick = scr_menu_pick(station_index, array_length(_opts));
		if (_spick != -1) {
			global.loadout[$ _keys[station_step]] = _spick;
			scr_apply_loadout();
			if (station_step == 2) scr_spawn_familiar();
			global.game_state = "HUB";
			io_clear();
		} else if (keyboard_check_pressed(vk_escape) || mouse_check_button_pressed(mb_right)) {
			global.game_state = "HUB";
			io_clear();
		}
		break;
		
    case "PLAYING":
		global.run_time += 1 / game_get_speed(gamespeed_fps); // run time in seconds
		if (keyboard_check_pressed(vk_f3)) scr_give_random_item();
		if (keyboard_check_pressed(vk_f4)) {
			repeat(100) {
				var _p = scr_get_spawn_point();
				if (!is_undefined(_p)) instance_create_layer(_p[0], _p[1], "Instances", obj_enemy_slime);
			}
		}
		if (keyboard_check_pressed(vk_f5)) global.run_time += 300; // jump 5 minutes
		if (keyboard_check_pressed(vk_escape)) {
			pause_return = "PLAYING";
			global.game_state = "PAUSED";
			pause_index = 0;
			io_clear();
		}
		break;
        
    case "PAUSED":
		if (keyboard_check_pressed(vk_escape)) { global.game_state = pause_return; io_clear(); break; }
		pause_index = scr_menu_nav(pause_index, array_length(pause_options));
		var _ppick = scr_menu_pick(pause_index, array_length(pause_options));
		if (_ppick != -1) {
			pause_index = _ppick
			switch (pause_options[pause_index]) {
				case "Resume":		 global.game_state = pause_return; break;
				case "Abandon Run": room_goto(rm_hideout); break; 
				case "Quit to Desktop": quit_confirm = true; quit_confirm_index = 1; break;
				}
				io_clear();
			}
			break;
			
	case "DEAD":
		end_index = scr_menu_nav(end_index, array_length(end_options));
		var _end_pick = scr_menu_pick(end_index, array_length(end_options));
		if (_end_pick != -1) {
			end_index = _end_pick;
			switch (end_index) {
				case 0: room_restart(); break; //new run same loadout
				case 1: room_goto(rm_hideout); break; // back to menu
				case 2: quit_confirm = true; quit_confirm_index = 1; break;
			}
			io_clear();
		}
		break;
}