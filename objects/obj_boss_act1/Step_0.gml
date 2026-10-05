if (scr_freeze_if_paused()) exit;
event_inherited();
if (hp <= 0 || !instance_exists(obj_player)) exit;
stun_timer = 0;                   // bosses shrug off stagger
knock_x = 0;
knock_y = 0;

var _fps = game_get_speed(gamespeed_fps);
if (phase == 1 && hp < max_hp * 0.5) {
	phase = 2;
	boss_speed *= 1.4;
	global.toast = { text: boss_name, sub: "enrages!", color: c_red, timer: _fps * 2 };
}
var _tick = (phase == 2) ? 1.6 : 1;

// move (and stop while winding up the slam)
if (slam_state == 1) {
	speed = 0;
} else {
	direction = point_direction(x, y, obj_player.x, obj_player.y);
	speed = boss_speed * speed_mult;
}

// summon: a ring of bats arrives from every direction
summon_timer -= _tick;
if (summon_timer <= 0) {
	summon_timer = _fps * 8;
	scr_pack_ring(obj_enemy_bat, (phase == 2) ? 26 : 14);
}

// slam: she marks where you are, then it lands about a second later
slam_timer -= _tick;
if (slam_state == 0 && slam_timer <= 0) {
	slam_state = 1;
	slam_wind = _fps * 1.2;
	slam_x = obj_player.x;
	slam_y = obj_player.y;
} else if (slam_state == 1) {
	slam_wind--;
	if (slam_wind <= 0) {
		if (point_distance(slam_x, slam_y, obj_player.x, obj_player.y) < slam_radius) scr_damage_player(obj_player, 40);
		part_particles_create(global.ps_sparks, slam_x, slam_y, global.pt_spark, 60);
		slam_state = 0;
		slam_timer = _fps * 10;
	}
}