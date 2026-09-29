//We now index all enemies under a "parent" enemy that can sort each kill into what enemy was hit
if (other.object_index == obj_enemy_slime) {
	global.slime_kill_count += 1;
}


//Stat Trak!
global.kill_count += 1;

//Everyone Likes a clean map
instance_destroy(other);
instance_destroy(self);