event_inherited();
// a slime of a random color: the same slime, but a different gas when the Hexweaver unmakes it
if (variable_global_exists("slime_sprites")) {
	sprite_index = global.slime_sprites[irandom(array_length(global.slime_sprites) - 1)];
	mask_index   = spr_enemy_slime;   // the same hitbox whatever its color
}
contact_damage = 10;
alarm[0] = game_get_speed(gamespeed_fps) * 1; // 1 second timer for the alarm. which is our dash based movement