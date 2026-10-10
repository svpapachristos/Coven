var _fps = game_get_speed(gamespeed_fps);

t = 0;
// the entrance's rhythm comes first, because everything after it waits for the world to break

lock_len   = 0;                    // no lead-in: the glitch IS the cast
glitch_len = floor(_fps * 0.7);   // reality glitches: windows onto her cosmos slash across the screen
still_len  = floor(_fps * 2);    // longer: her hex draws itself in the stillness now
tear_len   = floor(_fps * 0.3); // a crack runs in from the right edge, under her, and forks
gape_len   = floor(_fps * 0.95);  // the line of light holds, building, before the impact
slab_len   = floor(_fps * 2);   // how long the chunks take to drift away

// when each beat starts, counted from the cast
glitch_at  = lock_len;
still_at   = glitch_at + glitch_len;
tear_at    = still_at + still_len;
shatter_at = tear_at + tear_len + gape_len;      // the ground breaks into chunks and starts to drift
birth_at   = shatter_at + floor(slab_len * 0.8); // the stardust begins once the chunks have mostly gone: just her and them
duration   = birth_at + _fps * 5.5;

// her nebula and sky for this cast, fuller the further she has ascended
if (!variable_global_exists("hex_neb") || is_undefined(global.hex_neb)) global.hex_neb = scr_hex_nebula_fields(global.hex_seed);
var _tier = scr_hex_tier();
var _covers  = [0.62, 0.53, 0.45, 0.37];
var _brights = [0.90, 1.00, 1.10, 1.20];
var _spins   = [0.25, 0.55, 0.8, 1.1];
nebula_cover = _covers[_tier - 1];
spin = _spins[_tier - 1];
sky_start = random(360);
sky_angle = sky_start;

// some black hole stuff
time_scale = 0.5; // 1 = normal, 0 = the sky stops turning (a collapsing star slows time)
hitstop    = 0;   // frames left of the frozen impact frame
impact_x   = 0;   // where on screen the collapse happens, for the impact frame
impact_y   = 0;
impact_kind = 0;  // which impact frame to draw: 0 = a black hole collapsing, 1 = the ground breaking

// the star birth's timing
rise_end    = birth_at + _fps * 1.4;  // silhouettes rise and fly out to their places, counted from the break
cascade_len = _fps * 1.6;  // then ignite one after another, nearest her first
finale_at   = rise_end + cascade_len + _fps * 0.15;
ignitions   = [];          // flashes of stars being born
pulsed      = false;
pulse_t     = -1;
seize_len = _fps * 0.8; // how long the whole horde takes to fill with light before it starts to unravel
seize_end = birth_at + seize_len;     // the moment the seized enemies start pouring into their stars
new_from = array_length(global.hex_stars); // every star at or past this index is born in THIS cast (#4)
plan_grid = {}; // planned stars filed by 20px cell ("x,y" -> array), so condensing only checks nearby cells

// handles for sh_starlit's settings, looked up once instead of every frame
u_sl_texel = shader_get_uniform(sh_starlit, "u_texel");
u_sl_uvs   = shader_get_uniform(sh_starlit, "u_uvs");
u_sl_fill  = shader_get_uniform(sh_starlit, "u_fill");
u_sl_time  = shader_get_uniform(sh_starlit, "u_time");
u_sl_rim   = shader_get_uniform(sh_starlit, "u_rim");

// a soft glow and a solid dot, each drawn ONCE in code and turned into a sprite.
// stamping a sprite is far cheaper than drawing a circle, and every star stamping the same one gets batched together
var _gs = surface_create(32, 32);
surface_set_target(_gs);
draw_clear_alpha(c_black, 1);                              // black adds nothing in additive mode, so black is "empty"
draw_circle_color(16, 16, 15, c_white, c_black, false);
surface_reset_target();
spr_glow = sprite_create_from_surface(_gs, 0, 0, 32, 32, false, false, 16, 16);
surface_set_target(_gs);
draw_clear_alpha(c_black, 1);
draw_set_color(c_white);
draw_circle(16, 16, 15, false);
surface_reset_target();
spr_dot = sprite_create_from_surface(_gs, 0, 0, 32, 32, false, false, 16, 16);
surface_free(_gs);


