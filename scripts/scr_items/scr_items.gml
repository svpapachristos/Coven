// everything our loadout can currently use, the item db will check this to see if its tags can match the loadout requires
function scr_loadout_tags() {
	var _tags = ["any"];
	if (!variable_global_exists("loadout") || !variable_global_exists("witch_db")) return _tags;
	var _parts = [
		global.witch_db[global.loadout.witch],
		global.wand_db[global.loadout.wand],
		global.familiar_db[global.loadout.familiar]
	];
	for (var i = 0; i < array_length(_parts); i++) {
		if (!struct_exists(_parts[i], "tags")) continue;
		var _t = _parts[i].tags;
		for (var j = 0; j < array_length(_t); j++) if (!scr_array_has(_tags, _t[j])) array_push(_tags, _t[j]);
	}
	return _tags;
}

// items with no requirement work universally, otherwise you would need atleast one of the tags the item asks for
function scr_item_fits_loadout(_it, _tags) {
	if (!struct_exists(_it, "req")) return true;
	for (var i = 0; i < array_length(_it.req); i++) if (scr_array_has(_tags, _it.req[i])) return true;
	return false;
}

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
				array_push(global.event_listeners[$ _evs[j]], { fn: _it.triggers[$ _evs[j]], stacks: _n * (struct_exists(_it, "power") ? _it.power : 1) });
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
	var _it = global.item_db[$ _id];
	var _c = struct_exists(_it, "corruption") ? _it.corruption : ((_it.rarity == "corrupted") ? 10 : 0);
	if (_c > 0) scr_add_corruption(_c);
}





/// Builds the item database and starts a fresh run inventory. Called from the game controllers create

