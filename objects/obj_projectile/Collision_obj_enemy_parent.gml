if (element == "arcane") part_particles_create(global.ps_sparks, x, y, global.pt_arcane, 6);
if (scr_array_has(hit_list, other)) exit; //each bolt hits an enemy only once
array_push(hit_list, other);
scr_damage_enemy(other, damage);
scr_apply_element(other, element);
if (pierce > 0) pierce--; else instance_destroy();