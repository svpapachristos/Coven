# Stardust, Step 1: draft v1 (Oct 10, NOT typed yet)

The first full writeup, saved so the fresh version (after Sophia's references and a brainstorm) builds on it instead of re-deriving it. Don't type this version: it's the baseline to revise.

## The design in one breath
After the world breaks away, the doomed stand in full colour (her ingredients, coming with her). A crumble ripples out from her, nearest first. Each body burns away pixel by pixel from the head down, with a white-violet edge, and every pixel that goes becomes a mote. Motes tumble like ash for a beat, then her sky takes hold: they steer toward their planned star while being swept round her in one galaxy-wide swirl that fades as they close in. A protostar glow grows where dust lands. When a body's last mote lands, its star catches (the ignition flash), and the finale ring waits until all the dust has settled.

## Sharp details worth keeping
- **The crumble edge and the mote spawn must agree.** Shader order: `k = (1-h)*0.7 + n*0.3`, gone where `k < cut*1.05`. Spawn height: `_hf = 1 - (cut*1.05 - 0.15) / 0.7`.
- **Draw the crumble with c_white, not image_blend.** sh_timestop ignored v_vColour, so the frozen copy was never hex-tinted. White means nothing jumps at birth_at.
- **Motes are stored relative to her** (`mx, my`, offsets from obj_player), like her sky. Never use the field names `x`/`y`, which clash with the built-ins.
- **Steering, not forces.** `v += (wanted - v) * 0.09 * grip` is stable, always converges and gives smooth curves. The wanted speed is `min(10, 1.5 + d*0.05)` (far ones fly faster, so they all arrive around together). The swirl is `dust_swirl * 8 * min(1, d/150)`, so it fades and the mote can land. Tangent = direction from her + 90, the way the sky turns.
- **Removal is swap-and-pop**, not array_delete: thousands of motes.
- **Two draw passes** (all spr_glow, then all spr_dot). They sit on different texture pages, and alternating them per mote breaks the batch.
- **Ignition reuses the enemy's own Step**: set `e.unmake_at = t` when its `dust_left` hits 0, so `scr_unmake` fires naturally. Kills, souls and ascension stay untouched.
- **The plan carries `ph` and `dust`**, so motes fly in their star's final colour, and `scr_unmake` uses `_p.ph`.
- `finale_at = infinity` until `t > crumble_end` and no motes are left. `duration` goes to 6.5s.
- `dust_total` is shared between bodies, `_per = clamp(floor(dust_total / n), 3, 12)`. It's the main performance knob.
- Name check done against Draw and Step: `_mt _mn _msp _mhot _ck _pg* _grip _sp _tan _swv _wx _wy` are free (`_tx`/`_ty` exist in Draw, so they're used only in Step). Draw already has `var _m = 64` (the margin), so motes use `_mt`.

## The code (v1)

### scr_hexweaver
Plan creation in `scr_hex_plan_star`:
```gml
		_plan = { ox: _sx, oy: _sy, s: 0.6 + power(random(1), 2.5) * 1.6 + (_e.star_hexed ? 0.8 : 0), idx: -1,
		          ph: random(1000),   // its colour, decided now, so the dust flying to it already glows that colour
		          dust: 0 };          // how many motes have landed on it so far
```
In `scr_unmake`: `_ph = _p.ph;` (it was `random(1000)`).

### sh_crumble.fsh (the vertex shader stays GameMaker's default)
```glsl
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec4  u_uvs;
uniform vec2  u_texel;
uniform float u_cut;
uniform vec3  u_edge;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main()
{
	vec4  c   = texture2D(gm_BaseTexture, v_vTexcoord);
	float h   = (u_uvs.w - v_vTexcoord.y) / (u_uvs.w - u_uvs.y);
	float n   = hash(floor(v_vTexcoord / u_texel));
	float k   = (1.0 - h) * 0.7 + n * 0.3;
	float cut = u_cut * 1.05;
	if (k < cut) discard;
	float edge = (1.0 - smoothstep(0.0, 0.08, k - cut)) * step(0.001, u_cut);
	vec3 col = c.rgb * v_vColour.rgb;
	col = mix(col, u_edge, edge);
	col += vec3(1.0) * pow(edge, 3.0) * 0.6;
	gl_FragColor = vec4(col, c.a * v_vColour.a);
}
```

### Create
`duration` 6.5s, `finale_at = infinity`. Replaces the "nearest her ignite first" block:
```gml
dust_total   = 3000;
crumble_wave = _fps * 1.0;
crumble_len  = _fps * 0.6;
dust_fall    = _fps * 0.3;
dust_swirl   = 0.6;
dust_life    = _fps * 3;
crumble_end  = birth_at + floor(_fps * 0.2) + crumble_wave + crumble_len;
motes  = [];
protos = [];
u_cr_uvs   = shader_get_uniform(sh_crumble, "u_uvs");
u_cr_texel = shader_get_uniform(sh_crumble, "u_texel");
u_cr_cut   = shader_get_uniform(sh_crumble, "u_cut");
u_cr_edge  = shader_get_uniform(sh_crumble, "u_edge");
array_sort(_doomed, function(_a, _b) { return _a.d - _b.d; });
var _n   = array_length(_doomed);
var _per = clamp(floor(dust_total / max(1, _n)), 3, 12);
for (var i = 0; i < _n; i++) {
	var _entry = _doomed[i];
	var _e = _entry.inst;
	_e.unmaking   = 0.001;
	_e.unmake_at  = infinity;
	_e.crumble_at = birth_at + floor(_fps * 0.2) + ((_n > 1) ? i / (_n - 1) : 0) * crumble_wave;
	_e.dust_n     = _per;
	_e.dust_out   = 0;
	_e.dust_left  = _per;
}
```

### Step (under `sky_angle +=`, above the finale)
```gml
if (t >= birth_at && instance_exists(obj_player)) {
	var _fpsd = game_get_speed(gamespeed_fps);
	with (obj_enemy_parent) {
		if (unmaking <= 0 || !variable_instance_exists(id, "crumble_at")) continue;
		var _ck   = clamp((other.t - crumble_at) / other.crumble_len, 0, 1);
		var _want = floor(_ck * dust_n);
		while (dust_out < _want) {
			dust_out++;
			var _hf = clamp(1 - (_ck * 1.05 - 0.15) / 0.7, 0, 1);
			array_push(other.motes, {
				mx: random_range(bbox_left, bbox_right) - obj_player.x,
				my: lerp(bbox_bottom, bbox_top, _hf) + random_range(-2, 2) - obj_player.y,
				vx: random_range(-0.5, 0.5), vy: random_range(-1, 0),
				age: 0, e: id, p: star_plan,
				c: scr_hex_star_colour(star_plan.ph)
			});
		}
	}
	for (var i = array_length(motes) - 1; i >= 0; i--) {
		var _mt = motes[i];
		_mt.age++;
		var _pl = point_distance(0, 0, _mt.p.ox, _mt.p.oy);
		var _pa = point_direction(0, 0, _mt.p.ox, _mt.p.oy) + sky_angle;
		var _tx = lengthdir_x(_pl, _pa) - _mt.mx, _ty = lengthdir_y(_pl, _pa) - _mt.my;
		var _d  = max(0.01, point_distance(0, 0, _tx, _ty));
		if (_d < 3 + abs(_mt.vx) + abs(_mt.vy) || _mt.age > dust_life) {
			_mt.p.dust++;
			if (_mt.p.dust == 1) array_push(protos, _mt.p);
			if (instance_exists(_mt.e)) {
				_mt.e.dust_left--;
				if (_mt.e.dust_left <= 0) _mt.e.unmake_at = t;
			}
			motes[i] = motes[array_length(motes) - 1];
			array_pop(motes);
			continue;
		}
		var _grip = clamp((_mt.age - dust_fall) / (_fpsd * 0.5), 0, 1);
		_mt.vy += 0.07 * (1 - _grip);
		if (_grip > 0) {
			var _sp  = min(10, 1.5 + _d * 0.05);
			var _tan = point_direction(0, 0, _mt.mx, _mt.my) + 90;
			var _swv = dust_swirl * 8 * min(1, _d / 150);
			var _wx  = _tx / _d * _sp + lengthdir_x(_swv, _tan);
			var _wy  = _ty / _d * _sp + lengthdir_y(_swv, _tan);
			_mt.vx += (_wx - _mt.vx) * 0.09 * _grip;
			_mt.vy += (_wy - _mt.vy) * 0.09 * _grip;
		}
		_mt.mx += _mt.vx;
		_mt.my += _mt.vy;
	}
	if (finale_at == infinity && t > crumble_end && array_length(motes) == 0) finale_at = t + floor(_fpsd * 0.15);
}
```

### Draw
- Frozen horde: `u_ts_desat` 0, `u_ts_tint` (1, 1, 1), `u_ts_dark` 0 (only the block around line 405, not the ground's at 163).
- This replaces everything from `var _lite = ...` through the `gpu_set_blendmode(bm_add);` above "stage 3, ignition":
```gml
gpu_set_blendmode(bm_normal);
shader_set(sh_crumble);
shader_set_uniform_f(u_cr_edge, 0.85, 0.65, 1.0);
with (obj_enemy_parent) {
	if (unmaking <= 0 || sprite_index < 0) continue;
	if (other.t < other.birth_at || !variable_instance_exists(id, "crumble_at")) continue;
	if (point_distance(_px, _py, x, y) > _r) continue;
	var _ck = clamp((other.t - crumble_at) / other.crumble_len, 0, 1);
	if (_ck >= 1) continue;
	var _uv  = sprite_get_uvs(sprite_index, image_index);
	var _tex = sprite_get_texture(sprite_index, image_index);
	shader_set_uniform_f(other.u_cr_uvs, _uv[0], _uv[1], _uv[2], _uv[3]);
	shader_set_uniform_f(other.u_cr_texel, texture_get_texel_width(_tex), texture_get_texel_height(_tex));
	shader_set_uniform_f(other.u_cr_cut, _ck);
	draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, c_white, 1);
}
shader_reset();
gpu_set_blendmode(bm_add);
for (var i = 0; i < array_length(protos); i++) {
	var _pg = protos[i];
	if (_pg.idx >= 0) continue;
	var _pgl = point_distance(0, 0, _pg.ox, _pg.oy);
	var _pga = point_direction(0, 0, _pg.ox, _pg.oy) + sky_angle;
	var _pgs = min(3, 0.6 + sqrt(_pg.dust) * 0.5);
	var _pgc = scr_hex_star_colour(_pg.ph);
	draw_sprite_ext(spr_glow, 0, _px + lengthdir_x(_pgl, _pga), _py + lengthdir_y(_pgl, _pga), _pgs * 3 / 15, _pgs * 3 / 15, 0, _pgc, 0.5);
}
var _mn = array_length(motes);
for (var i = 0; i < _mn; i++) {
	var _mt  = motes[i];
	var _msp = point_distance(0, 0, _mt.vx, _mt.vy);
	draw_sprite_ext(spr_glow, 0, _px + _mt.mx, _py + _mt.my, (2.5 + _msp * 1.2) / 15, 2.5 / 15,
		point_direction(0, 0, _mt.vx, _mt.vy), _mt.c, 0.35);
}
for (var i = 0; i < _mn; i++) {
	var _mt   = motes[i];
	var _mhot = clamp(1 - _mt.age / 20, 0, 1);
	draw_sprite_ext(spr_dot, 0, _px + _mt.mx, _py + _mt.my, 1 / 15, 1 / 15, 0, merge_color(_mt.c, c_white, 0.3 + 0.7 * _mhot), 1);
}
gpu_set_blendmode(bm_add);
```

## Open questions for the brainstorm
- **Crumble look:** pixel-by-pixel head-first (v1), flakes peeling off in sheets, embers, or crumbling from the side facing its star?
- **Dust motion:** galaxy swirl around her (v1), or straight spirals into each star? How long should the ash fall? Should the dust drift like smoke, stream like sparks, or both?
- **The catch:** a soft bloom (v1 reuses the ignition flare), a sharp twinkle, or a pop with a ring?
- **Mote look:** a size, a streak length, colour cooling from white-hot to the star colour (v1), sparkle or twinkle?
- **Do the motes interact with each other** (clumping into filaments), or does each one go only to its own star?
- What about sprite-less enemies (skip, or shed motes from the bbox only)?

## Brainstorm decisions (Oct 10, afternoon). v2 builds on these
**Design pillar: childlike awe.** Every effect should earn a "whoa." Think of the power of an Infinity Stone. Sophia's own words: the feeling she's emulating "with every bit, detail, system, power, attack, and pixel in this game."

**Astrophysics as the source of the beauty, not a simulation.** Real rules that are simple to code and show on screen. Not overcomplicated.

Decided:
- **Every pixel becomes its own dust.** A mote is born the colour of the sprite pixel it came off. (Read each enemy sprite's pixels into a buffer once per cast and cache them.) Sophia: "each pixel of an enemy determines its dust type or at least color."
- **Lingering haze: YES ("1000%").** The dust streams leave wisps that persist for the whole run, so her nebula grows from her dead, cast after cast. **Black holes feed on it:** while a star collapses, the nearby haze stretches into spiralling streams that feed the disk (the gathering beat). The supermassive drinks a whole run's nebula. A hole's disk is woven from the gas colours her kills painted.

Also decided (confirmed Oct 10, 3:13pm, "yes to all"):
- **Rule 2, gas colours:** in flight, motes drift from creature colour toward real emission colours by hue. Reds → hydrogen red-pink, greens and teals → oxygen teal, oranges and yellows → sulphur gold-red, blues and purples → reflection blue-violet. Dark pixels (outlines) → **dark dust lanes** that dim rather than glow (Pillars of Creation).
- **Rule 3, star colour from mass:** a lone enemy makes a red dwarf, a clump makes a yellow-white star, a big crowd makes a blue giant. The blue giants are the ones that collapse (`HEX_COLLAPSE_MASS` is already physics). Replaces the random `ph` colour.
- **Rhythm loud, quiet, loud:** the BOOM, then the quiet snap (stillness, no shake, a slow unhurried crumble, the swirl as the swell), then the black hole BOOM. Possible art brief for a small cast gesture.
- **Black holes, from the references:** the Gargantua silhouette (disk band in front, far-side disk lensed over the top and under the bottom, a hairline photon ring, luminous bloom, torn streaky outer disk, scale). EHT: Doppler asymmetry (one side brighter, drifting with the spin) and an ember newborn look. Shutterstock: the palette (icy blue-white inner edge, magenta disk, red far rim) and the tilted "eye" angle. Ideas: three holes with three angles, a temperature journey (ember, then magenta, then white-hot), the disk made of spaghettified stars (its history visible), the hole as the brightest thing in the sky, background stars lensed into arcs.
- Kept out: true n-body gravity between motes (v1 steering stays), spectrum maths, stellar lifetimes.

**North star (Sophia, in her words):** turn the enemies' mass into equivalent elements that genuinely create streaks, nebulas, stars, black holes and eventually supermassives "in the most breathtaking way possible": accretion of stardust, a SPECTACLE of star creation and supernova / black hole creation. It's the main character's ULTIMATE: it reveals to the world "that not only does she intend to obtain godhood, she probably always had the power to do so."

- **Supernova added.** A collapsing blue giant goes supernova. The blast shell leaves a permanent **supernova remnant** in her nebula (Crab-style filaments in oxygen teal and sulphur / iron gold-red: elements forged in the star), with the black hole at its heart. The remnant becomes material for future stars and food for holes. The cycle: her dead → stars → supernova remnants → new stars and holes.
- **Holes:** a temperature journey for newborns (ember → magenta → white-hot, the photon ring snapping in last). Three angles by default (one per hole: edge-on Gargantua, tilted eye, near face-on donut). The supermassive is a full screen-dominating Gargantua. (Sophia can veto in favour of one signature look.)

Still open: regular vs supermassive screen size (to tune by eye), and the cast gesture art brief (optional).

## Roadmap to a perfect Unmaking (agreed Oct 10). Each phase gets clips and a polish loop before the next
Sophia: "if we dont even finish this today or tomorrow i want to keep going until we genuinely PERFECT this kit." Confirmed yes to every decision above.

1. **Phase 1, the quiet snap (stardust v2).** Stillness after the break, then the crumble rippling out with no shake. Motes take their pixel colours from a cached sprite buffer, drift toward gas colours by hue (darks become dark dust), and are steered round her in the swirl. Persistent haze wisps (a run-long array, capped, turning with her sky). Protostars. Star colour from mass. Includes the section 7 stars-stay-lit fix if it isn't already in.
2. **Phase 2, the living sky.** Stars drift and settle between casts, the nebula dims at key moments, and the haze thickens over the run.
3. **Phase 3, collapse and supernova.** A blue giant turns unstable (it swells and pulses, and time drags: wire `_slow`). It pulls in nearby stars and the haze in spiral streams, the core contracts, the light is sucked inward, a near-black beat, then the impact frame and BOOM. The supernova shell leaves a permanent remnant nebula (oxygen teal and sulphur / iron gold filaments), and the hole is born at its heart.
4. **Phase 4, the hole itself.** The temperature journey (ember → magenta → white-hot, the photon ring last). The Gargantua silhouette (disk band, far side lensed over and under), Doppler asymmetry, luminous bloom, a disk of spaghettified stars and haze, three angles.
5. **Phase 5, real lensing.** `sky_surf` plus `sh_lens`, with background stars and nebula bent into arcs round the shadow.
6. **Phase 6, the supermassive (F10 / endless).** Holes inspiral, ripples run through the sky, they merge, and a screen-dominating Gargantua drinks a whole run's nebula.
Still to fold in somewhere: the return (the entrance in reverse), camera language, the impact frame landing off-screen, and an optional cast gesture art brief.

**Clarified (Oct 10, 3:17pm):** "loud, quiet, loud" does NOT touch the entrance. The ground tearing, the BOOM and the planet splitting into slabs over the chasm all stay exactly as built (Sophia loves the rumble). It's the first LOUD. "Quiet" is only the stardust section after the chunks are gone.
**Parallel track, entrance polish (unfinished, paused for the stardust):** a dust burst along the crack as it runs. The sigil pass (light pool, a leading spark tracing its lines, the overload flicker and split right before the crack). Cleanup (debug messages; maybe the glitch bars and sigil drawn above the frozen horde). The return, rebuilt as the entrance in reverse. Switch to it whenever she wants a break, or after Phase 1.

## Phase 1 v2 (given Oct 10, ~3:30pm). Builds on v1, so the v1 code above is superseded
What changed from v1:
- **Star colour from mass:** `scr_hex_star_colour(_m, _ph, _hx = false)`, a log2 ramp from red dwarf to hot blue, fully blue at `HEX_MASS_BLUE` (64). `_ph` adds ±0.06 of variety; `_hx` leans 25% toward her violet. 7 hits for `scr_hex_star_colour(` (the definition, Draw section 7, scr_unmake, accrete x2, Step motes, Draw protostars).
- **Plans:** `ph`, `mp` (planned mass, summed for every enemy sharing the plan, so the motes fly in the final star's colour), and `landed`. The field is NOT named `dust`, because obj_unmaking already has a `dust` instance variable (the art sprites).
- **Pixel colours:** `scr_hex_sprite_pixels(spr, img)` draws the frame at its raw origin onto a surface, reads it with `buffer_get_surface` (BGRA, so the bytes are B G R A), keeps alpha >= 128, top row first, as `{u, v, c}`. Cached per cast in `pix_cache["spr:frame"]` and stored on the enemy as `dust_pix`. Mote j of n takes a pixel from the list at index (j + rand) / n, so the motes come off head first, matching the shader.
- **Gas colours:** `scr_hex_gas_colour(c)`. Value < 70 → -1 (dark dust). Saturation < 60 → reflection blue-white. By hue (GameMaker's 0-255): red → hydrogen pink-red, < 46 → sulphur gold, < 140 → oxygen teal, < 190 → reflection blue, else violet. In Draw, a mote goes white-hot (first 10 frames) → creature colour → gas over `gas_time` → star colour within 80px of landing. Dark motes are dim (55, 40, 50) specks.
- **Haze:** `global.hex_haze` (reset in obj_game_controller Create with `hex_haze_i`), a ring buffer capped at `HEX_HAZE_CAP` (1500). At `age == haze_at`, a mote leaves a wisp with chance `haze_rate` (0.12). Wisps are stored in sky coordinates with `ang` (their stream direction) and grow by 0.3 a frame to `smax`. Drawn as section 6b: soot in `bm_subtract` (result = dest x (1 - src colour), so the tint brightness sets the strength and the glow sprite's black edges do nothing), then glowing gas in `bm_add`.
- **Quiet:** `crumble_delay` 0.5s of stillness, and the ignition shake removed from scr_unmake (the ascension shake stays, and so does the finale's shake of 10).
- Timing: `duration` 7s, and when the finale is set, `duration = max(duration, finale_at + 2.5s)`. `_per` is clamped to 3..16.

## Big idea (Sophia, Oct 10, 3:42pm): the living universe, a real stellar life cycle. It becomes Phase 2, and Phase 3 is its climax
Her words: stars born from dust AND dying back into dust ("slightly less than they made, so they stay contained over a run while still being able to reach a supermassive in endless mode"). Nebulae as "the birthplace of new stars as well as the graveyards of old ones." "A sandbox where the player is god." "A whole game inside a single ability."
Doesn't change Phase 1 (keep typing it as given).
- **One mass budget:** stars plus gas (haze). Enemies add mass. Dense gas collapses into new stars (no enemy needed). Stars die by mass: red dwarfs effectively never die. Yellow/white stars become a **planetary nebula** ring (Ring / Helix) plus a white dwarf. Blue giants become a **supernova** (remnant filaments) plus a neutron star (maybe a pulsar with sweeping beams). The heaviest become a black hole (max 3 per run). Deaths return LESS than they took (the remnant keeps some), so the sky stays bounded, and the holes keep eating, which builds to the supermassive in endless mode.
- **Time:** her sky only exists during the ult. Quiet aging happens BETWEEN casts (a fast-forward when the sky opens: "time passed in her universe"). Big events (supernovae, collapses) happen LIVE during a cast as spectacle.
- **Roadmap:** Phase 2 "living sky" becomes the life cycle (births from haze, aging, planetary nebulae, gas returning). Phase 3 (collapse and supernova) is the dramatic end of the same cycle. Future tweak: haze wisps carry mass `m` so the budget adds up.
- **Scope rule for the slice:** every part must read in one cast. Quiet changes between casts, big events on screen.
- Open: are remnants visible (white dwarfs, pulsars) or just gas? How much time passes between casts?
