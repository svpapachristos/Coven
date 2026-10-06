#macro CORRUPTION_MAX 100

function scr_add_corruption(_n){
	global.corruption = clamp(global.corruption + _n, 0, CORRUPTION_MAX);
}

// 0 Clean , 1 Touched, 2 Marked, 3 Consumed
function scr_corruption_stage() {
	if (global.corruption >= 75) return 3;
	if (global.corruption >= 50) return 2;
	if (global.corruption >= 25) return 1;
	return 0;
}

function scr_corruption_stage_name(_stage) {
	return ["Clean", "Touched", "Marked", "Consumed"][_stage];
}