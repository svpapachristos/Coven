var _in_hub = (room == rm_hideout);
if (!variable_global_exists("boot_done")) global.boot_done = false; // false until the first time Play is pressed after startup

// for now, the hideout (room) will show the title screen once, then go straight into roaming
if (_in_hub) global.game_state = global.boot_done ? "HUB" : "MENU";
else global.game_state = "PLAYING";

pending_run_start = !_in_hub; // run room; applies loadout once player exists in the room
pending_hub_setup = _in_hub; //hideout: same, so your witch wand and familiar are ready

scr_loadout_init();
scr_elements_init();

//Item Banner for pickups
global.toast = undefined;
global.next_item_at = 25;

//debug
global.debug_hud = false;

station_step = 0;  // 0 = witch, 1 = wand, 2 = familiar
station_index = 0;
pause_return = "PLAYING";

//Main Menu Options
menu_options = ["Play", "Quit"];
menu_index = 0;

//Pause Menu Options
pause_options = _in_hub ? ["Resume", "Quit to Desktop"] : ["Resume", "Abandon Run", "Quit to Desktop"];
pause_index = 0;

//End of Run Screen Options
end_options = ["New Run", "Return to Hideout", "Quit to Desktop"];
end_index = 0;

//Essence
global.essence = 0;
global.level = 1;
global.essence_to_next = scr_essence_needed(1);
global.levelups_pending = 0;
levelup_choices = [];
levelup_index = 0;
levelup_mx = -1;
levelup_my = -1;

//"Final" Boss
global.boss_down = false;
global.blast_queue = [];
victory_options = ["Return to Hideout", "Quit to Desktop"];
victory_index = 0;

//Tryin somethin new here..
global.corruption = 0;

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


//some TAROT STUFFFFFF
if (!variable_global_exists("spread")) {
	global.spread = [];
	global.spread_rev = [];
	global.run_spread = [];
	global.reagents = 0;
}
global.spread_next = 0;
spread_mode = "reading";
spread_index = -1;

// Sparky sparks
if (!variable_global_exists("ps_sparks") || !part_system_exists(global.ps_sparks)) {
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

}

scr_items_init();