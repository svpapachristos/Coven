function scr_array_has(_arr, _v) {
	for (var i = 0; i < array_length(_arr); i++) if (_arr[i] == _v) return true;
	return false;
}


//fire a game event, items that declare a trigger for it react
function scr_fire_event(_name, _ctx = {}) {
	if (!struct_exists(global.event_listeners, _name)) return;
	var _list = global.event_listeners[$ _name];
	for (var i = 0; i < array_length(_list); i++) _list[i].fn(_ctx, _list[i].stacks);
}

// event names the game actually fires. add one here when you add a new fire point.
function scr_known_events(){
	return["kill", "cast", "levelup"];
}

// Warns in the Output window regarding items with empty stats

function scr_validate_items() {
	var _known = scr_known_stats();
	var _ids = variable_struct_get_names(global.item_db);
	var _kinds = ["add", "mult"];
	for (var i = 0; i < array_length(_ids); i++) {
		var _it = global.item_db[$ _ids[i]];
		for (var k = 0; k < 2; k++) {
			if (struct_exists(_it, "triggers")) {
				var _names = variable_struct_get_names(_it[$ _kinds[k]]);
				for (var j = 0; j < array_length(_names); j++) {
					if (!scr_array_has(_known, _names[j]))
						show_debug_message("ITEM WARNING: '" + _ids[i] + "' uses stat '" + _names[j] + "' but no code reads it");
				}
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
		
		// Basic Charms
		health_stone: {
			name: "Shattered Philosophers Stone", rarity: "charm", tags: ["max health"],
			desc: "+25 max health",
			add: { max_health: 25 }, mult: {}
		},
		black_candle:   { name: "Black Candle",   rarity: "charm",  tags: ["arcane"],
			desc: "Your witch ability recharges 15% faster.", 
			add: {}, mult: { ability_cooldown: 0.85 } 
		},
		soul_coin:  { name: "Soul Coin",  rarity: "charm",  tags: ["essence"],
			desc: "Gain 15% more essence.", 
			add: {}, mult: { essence_gain: 1.15 } 
		},
		ember_crystal:    { name: "Ember Crystal",    rarity: "charm",  tags: ["fire"],
			desc: "Burning deals 30% more damage and lasts 1 second longer.", 
			add: { burn_duration: 1 }, mult: { burn_damage: 1.3 } 
		},
		frost_charm:    { name: "Frostbitten Charm", rarity: "charm", tags: ["ice"],
			desc: "Chill slows enemies more and lasts longer.", 
			add: { chill_slow: 0.15, chill_duration: 1 }, mult: {} 
		},
		star_chart:     { name: "Star Chart",     rarity: "charm",  tags: ["arcane"],
			desc: "Magic missile fires 1 extra dart.", 
			add: { missile_count: 1 }, mult: {} 
		},
		raven_feather:  { name: "Raven Feather",  rarity: "charm",  tags: ["ultimate"],
			desc: "Your ultimate charges 20% faster.", 
			add: {}, mult: { ultimate_charge_rate: 1.2 } 
		},
		soul_lantern:   { name: "Soul Lantern",   rarity: "charm",  tags: ["mana"],
			desc: "Level ups restore 25% of your mana.", 
			add: {}, mult: {},
			triggers: { levelup: scr_trig_soul_lantern } 
		},
		mana_fruit: {
			name: "Mana Fruit", rarity: "charm", tags: ["max mana"],
			desc: "+25 maximum mana. ",
			add: { max_mana: 25 }, mult: {},
		},
		mana_fruit: {
			name: "Mana Crystal", rarity: "charm", tags: ["mana regen"],
			desc: "Increases mana regen rate by 10%",
			add: {}, mult: { mana_regen: 1.10 }
		},
		hags_tooth: {
			name: "Hag's Tooth", rarity: "charm", tags: ["health"],
			desc: "Kills havea 5% chance to restore health",
			add: {}, mult: {},
			triggers: { kill: scr_trig_hags_tooth }
		},
		
		//Scroll Tier
		scroll_tempest:  { name: "Tempest Scroll", rarity: "scroll", tags: ["lightning"],
			desc: "Chain lightning jumps to 2 more enemies.", 
			add: { chain_targets: 2 }, mult: {} 
		},
		scroll_artificer:    { name: "Artificer Scroll", rarity: "scroll", tags: ["arcane"],
			desc: "Magic missiles deal 40% more damage.", 
			add: {}, mult: { missile_damage: 1.4 } 
		},
		scroll_haste:   { name: "Haste Scroll", rarity: "scroll", tags: ["wand"],
			desc: "Your wand fires 15% faster.", 
			add: {}, mult: { attack_speed: 1.15 } 
		},
		
		//Corrupted Tier
		storm_crystal: {
			name: "Corrupted Stormcaller's Crystal", rarity: "corrupted", tags: ["lightning", "mana"],
			desc: "Corrupts the reader with eldritch energy, making their magic stronger, but more costly",
			add: {}, mult: { chain_damage: 2, chain_drain: 4.5 } 
		},
		
		//Tarot Tier
		tarot_magician: {
			name: "The Magician", rarity: "tarot", tags: ["tarot", "mana"],
			desc: "Manifestation. Resourcefulness. The Power to turn your Ideas to Reality.",
			add: { infinite_mana: 1 }, mult: {}, weight: 3, min_time: 600, max_stacks: 1
		},
		tarot_tower: { name: "The Tower", rarity: "tarot", tags: ["tarot", "explosive"], 
			desc: "Upheaval. Every enemy that dies detonates, and the blast can set off the next.", 
			add: {}, mult: {}, weight: 3, max_stacks: 1,
			triggers: { kill: scr_trig_tower } 
			},
		tarot_sun:   { name: "The Sun", rarity: "tarot", tags: ["tarot", "ability"], 
			desc: "Radiance. Your witch ability barely has a cooldown.", weight: 3, max_stacks: 1,
			add: {}, mult: { ability_cooldown: 0.05, ability_damage: 1.5 } 
			},
	};  //close the item db
	global.item_ids = variable_struct_get_names(global.item_db);
	global.run_items = [];
	scr_rebuild_items();
	scr_validate_items();
}// close the function
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

function scr_roll_item(_type = undefined, _exclude = [], _allowed = undefined) {
	static _type_weight = { charm: 100, scroll: 40, corrupted: 15, tarot: 5 };
	var _pool = [], _total = 0;
	
	for (var i = 0; i < array_length(global.item_ids); i++) {
		var _id = global.item_ids[i];
		var _it = global.item_db[$ _id];
		if (!is_undefined(_type) && _it.rarity != _type) continue;
		if (!is_undefined(_allowed) && !scr_array_has(_allowed, _it.rarity)) continue;
		if (scr_array_has(_exclude, _id)) continue;
		if (struct_exists(_it, "min_time") && global.run_time < _it.min_time ) continue;
		
		var _owned = struct_exists(global.item_counts, _id) ? global.item_counts[$ _id] : 0;
		if (struct_exists(_it, "max_stacks") && _owned >= _it.max_stacks) continue;
		
		var _w = struct_exists(_it, "weight") ? _it._type_weight
			: (struct_exists(_type_weight, _it.rarity) ? _type_weight[$ _it.rarity] : 50);
		array_push(_pool, { id: _id, w: _w });
		_total += _w;
	}
	if (array_length(_pool) == 0) return undefined;
	
	var _r = random(_total);
	for (var i = 0; i < array_length(_pool); i++) {
		_r -= _pool[i].w;
		if (_r <= 0) return _pool[i].id;
	}
	return _pool[array_length(_pool) - 1].id;
}