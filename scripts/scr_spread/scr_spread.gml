function scr_tarot_pool(_exclude = []) {
	var _pool = [];
	for (var i = 0; i < array_length(global.item_ids); i++) {
		var _id = global.item_ids[i];
		if (global.item_db[$ _id].rarity == "tarot" && !scr_array_has(_exclude, _id)) array_push(_pool, _id);
	}
	return _pool;
}

function scr_draw_spread() {
	var _pool = scr_tarot_pool();
	var _spread = [];
	repeat (min(3, array_length(_pool))) {
		var _i = irandom(array_length(_pool) - 1);
		array_push(_spread, _pool[_i]);
		array_delete(_pool, _i, 1);
	}
	global.spread = _spread
	global.spread_rev = [false, false, false];
}

function scr_reroll_spread_card(_i) {
	var _pool = scr_tarot_pool(global.spread);
	if (array_length(_pool) == 0) return false;
	global.spread[_i] = _pool[irandom(array_length(_pool) - 1)];
	global.spread_rev[_i] = false;
	return true;
}

function scr_spread_card_id(_i) {
	return global.spread[_i] + (global.spread_rev[_i] ? "_rev" : "");
}

function scr_open_spread(_mode) {
	if (_mode == "reading" && array_length(global.spread) == 0) scr_draw_spread();
	global.game_state = "SPREAD";
	obj_game_controller.spread_mode = _mode;
	obj_game_controller.spread_index = -1;
	io_clear();
}

function scr_drop_item(_x, _y, _id) {
	var _p = instance_create_layer(_x, _y, "Instances", obj_pickup_item);
	_p.item_id = _id;
	_p.pickup_color = scr_rarity_color(global.item_db[$ _id].rarity);
	return _p;
}

// Elites hand out cards from your reading, in order
function scr_spread_reward(_x, _y) {
	if (global.spread_next >= array_length(global.run_spread)) return scr_item_reward(_x, _y, "tarot"); //no reading = random tarot
	scr_drop_item(_x, _y, global.run_spread[global.spread_next]);
	global.spread_next++;
	return true;
}

// Draws one card inside rectangle _r (the caller sets draw_set_halign(fa_center))
function scr_draw_card(_r, _item_id, _selected, _footer = "") {
	var _it = global.item_db[$ _item_id];
	var _col = scr_rarity_color(_it.rarity);
	var _cx = (_r.x1 + _r.x2) / 2;
	draw_set_color(c_black);
	draw_set_alpha(0.85);
	draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, false);
	draw_set_alpha(1);
	draw_set_color(_selected ? c_white : _col);
	draw_rectangle(_r.x1, _r.y1, _r.x2, _r.y2, true);
	if (_selected) draw_rectangle(_r.x1 + 2, _r.y1 + 2, _r.x2 - 2, _r.y2 - 2, true);
	draw_set_color(_col);
	draw_text_transformed(_cx, _r.y1 + 30, _it.name, 2, 2, 0);
	draw_set_color(c_gray);
	draw_text(_cx, _r.y1 + 70, string_upper(_it.rarity));
	draw_set_color(c_white);
	draw_text_ext(_cx, _r.y1 + 120, _it.desc, 22, _r.x2 - _r.x1 - 40);
	draw_set_color(c_dkgray);
	draw_text(_cx, _r.y2 - 30, _footer);
	draw_set_color(c_white);
}