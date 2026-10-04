function scr_select_db(_step) {
	switch (_step) {
		case 0: return global.witch_db;
		case 1: return global.wand_db;
		case 2: return global.familiar_db;
	}
}

function scr_loadout_init() {
	global.witch_db = [
		{ name: "Hedgewitch", desc: "A Naturalist with a connection to the earth and the secrets it holds.", ability: { name: "Placeholder Spell Hedge", cooldown: 10, fn: scr_flame_nova  }, ultimate: { name: "Placeholder Ult Hedge", charge_needed: 25, fn: scr_ultimate_place_holder } },
		{ name: "Elementalist", desc: "A Witch with a special connection to the wands she equips", ability: { name: "Placeholder Spell Element", cooldown: 10, fn: scr_flame_nova }, ultimate: { name: "Placeholder Ult Element", charge_needed: 25, fn: scr_ultimate_place_holder } },
		{ name: "Necromancer", desc: "A Necromancy Witch. Commander of the dead and dark forces that corrupt this world", ability: { name: "Placeholder Spell Necro", cooldown: 10, fn: scr_flame_nova }, ultimate: { name: "Placeholder Ult Necro", charge_needed: 25, fn: scr_ultimate_place_holder } },
		{ name: "Diviner", desc: "A Witch who sees the strands of time itself. Their knowledge of the arcane unbound.", ability: { name: "Placeholder Spell Oracle", cooldown: 10, fn: scr_flame_nova }, ultimate: { name: "Placeholder Ult Diviner", charge_needed: 25, fn: scr_ultimate_place_holder } }
	];
	global.wand_db = [
	{ name: "Witches Wand", element: "arcane", desc: "A witchwood wand of unaspected magicks. ", alt_fire: scr_magic_missile, alt_interval: 18 },
	{ name: "Strun", lement: "storm", desc: "An elderwood wand containing a Storm crystal. High Voltage!", alt_fire: scr_alt_chain_lightning },
	{ name: "Kenaz", element: "fire",  desc: "A silverwood wand containing a Cinder crystal. Feel the Burn.", alt_fire: scr_alt_chain_lightning },
	{ name: "Suvon", element: "ice",   desc: "An weirwood wand containing a Frost crystal. The blizzard is coming.", alt_fire: scr_alt_chain_lightning },
	{ name: "Vern", element: "earth", desc: "A maplewood wand containing a Terra crystal. Shatter them all.", alt_fire: scr_alt_chain_lightning },
	{ name: "Feng", element: "air",   desc: "A palmwood wand containing a Breeze crystal. Light as a feather,  ", alt_fire: scr_alt_chain_lightning }
	];
	global.familiar_db = [
		{ name: "Munin", desc: "Your first companion. This small bird remembers what was lost, more than most.", obj: obj_fam_raven },
		{ name: "Salem", desc: "A Witches best friend.", obj: obj_fam_cat},
		{ name: "Cenx", desc: "A friendly Wisp, wandering through wicked woods", obj: obj_fam_wisp }
	];
	if (!variable_global_exists("loadout")) global.loadout = { witch: 0, wand: 0, familiar: 0 };
} //if the loadout doesnt reset after a run, delete the if before global.loadout

function scr_select_options(_step) {
	var _db = scr_select_db(_step);
	var _names = [];
	for (var i = 0; i < array_length(_db); i++) array_push(_names, _db[i].name);
	return _names;
}

function scr_apply_loadout() {
	if (!instance_exists(obj_player)) return;
	var _wand = global.wand_db[global.loadout.wand];
	with (obj_player) {
		alt_fire = _wand.alt_fire;
		wand = _wand;
		witch = global.witch_db[global.loadout.witch];
		ability_cd = 0;
		ultimate_charge = 0;
		ultimate_charge_max = witch.ultimate.charge_needed;
	}
}

// Replaces familiar with whichever one is chosen
function scr_spawn_familiar() {
	with (obj_familiar_controller) instance_destroy();
	if (!instance_exists(obj_player)) return;
	var _fam = global.familiar_db[global.loadout.familiar];
	if (_fam.obj != -1) instance_create_layer(obj_player.x, obj_player.y, "Instances", _fam.obj);
}

function scr_start_run() {
	scr_apply_loadout();
	scr_spawn_familiar();
	global.game_state = "PLAYING";
	io_clear();
}

// step: 0 witch, 1 wand, 2 familiar
function scr_open_station(_step) {
	global.game_state = "STATION";
	
	var _keys = ["witch", "wand", "familiar"][_step];
	obj_game_controller.station_step = _step;
	obj_game_controller.station_index = global.loadout[$ _keys];
	
	io_clear();
}

// True while things should be moving (aka not dead or paused)
function scr_is_live(){
	return global.game_state == "PLAYING" || global.game_state == "HUB";
}