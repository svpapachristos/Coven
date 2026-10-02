var _start_run = variable_global_exists("start_run_after_restart")
	&& global.start_run_after_restart;
	
global.start_run_after_restart = false;
global.game_state = _start_run ? "PLAYING" : "MENU";

pending_run_start = _start_run;
scr_loadout_init();

//debug
global.debug_hud = false;

//scr_loadout_init();
select_step = 0;  // 0 = witch, 1 = wand, 2 = familiar
select_index = 0;

//Main Menu Options
menu_options = ["Start Run", "Quit"];
menu_index = 0;

//Pause Menu Options
pause_options = ["Resume", "Quit to Menu", "Quit to Desktop"];
pause_index = 0;

//End of Run Screen Options
end_options = ["New Run", "Back to Menu", "Quit Game"];
end_index = 0;

//global stats
global.run_time = 0;
global.kill_count = 0;
global.slime_kill_count = 0;
global.bat_kill_count = 0;
global.pumpkin_kill_count = 0;

//Quit Confirmation
quit_confirm_options = ["Yes, Quit", "Cancel"];
quit_confirm_index = 1; // Default to cancel
quit_confirm = false;

// Sparky sparks
global.ps_sparks = part_system_create();
part_system_depth(global.ps_sparks, -100); // in front of enemies and the player 

global.pt_spark = part_type_create();
part_type_shape(global.pt_spark, pt_shape_pixel);
part_type_size(global.pt_spark, 3, 6, -0.12, 0);		//may need adjusting
part_type_color3(global.pt_spark, c_white, c_aqua, c_blue);
part_type_alpha3(global.pt_spark, 1, 1, 0);		
part_type_speed(global.pt_spark, 2, 7, -0.2, 0); //so they burst up quick then fall slow
part_type_direction(global.pt_spark, 0, 359, 0, 0);
part_type_gravity(global.pt_spark, 0.15, 270);			//makes the sparks arc down
part_type_life(global.pt_spark, 12, 28);
part_type_blend(global.pt_spark, true);       // a bit of a glow

scr_items_init();