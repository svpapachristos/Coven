event_inherited();


//Health
max_hp = 350;
hp = max_hp;

//Move speed, + preferred distance
move_speed = random_range(1.8, 2.2) * SPEED_SCALE * speed_mult;
preferred_distance = 85 * WORLD_SCALE;
distance_margin = 20 * WORLD_SCALE;

//Attacks
contact_damage = 75;
attack_cooldown_max = game_get_speed(gamespeed_fps) * 2;
attack_cooldown = attack_cooldown_max;
fireball_speed = 14 * SPEED_SCALE;

//Pumpkin Essence + Drop Chance
essence_value = 5;
drop_chance = 0.5;