function scr_items_init() {
	global.item_db = {
		
		// Basic Charms
		health_stone: {
			name: "Vidas Stone", rarity: "charm", tags: ["max health"],
			desc: "+25 max health",
			add: { max_health: 25 }, mult: {}
		},
		black_candle:   { name: "Black Candle",   rarity: "charm",  tags: ["arcane"],
			desc: "Your witch ability recharges 15% faster.", 
			add: {}, mult: { ability_cooldown: 0.85 } 
		},
		soul_coin:  { name: "Soul Coin",  rarity: "charm",  tags: ["souls"],
			desc: "Gain 15% more souls.", 
			add: {}, mult: { soul_gain: 1.15 } 
		},
		ember_crystal:    { name: "Ember Crystal",    rarity: "charm",  tags: ["fire"],
			desc: "Burning deals 30% more damage and lasts 1 second longer.", 
			add: { burn_duration: 1 }, mult: { burn_damage: 1.3 }, req: ["fire"]
		},
		frost_charm:    { name: "Frostbitten Charm", rarity: "charm", tags: ["ice"],
			desc: "Chill slows enemies more and lasts longer.", 
			add: { chill_slow: 0.15, chill_duration: 1 }, mult: {},  req: ["ice"]
		},
		mana_fruit: {
			name: "Mana Fruit", rarity: "charm", tags: ["max mana"],
			desc: "+25 maximum mana. ",
			add: { max_mana: 25 }, mult: {},
		},
		mana_crystal: {
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
		raven_feather:  { name: "Raven Feather",  rarity: "charm",  tags: ["ultimate"],
			desc: "Your ultimate charges 20% faster.", 
			add: {}, mult: { ultimate_charge_rate: 1.2 } 
		},
		grave_bell: { name: "Grave Bell", rarity: "charm", tags: ["summons"], req: ["necromancer"],
			desc: "Your army can hold 8 more thralls.",
			add: { army_cap: 8 }, mult: {}
		},
		marrow_charm: { name: "Marrow Charm", rarity: "charm", tags: ["summons"], req: ["necromancer"],
			desc: "Thralls deal 20% more damage.",
			add: {}, mult: { thrall_damage: 1.2 }
		},
		ossuary_scroll: { name: "Ossuary Scroll", rarity: "scroll", tags: ["summons"], req: ["necromancer"],
			desc: "Raise the Fallen pulls up 5 more of the dead.",
			add: { raise_count: 5 }, mult: {}
		},
		focusing_lens: { name: "Focusing Lens", rarity: "scroll", tags: ["arcane"], req: ["beam"],
			desc: "Your beam reaches 25% further.",
			add: {}, mult: { beam_length: 1.25 }
		},
		
		//Scroll Tier
		fractal_lens:   { name: "Fractal Lens",   rarity: "scroll",  tags: ["arcane", "wand"],
			desc: "Your Arcane Wand fires an additional bolt", 
			add: { primary_count: 1 }, mult: {}, req: ["bolt"]
		},
		scroll_tempest:  { name: "Tempest Scroll", rarity: "scroll", tags: ["lightning"],
			desc: "Chain lightning jumps to 2 more enemies.", 
			add: { chain_targets: 2 }, mult: {},  req: ["lightning"] 
		},
		scroll_artificer:    { name: "Artificer Scroll", rarity: "scroll", tags: ["arcane"],
			desc: "Magic missiles deal 40% more damage.", 
			add: {}, mult: { primary_damage: 1.4 },  req: ["arcane"]
		},
		scroll_haste:   { name: "Haste Scroll", rarity: "scroll", tags: ["wand"],
			desc: "Your wand fires 15% faster.", 
			add: {}, mult: { attack_speed: 1.15 } 
		},
		
		//Corrupted Tier
		storm_crystal: {
			name: "Corrupted Stormcaller's Crystal", rarity: "corrupted", tags: ["lightning", "mana"],
			desc: "Corrupts the reader with eldritch energy, making their magic stronger, but more costly",
			add: {}, mult: { alt_damage: 2, alt_drain: 4.5 } 
		},
		
		//Tarot Tier
		tarot_fool: { // 0
			name: "The Fool", rarity: "tarot", tags: ["tarot", "fool" ],
			desc: "Beginnings. Spontaneity. Unlimited and untold potential",
			add: {}, mult: {}
		},
		tarot_magician: { // I
			name: "The Magician", rarity: "tarot", tags: ["tarot", "mana"],
			desc: "Manifestation. Resourcefulness. The Power to turn your Ideas to Reality.",
			add: { infinite_mana: 1 }, mult: {}, weight: 3, min_time: 600, max_stacks: 1
		}, 
		tarot_highpriestess: { // II
			name: "The High Priestess", rarity: "tarot", tags: ["tarot"], 
			desc: "Intuition. Sacred Knowledge. The ability to choose correctly when the time comes.",
			add: {}, mult: {}
			},
		tarot_empress: { // III
			name: "The Empress", rarity: "tarot", tags: ["tarot"],
			desc: "Growth. Abundance. Nurturing energy and a deep connection to the natural world.",
			add: {}, mult: {}
		},
		tarot_emperor: { // IV
			name: "The Emperor", rarity: "tarot", tags: ["tarot"], 
			desc: "Authority.", 
			add: {}, mult: {}
			},
		tarot_heirophant: { // V
			name: "The Heirophant", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_lovers: { // VI
			name: "The Lovers", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_chariot: { // VII
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_strength: { //VIII
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_hermit: { //IX
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_wheel: { //X
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_justice: { //XI
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_hman: { //XII
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_death: { //XIII
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_temperance: { //XIV
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_devil: { //XV
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_tower: { //XVI 
			name: "The Tower", rarity: "tarot", tags: ["tarot", "explosive"], 
			desc: "Upheaval. Every enemy that dies detonates, and the blast can set off the next.", 
			add: {}, mult: {}, weight: 3, max_stacks: 1,
			triggers: { kill: scr_trig_tower } 
		},
		tarot_star: { //XVII
			name: "The Placeholder", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_moon: { //XVIII
			name: "The Moon", rarity: "tarot", tags: ["tarot", "placeholder"],
			add: {}, mult: {}
		},
		tarot_sun: { //XIX
			name: "The Sun", rarity: "tarot", tags: ["tarot", "ability"], 
			desc: "Radiance. Your witch ability barely has a cooldown.", weight: 3, max_stacks: 1,
			add: {}, mult: { ability_cooldown: 0.05, ability_damage: 1.5 } 
			},
		tarot_judgement: { //XX
			name: "Judgement", rarity: "tarot", tags: ["tarot", "placeholder"],
			desc: "Placeholder. the ability to place holders in places that need holding.",
			add: {}, mult: {}
		},
		tarot_world: { //XXI
			name: "The World", rarity: "tarot", tags: ["tarot", "time"],
			desc: "Completion. Wholeness. Dance around your enemies as if Time itself answers to you.",
			add: {}, mult: {}
		},
		//REALLY? ALL 22 MAJOR ARCANA? YES

	};  //close the item db
	global.item_ids = variable_struct_get_names(global.item_db);
	scr_normalize_items();
	for (var i = 0; i < array_length(global.item_ids); i++) {
		if (global.item_db[$ global.item_ids[i]].rarity == "tarot") scr_make_reversed(global.item_ids[i]);
	}
	scr_tarot_placeholders();
	global.run_items = [];
	scr_rebuild_items();
	scr_validate_items();
}// close the function

/// Registers any of the 22 Major Arcana that don't have a real entry yet, as inert placeholders.
/// A real card's id must be exactly "tarot_<key>" (tarot_tower, tarot_sun, ...).
function scr_tarot_placeholders() {
	var _cards = [
		["fool", "The Fool"], ["magician", "The Magician"], ["priestess", "The High Priestess"],
		["empress", "The Empress"], ["emperor", "The Emperor"], ["hierophant", "The Hierophant"],
		["lovers", "The Lovers"], ["chariot", "The Chariot"], ["strength", "Strength"],
		["hermit", "The Hermit"], ["fortune", "Wheel of Fortune"], ["justice", "Justice"],
		["hanged", "The Hanged Man"], ["death", "Death"], ["temperance", "Temperance"],
		["devil", "The Devil"], ["tower", "The Tower"], ["star", "The Star"],
		["moon", "The Moon"], ["sun", "The Sun"], ["judgement", "Judgement"], ["world", "The World"]
	];
	var _done = 0;
	for (var i = 0; i < array_length(_cards); i++) {
		var _id = "tarot_" + _cards[i][0];
		if (struct_exists(global.item_db, _id)) { _done++; continue; }
		global.item_db[$ _id] = {
			name: _cards[i][1], rarity: "tarot", tags: ["tarot"],
			desc: "(not designed yet)", add: {}, mult: {},
			weight: 3, max_stacks: 1, placeholder: true
		};
	}
	show_debug_message("TAROT: " + string(_done) + " of " + string(array_length(_cards)) + " designed");
}

// Builds <id>_rev - same card, stronger, corrupts the player
function scr_make_reversed(_id) {
	var _src = global.item_db[$ _id];
	var _rev = {};
	var _keys = variable_struct_get_names(_src);
	for (var i = 0; i < array_length(_keys); i++) _rev[$ _keys[i]] = _src[$ _keys[i]];
	
	_rev.name = _src.name + " (Reversed)";
	_rev.desc = _src.desc + " [Reversed: Stronger, but gives +50 Corruption]";
	_rev.reversed = true;
	_rev.corruption = 15;
	_rev.power = 1.5; // how much it multiplies the triggers of an item, this basically increases the reveres tarots power by 50%
	_rev.add = {};
	_rev.mult = {};
	var _n = variable_struct_get_names(_src.add);
	for (var j = 0; j < array_length(_n); j++) _rev.add[$ _n[j]] = _src.add[$ _n[j]] * 1.5;
	_n = variable_struct_get_names(_src.mult);
	for (var j = 0; j < array_length(_n); j++) _rev.mult[$ _n[j]] = power(_src.mult[$ _n[j]], 1.5);
	
	global.item_db[$ _id + "_rev"] = _rev;
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

function scr_roll_item(_type = undefined, _exclude = [], _allowed = undefined) {
	static _type_weight = { charm: 100, scroll: 40, corrupted: 15, tarot: 5 };
	var _pool = [], _total = 0;
	var _loadout = scr_loadout_tags();
	for (var i = 0; i < array_length(global.item_ids); i++) {
		var _id = global.item_ids[i];
		var _it = global.item_db[$ _id];
		if (!is_undefined(_type) && _it.rarity != _type) continue;
		if (!is_undefined(_allowed) && !scr_array_has(_allowed, _it.rarity)) continue;
		if (scr_array_has(_exclude, _id)) continue;
		if (!scr_item_fits_loadout(_it, _loadout)) continue;
		if (struct_exists(_it, "min_time") && global.run_time < _it.min_time ) continue;
		
		var _owned = struct_exists(global.item_counts, _id) ? global.item_counts[$ _id] : 0;
		if (struct_exists(_it, "max_stacks") && _owned >= _it.max_stacks) continue;
		
		var _w = struct_exists(_it, "weight") ? _it.weight
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

/// Gives every item the fields the rest of the code expects, and says which ones were missing
function scr_normalize_items() {
	var _ids = variable_struct_get_names(global.item_db);
	for (var i = 0; i < array_length(_ids); i++) {
		var _it = global.item_db[$ _ids[i]];
		if (!struct_exists(_it, "add"))  { _it.add = {};  show_debug_message("ITEM FIX: '" + _ids[i] + "' had no add, using {}"); }
		if (!struct_exists(_it, "mult")) { _it.mult = {}; show_debug_message("ITEM FIX: '" + _ids[i] + "' had no mult, using {}"); }
		if (!struct_exists(_it, "tags")) _it.tags = [];
		if (!struct_exists(_it, "desc")) _it.desc = "(no description)";
		if (!struct_exists(_it, "name")) _it.name = _ids[i];
	}
}