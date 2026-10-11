// the sky art is cached for the whole run (scr_hex_sky_art_free clears it when a new run starts)
// spr_glow, spr_dot, spr_px and spr_soft are kept for the whole game now (global.hex_fx), so they're not deleted here
if (surface_exists(snap)) surface_free(snap);
if (surface_exists(sky_a)) surface_free(sky_a);
if (surface_exists(sky_b)) surface_free(sky_b);
if (surface_exists(world_surf)) surface_free(world_surf);
// bring back everything hidden for the clean frame
for (var i = 0; i < array_length(hidden); i++) { var _hi = hidden[i]; if (instance_exists(_hi)) _hi.visible = true; }
global.hex_last_peek = current_time; // her universe keeps living from this moment until she looks again
if (gaze) global.game_state = gaze_state_was;   // the world comes back to life after just watching

window_set_cursor(cr_default);   // in case the HUD (and cursor) were hidden while sitting in her universe
