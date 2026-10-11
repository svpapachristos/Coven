# Step 2.2 (draft, ready to type once 2.1 works): stars age, red giants, planetary nebulae
Written Oct 10, ~9:40pm. Type this **after** 2.1 is tested and working. It hasn't been run yet, so expect one or two small fixes.

## What it does (the real astrophysics, kept simple)
Her stars now **age** while she's away fighting (cosmic time, the same clock that drives 2.1's births). How a star ages depends on its mass, like real stars:
- **Red dwarfs (light stars)** live forever. They're the steady background of her sky.
- **Sun-like stars (middle mass)** live a while, and the heavier ones die sooner because they burn hotter. In the last 30% of their life they **swell into red giants**: bigger, and shifting orange-red. So across casts you notice "that yellow star turned into a big orange one".
- When a sun-like star's life runs out, it dies **during a peek, where she can see it**. It throbs a few times, then **puffs its outer layers off into a glowing ring** (a planetary nebula, like the Ring Nebula): red hydrogen outside, teal oxygen inside. Left at the center is a **white dwarf**, a tiny white-hot core.
- The ring settles into lasting haze, so it becomes **food for new stars**. That's the matter cycle closing: stars are born from her kills, die back into gas, and the gas makes new stars.
- **Blue giants** don't die here. They'll go supernova in Phase 3.

At most one death per cast, so each one gets noticed.

**Debug: N** (during a cast) makes a minute of cosmic time pass instantly: every star ages 60 seconds, and if a star's time is up, it dies right then. Press it a few times to watch red giants swell and then pop.

---

## 1. scr_hexweaver
**a)** Under the `HEX_PEEK_BIRTHS` macro, add:
```gml
#macro HEX_MASS_SUN_MIN 6   // stars at least this heavy are sun-like: they age, swell into red giants and die as planetary nebulae. lighter ones live forever
#macro HEX_MASS_GIANT   24  // this heavy and up is a blue giant: it skips the planetary nebula (it goes supernova later)
#macro HEX_SUN_LIFE     240 // seconds of her fighting a mass-10 star lives. heavier dies sooner, lighter lives longer
```

**b)** At the very **bottom** of the script, add:
```gml
// how old a star is in cosmic seconds (stars from before aging existed count as newborn)
function scr_hex_age(_st) {
	var _a = _st[$ "age"];
	return is_undefined(_a) ? 0 : _a;
}

// a star's life, in seconds of her fighting. heavier stars burn hotter and die sooner, like real ones. red dwarfs never die
function scr_hex_star_life(_m) {
	if (_m < HEX_MASS_SUN_MIN) return infinity;
	return HEX_SUN_LIFE * power(10 / _m, 1.2);
}

// the sun-like star furthest past the end of its life, or undefined if none is due
function scr_hex_find_death() {
	var _best = undefined, _over = 0;
	for (var i = 0; i < array_length(global.hex_stars); i++) {
		var _st = global.hex_stars[i];
		if (_st.s <= 0 || _st[$ "wd"] == true || _st[$ "dying"] == true) continue;   // gone, already a white dwarf, or dying now
		if (_st.m < HEX_MASS_SUN_MIN || _st.m >= HEX_MASS_GIANT) continue;          // only sun-like stars die this way
		var _ov = scr_hex_age(_st) - scr_hex_star_life(_st.m);
		if (_ov > _over) { _over = _ov; _best = _st; }
	}
	return _best;
}
```

## 2. obj_unmaking → Create
At the very **bottom**, under the 2.1 block, add:
```gml
// ---- the peek, part 2: her stars aged while she was away. sun-like stars swell into red giants, and one whose time is up
// dies while she watches: it puffs its outer layers off into a glowing ring and leaves a white dwarf ----
death_len = _fps * 1.2;      // the dying star throbs this long before it lets go
shell_len = _fps * 3;        // the ring takes this long to puff out and settle
deaths = [];                 // stars dying while she watches: { st, t0 }
shells = [];                 // planetary nebulae puffing out: { ox, oy, t0, ang, ell }
for (var i = 0; i < array_length(global.hex_stars); i++) {
	var _ast = global.hex_stars[i];
	_ast.age = scr_hex_age(_ast) + _away;                    // cosmic time passed while she fought
}
var _dth = scr_hex_find_death();
if (!is_undefined(_dth)) {
	_dth.dying = true;
	array_push(deaths, { st: _dth, t0: _pstart + floor(_fps * 0.4) });
	duration = max(duration, _pstart + floor(_fps * 0.4) + death_len + shell_len + _fps);
}
```

