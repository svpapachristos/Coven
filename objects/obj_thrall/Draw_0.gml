var _col = make_color_rgb(170, 140, 255); //ghostly violet
if (global.necro_frenzy > 0) _col = merge_color(_col, make_color_rgb(255, 120, 255), 0.5 + 0.5 * sin(current_time / 80 + orbit));
draw_sprite_ext(sprite_index, image_index, x, y + (1 - rise) * 10, flip, rise, 0, _col, 0.9);
