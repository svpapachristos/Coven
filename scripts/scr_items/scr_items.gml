function scr_array_has(_arr, _v) {
	for (var i = 0; i < array_length(_arr); i++) if (_arr[i] == _v) return true;
	return false;
}

// Warns in the Output window regarding items with empty stats

function scr_validate_items() {
	var _known = scr_known_stats();
	var _ids = variable_struct_get_names(global.item_db);
	var _kinds = ["add", "mult"];
	for (var i = 0; i < array_length(_ids); i++) {
		var _it = global.item_db[$ _ids[i]];
		for (var k = 0; k < 2; k++) {
			var _names = variable_struct_get_names(_it[$ _kinds[k]]);
			for (var j = 0; j < array_length(_names); j++) {
				if (!scr_array_has(_known, _names[j]))
					show_debug_message("ITEM WARNING: '" + _ids[i] + "' uses stat '" + _names[j] + "' but no code reads it");
			}
		}
	}
}

function scr_stat_entry(_name) {
	if (!struct_exists(global.stat_cache, _name)) global.stat_cache[$ _name] = { add: 0, mult: 1 };
	return global.stat_cache[$ _name];
}

function scr_rebuild_items() {
	global.item_counts = scr_item_counts();
	global.stat_cache = {};
	global.event_listeners = {};
	
	var _ids = variable_struct_get_names(global.item_counts);
	for (var i = 0; i < array_length(_ids); i++) {
		var _it = global.item_db[$ _ids[i]];
		var _n = global.item_counts[$ _ids[i]];
		
		var _names = variable_struct_get_names(_it.add);
		for (var j = 0; j < array_length(_names); j++) scr_stat_entry(_names[j]).add += _it.add[$ _names[j]] * _n;
		
		_names = variable_struct_get_names(_it.mult);
		for (var j = 0; j < array_length(_names); j++) scr_stat_entry(_names[j]).mult *= power(_it.mult[$ _names[j]], _n);
		
		if (struct_exists(_it, "triggers")) {
			var _evs =variable_struct_get_names(_it.triggers);
			for (var j = 0; j < array_length(_evs); j++) {
				if (!struct_exists(global.event_listeners, _evs[j])) global.event_listeners[$ _evs[j]] = [];
				array_push(global.event_listeners[$ _evs[j]], { fn: _it.triggers[$ _evs[j]], stacks: _n });
			}
		}
	}
}
		
		
// scr stat now acts as a stat lookup
function scr_stat(_name, _base) {
	if (!struct_exists(global.stat_cache, _name)) return _base;
	var _s = global.stat_cache[$ _name];
	return (_base + _s.add) * _s.mult;
}

function scr_give_item(_id) {
	array_push(global.run_items, _id);
	scr_rebuild_items();
}





/// Builds the item database and starts a fresh run inventory. Called from the game controllers create

function scr_items_init() {
	global.item_db = {
		health_stone: {
			name: "Philosophers Stone", rarity: "charm", tags: ["health"],
			desc: "Grants the weilder a fraction of everlasting life",
			add: { max_hp: 25 }, mult: {}
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
	scr_rebuild_items();
	scr_validate_items();
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