## 3. obj_unmaking → Step
**a)** Right **under** the 2.1 `B` debug block (its closing `}`), add:
```gml
if (keyboard_check_pressed(ord("N"))) {                     // debug: a minute of cosmic time passes in an instant
	for (var i = 0; i < array_length(global.hex_stars); i++) {
		var _ast = global.hex_stars[i];
		_ast.age = scr_hex_age(_ast) + 60;
	}
	if (array_length(deaths) == 0) {
		var _dth = scr_hex_find_death();
		if (!is_undefined(_dth)) {
			_dth.dying = true;
			array_push(deaths, { st: _dth, t0: t });
			duration = max(duration, t + death_len + shell_len + _fpsn);
		}
	}
}
// a sun-like star lets go: its outer layers puff off into a ring, and its bare core is left behind, a white dwarf
for (var i = array_length(deaths) - 1; i >= 0; i--) {
	var _dtt = deaths[i];
	if (t < _dtt.t0 + death_len) continue;                  // it throbs first (Draw)
	var _ast = _dtt.st;
	_ast.dying = false;
	_ast.wd = true;
	_ast.s  = 0.7;
	_ast.m  = max(1, _ast.m * 0.3);                        // most of its mass goes back into her nebula
	array_push(shells, { ox: _ast.ox, oy: _ast.oy, t0: t, ang: random(180), ell: random_range(0.7, 1) }); // real rings are a little oval
	array_push(ignitions, { ox: _ast.ox, oy: _ast.oy, t0: t, big: false, s: 1.6, merged: false, c: make_color_rgb(205, 225, 255) });
	array_delete(deaths, i, 1);
}
// the ring puffs out, then settles into lasting haze: red hydrogen outside, teal oxygen inside. food for new stars
for (var i = array_length(shells) - 1; i >= 0; i--) {
	var _sh = shells[i];
	if (t < _sh.t0 + shell_len) continue;
	for (var _shj = 0; _shj < 18; _shj++) {
		var _shd = _shj * 20;
		for (var _shk = 0; _shk < 2; _shk++) {
			var _shr = (_shk == 0) ? 58 : 40;
			var _sx0 = lengthdir_x(_shr, _shd), _sy0 = lengthdir_y(_shr, _shd) * _sh.ell;      // a point on the oval
			var _shx = _sh.ox + lengthdir_x(_sx0, _sh.ang) - lengthdir_y(-_sy0, _sh.ang);       // turned to the ring's angle
			var _shy = _sh.oy + lengthdir_y(_sx0, _sh.ang) + lengthdir_x(-_sy0, _sh.ang);
			scr_hex_haze_add({ ox: _shx, oy: _shy, ang: random(360),
				c: (_shk == 0) ? make_color_rgb(255, 85, 115) : make_color_rgb(70, 220, 200),
				s: 12, s0: 12, smax: 26, a: 0.02, f: 1, at: 0.1 });                               // it fades up as the ring's light fades down
		}
	}
	array_delete(shells, i, 1);
}
```
*(The ring math turns each point on an oval by the ring's angle. If the ring ever comes out looking skewed, tell me. It's the one spot I'd double-check.)*

## 4. obj_unmaking → Draw
**a) Red giants and white dwarfs.** In section 7, replace the line
`var _sc = scr_hex_star_color(_st.m, _st.ph, _st.hx); // its mass sets its color: red dwarf to blue giant`
with:
```gml
	var _sc = scr_hex_star_color(_st.m, _st.ph, _st.hx); // its mass sets its color: red dwarf to blue giant
	var _sgk = 0;                                          // how far into its red giant years it is
	if (_st[$ "wd"] == true) _sc = make_color_rgb(205, 225, 255);              // a white dwarf: the bare core, white-hot and tiny
	else if (_st.m >= HEX_MASS_SUN_MIN && _st.m < HEX_MASS_GIANT) {
		var _slf = scr_hex_age(_st) / scr_hex_star_life(_st.m);
		_sgk = clamp((_slf - 0.7) / 0.3, 0, 1);                                // the last of a sun-like life: it swells into a red giant
		_sc = merge_color(_sc, make_color_rgb(255, 120, 60), 0.75 * _sgk);
	}
```
Then right **under** the line `var _ss = _st.s * (1 + 1.5 * _wb); ...`, add:
```gml
	_ss *= 1 + 0.9 * _sgk;                                 // red giants are big
```

