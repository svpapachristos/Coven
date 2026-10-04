scr_damage_enemy(other, damage, scr_element_color(element), true);
scr_apply_element(other, element);
part_particles_create(global.ps_sparks, x, y, global.pt_spark, 5);
instance_destroy();