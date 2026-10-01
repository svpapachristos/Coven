draw_set_halign(fa_center);
draw_set_valign(fa_bottom);


draw_set_alpha(alpha);
draw_set_color(number_color);
draw_set_color(c_black);
draw_text_transformed(x + 1, y + 1, string(dmg_amount), number_scale*1.1, number_scale*1.1, 0);
draw_set_color(number_color);
draw_text_transformed(x, y, string(dmg_amount), number_scale, number_scale, 0);
draw_set_alpha(1); // reset so it doesnt affect anything drawn after
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);