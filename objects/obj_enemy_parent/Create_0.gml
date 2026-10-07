max_hp = 200;
hp = max_hp;
contact_damage = 10;
drop_chance = 0.10; // 10% chance per kill, nice modifiable number to adapt to other item types

body_radius = 12;

sep_radius = 44;
sep_strength = 0.45;

//necromancer stats
thrall_claims = 0; //how many thralls are currently targeting this enemy

//arcane wand stats
beam_acc = 0;

//fire wand stats
burn_timer = 0; 
burn_dps = 0;
burn_tick = 0;

//ice wand stats
speed_mult = 1;
chill_timer = 0;
chill_slow = 0;

//earth wand stats
stun_timer = 0;

//air wand stats
knock_x = 0;
knock_y = 0;

//souls
soul_value = 1;

//elites and bosses
is_elite = false;
is_boss = false;
elite_drop = undefined;