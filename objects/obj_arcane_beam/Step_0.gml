if (scr_freeze_if_paused()) exit;
life--;
if (life <= 0 || !instance_exists(obj_player)) { instance_destroy(); exit; }

beam_line = scr_beam_line(obj_player, heat);

x = beam_line.x1;
y = beam_line.y1;
angle = beam_line.angle;

// sparks but working this time

var _half = scr_beam_half(heat);
repeat (2 + floor(heat * 5)) {
	var _t = random(1);
	var _spread = random_range(-_half, _half) * (0.2 + 0.8 * _t);
	var _px = lerp(beam_line.x1, beam_line.x2, _t) + lengthdir_x(_spread, angle + 90);
	var _py = lerp(beam_line.y1, beam_line.y2, _t) + lengthdir_y(_spread, angle + 90);
	part_particles_create(global.ps_sparks, _px, _py, global.pt_arcane, 1);
}
// beam dissipates at its far end
if (irandom(1) == 0) part_particles_create(global.ps_sparks, beam_line.x2, beam_line.y2, global.pt_arcane , 2);
global.shake = max(global.shake, 0.5 + 2.5 * heat); // makes the screen rumble as you hold your wands beam
