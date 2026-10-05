function scr_trig_tower(_ctx, _stacks) {
	array_push(global.blast_queue, { x: _ctx.x, y: _ctx.y, dmg: scr_stat("tower_damage", 60) * _stacks, r: 120 * WORLD_SCALE });
}