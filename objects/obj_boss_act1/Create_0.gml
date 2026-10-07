event_inherited();
is_boss = true;
boss_name = "The Shroom-Mother";
max_hp = 8000 * (1 + global.corruption / 100); //more corrupted player = more hp
hp = max_hp;
contact_damage = 30;
soul_value = 200;
drop_chance = 0;
sep_strength = 0;                 // the swarm can't shove her around
image_xscale = 4;
image_yscale = 4;
boss_speed = 2.5 * SPEED_SCALE;
phase = 1;
var _fps = game_get_speed(gamespeed_fps);
summon_timer = _fps * 6;
slam_timer = _fps * 9;
slam_state = 0;                   // 0 = idle, 1 = telegraphing
slam_wind = 0;
slam_x = 0;
slam_y = 0;
slam_radius = 60 * WORLD_SCALE;