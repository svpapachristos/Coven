// the sky art is cached for the whole run (scr_hex_sky_art_free clears it when a new run starts)
sprite_delete(spr_glow);
sprite_delete(spr_dot);
if (surface_exists(snap)) surface_free(snap);
if (surface_exists(world_surf)) surface_free(world_surf);
// bring back everything hidden for the clean frame
for (var i = 0; i < array_length(hidden); i++) { var _hi = hidden[i]; if (instance_exists(_hi)) _hi.visible = true; }