// gather the doomed: everything on screen she's strong enough to erase
var _cam = view_camera[0];
var _x0 = camera_get_view_x(_cam), _y0 = camera_get_view_y(_cam);
var _x1 = _x0 + camera_get_view_width(_cam), _y1 = _y0 + camera_get_view_height(_cam);
var _doomed = [];
with (obj_enemy_parent) {
	if (!point_in_rectangle(x, y, _x0, _y0, _x1, _y1)) continue;
	if (scr_hex_can_toad(id)) {
		scr_hex_plan_star(id, other.sky_angle);
		array_push(_doomed, { inst: id, d: point_distance(x, y, obj_player.x, obj_player.y) });
	} else {
		// elites and bosses she can't erase yet are fully cursed and torn at instead
		scr_hex_apply(id, 1);
		scr_damage_enemy(id, max_hp * (is_boss ? 0.1 : 0.25), HEX_VIOLET);
	}
}

// nearest her ignite first, so the wave of new stars ripples outward from her
array_sort(_doomed, function(_a, _b) { return _a.d - _b.d; });
var _n = array_length(_doomed);
for (var i = 0; i < _n; i++) {
	var _entry = _doomed[i];
	var _e = _entry.inst;
	_e.unmake_at = rise_end + ((_n > 1) ? i / (_n - 1) : 0) * cascade_len + 1;
	_e.unmaking = 0.001;
}

var _art = scr_hex_sky_art(_tier, nebula_cover, _brights[_tier - 1],
	ceil(point_distance(0, 0, camera_get_view_width(_cam), camera_get_view_height(_cam)) * 1.1));
nebula = _art.neb;
dust   = _art.dust;

// ---- the entrance: the world frozen in the instant she cast, about to crack and shatter ----
// the screen as it was last frame, copied into a sprite we can break into pieces
var _aw = surface_get_width(application_surface), _ah = surface_get_height(application_surface);
snap = -1;   // the photo of the bare world is taken next frame, in Draw GUI, straight into a surface
snap_x = _x0; snap_y = _y0;            // the snapshot sits exactly where the view was, in the world
snap_w = _x1 - _x0; snap_h = _y1 - _y0;
snap_sc = _aw / snap_w;   // snapshot pixels per world pixel (the screen isn't always drawn at the view's size)
world_surf = -1;          // the frozen world gets drawn in here first, so that it can be torn later


u_ts_center = shader_get_uniform(sh_timestop, "u_center");
u_ts_desat  = shader_get_uniform(sh_timestop, "u_desat");
u_ts_tint   = shader_get_uniform(sh_timestop, "u_tint");
u_ts_dark  = shader_get_uniform(sh_timestop, "u_dark");
u_ts_solid = shader_get_uniform(sh_timestop, "u_solid");

// the sphere's centre, and how far it has to reach to swallow every corner of the screen
var _cx = obj_player.x, _cy = obj_player.y;
crack_cx = _cx; crack_cy = _cy;
crack_R  = max(point_distance(_cx, _cy, _x0, _y0), point_distance(_cx, _cy, _x1, _y0),
               point_distance(_cx, _cy, _x0, _y1), point_distance(_cx, _cy, _x1, _y1)) + 10;

// ---- the clean frame: hide the doomed, her and her familiar for one frame, so the world can be photographed
// without them (Draw GUI Begin does it). the ground that breaks away then won't carry copies of them off with it
hidden = [];
for (var i = 0; i < _n; i++) array_push(hidden, _doomed[i].inst);
array_push(hidden, obj_player.id);
with (obj_familiar_controller) array_push(other.hidden, id);
with (obj_damage_number) array_push(other.hidden, id);   // floating numbers aren't part of the ground either
for (var i = 0; i < array_length(hidden); i++) { var _hi = hidden[i]; _hi.visible = false; }
clean_pending = true;
global.shake = 0;   // a still camera for the photograph