**b) The death and the ring.** Right **after** the 2.1 infall loop in section 6c (its closing `}`), add:
```gml
// a dying star throbs, swelling and dimming a few times as its outer layers come loose
for (var i = 0; i < array_length(deaths); i++) {
	var _dtt = deaths[i];
	if (t < _dtt.t0) continue;
	var _dtk = (t - _dtt.t0) / death_len;
	var _shl = point_distance(0, 0, _dtt.st.ox, _dtt.st.oy);
	var _sha = point_direction(0, 0, _dtt.st.ox, _dtt.st.oy) + sky_angle;
	var _shx = _px + lengthdir_x(_shl, _sha), _shy = _py + lengthdir_y(_shl, _sha);
	var _thr = 0.5 + 0.5 * sin(_dtk * pi * 6);                                      // three throbs
	draw_sprite_ext(spr_soft, 0, _shx, _shy, (8 + 10 * _dtk * _thr) / 20, (8 + 10 * _dtk * _thr) / 20, 0, make_color_rgb(255, 120, 60), (0.15 + 0.3 * _thr) * _neb);
}
// a planetary nebula puffing out: a ring of glowing gas, red outside and teal inside, around a white-hot core
for (var i = 0; i < array_length(shells); i++) {
	var _sh  = shells[i];
	var _shk = (t - _sh.t0) / shell_len;
	var _shr = 58 * (1 - sqr(1 - _shk));                                            // puffs out fast, then slows
	var _sha = (_shk < 0.15) ? _shk / 0.15 : 1 - 0.6 * (_shk - 0.15) / 0.85;        // flares up, then dims toward the haze it becomes
	var _shl = point_distance(0, 0, _sh.ox, _sh.oy);
	var _scd = point_direction(0, 0, _sh.ox, _sh.oy) + sky_angle;
	var _shx = _px + lengthdir_x(_shl, _scd), _shy = _py + lengthdir_y(_shl, _scd);
	var _shrt = _sh.ang + sky_angle;
	for (var _shj = 0; _shj < 24; _shj++) {
		var _shd = _shj * 15;
		for (var _sri = 0; _sri < 2; _sri++) {
			var _shrr  = _shr * ((_sri == 0) ? 1 : 0.7);
			var _sx0 = lengthdir_x(_shrr, _shd), _sy0 = lengthdir_y(_shrr, _shd) * _sh.ell;
			draw_sprite_ext(spr_soft, 0, _shx + lengthdir_x(_sx0, _shrt) - lengthdir_y(-_sy0, _shrt), _shy + lengthdir_y(_sx0, _shrt) + lengthdir_x(-_sy0, _shrt),
				9 / 20, 9 / 20, 0, (_sri == 0) ? make_color_rgb(255, 85, 115) : make_color_rgb(70, 220, 200), 0.16 * _sha * _neb);
		}
	}
	draw_sprite_ext(spr_soft, 0, _shx, _shy, 10 / 20, 10 / 20, 0, make_color_rgb(205, 225, 255), 0.35 * _sha * _neb); // the white dwarf lighting its ring
}
```

---

## Tuning knobs
- `HEX_SUN_LIFE` sets when the first deaths happen. For a 15-minute slice, the first ring should land around the third cast. Lower it if deaths never show up, raise it if every cast has one.
- `HEX_MASS_SUN_MIN` / `HEX_MASS_GIANT` set which stars count as sun-like.
- The red giant phase is the last 30% of a star's life (the `0.7` in Draw).
