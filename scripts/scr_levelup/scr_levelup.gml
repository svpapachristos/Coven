function scr_souls_needed(_level){
	return floor(8 * power(1.12, _level - 1));
}
function scr_gain_souls(_v) {
	global.souls += _v * scr_stat("soul_gain", 1);
	while (global.souls >= global.souls_to_next) {
		global.souls -= global.souls_to_next;
		global.level++;
		global.souls_to_next = scr_souls_needed(global.level);
		global.levelups_pending++;
		scr_fire_event("levelup", { level: global.level });
	}

}

// Where a card is on screen (shared by drawing and clicking)
function scr_card_rect(_i, _count) {
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	var _w = _gw * 0.2, _h = _gh * 0.45, _gap = _gw * 0.03;
	var _total = _count * _w + (_count - 1) * _gap;
	var _x1 = (_gw - _total) / 2 + _i * (_w + _gap);
	var _y1 = _gh / 2 - _h / 2;
	return { x1: _x1, y1: _y1, x2: _x1 + _w, y2: _y1 + _h };
}

// Rolls 3 different items and opens a card screen
function scr_open_levelup() {
	var _picks = [];
	repeat (3) {
		var _id = scr_roll_item(undefined, _picks, ["charm", "scroll"]);
		if (is_undefined(_id)) break;
		array_push(_picks, _id);
	}
	if (array_length(_picks) == 0) { //nothing left to offer
		global.levelups_pending = max(0, global.levelups_pending - 1);
		return;
	}

	// testing shortcut: grab one of the three at random and keep playing
	if (global.auto_pick) {
		var _pick = _picks[irandom(array_length(_picks) - 1)];
		scr_give_item(_pick);
		var _it = global.item_db[$ _pick];
		global.toast = { text: _it.name, sub: _it.desc, color: scr_rarity_color(_it.rarity), timer: game_get_speed(gamespeed_fps) * 2 };
		global.levelups_pending--;
		return;
	}

	obj_game_controller.levelup_choices = _picks;
	obj_game_controller.levelup_index = 0;
	global.game_state = "LEVELUP";
	io_clear();
}

//Beat the first boss

function scr_act_complete() {
	global.game_state = "VICTORY";
	sr_essence_bank_run();
	with (obj_enemy_parent) {                 // everything left dies in one burst
		part_particles_create(global.ps_sparks, x, y, global.pt_spark, 4);
		instance_destroy();
	}
	obj_game_controller.victory_index = 0;
	io_clear();
}