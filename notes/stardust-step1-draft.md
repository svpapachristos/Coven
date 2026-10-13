# Stardust, Step 1: draft v1 (Oct 10, NOT typed yet)

The first full writeup, saved so the fresh version (after Sophia's references and a brainstorm) builds on it instead of re-deriving it. Don't type this version: it's the baseline to revise.

## The design in one breath
After the world breaks away, the doomed stand in full color (her ingredients, coming with her). A crumble ripples out from her, nearest first. Each body burns away pixel by pixel from the head down, with a white-violet edge, and every pixel that goes becomes a mote. Motes tumble like ash for a beat, then her sky takes hold: they steer toward their planned star while being swept round her in one galaxy-wide swirl that fades as they close in. A protostar glow grows where dust lands. When a body's last mote lands, its star catches (the ignition flash), and the finale ring waits until all the dust has settled.

## Sharp details worth keeping
- **The crumble edge and the mote spawn must agree.** Shader order: `k = (1-h)*0.7 + n*0.3`, gone where `k < cut*1.05`. Spawn height: `_hf = 1 - (cut*1.05 - 0.15) / 0.7`.
- **Draw the crumble with c_white, not image_blend.** sh_timestop ignored v_vColor, so the frozen copy was never hex-tinted. White means nothing jumps at birth_at.
- **Motes are stored relative to her** (`mx, my`, offsets from obj_player), like her sky. Never use the field names `x`/`y`, which clash with the built-ins.
- **Steering, not forces.** `v += (wanted - v) * 0.09 * grip` is stable, always converges and gives smooth curves. The wanted speed is `min(10, 1.5 + d*0.05)` (far ones fly faster, so they all arrive around together). The swirl is `dust_swirl * 8 * min(1, d/150)`, so it fades and the mote can land. Tangent = direction from her + 90, the way the sky turns.
- **Removal is swap-and-pop**, not array_delete: thousands of motes.
- **Two draw passes** (all spr_glow, then all spr_dot). They sit on different texture pages, and alternating them per mote breaks the batch.
- **Ignition reuses the enemy's own Step**: set `e.unmake_at = t` when its `dust_left` hits 0, so `scr_unmake` fires naturally. Kills, souls and ascension stay untouched.
- **The plan carries `ph` and `dust`**, so motes fly in their star's final color, and `scr_unmake` uses `_p.ph`.
- `finale_at = infinity` until `t > crumble_end` and no motes are left. `duration` goes to 6.5s.
- `dust_total` is shared between bodies, `_per = clamp(floor(dust_total / n), 3, 12)`. It's the main performance knob.
- Name check done against Draw and Step: `_mt _mn _msp _mhot _ck _pg* _grip _sp _tan _swv _wx _wy` are free (`_tx`/`_ty` exist in Draw, so they're used only in Step). Draw already has `var _m = 64` (the margin), so motes use `_mt`.

## The code (v1)

### scr_hexweaver
Plan creation in `scr_hex_plan_star`:
```gml
		_plan = { ox: _sx, oy: _sy, s: 0.6 + power(random(1), 2.5) * 1.6 + (_e.star_hexed ? 0.8 : 0), idx: -1,
		          ph: random(1000),   // its color, decided now, so the dust flying to it already glows that color
		          dust: 0 };          // how many motes have landed on it so far
```
In `scr_unmake`: `_ph = _p.ph;` (it was `random(1000)`).

### sh_crumble.fsh (the vertex shader stays GameMaker's default)
```glsl
varying vec2 v_vTexcoord;
varying vec4 v_vColor;
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
	vec3 col = c.rgb * v_vColor.rgb;
	col = mix(col, u_edge, edge);
	col += vec3(1.0) * pow(edge, 3.0) * 0.6;
	gl_FragColor = vec4(col, c.a * v_vColor.a);
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
				c: scr_hex_star_color(star_plan.ph)
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
	var _pgc = scr_hex_star_color(_pg.ph);
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
- **Mote look:** a size, a streak length, color cooling from white-hot to the star color (v1), sparkle or twinkle?
- **Do the motes interact with each other** (clumping into filaments), or does each one go only to its own star?
- What about sprite-less enemies (skip, or shed motes from the bbox only)?

## Brainstorm decisions (Oct 10, afternoon). v2 builds on these
**Design pillar: childlike awe.** Every effect should earn a "whoa." Think of the power of an Infinity Stone. Sophia's own words: the feeling she's emulating "with every bit, detail, system, power, attack, and pixel in this game."

**Astrophysics as the source of the beauty, not a simulation.** Real rules that are simple to code and show on screen. Not overcomplicated.

Decided:
- **Every pixel becomes its own dust.** A mote is born the color of the sprite pixel it came off. (Read each enemy sprite's pixels into a buffer once per cast and cache them.) Sophia: "each pixel of an enemy determines its dust type or at least color."
- **Lingering haze: YES ("1000%").** The dust streams leave wisps that persist for the whole run, so her nebula grows from her dead, cast after cast. **Black holes feed on it:** while a star collapses, the nearby haze stretches into spiralling streams that feed the disk (the gathering beat). The supermassive drinks a whole run's nebula. A hole's disk is woven from the gas colors her kills painted.

Also decided (confirmed Oct 10, 3:13pm, "yes to all"):
- **Rule 2, gas colors:** in flight, motes drift from creature color toward real emission colors by hue. Reds → hydrogen red-pink, greens and teals → oxygen teal, oranges and yellows → sulphur gold-red, blues and purples → reflection blue-violet. Dark pixels (outlines) → **dark dust lanes** that dim rather than glow (Pillars of Creation).
- **Rule 3, star color from mass:** a lone enemy makes a red dwarf, a clump makes a yellow-white star, a big crowd makes a blue giant. The blue giants are the ones that collapse (`HEX_COLLAPSE_MASS` is already physics). Replaces the random `ph` color.
- **Rhythm loud, quiet, loud:** the BOOM, then the quiet snap (stillness, no shake, a slow unhurried crumble, the swirl as the swell), then the black hole BOOM. Possible art brief for a small cast gesture.
- **Black holes, from the references:** the Gargantua silhouette (disk band in front, far-side disk lensed over the top and under the bottom, a hairline photon ring, luminous bloom, torn streaky outer disk, scale). EHT: Doppler asymmetry (one side brighter, drifting with the spin) and an ember newborn look. Shutterstock: the palette (icy blue-white inner edge, magenta disk, red far rim) and the tilted "eye" angle. Ideas: three holes with three angles, a temperature journey (ember, then magenta, then white-hot), the disk made of spaghettified stars (its history visible), the hole as the brightest thing in the sky, background stars lensed into arcs.
- Kept out: true n-body gravity between motes (v1 steering stays), spectrum maths, stellar lifetimes.

**North star (Sophia, in her words):** turn the enemies' mass into equivalent elements that genuinely create streaks, nebulas, stars, black holes and eventually supermassives "in the most breathtaking way possible": accretion of stardust, a SPECTACLE of star creation and supernova / black hole creation. It's the main character's ULTIMATE: it reveals to the world "that not only does she intend to obtain godhood, she probably always had the power to do so."

- **Supernova added.** A collapsing blue giant goes supernova. The blast shell leaves a permanent **supernova remnant** in her nebula (Crab-style filaments in oxygen teal and sulphur / iron gold-red: elements forged in the star), with the black hole at its heart. The remnant becomes material for future stars and food for holes. The cycle: her dead → stars → supernova remnants → new stars and holes.
- **Holes:** a temperature journey for newborns (ember → magenta → white-hot, the photon ring snapping in last). Three angles by default (one per hole: edge-on Gargantua, tilted eye, near face-on donut). The supermassive is a full screen-dominating Gargantua. (Sophia can veto in favour of one signature look.)

Still open: regular vs supermassive screen size (to tune by eye), and the cast gesture art brief (optional).

## Roadmap to a perfect Unmaking (agreed Oct 10). Each phase gets clips and a polish loop before the next
Sophia: "if we dont even finish this today or tomorrow i want to keep going until we genuinely PERFECT this kit." Confirmed yes to every decision above.

1. **Phase 1, the quiet snap (stardust v2).** Stillness after the break, then the crumble rippling out with no shake. Motes take their pixel colors from a cached sprite buffer, drift toward gas colors by hue (darks become dark dust), and are steered round her in the swirl. Persistent haze wisps (a run-long array, capped, turning with her sky). Protostars. Star color from mass. Includes the section 7 stars-stay-lit fix if it isn't already in.
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
- **Star color from mass:** `scr_hex_star_color(_m, _ph, _hx = false)`, a log2 ramp from red dwarf to hot blue, fully blue at `HEX_MASS_BLUE` (64). `_ph` adds ±0.06 of variety; `_hx` leans 25% toward her violet. 7 hits for `scr_hex_star_color(` (the definition, Draw section 7, scr_unmake, accrete x2, Step motes, Draw protostars).
- **Plans:** `ph`, `mp` (planned mass, summed for every enemy sharing the plan, so the motes fly in the final star's color), and `landed`. The field is NOT named `dust`, because obj_unmaking already has a `dust` instance variable (the art sprites).
- **Pixel colors:** `scr_hex_sprite_pixels(spr, img)` draws the frame at its raw origin onto a surface, reads it with `buffer_get_surface` (BGRA, so the bytes are B G R A), keeps alpha >= 128, top row first, as `{u, v, c}`. Cached per cast in `pix_cache["spr:frame"]` and stored on the enemy as `dust_pix`. Mote j of n takes a pixel from the list at index (j + rand) / n, so the motes come off head first, matching the shader.
- **Gas colors:** `scr_hex_gas_color(c)`. Value < 70 → -1 (dark dust). Saturation < 60 → reflection blue-white. By hue (GameMaker's 0-255): red → hydrogen pink-red, < 46 → sulphur gold, < 140 → oxygen teal, < 190 → reflection blue, else violet. In Draw, a mote goes white-hot (first 10 frames) → creature color → gas over `gas_time` → star color within 80px of landing. Dark motes are dim (55, 40, 50) specks.
- **Haze:** `global.hex_haze` (reset in obj_game_controller Create with `hex_haze_i`), a ring buffer capped at `HEX_HAZE_CAP` (1500). At `age == haze_at`, a mote leaves a wisp with chance `haze_rate` (0.12). Wisps are stored in sky coordinates with `ang` (their stream direction) and grow by 0.3 a frame to `smax`. Drawn as section 6b: soot in `bm_subtract` (result = dest x (1 - src color), so the tint brightness sets the strength and the glow sprite's black edges do nothing), then glowing gas in `bm_add`.
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

**Debug and slice tuning (Oct 10, 3:48pm):** Deadlock-level polish applies to the Unmaking even though it ships inside the 15-minute slice. F10 (`global.hex_debug_holes`, obj_game_controller Step line ~208) currently means "collapse at a tiny mass, any tier." As the life cycle lands, F10 grows into a **cosmic time** mode: fast-forward between casts, lower thresholds for births and deaths, holes at a tiny mass. Maybe a companion key to force the biggest star to go supernova or collapse live, for tuning the spectacle. **The default tuning must show the whole story in a normal 15-minute run** (births from haze, at least one planetary nebula, a supernova, at least one black hole). Endless mode gets all three holes and the supermassive.

## Phase 1.1 (given Oct 10, ~4:50pm): making the snap hit
Clip read of v2 (a huge frog/slime horde, plus a tier-4 cast): the whole chain works, but (1) the dust was nearly invisible (3 motes per body for about 1,000 bodies, 1px dots), (2) the crumble read as scanlines (70% height / 30% noise), (3) pixels vanished instead of becoming dust, (4) the haze popped in at full alpha, (5) an all-green horde painted all teal (physically right, but flat).
Fixes:
- **sh_crumble:** crumbs of 2x2 texels, `k = (1-h)*0.45 + n*0.55`.
- **scr_hex_sprite_pixels:** sorts the pixels by the same ragged order (`k = v/(h-1)*0.45 + rand*0.55`), so motes come off where the body is breaking.
- **Motes are born as real pixel chunks:** `spr_px` (a 4x4 white square), size `ps = abs(image_xscale)`, in the exact creature color, tumbling (`rot`, `spin`), shrinking and fading over `chunk_time` (0.45s) while the glow grows in (`lit`). Bigger glow (3.5 + speed*1.5, alpha 0.5) and a 1.4px core.
- `dust_total` 5000, `_per` clamped to 5..24.
- **Hydrogen mixing:** a 25% chance a mote's gas is half-blended with hydrogen pink ("every cloud is mostly hydrogen").
- **Haze laid along the streams:** every 6 frames after `dust_fall`, with chance `haze_rate` (0.006), about 450 wisps per cast at 5000 motes. Wisps start at s 2, smax 8-20, fade in (`f` += 0.02 a frame), and the draw multiplies by `f`. `haze_at` retired.
- `spr_px` is deleted in Clean Up.

## Phase 1.1 result (clip, Oct 10, 6:58pm) and the next idea
Works: the crumble reads (a storm of colored pixel chunks), the dust sweeps out in visible arcs, and stars catch out of it.
**Sophia's note: the pixels that become stardust should drift and settle, not all coalesce into stars.** This is real astrophysics: only a few percent of a cloud's gas ever becomes stars, and the rest IS the nebula.
**Plan (first item of Phase 2):** each mote gets a fate when it comes loose. **Most drift and settle:** they slow, spread, cool and fade into the haze, carrying gas mass, and become the material future stars are born from between casts. **A smaller share streams into stars** (today's bright arcs). The quiet snap then has two textures: a slow settling dust cloud, with brighter threads pulling out of it into stars. This replaces "motes drop haze along the way" with "the crumble itself makes the nebula." Knob: the settle fraction (start around 0.7). Each enemy's star still gets its mass, through `dust_left` counting only the stream motes.

## Phase 2, Step 1 given (Oct 10, ~7:10pm): drift and settle
Sophia: cloud dust should drift and settle onto its position. Right now it reaches a point and "a little ellipse generates in its place" (the haze wisp popping in). Star dust still goes to its star. The goal: "a genuine feeling universe simulation," beautiful and polished.
- **Fates:** `settle_frac` 0.7. Per body, `dust_stream = max(1, round(_per * 0.3))`, spread evenly through the shed order (`floor((j+1)*s/n) > floor(j*s/n)`), so `dust_left` counts only stream motes. `streams_live` tracks star dust in flight, and the finale waits on it (not on `motes` being empty).
- **Cloud dust:** its rest spot is in the sky frame (`sox, soy` = star plan + r 30..140 at a random angle: a stellar nursery). Arrive steering (`sp = min(3.5, d*0.035)`), a gentler swirl (x4, fades within 200px), a sin/cos wobble with a per-mote seed, steer 0.05. A settle look `sp = 1 - d/50` blends the streak into a round glow of radius `re` (5-9) at alpha `ae` (0.08-0.14) while the core fades. At rest (d < 4, speed < 0.5): with chance `wisp_keep` 0.12 it becomes a wisp drawn identically (s = s0 = re, a = ae, f = 1, round 1.25:1, random angle). Otherwise `st = 1` and it fades over 0.8s. After `settle_life` (3.5s) it fades where it is.
- **Wisps** diffuse: s += 0.05 up to smax (re + 6..16), drawn at alpha × sqrt(s0/s). The haze drop along the streams is removed, and so is `haze_rate`.

## Phase 2, Step 1.1 (the four tweaks) result, then Step 1.2 given (Oct 10, ~7:30pm): a real stellar nursery
Clip read: the nebula growth is beautiful (soft teal/blue clouds linger after the cast), and mixed hordes give mixed gas. Still holding it back: (1) the settling gas reads as "bokeh" (spr_glow's linear falloff keeps a visible disc edge on every puff), (2) you can't see stars being made (faint, short threads, and stars just appear), (3) newborn stars don't affect the gas.
Step 1.2:
- **`spr_soft`** (64px, made in Create from 24 additive rings weighted by bell-curve differences `exp(-3 (r/31)^2)`, so there's no edge). Deleted in Clean Up. Used for settling gas, soot and haze, at scale radius/20.
- **Draw passes:** streaks (spr_glow, × (1 - sp)), then soft gas (spr_soft, lerp(4, re, sp), alpha ae × sp), soot (subtract, spr_soft), cores (× (1 - sp)), chunks. A streak crossfades into soft gas. Star dust threads are 4 + speed*3 long, 2.2 wide, alpha 0.7.
- **Haze** on spr_soft, round at birth and stretching 25% as it diffuses (`1 + 0.25*(1 - s0/s)`).
- **Protostars:** a cocoon (spr_soft, size × 9, star color darkened 30%, alpha 0.22) plus the core.
- **Births blow bubbles:** when the last thread lands and `p.idx < 0`, push to `_births` {bx, by}. After the fly loop, cloud motes within 90px get an outward kick `(1 - d/90) * 2.5`, then they drift back.
- `re` 18-36, `ae` 0.03-0.06.

## Step 1.2 result and Step 1.3 given (Oct 10, ~7:55pm): staging the birth
Step 1.2 check: everything was typed. It looked unchanged because `ae` was too faint once spr_soft spread the light over about 2.4x the area, so `ae` was raised to 0.08-0.15. Clip after that: **the soft gas reads as a real nebula** (teal clouds with red/violet patches from rainbow slimes, no bokeh). **Star births were invisible:** stars lit up while the cloud was still flying in (side by side, not inside it), the ignition was small in a busy sky, and the cocoons and bubbles were too small.
**Rainbow slimes (done):** `scr_make_hue_variants(spr, from_hue, [hues])` in scr_director makes recolored sprite copies once (via buffer HSV, blending off). `global.slime_sprites` = original + [245, 30, 165, 200] (the slime art's green is hue 92), built in obj_game_controller Create. Slime Create picks one (`mask_index = spr_enemy_slime`). Gotcha hit: the code first went into the slime's Collision-with-player event (it re-rolled colors every frame while touching, and there was a double `scr_damage_player` via `event_inherited`).
Step 1.3:
- `stream_wait` 1.4s: star dust drifts with the cloud (targets `sox, soy`) until `age > dust_fall + stream_wait`, then condenses (`_cnd`). Waiting star dust skips settling (`} else if (!_mt.strm)`). `dust_life` 4.5s.
- **Birth light (an emission nebula):** births carry `c` and `m`. In 2b each birth pushes `lights` {sky ox, oy, c, t0, r = 50 + 12·√m} plus a lasting haze wisp in the star's color (s 20 → 45, a 0.06). Drawn after protostars: spr_soft, radius r × (0.7 + 0.3k), alpha 0.35 × (fast swell over 15%, slow fade), 2.5s.
- Cocoon radius 8 + pgs·6, alpha 0.3. Thread alpha 0.85.

## Step 1.3 result and Step 1.4 given (Oct 10, ~8:20pm): one light per star, births staggered
Clip: a huge orange-to-white glow pulsed through every cast. Cause: births were pushed **per enemy**, not per star. Every enemy in a shared clump whose last thread landed before the plan's `idx` was set added its own light and haze wisp. That meant hundreds of lights, each about 1.6x bigger than intended (`r` 50 + 12√m on spr_soft /20), all inside about 1s because every plan condensed on the same clock. Additive stacking caused the whiteout; low masses are orange. The lingering peach bloom came from the stacked haze wisps. Threads were too fast to read (speed cap 10).
Step 1.4:
- Plans gain `lit: false` and `wt: random(fps*4)` (scr_hexweaver). Condense when `age > dust_fall + stream_wait + p.wt`. Forced landing at `dust_life + p.wt`. Births are guarded by `!p.lit`, which is then set to true.
- Thread speed `min(3.5, 0.6 + d*0.025)`.
- Light `r` 30 + 6√m, alpha 0.25, lasts 1.8s.

## Direction change (Oct 10, 8:50pm): the cast is the peek. Step 2.0 strips the birth staging
Step 1.4 was typed correctly, and it still didn't land. Diagnosis: a design problem, not a tuning one. Thirty tiny births in three seconds inside a bright cloud, right after the loudest beat, gives the eye nowhere to land. Sophia agreed: the goal is the universe sandbox she feeds and watches evolve over a run. **New plan (see spine §3):** the cast = the peek, which means catch-up births from old haze (a few at a time) and then the snap feeds new food. Step 2.0 removes 1.3/1.4 staging: `_cnd = _mt.strm`, no `wt`, the old thread speed, `dust_life` back to 3s, lights and stream_wait removed. Kept: `lit` on plans, the soft gas, bigger cocoons, brighter threads, and the bubble push. Next: Step 2.1, a single readable birth from haze, built in isolation (F10 trigger), before multiplying it.

## Step 2.1 given (Oct 10, ~9:30pm): the peek, births from old haze
- Macros `HEX_BIRTH_EVERY` 20 (seconds per birth) and `HEX_PEEK_BIRTHS` 4. New in scr_hexweaver: `scr_hex_haze_add(w)`, `scr_hex_nursery_at(cx, cy, t0, force)` (claims free wisps within 80px with `u = true`; mass = round(glowing wisps × 0.6); force sows 8 wisps), and `scr_hex_find_nursery(taken, t0, rmax)` (random non-soot wisp, 90..rmax from her, 140 apart).
- `global.hex_last_peek` (controller Create -1; set to current_time in obj_unmaking Clean Up). Create: `nurse_len` 4.5s, `nurseries`, `infall`. Births due = min(4, away/20); start at shatter + 0.9s, 1.3s apart; duration extended.
- Step (under `sky_angle +=`): **B** debug-seeds at the mouse. Per nursery: k < 0.7 gather (pull 0.003 + 0.025k, s shrinks to s0/2 so it brightens), infall spawned k < 0.62. At k 0.7 it catches: pushes to hex_stars (s = 0.7 + 0.3√m) and ignitions, sets the bubble push velocities, adds a lasting star-colored wisp. After: the bubble damps by 0.94 and wisp f fades to 0.4. Infall is Keplerian: ω = min(14, 160/r^1.2), r -= 0.35 + 22/r.
- Draw 6c (after the haze): the Bok globule (subtract, 30 → 14 radius), the red flickering protostar (k 0.25-0.7), Herbig-Haro jets (k 0.48-0.82, 70px, with knots), and the lamp after lit (34 + 4√m, alpha 0.3). The infall is drawn as spr_px streaks along the tangent.

## Step 2.0b + 2.1 RESULT (Oct 10, 9:43pm): IT WORKS. Stars are born from her nebula
Crash fix: the HEX_BIRTH_EVERY / HEX_PEEK_BIRTHS macros had been missed. Clip: the horde (rainbow slimes in a ring) becomes a lasting ring nebula colored by what the enemies were made of, and **births visibly happen in it**: the gas gathers into a sparkling knot, a red jet line appears, and it catches with a bright flare. Sophia: "that is it... a sign we are on the right path."
Polish list for births (from frame steps):
- The infall reads as a static sparkly fuzz, not a spiral. Needs longer streaks, a bigger starting radius, fewer but brighter motes, and maybe a faint trail.
- The dark globule barely reads against a bright nebula. Needs a stronger subtract or a darker rim, and maybe a dim cocoon edge.
- Jets are thin. They could be 2px with brighter knots and a slight wobble (precession).
- Catch: the flare plus lamp reads as a white ring/disc. Good, but it could use a brief light ring sweeping outward through the gas (the ionization front).
- The bubble push is hard to see.
Next: Step 2.2 (aging, red giants, planetary nebulae) is drafted in step-2-2-draft.md.

## Step 2.2 + birth polish APPLIED DIRECTLY by Claude (Oct 10, ~9:55pm)
Sophia gave permission **for this chat only** to edit Coven files directly, to make the most of the last minutes before the weekly reset. (The standing rule otherwise: she types every line.) Applied to Draw/Step/Create of obj_unmaking and to scr_hexweaver:
- **Step 2.2 in full** (aging, red giants, planetary nebula death with ring, white dwarfs, **N** debug key), exactly as in step-2-2-draft.md.
- **Birth polish:** infall spawns 2 per frame (was 3) from 35+ px out, falls slower (0.2 + 14/r), and streaks are longer and brighter (r × 0.06, 3..16px, alpha 1). The globule gets a lit rim (gas color, 1.4× size, 0.22) plus a darker heart (subtract 0.85). Jets are 2.5px with a precession wobble (8°) and bigger knots. The catch adds a light front: a ring of 28 stamps sweeping out to 95px in the star's color. The bubble push is 2..3.5.
Brackets balanced and CRLF kept. Untested at the time of writing.

## Step 2.2 result + polish pass 2 (Oct 10, ~10:10pm, applied directly)
Clip: births read (knot, jets, catch ring). B spam in one spot stacked births into a white blob and left a big cream glow (stacked lamp wisps). N aged stars and one puffed a ring: visible but small and dim. The infall still read as sparkly fuzz.
Applied:
- **B guard:** no new debug birth within 70px of an unlit one. Lamp wisp a 0.07 → 0.05.
- **Infall comet trails:** each mote is drawn as 5 fading dots along its recent spiral path (trail reaches clamp(ω × 2.5, 3, 30)°, farther out per step), with less white (0.2).
- **Planetary nebula:** radius 58 → 80 (inner ring 0.7×), lumpy radius (±10% via scr_hash), stamps 12/20 at alpha 0.22. Haze ring at 80/56, lumpy, s 14 → 30, fading up to at 0.12.
Next ideas: red giant swelling visible over a peek (pulsing), supernova for blue giants (Phase 3), births happening in the background sky between casts, F10 cosmic time mode.

## Sophia's note (Oct 10, 10:20pm): the birth jets need a real pass, and the jets should trim the garden
References: Hubble HH 1/2-style jet (a thin knotty teal-blue beam with a white base, one side green/dimmer behind the cloud, an orange-red cloud, a pale blue-white hourglass of lit gas around the star, a dark lane across the star) and JWST HH 211 (pink/orange knotted lobes, bow-shock arrowheads at the tips, a teal/gold glow at the base, symmetric). "These colors encapsulate the feeling I want this entire ult to have."
**Design:** jets are the outflow that clears the cocoon. The star keeps only part of its gas, and **the jets carry most of the rest (slightly less than all) out along the axis**, where it settles as long, thin lobes of haze. That's the "trim of the garden": it's the drain for births, accurate science (star formation is inefficient; outflows clear the cloud), and it leaves birth scars in the sky.
**Visual plan:**
- A knotty beaded beam: soft stamps streaming outward, elongated along the axis. The color runs from a white/teal base through teal-blue in the middle to pink/orange bow shocks.
- Bow-shock crescents at each tip.
- An edge-on disk: a dark lane across the protostar, perpendicular to the jets.
- An hourglass of pale reflected light flaring at the base.
- Asymmetry: the far jet is dimmer and redder (seen through the cloud).
- A slow precession wobble, so the knots trace a gentle S.
- A longer, showpiece jet phase (~1.5-2s) that fades after the catch.
Fold into the gas balance pass as "births eat their gas."

## Gas balance + HH jets pass APPLIED (Oct 10, ~10:45pm, direct edit)
**Gotcha found:** the Draw event had reverted to the pre-polish-2 version. GameMaker almost certainly saved an open editor tab over the external edit. Rule: before Claude edits files directly, close those event tabs (or accept GameMaker's reload prompt) and don't Ctrl+S an old tab afterward. Polish-2 draw edits were reapplied in this pass.
**scr_hexweaver:** macros HEX_HAZE_GLOW 0.6, HEX_GAS_REF 20, HEX_COLLAPSE_L 0.45, HEX_STAR_KEEP 0.3, HEX_POCKET_KEEP 0.12. Nursery struct gets `jetgo`. New functions:
- `scr_hex_wisp_light(w)` = a·f·√(s0/s)·(s/24)².
- `scr_hex_haze_expose(k)`: 48px cells of summed light L; per-cell ratio r = G(1-e^(-L/G))/L; each glowing wisp's `ex` eases toward r by k. Returns cells {L, x, y} (light-weighted centroid).
- `scr_hex_haze_merge()`: every wisp spreads (s × 1.06, cap 90) and thins (a × 0.96); a·f < 0.003 is dropped; u-claimed wisps are kept as-is; otherwise per 36px cell (glow and soot separately) wisps merge until ≤ 2, areas adding, light conserved, colors mixing by light. Rebuilds the array; haze_i = 0.
**Create:** `jbeads`. Births are now density-driven: merge, then expose(1), then cells sorted by L; due = min(PEEK, away/EVERY × clamp(gasL/REF, 0.5, 2.5)); seeds at the densest cells ≥ COLLAPSE_L, on screen, 90+ from her, 140 apart.
**Step:** expose(0.25) every 10 frames. Nursery at k 0.42 sets jetgo and assigns roles: jr 1 swallowed (pulled in, f → 0), jr 2 ejected (target 50-160px along a random pole, ±14 lateral; ang = jet, st 2-3 stretch, color 35% toward shock pink), jr 0 pocket (bubble). Jet beads emit in pulses (sin > 0.2) during k 0.42-0.88: d += v (3-4.2), v × 0.985, life 75.
**Draw:** haze uses ex (glow alpha) and st (x stretch), and skips f ≤ 0.01. Jets drawn HH-style: hourglass (5 pale blue stamps per side), beam (white-teal base, far side greenish), bow-shock crescents (7 stamps, pink; far side redder and at half alpha), an edge-on disk dark lane (subtract 24×5), and a precessing axis. Bead knots are drawn as stretched stamps colored white-teal → blue → shock pink along the distance, with the far side reddened and halved. Plus the polish-2 reapply (infall comets, PN ring 80 lumpy and brighter).

## Gas balance result + jet fix (Oct 10, ~10:55pm)
Clip: **births happened naturally** (density-driven, no B). The nebula is rich purple with no whiteout after the casts, and two black holes from earlier sit in the sky. The jets read as "warbling waves": the whole jet swung with the precession and an S-wobble applied at draw time, like a waving rope.
Fix (applied): each bead stores its launch angle `ang` (jet + 8·sin(t·0.05 + ph) + side·180 ± 2) and flies straight out, so the trail of knots freezes into an S like real jets; no draw-time wobble. Beads are chunkier (7 + 0.07d by 3.5 + 0.02d, alpha 0.6) with a hot white core. Ejected wisps travel faster (0.05) and stay visible (f ≥ 0.8), so the streak shows where the jet's gas landed.
Still to watch: merged wisps up to s 90 can read as big round blobs (soft bokeh). If so, cap the merge at about 60 or vary the stretch.

## Crash + overwrite again, jet spray added (Oct 10, ~11:05pm)
Crash `scr_hex_star_colour not set`: GameMaker saved old open Draw/Step tabs over the disk (pre-color-rename and pre-jet-fix) at 22:51. The clip she sent therefore showed the OLD jets. Restored the color + jet-fix versions, and added:
- **Jet spray** (k = 1 beads): about 4 per side per frame (× _jpow: full until k 0.6, then fading to 0 at 0.88), speed 3.5-7.5, a ±7° cone, life 50, drawn as spr_px streaks (length 3 × v). That gives "uncontrollably shooting dust".
- **Knots** (k = 0) are now gated at sin > 0.55, so they come as distinct blobs with gaps.
**Workflow fix needed:** GameMaker's open tabs keep overwriting direct edits. Sophia should close the obj_unmaking event tabs before Claude edits, then reload from disk (never save the old tab).

## Jets reshaped: aerosol plus wide wind, smaller births, newborn halo (Oct 10, ~11:15pm)
Sophia: the jets looked like a Roman candle and were too long for such small stars. Wanted something more like an aerosol: a stream of dispersing gas. Births a touch too large. Interested in a newborn glow. The violet megastructure is her ascension violet, which is a nice touch (her influence on her own universe), so keep it.
Applied:
- Knots: v 2-2.6, damping 0.97, life 60 (jet ~70px).
- Spray (k = 1): v 2.5-5, damping 0.95, life 45, ±6°, lateral drift lv ±0.25. Drawn as a bright speck for the first 40% of its life, then a growing mist puff (spr_soft 2 → 11, alpha 0.22).
- Wide wind (k = 2): 2 per side per frame, ±28°, v 1.2-2.4, damping 0.96, life 60, pale big faint puffs (4 → 16, alpha 0.1).
- Color gradient over d/80. Beam 22, bow shock at 75, light front 60, globule 22 → 11. Ejected gas lands at 30-90px.
- **Newborn halo:** stars with i ≥ new_from get a soft spr_soft halo ((6 + 3·ss)/20, alpha 0.12) for the rest of the cast.
Next big pass: **nebula texture** (filaments, dark lanes, lit edges) so the nebula matches the stars and holes. Then perfect the black holes (Sophia can't wait).

## Nebula texture pass 1 (Oct 10, ~11:40pm, applied directly)
- `scr_hex_wisp_sprite()` builds a 256×128 atlas once per game (global.hex_wisp_spr, built in obj_unmaking Create if missing). It holds 8 cells of 64px: 0-3 are billows (warped fBm, clamp((n - 0.3) × 2.2)), 4-7 are threads (ridged noise^4, anisotropic 0.75/1.7). Each cell is enveloped by the same bell as spr_soft and energy-normalized to 0.9 × the bell's light, so swapping it in keeps brightness.
- `scr_hex_draw_wisp(spr, fr, x, y, xs, ys, rot, col, a)` uses draw_sprite_general with a corner offset so it rotates around the cell's center. One texture, so it stays one batch.
- Haze draw (soot + glow) goes through the atlas with frame `fr` (lazy random). Fresh mote-born wisps have `tx` 0 → 1 (+0.008/frame): a crossfade from spr_soft to texture, so there's no pop. Merged wisps get thread frames 60% of the time; jet-ejected gas always gets threads.
- Possible first-cast hitch while the atlas builds (~330k noise samples). If it's noticeable, build it at game start instead.
Next ideas for texture pass 2: lit edges (gas near young stars brighter on the star-facing side), more dark lanes (soot companions for dense gas), color variation inside a wisp.

## Performance batch 1 (Oct 10, ~11:55pm, applied directly)
Clip: the texture pass looked amazing, but the game dropped to ~30 fps with 600 enemies, and the bare world (enemies and her hidden, only fireballs left) stayed on screen for about 6 recorded frames (~0.2s) at the cast start. The clean-frame photo was held during a hitch, and the flash didn't cover it.
Applied:
- `scr_hex_wisp_norm(w)` gives every wisp ex/st/tx/fr/at/u. It's called by scr_hex_haze_add (all creation now goes through it, including mote → wisp) and by the merge (normalizes old wisps each cast). Hot loops use plain dot access: no `[$ "name"]` lookups per wisp per frame.
- Expose and merge use ds_map with numeric keys (no string building). Expose keeps the wisp → cell link in a local array (no `ck` field).
- Haze draw: the sky turn is computed once (cos/sin of sky_angle) and each wisp position is rotated with 4 multiplies instead of point_distance/direction/lengthdir. The distance check is squared. The atlas draw is inlined (no function call).
- Dust budget: dust_total 5000 → 3200, per-body min 5 → 3. wisp_keep 0.475 → 0.3 with brighter growth (at = ae × 2.4), so it's the same nebula with fewer wisps.
- The atlas is built at game start (obj_game_controller Create), with the Create check as a fallback.
**Next for perf (needs measurement):** GameMaker's profiler during a cast (Debug run → Profiler → top functions), and a test with **YYC** instead of VM (often 2-5× faster for heavy GML loops). Candidates after that: the mote draw passes (5 per mote), section-7 star color recomputed every frame (cache it), mote steering math, skipping offscreen motes and wisps.
**The bare-world frames:** still to diagnose. Ideas: keep the flash up until the first real frame draws, pre-warm the big sky sprites at run start, hide projectiles for the photo too.

## 1200-enemy test after perf batch 1 (Oct 10, ~midnight)
Twice the horde, and it only dipped to ~40 fps at the end (it was 30 at 600 before), so batch 1 roughly doubled headroom. The dip comes as stars settle and gravitate: scr_hex_accrete runs every frame after the finale and re-sorts all newborns with a script comparator each time. The textured nebula reads beautifully at this scale (teal filaments, purple billows, dark lanes). The bare-world frames are still there (~4 recorded frames at the cast start).
Applied: accretion runs every other frame (half the cost, a gentler settle), and Draw GUI keeps a fading flash for t < 4 to cover any hitch.
Still to do for perf: a profiler capture, the YYC comparison, a cheaper accrete (spatial grid instead of sort), cached star colors, maybe projectiles hidden for the photo.

## 1400-enemy test, no backdrop (Oct 11, ~12:05am)
- About 800 enemies were pulled in: the ult only takes enemies **on screen** (camera rect), not a hard cap.
- FPS: 60 → 30 when the dusting starts, ~45 for the rest of the cast. Motes are the main cost while dusting.
- **The bare frame is a real freeze:** recorded frames 6-15 (~0.33s) are pixel-identical, showing the bare world with HUD and no flash. So the game froze right after presenting the clean frame, and the flash didn't appear on it (cause still unknown).
- Without the backdrop, the settled nebula of the first cast reads thin and speckled (small dim textured wisps). This confirms the thinning from perf batch 1.
Applied:
- **PERF PROBES** (show_debug_message, visible in the Output window): Create duration + doomed count + haze count, and Step/Draw ms for the first 6 frames then once a second (plus motes, haze, fps_real). Remove once measured.
- Fuller nebula: kept gas brightens 0.003/frame (was 0.0008) and billows out at +0.3/frame while its texture fades in (was +0.08).
- Sophia set `_covers` to 0.99 (no backdrop) for testing. Restore [0.87, 0.73, 0.62, 0.55] afterwards.

## Probe results + perf batch 2 (Oct 11, ~12:20am)
Probe (1132 doomed, VM): **Create 226 ms** (that's the freeze). Entrance frames: Step ~0.01 ms, Draw ~1-4 ms (fps_real 80-120). Dusting: Step 10-19 ms with 1.9-3.3k motes, Draw 9-15 ms, fps ~35. Motes are the cost. Afterward ~45 fps.
Applied:
- **Create no longer freezes:** per-body star planning and sprite pixel reads moved into a Step queue (`plan_queue`/`plan_qi`), up to 80 bodies per frame and at most 2 new sprite reads per frame, during the entrance (seconds of idle time before the crumble).
- Mote steering has no trig: the sky's cos/sin are computed once per frame, the target rotation uses multiplies, and the swirl tangent is the perpendicular vector (my, -mx)/r.
- Mote streak pass: color only recomputed while it's changing (age ≤ gas_time, or stream motes); settled motes skip the streak entirely.
- Settled dust fade 4s → 2.5s (fewer live motes). Per-body min motes 3 → 2 for huge hordes.
Sophia asked about a 60-240 fps setting: the game logic is frame-based (per-frame speeds/timers everywhere), so >60 would speed everything up unless converted to delta time. That's a big refactor; it's parked as a post-slice idea. Note that fps_real shows headroom outside the cast.

## Probe round 2 + perf batch 3 (Oct 11, ~12:35am)
Probe: Create 137 ms at 1156 doomed, but **132 ms at only 257 doomed**, so most of the setup cost is fixed, not per-enemy. Step during the dust peak is 7-9 ms (was 10-19), Draw 6-8 ms (was 9-15); late-cast Step 16-17 ms with ~900 motes (that's the accretion/haze phase).
Applied:
- The fx sprites (spr_glow/dot/px/soft) are built once per game in global.hex_fx (each sprite_create_from_surface stalls on the GPU). Clean Up no longer deletes them.
- Create section probes (start / fx sprites / gather doomed / dust plans + sky art / entrance / peek) to find the remaining fixed cost.
- Dust that never comes to rest can still become haze where it is (wisp_keep chance at settle_life), sized to how it looks at that moment, so nothing pops. That's more nebula at the same mote cost.
- Motes re-steer every other frame (alternating halves; they coast in between, with steering strength × 1.9). Landing/settle checks still run every frame.
Sophia asked whether converting to delta time would make it cheaper: **no**. Delta time makes the game frame-rate-independent, but it doesn't reduce work per frame; at higher fps it does more total work. The levers for "heavier" are YYC, less work per element, spreading work over frames, and the GPU.

## Tonight's plan (Oct 11, 12:40am) + Step 3.1 supernovae APPLIED
Sophia: stay on the spine. Tonight: finish the full cycle (supernovae), polish the black holes, then the stargazing spot. **Parked:** a GPU path for motes/gas (vertex buffer or shader particles), the biggest perf lever after YYC; delta time (not worth it now).
Step 3.1, applied:
- `scr_hex_find_death` now includes giants (m ≥ HEX_MASS_GIANT) with priority (+100000), and skips ns/wd.
- Release in Step: a giant with m ≥ collapse mass (15 in F9 debug) and tier ≥ 4 or debug, with room, becomes a black hole (pushed to hex_holes at age 0, so the existing gather/impact plays, and the star is removed). Otherwise a **supernova**: the star becomes a neutron star (ns, s 0.6, m 2), the impact frame plays (impact_kind 2: a starburst with a small core ring), and `novae` gets { ox, oy, t0, ph }, nova_len 4s.
- Draw: the giant's death throb is faster and harder, white-blue. Nova: a flash (0-15%), 90 filaments (teal/gold/red, radius 150·(1-(1-k)^2.2), inner 0.72-0.9R → outer 1-1.1R), and 36 shell glow stamps. Neutron stars are pale blue with two sweeping pulsar beams (28px). Giants also swell and redden in old age (red supergiants), since the upper mass bound on that look was removed.
- Remnant → haze: 48 thread wisps on a ring (0.82-1.05 × 150) in teal/gold/red, st 1.6, at 0.13. Food, in colors kills can't make.

## Gaze mode (G) APPLIED (Oct 11, ~12:50am): sit in her universe
For testing the terrarium (and the seed of the stargazing spot). In a run (PLAYING state), **G** opens obj_unmaking with global.hex_gaze: nobody is unmade, nothing is hidden, no photo; t starts at birth_at (no entrance), duration = infinity; planned births/deaths are shifted to just after open. game_state becomes "GAZE" (the world freezes; unmaking skips its own freeze check) and is restored in Clean Up. While gazing: stars age 1 cosmic second per real second, a due death is queued when none is active, and every HEX_BIRTH_EVERY seconds the densest on-screen cell ≥ COLLAPSE_L starts a nursery. **G** again closes the sky (no return shockwave). B and N still work.
Next: black hole polish (look + feeding), then the hub stargazing spot (needs the sky saved/kept across rooms).

## V key + gaze warp (Oct 11, ~1:05am, applied)
- **V** (during a cast or G): spawns a 40-mass giant at the mouse with age at 101% of its life. It's dying immediately but its death starts 1.5s later, so it shows as a red supergiant first, then the throb and the supernova. With F10 on (collapse mass 15), it collapses into a black hole instead.
- **Gaze warp:** in G, the sky opens over 0.6s from her (the jagged tear circle grows, with the violet edge) and closes over 0.5s on G again. 56 violet-white streaks rush outward while opening and inward while closing (hyperspace-style), alpha × (1 - open). This is the planned entrance for the hub stargazing station.

- Gaze pause (Oct 11, 1:08am): Esc or P toggles `gaze_paused`, which makes Step exit early so births, aging, gas and sky turn all hold. G still leaves. Draw GUI shows "PAUSED - Esc / P to resume - G to leave".

## Black holes first-pass polish (Oct 11, ~1:20am, applied)
Line count at this point: ~7,800 lines across the project (~6,300 non-blank, non-comment). obj_unmaking ~1,950, scr_hexweaver ~1,000.
Tonight's queue (Sophia): BH polish ✓ (first pass) → timelapse in G → supermassive → shaders/GPU (haze as a static vertex buffer rotated by a uniform is the likely first win; mote logic stays on the CPU unless we go full GPU simulation). Sophia creates any new shader asset in the IDE (Create Shader) and Claude fills the files, since new assets need project registration.
Applied:
- **The hole (scr_hex_draw_hole, after gather/aftermath):** a two-layer bloom (spr_soft), the disk as 3 rings × 40 soft stamps with **Doppler beaming** (the approaching side is blue-white and bright, the receding side dim and red), far half behind the shadow and near half in front. 110 orbit streaks per pass (was 220). **Lensed far-side arc over the top** (37 stamps on an ellipse 1.5r × 1.28r, brightest at the top) plus a fainter under-arc. Black horizon. The photon ring is now a hairline plus two glow rings.
- **Feeding (Step):** holes ≥ 1s old pull every wisp within 300px into a spiral (ω = min(4, 250/d^1.2)°/frame, inward 0.05 + 30/d px/frame), stretch it along the orbit (st 1 → 3.5, ang = tangent), and swallow it inside 1.3r (f = 0, m += 0.04). It's the final drain, and the hole grows.
- **Lensing (Draw §7):** stars within 7r of a hole are pushed outward by 1 + (2.1r)²/d² (crowding into an Einstein ring); stars right behind the shadow are hidden.

## Black holes pass 2 (Oct 11, ~1:50am, applied)
Clip: the shape is heading somewhere nice, but the disk + lensed cap clipped to solid white (additive stacking: ~120 stamps + 110 streaks + bloom). The feeding gas swirled as a flat face-on circle around each hole, mismatched with the edge-on disk. Post-birth jet streaks read stiff. Note: the pass-1 disk soften edit never reached disk (commit race), so the clip showed the brightest version.
Applied:
- **Disk:** 4 rings × 32 stamps, thin and wide (radius 1.55r → 3.8r), with a temperature gradient (white-gold → orange → violet). Alpha 0.025 + 0.11·dop², so only the approaching inner edge reaches white. Doppler shifts toward blue-white or dim red. Streaks: 90 per pass, alpha 0.08 + 0.4·beam². Bloom alpha 0.07/0.08.
- **Lensed arc:** hugs the shadow (1.22r × 1.34r), thinner stamps at alpha 0.11, warm color; under-arc 1.14r × 1.16r at 0.07. Photon ring 0.85 / 0.3 / 0.12.
- **Feeding in the disk plane:** each wisp is transformed into the hole's frame (tilt - sky_angle), sinks toward the disk plane (0.25 + 1.2% of its height per frame), and orbits/falls in the plane coordinates (y/0.22) before converting back. Streams are stretched along the squashed orbit tangent, and gas heats toward white-gold inside 4r.
- **Jet streaks relax:** u-claimed wisps with st > 1.2 lose 0.002 st/frame and rejoin the garden (u = false) at 1.2.
Reference targets: NASA Goddard 2019 black hole visualization (Schnittman), Interstellar's Gargantua, and EHT M87*/Sgr A* for the ring proportions.

## Sticks fix + shader foundation (Oct 11, ~2:45am, applied)
Clip at 2:01am: the collapse is a boom (impact frame, white ball, translucent bubble + outward ring); the disk is a one-sided streak (Doppler²); the white photon ring outline is too hard; the lensed arc is barely visible; jets outshine the hole; supernova debris reads as fireworks; planetary nebula rings are starting to tile. **Sticks** = one big wisp stretched 4× along a tight orbit (a straight sprite can't bend), and the leftover `ang = point_direction(_fnx,_fny)+90` line was overriding the orbit angle.
**Sticks fix (Step + Draw):**
- Tidal shredding: a wisp with s > 9 inside 7r splits into 3 (s and s0 × 0.58 conserves light), spread radially ±0.9s. At most 4 splits per hole per frame. Pieces turn stringy (atlas cells 4–7).
- A caught wisp (`tr`) stops spreading (smax = s) and records p1/p2 every 4 frames. Draw adds 2 fading trail stamps along its real path, so streams curve.
- Angle = actual motion direction. Stretch capped so length ≤ 0.3 × distance to the hole.
- Heat by radius: its own color beyond 6r, orange (255,150,80) at 3–6r, white-gold (255,222,188) inside 3r.
- `tr` default added to scr_hex_wisp_norm.
**Shader foundation (Draw, Create, CleanUp):**
- Sky sections 2–7 draw into `sky_a` (rgba16float if supported) with camera_apply.
- sh_hex_lens copies it into `sky_b`, bending light with the point-lens equation: src = p − d·θE²/|d|², capped at 2, fading out past 4–9 θE. θE = 1.8r; strength = 0.5·k² during the gather, so light bends before the collapse. u_ripple[4] is ready for gravitational waves and shockwaves (zeros for now).
- Holes draw into `sky_b`. Then sh_hex_tone composites additively: linear below a luminance knee of 0.7, exponential roll-off above it, overbright colors bleach toward white.
- CPU star lensing is off when the shaders are active. With no shaders, it falls back to the old direct drawing (looked up with asset_get_index).
- Watch: soot subtract in a float surface can go below 0, so dark lanes may read a bit stronger.
**Order from here:** hole look under HDR (full disk across the shadow, Doppler^1.5 with a floor, disk-colored over/under arcs, thin warm photon ring, hot spots, growth) → formation (inhale, vanish, polar beams, ignition; drop the bubble) → role (feeding jets that trigger births, migration, merge + GW ripple) → supermassive (galaxy, quasar, twilight, Hawking evaporation → new aeon, CCC). Tomorrow: the universe bible audit.

## First HDR clip fixes (Oct 11, ~3:05am, applied)
Clip at 2:50am. The shaders work: at t=4s the lensed nebula swirling around the hole looks great. Bugs found:
- **The whole nebula vanished in ~4s.** Shreds used scr_hex_haze_add. At the cap, that overwrites the oldest wisps anywhere, so 8 shreds per frame erased the sky. Fix: shreds array_push past the cap (up to CAP+800, cleaned up at the next merge) and only tear wisps with s > 14.
- **Spiky rainbow halo at about 2.5r** = the Einstein ring magnifying tiny stars into spokes. Fix: θE 1.8r → 1.3r (tucked near the photon ring), plus a 5-tap tangential blur near the ring.
- **Disk was a laser line with bright tips.** Concentric rings seen edge-on pile up at their ends. Fix: 150 stamps at random radii (u², crowded inward) from 1.5 to 4.9r, tapering in alpha and size toward the rim. Doppler beaming 0.3 + 0.7·dop^1.5.
- **Photon ring** was a white outline. Now warm (255,214,170) at alpha 0.5, plus a blue stamp on the approaching side.
- **Births sparking in the disk** (gas collects there, so the density nurseries fired). Fix: no nurseries within 7r of a hole (the tidal/Roche limit).

## The Gargantua pass: the disk drawn in the shader (Oct 11, ~3:30am, applied)
Clip at 3:13am: the nebula survives now, and the hole carves a dark cavity around itself (real quenching, keep it). Still missing the Interstellar look: the disk is a thin flat line, the over-the-top arc is only a faint ring hugging the shadow, and there's no fine texture. The rainbow spikes were still there early on: an exact Einstein ring maps a tiny circle behind the hole onto the whole ring, so star pixels fan out into radial spokes.
**The key idea:** Gargantua's look *is* lensing. The arc over the top is the far half of the disk, seen by light bent over the hole. sh_hex_lens already knows where every pixel's light came from, so it now draws the disk itself, per pixel:
- **Softened lens** src = p − d·θE²/(d² + 0.55θE²): no singular ring, no mirrored zone, finite magnification (~9× at the shadow edge), so no spokes. The bright compressed ring hugs the shadow.
- **disk(q):** un-squash (y/0.22) → ρ in shadow radii, from 1.15 to 5.6. Profile (1.25/ρ)^2.2. Keplerian spin ph = φ − 1.8t·ρ^−1.5. Fine orbit streaks (two sine layers with integer φ frequencies, so there's no seam). Two orbiting hot spots (real: Sgr A* flares). Doppler (1 + v·cosφ)³ with v = 0.35/√ρ, plus a blue/red color shift. Temperature colors white-gold → orange → her violet.
- **Per pixel:** inside r is the black shadow. Otherwise the far half is sampled through the lens map (arc over the top), plus a mirrored 0.35× image under the shadow within 2.2r, plus a photon ring hairline at 1.03r. The near half is direct and crosses the shadow.
- GML passes u_disk[4] (r in px with the overshoot swell, tilt in radians, disk ramp, seed) and u_time = t/fps (pauses with the game). scr_hex_draw_hole(…, _gpu) keeps the gather, aftermath and bloom, and skips the CPU disk/arc/horizon/ring.
- Shredding threshold s > 14 → 11 (finer streams).

## Shader disk, first look + fixes (Oct 11, ~3:50am, applied)
Clip at 3:32am (50s: a 1,100-enemy cast, then gaze with two holes). **The Gargantua silhouette landed:** shadow, a soft brim arc over the top, a violet under-arc, the near band, a crisp photon ring. Problems:
- The near half covered the lower half of the shadow like murky fog (SQ 0.22 is too face-on) → **SQ 0.12**, nearly edge-on, so the band across the shadow is thin. The brim samples the hotter inner disk, so it should read gold, not lavender.
- **The rainbow spoke ring was in-falling gas**, not lensing: the sink-to-plane motion was mostly vertical, and wisps were stretched along their motion, so every cloud above or below pointed at the hole. Fix: angle = orbit tangent only. The plane-sink is gone; instead each caught cloud's orbit flattens fz 1 → 0.12 at 0.004 per frame (Bardeen-Petterson alignment), so nothing swings wide.
- **The laser line while feeding** = fed gas piling into the plane and stacking additively. Fix: inside 4r, a cloud's f drains 2% per frame into hole.feed (swallowed f also counts). feed decays ×0.995 per frame. Shader disk brightness = ramp × (0.55 + 0.9(1 − e^(−feed/40))): a starving hole is dim, a feeding one blazes.
- New hole field feed:0 (with a variable_struct_exists guard for old holes). wisp_norm defaults fz = 1.

## Fluid feeding + Interstellar pass + formation sequence (Oct 11, ~4:15am, applied)
Clip at 3:43am (3 holes): the whole nebula had turned into stretched strokes and chevrons, because with 3 holes at 300px reach nearly every wisp was being pulled, stretched (st up to 4) and given thread texture.
**Fluid feeding (Step):** reach = min(300, 7r), with the pull fading in smoothly (smoothstep from the reach to 3r) on both orbit speed and infall. Only clouds within 4.5r are "caught" (tr: trails, frozen spread, flattening, stretch, heat, drain). Far gas just drifts and keeps its billowy shape. Angles ease toward the orbit tangent (12% per frame caught, ≤2% far) and never snap. Stretch eases to ≤2.2. Shreds are soft billows (cells 0–3), not threads. Drain into the disk inside 3r.
**Interstellar detail (sh_hex_lens):** periodic value-noise fbm turbulence sheared along orbits, using two flow copies on a 7s cycle so the Kepler shear never winds the pattern into stripes. Fine lanes on top. A smoky envelope (SQT 0.30, wispy thresholded turbulence, cooler color). Gravitational redshift dims and reddens the inner edge (ρ 1.15–1.9). A layered photon ring (3 nested hairlines at 1.030/1.012/1.004r, Doppler-brightened). Glare: a soft halo plus a streak along the disk.
**Formation:** the inhale = 3 contracting light rings + 28 inward streaks, the star swelling and reddening then crushed, and the lens ramping to full strength. The impact frame stays (the vanish). Then: twin polar gamma-ray beams (1400px, 0.7s, flicker), a 0.15s core flash, a gravitational ripple (u_ripple, 1500px over 1.4s, amp 7px), the photon ring igniting first (u_ringk flare ×3 → 1), and the disk building over 2.5s. Fallback: 28 warm wisps at 2.6–4.4r spiral in and feed it. The sky's light seeps back over 1s. The old violet shockwave band, white ring and big afterglow are gone.

## Supermassive foundation, freeze fix, the heart (Oct 11, ~4:40am, applied)
- **Freeze at V:** a find-and-replace turned scr_hex_hole_size's own body into a call to itself (infinite recursion). Found with the debugger pause (scr_hexweaver line 601). Fixed.
- **Supermassive screenshot:** it works and looks great, but it sat on top of her, with gray inside the top of the shadow. Fixes: scr_hex_holes_clear_her() keeps holes ≥ max(HEX_HOLE_MIN_DIST, 3.2·size) from her, easing out 8% per frame (called after migration and merges). In the shader path, the CPU bloom stamps are gone (they were drawn after the lens pass, over the shadow).
- **The heart (outflow):** 2% per frame of disk gas drains into hole.out, × keep (0.9 for a supermassive, 0.35 for small holes). Up to 3 wisps per frame are emitted from the poles as flying gas (fl = true, vx/vy, damping 0.985, cooling blue-white → violet, stretched by speed). It settles where it slows, and density births do the rest. A supermassive also blows a ±60° wind. Feeding skips flying gas. The haze merge lands all flying gas and clears global.hex_flow.
- **Faint polar jets** are drawn while feed > 8 (longer for a supermassive).
- **Tidal disruption:** every 12–22s, a supermassive tears apart its nearest star (within 10r): a 22-wisp arc, half flung outward (flow), +40 feed flare, half the star's mass swallowed, plus a big ignition flash.
- The 4:24 clip upload was a duplicate of the 3:43 clip, so the stuck-hole bug hasn't been seen yet.

## The aeon cycle, first pass (Oct 11, ~4:55am, applied)
Clip at 4:33 (before the heart): the supermassive with the galaxy turning, the nebula swept into a giant lensed ring. Sophia: the supermassive is the main spectacle and the bridge from the end of the loop to the beginning. Feeding gas read as dashes, because trail stamps were spaced 4 frames apart → now each trail segment is one soft stamp stretched across its whole gap (continuous streaks).
**scr_hex_aeon_step()** (global.hex_aeon {phase, t, n}), called every frame from Step:
- **dawn/galaxy:** a supermassive exists → galaxy. Its meal (disk gas drained) ≥ HEX_QUASAR_MEAL 300 → quasar.
- **quasar (10s):** qk ramps up, holds, fades. Disk brightness ×(1 + 2.5qk), feed ≥ 80 (polar jets), screen-crossing relativistic jets + a halo (draw_hole gpu branch). Quasar wind: up to 30 wisps per frame within 12× size are turned into flying gas, blown radially outward and heated blue-white. No births (nursery_at returns undefined unless forced).
- **twilight (45s):** no births, gas dims (a×0.995 on a rotating tenth), gaze aging ×4 so old stars die into rings and embers.
- **evaporation (14s):** evk 0 → 1 shrinks the hole (size × (1 − 0.92evk)) and fades its disk, while a white-blue Hawking glow grows. At the end: 12 clumps × 34 primordial wisps in the next palette (4 palettes, cycling), a 24px ripple, a big ignition flash, shake, and the supermassive is removed → dawn, aeon n+1.
- **K (debug):** skip to the next phase (galaxy → quasar instantly).

## Stabilizing pass + Hide HUD (Oct 11, ~5:05am, applied)
Clip at 4:49 (57s, lots of key-mashing). Diagnosis: (1) stacked holes = a third hole migrating onto a pair mid-inspiral (only one merger at a time, and nothing held it back); (2) quasar = up to 30 clouds per frame flung out and stretched up to 3× (hyperspace streaks) at **5 FPS** (overdraw plus one-by-one deletes); (3) no primordial gas at dawn = dead (eaten) wisps never removed in G mode (merge only runs per cast), so the list hit cap+800 and silently blocked shreds, outflow, fallback, TDE and primordial gas.
Fixes:
- **Dead-gas sweep** every 120 frames (f ≤ 0.01 removed, haze_i reset).
- **Flow list** rebuilt in one pass each frame. Flying stretch ≤ 1.8. Flying gas capped at 700 (outflow and quasar both respect it).
- **Quasar wind:** ≤12 per frame, speed 3.5–6 (was 30, 5–9).
- **Stand-off:** migration never moves a hole closer than 1.2× combined size to another (2.8× while a merger is running). Mergers complete when the horizons touch (sep ≤ 0.95× combined).
- **Evaporating supermassive** stops feeding and outflow (Hawking radiation is light, not gas; what it kept returns at the final flash).
- **H** in G mode hides the HUD, the readout, PAUSED text and the cursor (wallpaper mode). HUD Draw GUI exits when GAZE + hex_hide_hud.
- **Debug readout** (bottom-right in G): aeon n + phase, holes, gas (flying), supermassive meal/300, and the key list.

## THE BIG BANG (Oct 11, ~5:15am, applied)
Sophia: "are we about to genuinely recreate a big bang to complete this cycle… lets do it." Science framing: Hawking evaporation leaks mass as light over the hole's whole life (the last second is violent, but most mass is already gone), so the flash isn't the hole dumping its mass. Instead, per Penrose's conformal cyclic cosmology, a dead universe of nothing but light becomes the next Big Bang. The end of the aeon IS the next beginning.
- **Singularity → whiteout:** global.hex_bang {ox, oy, t}. Draw GUI washes the screen white (full for 0.15s, fading over ~1s).
- **Expansion:** 12 clumps × 34 primordial wisps launch from the singularity with v = distance × 0.015 (exactly enough to coast to their resting spot at 1.5% damping), growing as they fly (s 0.35 → 1.6 × size), fading in (tx 0, a 0.03 → 0.11). Flying gas keeps its own palette color (flow uses `cool` when set). Allowed up to cap+1300.
- **Afterglow (the cosmic microwave background):** the whole sky glows additive orange (255,160,80) cooling through deep red to dark over 7s.
- **The old universe is gone:** old gas f × 0.35 (a faint memory), all holes removed, merge cleared, and (only in G mode, so cast dust indexing stays safe) all old stars cleared.
- 24px ripple, shake 30. Then density births light the first stars of the new aeon, in its new palette.

## The Big Crunch → Big Bounce, and a better Big Bang (Oct 11, ~5:35am, applied)
Clip at 5:19 (86s). Problems: flat brown afterglow wash; the expansion read as ~12 fat blobs (each clump's 34 wisps flew together); the new gas was sparse, dim and mostly off screen (clumps 160–850px from a bang at the top of the screen); no first stars. Sophia: the disk spinning faster as it condenses is great. Could the supermassive pull the whole screen in as it spins up, a Big Crunch, then the ultimate Big Bang?
**Science:** the Big Crunch → Big Bounce is a real cyclic-universe family (bounce cosmologies), distinct from Penrose's CCC; observations currently favor endless expansion, but it's published physics. Spin-up while contracting = conservation of angular momentum (real). Lensing growing as density rises (real).
- **Evaporation phase replaced by "crunch"** (12s, after twilight): all gas, stars (G mode only) and other holes spiral into the supermassive. The fall per frame is 0.3% → 4.8%, the spin 0.4 → 8.4°/frame at 300px (∝ 300/d). Gas inside 1.2r is swallowed, holes absorbed with ripples, flying gas stopped. Supermassive ck: lens θE × (1 + 1.6ck), disk × (1 + 2ck), feed up to 260, shake ramp. **The disk clock spins up:** global.hex_disk_time advances (1 + 9ck²)× and feeds u_time.
- **Bang:** 44 small clumps × 10 wisps launched from the singularity to rest spots in a disk of radius 60–780 around 0.3× the bang point (so it settles around her, in view). White-hot (255,246,236), cooling into the palette while flying (cool). 26px ripple, shake 34, whiteout held 0.25s.
- **Mottled cosmic microwave background:** in sh_hex_lens (u_cmb: strength 0.42·(1−k)², temperature k over 8s, seed per aeon), two-octave fbm patches, hot orange → deep red. Replaces the flat rectangle.
- **First light:** from 2.5s to 16s after the bang, every 1.4s, try a nursery at a landed bang wisp.
- **Still to do:** Hawking-point seeding (old hole positions → warm clumps), run-signature palettes.

## The universe ends, then the lightswitch (Oct 11, ~5:55am, applied)
Clip at 5:38 (138s). The crunch swallowed all the gas in ~5s, then the supermassive sat in an empty sky for ~7s; it never grew, and the bang read as ~40 dash blobs. Sophia's target: "the entire universe just ended, Pucci won, game over, then the lightswitch of life switches back on."
- **Paced crunch:** each thing's remaining distance follows (1−k)^1.6, so everything arrives exactly at the end (slow, then a rush). Spin (0.5 + 10k²)·300/d °/frame, capped at 12. The supermassive drifts toward her (2%·k per frame) and is exempt from her clearance.
- **The horizon swallows the sky:** size × (1 + 9k⁵) during the crunch. The shadow fills the screen (a horizon forming around everything).
- **"void" phase (1.1s):** total black and silence (shake 0), then the Big Bang.
- **Bang:** clumps plus 70 broad soft haze wisps (36–60 size) filling the space between. Bang gas stretch × 0.25 (no dashes).
- **Ringdown:** a merged hole's size × (1 + 0.16·e^(−mf/20)·sin(0.85·mf)) for 100 frames (the "struck bell" LIGO hears).
- **Cleaner disk:** gas dissolves into the disk from 4.5r (2.5%/frame, 6% inside 3r), so the shader disk reads as one body.
- **Softer outflow:** billow cells, size 10–15, stretch 1.3, a 0.05.
- **Spine idea: dark matter.** The galaxy's flat rotation curve is the real evidence for it. Show it as an invisible halo seen only through faint weak lensing everywhere.

## End-of-universe fixes (Oct 11, ~6:10am, applied)
Clip at 5:57 (61s, in regular casts, not G mode, which is why no readout or H). The horizon swelled but never covered the corners; no black hold; no visible flash; the bang still read as darts (thread textures, angled along flight); blocky rectangles on the giant disk (gas stamps blown up huge).
- **K can't skip** the crunch or the void.
- **The void covers everything:** a GUI black overlay ramps in over the last 1.5s of the crunch and holds through the void. The HUD exits during the void.
- **The backdrop fades with the old universe:** nebula sprite, deep field, mid stars and bright stars × _bgk (1 → 0 over 9s of crunch, 0 in the void, back with (t/14s)² after the bang, as if the new stars' light is only now arriving).
- **Crunch gas** within 2.5r fades (f × 0.9 per frame); stretch ≤ 1.9.
- **Bang gas:** billow cells only, random angle, zero flight stretch (a blooming cloud, not darts).
- Sophia's note for optimization: lag is worse when spawned slimes are bunched together, which suggests nearby-object checks (enemy separation or collisions) scale badly with crowding. Look at it in the optimization pass.

## Smoothing: no more star BOIOIOING (Oct 11, ~6:20am, applied)
Sophia: the stars go BOIOIOING when black holes merge and grow; the systems need smoothing between them to be stunning, smooth and readable, with real physics and optimization. Cause: lens θE was tied to the raw size, which jumps ×1.45 on a merge and then oscillates with the ringdown, so lensed stars snapped and bounced.
- **hole.rs:** the drawn size eases toward the true size (no ringdown) at 4% per frame (25% during the crunch so it keeps up). scr_hex_hole_vis() returns it.
- **Lens θE** uses rs (smooth, no wobble). **The shadow** uses rs × scr_hex_ringk() (it still rings). scr_hex_hole_size(_ho, _ring = true) can now leave the ringdown out.
- The 6:10 clip upload was again a duplicate of the 9:51 recording.
**Tomorrow's "smoothing pass" theme** (Sophia): ease every transition between systems (sizes, brightness, lens strength, phase changes, gas handoffs between feeding/flying/settled) so it's visually stunning, smooth and readable, physics-first, then optimize.

## The aeon director, first version (Oct 11, ~6:40am, applied)
- **global.hex_mood {bg, dark, spin, lensk}**, eased every frame in scr_hex_aeon_step toward per-phase targets. Twilight: bg 0.75. Crunch: bg 1 − k, spin 1 + 9k², lensk 1 + 0.5k, dark ramps over the last 18%. Void: bg 0, dark 1, spin 0.3. After the bang, bg is capped by (t/14s)². Rates: bg 6%, dark 15%, spin 5%, lensk 3% per frame. At the bang, dark and bg reset to 0 (the whiteout covers the cut).
- **Consumers:** Draw _bgk = mood.bg (backdrop), Draw GUI black overlay = mood.dark, disk clock += mood.spin/fps, lens θE × mood.lensk.
- **Lens no longer follows the crunch swell** (θE divides out the 1 + 9ck⁵ factor), so the sky isn't magnified into blocky rectangles.
- Next on the director: brightness/exposure, shake, gas brightness, quasar glow, hole formation ramps. Then the crunch as a fully scripted cinematic on top of it (see terrarium-status.md).

## Color grade per age + a real Big Bang (Oct 11, ~6:55am, applied)
2.9s clip: before the bang, still the blocky swollen horizon, no black, no white flash; the new universe just "poofs" into dust. GUI overlays not visible (question to Sophia: was this in G mode? no readout visible).
- **Darkness and whiteout are also drawn in world space** at the very end of Draw_0 (normal blend, over the view), so they can't be missed even if the GUI layer misbehaves.
- **The bang in the sky (HDR):** a singularity core flare (spr_glow, 16× shrinking to 2× over 2s) plus a warm halo, and a 7-ring shell of first light racing to ~1930px over 1.8s (white → blue-white).
- **Color grade (director → sh_hex_tone u_grade/u_lift):** quasar (1.05, 1.03, 1.12); twilight amber (1.12, 0.86, 0.66); crunch blueshift lerping to (0.7, 0.88, 1.45) with a blue lift up to 0.05 (the background brightening); after the bang a cool (0.86, 0.96, 1.14) grade easing back to neutral over 16s. Eased 2%/frame (lift 3%).
- Next science visuals (see the chat): Fermi bubbles during the quasar, stars reddening in twilight, the dark ages after the bang, then cosmic dawn (first massive blue stars blowing glowing reionization bubbles that merge).

## The matter ledger + the biggest boom a witch ever saw (Oct 11, ~7:15am, applied)
3.5s clip: the crunch → black → void → white → shell → gas all worked, but with no "mmph" (a long gray fade, then soft blobs).
- **Ledger (scr_hex_matter_take, at crunch start):** total L = Σ wisp light + Σ star m·0.02 + Σ hole m·0.05, plus a sample of up to 64 colors. The bang releases clamp(L/1.2, 260, 720) wisps in clumps of 8, colored merge(old color, new palette, 0.5): the same matter, transformed. Only kills add new matter (full ledger for every system = next step).
- **The void:** a trembling white pinprick at the singularity grows from 25% to 100% of the void, and vanishes 2 frames before the end (one frame of nothing).
- **Impact frame:** hitstop 9, kind 2 at the bang point (time stops on creation). Then a white punch (full 0.12s, gone by 0.6s), in GUI and world, only after hitstop.
- **Screen tearing:** sh_hex_lens u_chroma: red pushed outward and blue pulled inward from the bang, 16px fading over 1.2s.
- **Triple ripple:** amps 46/26/14, staggered (negative start age = waiting).
- **Inflation:** launch drag starts at 0.78 and relaxes to 0.985 (wisp.dmp); launch speed = distance / precomputed carry factor, so matter slams out almost at once, then drifts to rest.
- **The fog that clears (recombination):** CMB strength 1.6 (blazing opaque-looking plasma) for 0.5s, falling to 0.42 by 1.6s (the universe turns transparent), then the mottled afterglow fades over 8s.
