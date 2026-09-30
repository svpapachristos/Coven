//walk_speed = 3;
//shoot_timer = 0;
//image_index = 0;

state = "IDLE";

//HP and Mana
max_hp = 100;
hp = max_hp;

max_mana = 100;
mana = max_mana;
mana_regen = 10; //per second

//Wand Cast
alt_fire_cd = 0;
alt_fire_cost = 30;
alt_fire = scr_alt_chain_lightning; // our lightning script


//I-Frames
iframes = 0; //we all know what I-Frames are right?
hit_flash = 0;


//Attack and Directionals
facing_dir = 1;
can_shoot = true;
can_walk = true;
shoot_timer = 0;

attack_speed = 0.33 * WORLD_SCALE;
proj_speed = 2.5 * WORLD_SCALE;
move_speed = 2.5 * WORLD_SCALE;