// ---- the tear: a crack runs in from the right edge of the world, under her feet, and forks just behind her,
// splitting the ground into three huge chunks: above, below, and a wedge between the fork.
// each chunk is a strip of columns between two edges (a crack or the screen's edge), which keeps it simple to draw
var _pad  = 400;                                              // the ground runs this far past every edge of the screen, so no shake or drift ever shows its end
tear_n    = ceil(32 * (snap_w + _pad * 2) / (snap_w + 160));  // more columns for the wider ground, so each stays as wide as before
tear_rows = 5;
var _x0t = snap_x - _pad, _x1t = snap_x + snap_w + _pad;
var _top = snap_y - _pad, _bot = snap_y + snap_h + _pad;
tear_x = [];
for (var _i = 0; _i <= tear_n; _i++) array_push(tear_x, lerp(_x0t, _x1t, _i / tear_n));
tear_mid  = (crack_cx - _x0t) / (_x1t - _x0t) * tear_n;   // her column
tear_fork = max(3, floor(tear_mid) - irandom_range(1, 5));     // the crack forks somewhere behind her, never quite the same spot
var _ph    = random(10);
var _fy    = crack_cy + 8;                                     // at her feet
var _vis  = max(2, tear_fork - _pad / (tear_x[1] - tear_x[0]));           // columns from the fork to the screen's left edge
var _rise = (crack_cy - snap_y) * random_range(0.12, 0.4) / _vis;          // each branch spreads its own amount,
var _fall = (snap_y + snap_h - crack_cy) * random_range(0.12, 0.4) / _vis; // so the fork is lopsided, never a neat V
var _bendu = random_range(-0.7, 0.7), _bendd = random_range(-0.7, 0.7);          // each branch curves its own way
var _slope = random_range(-0.15, 0.15);                                           // the main crack runs a little uphill or down
var _amp   = random_range(8, 30), _freq = random_range(0.25, 0.8);                // how much, and how tightly, it wanders
var _colw  = tear_x[1] - tear_x[0];
var _vc0  = floor(_pad / _colw);   // the first column that's on screen (the same count is off screen on the right)

// jogs: a few places where a crack suddenly steps sideways, the way real cracks follow weak spots in the ground.
// they build up away from the fork, so the crack stays joined at the fork
var _jogm = array_create(tear_n + 1, 0), _jogu = array_create(tear_n + 1, 0), _jogd = array_create(tear_n + 1, 0);
var _am = 0, _au = 0, _ad = 0;
for (var _i = tear_fork + 2; _i <= tear_n; _i++) {             // the main crack, from the fork out to the right
	if (random(1) < 0.18) _am += random_range(-40, 40);
	_jogm[_i] = _am;
}
for (var _i = tear_fork - 2; _i >= 0; _i--) {                  // the branches, from the fork out to the left
	if (random(1) < 0.2) _au += random_range(-30, 30);
	if (random(1) < 0.2) _ad += random_range(-30, 30);
	_jogu[_i] = _au; _jogd[_i] = _ad;
}

