event_inherited();
max_hp = 1;
hp = 1;
contact_damage = 0;
hex = -1;
mask_index = spr_enemy_slime;
sprite_index = spr_hex_toad;               // the frog art (the hop pose is swapped in while it's in the air)
image_speed  = 0;
image_xscale = 2; image_yscale = 2;        // the art is about 22 pixels wide, so this matches the old code frog's size				   //drawn by code until art is ready
life = game_get_speed(gamespeed_fps) * 8;  //pops on its own eventually
pop_grace = 25;							   //a small grace period before the toad can pop
popping = false; // set right before it bursts, so only its own pop, or Unmaking can kill it
hop_timer = irandom(30);
hop_dir = random(360);
hop_t = 0;