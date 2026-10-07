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
if (keyboard_check_pressed(vk_f2)) {
	global.auto_pick = !global.auto_pick;
	global.toast = { text: global.auto_pick ? "AUTO-PICK ON" : "AUTO-PICK OFF", sub: "Level-ups choose a random item", color: c_yellow, timer: game_get_speed(gamespeed_fps) * 2 };
}



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
		if (global.boss_down) { global.boss_down = false; scr_act_complete(); }
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
		if (!is_undefined(global.toast)) {
			global.toast.timer--;
			if (global.toast.timer <= 0) global.toast = undefined;
		}
		if (keyboard_check_pressed(vk_f6)) {
			scr_item_reward(obj_player.x + 120, obj_player.y)
			var _id = scr_roll_item();
			if (!is_undefined(_id)) {
				var _p = instance_create_layer(obj_player.x + 120, obj_player.y, "Instances", obj_pickup_item);
			_p.item_id = _id;
			_p.pickup_color = scr_rarity_color(global.item_db[$ _id].rarity);
			}
		}
		if (global.levelups_pending > 0) scr_open_levelup();
		if (variable_global_exists("necro_frenzy") && global.necro_frenzy > 0) global.necro_frenzy--;
		
		if (keyboard_check_pressed(vk_f7)) scr_gain_souls(100); //test key to give souls
		if (keyboard_check_pressed(vk_f8)) scr_add_corruption(15); //test key to corrupt the player
		if (keyboard_check_pressed(vk_f9)) global.boss_down = true;
		if (keyboard_check_pressed(vk_f10)) scr_give_item("tarot_magician"); //test key for infinite mana
		
		
		var _bn = min(array_length(global.blast_queue), 20);   // at most 20 blasts a frame
		for (var i = 0; i < _bn; i++) {
			var _b = global.blast_queue[i];
			with (obj_enemy_parent) {
			if (point_distance(_b.x, _b.y, x, y) < _b.r) scr_damage_enemy(id, _b.dmg, make_color_rgb(255, 170, 60), false);
			}
		part_particles_create(global.ps_sparks, _b.x, _b.y, global.pt_spark, 10);
		}
		array_delete(global.blast_queue, 0, _bn);
		break;
		
	case "LEVELUP":
		var _lvn = array_length(levelup_choices);
		var _lvd = (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D")))
				 - (keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A")));
		levelup_index = (levelup_index + _lvd + _lvn) mod _lvn;
		
		var _lmx = device_mouse_x_to_gui(0), _lmy = device_mouse_y_to_gui(0);
		var _lvh = -1;
		for (var i = 0; i < _lvn; i++) {
			var _lr = scr_card_rect(i, _lvn);
			if (point_in_rectangle(_lmx, _lmy, _lr.x1, _lr.y1, _lr.x2, _lr.y2)) _lvh = i;
		}
		if ((_lmx != levelup_mx || _lmy != levelup_my) && _lvh != -1) levelup_index = _lvh;
		levelup_mx = _lmx;
		levelup_my = _lmy;
		
		var _lvc = -1;
		if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) _lvc = levelup_index;
		for (var i = 0; i < _lvn; i++) if (keyboard_check_pressed(ord("1") + i)) _lvc = i;
		if (mouse_check_button_pressed(mb_left) && _lvh != -1) _lvc = _lvh;
		
		if (_lvc != -1) {
			var _lvid = levelup_choices[_lvc];
			scr_give_item(_lvid);
			var _lvit = global.item_db[$ _lvid];
			global.toast = { text: _lvit.name, sub: _lvit.desc, color: scr_rarity_color(_lvit.rarity), timer: game_get_speed(gamespeed_fps) * 4 };
			global.levelups_pending--;
			global.game_state = "PLAYING";
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
	case "VICTORY":
		victory_index = scr_menu_nav(victory_index, array_length(victory_options));
		var _vpick = scr_menu_pick(victory_index, array_length(victory_options));
		if (_vpick != -1) {
			if (_vpick == 0) room_goto(rm_hideout);
			else { quit_confirm = true; quit_confirm_index = 1; }
			io_clear();
		}
		break;
		
	case "SPREAD":
		var _sn = array_length(global.spread);
		var _smx = device_mouse_x_to_gui(0), _smy = device_mouse_y_to_gui(0);
		spread_index = -1;
		for (var i = 0; i < _sn; i++) {
			var _sr = scr_card_rect(i, _sn);
			if (point_in_rectangle(_smx, _smy, _sr.x1, _sr.y1, _sr.x2, _sr.y2)) spread_index = i;
		}

		if (keyboard_check_pressed(vk_escape) || mouse_check_button_pressed(mb_right)) {
			global.game_state = "HUB";
			io_clear();
		} else if (spread_mode == "reading") {
			if (keyboard_check_pressed(ord("R"))) scr_draw_spread();   // free redraws while testing
			if (mouse_check_button_pressed(mb_left) && spread_index != -1) global.spread_rev[spread_index] = !global.spread_rev[spread_index];
		} else if (mouse_check_button_pressed(mb_left) && spread_index != -1 && global.reagents > 0) {
			if (scr_reroll_spread_card(spread_index)) global.reagents--;
		}
		break;
		
		
}