// the cracks, as a height at every column: the main one (right of the fork) and the two branches (left of it)
var _main = [], _up = [], _dn = [];
for (var _i = 0; _i <= tear_n; _i++) {
	var _d   = _i - tear_fork;                                   // columns right of the fork (negative = left of it)
	var _l   = max(0, -_d);                                      // columns left of the fork
	var _lf  = _l / tear_fork;                                   // 0 at the fork, 1 at the left edge
	var _wlu = sin(_l * _freq * 1.3 + _ph * 2) * _amp * 0.6 * min(1, _l / 2);   // each branch wanders on its own
	var _wld = sin(_l * _freq * 1.1 + _ph * 3.7) * _amp * 0.6 * min(1, _l / 2);
	array_push(_main, _fy + _d * _slope * _colw + sin(_d * _freq + _ph) * _amp * min(1, abs(_d) / 3) + _jogm[_i]
	                      + (scr_hash(_i * 7.3 + _ph) - 0.5) * 18 * min(1, abs(_d) / 2));
	var _yu = _fy - _l * _rise * (1 + _bendu * _lf) + _wlu + _jogu[_i] + (scr_hash(_i * 3.1 + _ph) - 0.5) * 22 * min(1, _l / 2);
	var _yd = _fy + _l * _fall * (1 + _bendd * _lf) + _wld + _jogd[_i] + (scr_hash(_i * 5.9 + _ph) - 0.5) * 22 * min(1, _l / 2);
		_yu = max(_yu, _top + 40); _yd = min(_yd, _bot - 40);            // far off screen the branches keep spreading: never past the ground's own edge
	if (_yd < _yu + 12 * min(1, _l)) _yd = _yu + 12 * min(1, _l);   // the two branches never cross
	array_push(_up, _yu); array_push(_dn, _yd);
}
// each chunk's upper and lower edge at every column
var _ta = [], _tb = [], _ba = [], _bb = [];
for (var _i = 0; _i <= tear_n; _i++) {
	array_push(_ta, _top);
	array_push(_tb, (_i < tear_fork) ? _up[_i] : _main[_i]);
	array_push(_ba, (_i < tear_fork) ? _dn[_i] : _main[_i]);
	array_push(_bb, _bot);
}
chunks = [
	{ i0: 0, i1: tear_n, up: _ta, lo: _tb, cx: crack_cx, cy: lerp(snap_y - 80, _fy, 0.5), rub: true, cu: false, cl: true,  // above: lifts away up
	  vx: random_range(-60, 60), vy: -random_range(1500, 1775), spin: random_range(-1, 1), grow: 0.05 },
	{ i0: 0, i1: tear_n, up: _ba, lo: _bb, cx: crack_cx, cy: lerp(_fy, snap_y + snap_h + 80, 0.5), rub: false, cu: true, cl: false, // below: sinks away down
	  vx: random_range(-60, 60), vy: random_range(550, 700), spin: random_range(-1, 1), grow: 0.05},
	{ i0: 0, i1: tear_fork, up: _up, lo: _dn, cx: lerp(snap_x - 80, tear_x[tear_fork], 0.5), cy: _fy, rub: true, cu: true, cl: true, // the wedge: tumbles toward us and past
	  vx: -random_range(350, 600), vy: random_range(-80, 80), spin: random_range(-1, 1), grow: 1.4 }
];

// pebbles knocked loose as the crack runs: rising and tumbling slowly in the stopped time
grit = [];
repeat (95) {
	var _gi = irandom_range(_vc0, tear_n - 1 - _vc0);
	var _gy = (_gi >= tear_fork) ? _main[_gi] : ((random(1) < 0.5) ? _up[_gi] : _dn[_gi]);
	array_push(grit, { i: _gi, px: tear_x[_gi] + random(_colw), py: _gy + random_range(-10, 10),
		s: (random(1) < 0.2) ? random_range(7, 12) : random_range(3, 6),    // mostly small, a few big ones
		vx: random_range(-0.3, 0.3), vy: random_range(-0.6, -0.15),          // drifting up, out of the crack
		rot: random(360), spin: random_range(-3, 3) });
}

// rubble: big lumps of rock flung out of the crack the moment the ground breaks, tumbling off into her cosmos
rocks = [];
repeat (40) {
	var _ri  = irandom_range(_vc0, tear_n - 1 - _vc0);
	var _rmy = (_ri >= tear_fork) ? _main[_ri] : ((random(1) < 0.5) ? _up[_ri] : _dn[_ri]);  // somewhere along the crack
	array_push(rocks, { px: tear_x[_ri] + random(_colw), py: _rmy + random_range(-8, 8),
		r: random_range(14, 44),                                                         // size
		vx: random_range(-220, 220), vy: random_range(-380, 380),                        // how far it's flung, up or down
		rot: random(360), spin: random_range(-120, 120), seed: random(100) });
}