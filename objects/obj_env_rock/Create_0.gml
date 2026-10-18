// A loose stone: the first environment object. Everything it does (sliding, being lifted, weight, landing,
// hitting enemies, its shadow) comes from obj_env_parent; this only says what kind of thing it is.
event_inherited();
material = "stone";
r = 10;
weight = 1;
if (irandom(2) == 0) sprite_index = spr_env_mossystone;   // about one in three is mossy
