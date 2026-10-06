draw_self();
if (near) {
	draw_set_halign(fa_center);
	draw_text_transformed(x, y - 48, "[F] " + label, 2, 2, 0);
	draw_set_halign(fa_left);
}