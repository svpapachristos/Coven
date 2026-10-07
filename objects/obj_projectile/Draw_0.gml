var _c = (is_undefined(element)) ? c_white : scr_element_color(element);

gpu_set_blendmode(bm_add);

//a soft halo behind the bolt
draw_set_color(_c);
draw_set_alpha(0.25);
draw_circle(x, y, 14, false);
draw_set_alpha(0.35);
draw_circle(x, y, 8, false);

// the bolt itself, drawn twice so the light combines for a brighter bolt
draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, _c, 1);
draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, c_white, 0.05);
gpu_set_blendmode(bm_normal);
draw_set_alpha(1);
draw_set_color(c_white);