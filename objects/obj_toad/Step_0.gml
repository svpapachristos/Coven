if (scr_freeze_if_paused()) exit;
event_inherited();
if (unmaking > 0) exit;
speed = 0;

//little hops in random directions
hop_timer--;
if (hop_timer <= 0) { hop_timer = irandom_range(25, 50); hop_dir = random(360);
	image_xscale = abs(image_xscale) * ((lengthdir_x(1, hop_dir) < 0) ? 1 : -1); hop_t = 12; }
if (hop_t > 0) {
	hop_t--;
	x += lengthdir_x(1.2, hop_dir);
	y += lengthdir_y(1.2, hop_dir);
	sprite_index = spr_hex_toad_hop;
} else sprite_index = spr_hex_toad;        // landed: back to sitting

life--;
pop_grace--;
if (pop_grace <= 0) {
	// anything that walks into it except for other toads
	var _touch = (life <= 0);
	if (!_touch && instance_exists(obj_thrall)) _touch = place_meeting(x, y, obj_thrall);
	if (!_touch) {
		var _o = instance_place(x, y, obj_enemy_parent);
		if (_o != noone && _o.object_index != obj_toad) _touch = true;
	}
	if (_touch) { scr_toad_pop(id); exit; }
}