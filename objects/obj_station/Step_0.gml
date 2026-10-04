if (!instance_exists(obj_player)) exit;
near = (global.game_state == "HUB") && point_distance(x, y, obj_player.x, obj_player.y) < interact_range;
if (near && keyboard_check_pressed(ord("F"))) interact();

if (near) {
	draw_set_halign(fa_center);
	draw_text_transformed(x, y - 48, "[F] " + label, 2, 2, 0);
	draw_set_halign(fa_left);
}