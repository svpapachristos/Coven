global.game_state = "MENU"; // we playin; switch to start when we make a menu
//debug
global.debug_hud = false;


//Main Menu Options
menu_options = ["Start Run", "Quit"];
menu_index = 0;

//Pause Menu Options
pause_options = ["Resume", "Quit to Menu", "Quit to Desktop"];
pause_index = 0;



global.run_time = 0;
global.kill_count = 0;
global.slime_kill_count = 0;
global.bat_kill_count = 0;
global.pumpkin_kill_count = 0;
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