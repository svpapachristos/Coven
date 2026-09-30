//Collision between player and parent(any) enemy
var _e = instance_place(x, y, obj_enemy_parent);
if (_e != noone && iframes <= 0) {
	hp -= _e.contact_damage;
	iframes = game_get_speed(gamespeed_fps) * 0.75;
	if (hp <= 0) global.game_state = "DEAD";
}




if (global.game_state != "PLAYING") exit;



