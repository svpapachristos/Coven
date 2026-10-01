/// Builds the item database and starts a fresh run inventory. Called from the game controllers create

function scr_items_init() {
	global.item_db = {
		health_stone: {
			name: "Philosophers Stone", rarity: "charm", tags: ["health"],
			desc: "Grants the weilder a fraction of everlasting life",
			add: { max_health: 25 }, mult: {}
		},
		fae_dust: {
			name: "Faerie Dust", rarity: "charm", tags: ["attack speed"],
			desc: "Imbues your Wand with a sprinkle of Fae Dust, overcharging its casting rate",
			add: {}, mult: { attack_speed: 1.10 }
		},
		storm_scroll: {
			name: "Corrupted Stormcaller's Scroll", rarity: "corrupted", tags: ["lightning", "mana"],
			desc: "Corrupts the reader with eldritch energy, making their magic stronger but more costly",
			add: {}, mult: { chain_damage: 2, chain_drain: 4.5 } 
		},
		tarot_magician: {
			name: "The Magician", rarity: "tarot", tags: ["tarot", "mana"],
			desc: "Manifestation. Resourcefulness. The Power to Turn Your Ideas to Reality.",
			add: { infinite_mana: 1 }, mult: {}
		}
	};
	global.item_ids = variable_struct_get_names(global.item_db);
	global.run_items = [];
}

/// Final value of a stat after every owned item's modifiers
function scr_stat(_name, _base) {
	var _add = 0, _mult = 1;
	for (var i = 0; i < array_length(global.run_items); i++) {
		var _it = global.item_db[$ global.run_items[i]];
		if (struct_exists(_it.add, _name)) _add += _it.add[$ _name];
		if (struct_exists(_it.mult, _name)) _mult *= _it.mult[$ _name];
	}
	return (_base + _add) * _mult;
}

function scr_give_item(_id) {
	array_push(global.run_items, _id);
}

function scr_give_random_item() {
	scr_give_item(global.item_ids[irandom(array_length(global.item_ids) - 1)]);
}

function scr_item_counts(){
	var _c = {};
	for (var i = 0; i < array_length(global.run_items); i++) {
		var _id = global.run_items[i];
		_c[$ _id] = struct_exists(_c, _id) ? _c[$ _id] + 1 : 1;
	}
	return _c;
}

function scr_rarity_color(_rarity) {
	switch (_rarity) {
		case "charm": return c_white;
		case "scroll": return c_lime;
		case "corrupted": return c_navy;
		case "tarot": return c_red;
	}
	return c_white;
}