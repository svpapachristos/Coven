if (scr_freeze_if_paused()) exit;


//rolls outward fast, reaching full size in about a quarter of a second
r = min(max_r, r + max_r / 14);

//curse everything the wave front passes over, once each
var _list = ds_list_create();
var _n = collision_circle_list(x, y, r, obj_enemy_parent, false, true, _list, false);
for (var i = 0; i < _n; i++) {
	var _e = _list[| i];
	if (_e.hex < 0 || _e.last_hex_wave == id) continue; // toads and already hexed enemies
	_e.last_hex_wave = id;
	scr_hex_apply(_e, hex_amt);
	if (dmg > 0) scr_damage_enemy(_e, dmg, HEX_VIOLET, irandom(2) == 0);
}
ds_list_destroy(_list);

if (r >= max_r) {
	fade--;
	if (fade <= 0) instance_destroy();
}