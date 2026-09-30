pickup_type = "NONE";
pickup_color = c_white;
pickup_range = 14 * WORLD_SCALE;     // how close counts as grabbed
magnet_range = 70 * WORLD_SCALE;     // when it starts drifting to you
magnet_speed = 2.5 * WORLD_SCALE;
life = game_get_speed(gamespeed_fps) * 15;   // despawns after 15 seconds
bob_t = random(360);