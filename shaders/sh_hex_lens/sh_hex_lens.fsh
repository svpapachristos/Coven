// sh_hex_lens: bends her sky's light around black holes, draws their disks the way light really reaches us, and sends
// ripples through space. for every pixel it works out where that light really came from (the lens equation), and shows that.
varying vec2 v_vTexcoord;
varying vec4 v_vColor;

uniform vec2  u_size;       // the surface's size in pixels
uniform vec4  u_lens[4];    // each black hole: x, y (pixels), Einstein radius squared, strength 0 to 1
uniform vec4  u_disk[4];    // each black hole's disk: shadow radius (pixels), tilt (radians), brightness, seed
uniform vec4  u_ringk;      // each black hole's photon ring brightness (it flares as it ignites)
uniform vec4  u_ripple[4];  // each ripple through space: x, y (pixels), how far it has spread, how hard it shoves (pixels)
uniform float u_time;       // seconds of her sky's time, so the disk turns (runs faster during the crunch)
uniform vec4  u_cmb;        // the Big Bang's afterglow: strength, how far it has cooled (0 hot, 1 cold), seed, unused

const float SQ  = 0.12;     // how flat the disk looks: nearly edge-on, like Gargantua (matches the gas falling in, in obj_unmaking Step)
const float SQT = 0.30;     // the puffy, smoky envelope around the thin disk is thicker
const float TAU = 6.2831853;

// ---- noise: soft random structure for turbulent gas. periodic around the hole (P cells per lap), so there's no seam ----
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p, float P) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(vec2(mod(i.x, P), i.y)),       b = hash(vec2(mod(i.x + 1.0, P), i.y));
	float c = hash(vec2(mod(i.x, P), i.y + 1.0)), d = hash(vec2(mod(i.x + 1.0, P), i.y + 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p, float P) {
	float s = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { s += a * vnoise(p, P); p *= 2.0; P *= 2.0; a *= 0.5; }
	return s;
}

// where the light seen at p left from. the lens is softened a little at its heart, so the sky bends into a bright,
// compressed ring hugging the shadow instead of a razor-thin Einstein ring that shreds tiny stars into spikes
vec2 lensmap(vec2 p, vec4 L) {
	vec2  d    = p - L.xy;
	float d2   = dot(d, d);
	float er   = sqrt(L.z);
	float fade = 1.0 - smoothstep(4.0 * er, 9.0 * er, sqrt(d2));
	return p - d * (L.z / (d2 + 0.55 * L.z)) * L.w * fade;
}

// turbulent gas on its orbits. the inner disk turns faster than the outer (Kepler), which would wind any pattern into
// ever-thinner stripes, so two copies of the flow take turns, each fading out just before it winds too far
float turb(float phi, float rho, float seed) {
	float T  = 7.0;
	float t1 = mod(u_time, T), t2 = mod(u_time + T * 0.5, T);
	float om = 1.8 * pow(rho, -1.5);
	float n1 = fbm(vec2((phi - t1 * om) / TAU * 14.0 + seed, rho * 9.0), 14.0);
	float n2 = fbm(vec2((phi - t2 * om) / TAU * 14.0 + seed + 7.0, rho * 9.0), 14.0);
	float w  = 1.0 - abs(2.0 * t1 / T - 1.0);
	return mix(n2, n1, w);
}

// the light of the accretion disk at a point in the hole's frame (pixels): x along the disk, y across it on screen (+ = near side)
vec3 disk(vec2 q, float r, float seed) {
	vec3 hot = vec3(1.0, 0.93, 0.82), mid = vec3(1.0, 0.55, 0.25), cool = vec3(0.55, 0.22, 0.62);   // cooling to her violet at the rim
	vec3 outc = vec3(0.0);
	// the thin, hot disk itself
	vec2  pl  = vec2(q.x, q.y / SQ);
	float rho = length(pl) / r;
	if (rho > 1.15 && rho < 5.6) {
		float phi = atan(pl.y, pl.x);
		float ph  = phi - u_time * 1.8 * pow(rho, -1.5);
		float prof = pow(1.25 / rho, 2.2) * smoothstep(1.15, 1.35, rho) * (1.0 - smoothstep(3.6, 5.6, rho));
		// turbulent clumps and filaments sheared along their orbits, threaded with fine streaks
		float tb    = turb(phi, rho, seed);
		float lanes = 0.5 + 0.5 * sin(rho * 37.0 + 1.7 * sin(2.0 * ph + rho * 3.0) + seed);
		float fine  = 0.5 + 0.5 * sin(rho * 91.0 + 2.3 * sin(3.0 * ph - rho * 7.0) + seed * 2.0);
		float tex   = 0.25 + 1.1 * tb * tb * 1.6 + 0.25 * lanes + 0.15 * fine;
		// hot spots: bright clumps whipping round the inner edge (real: flares seen orbiting our galaxy's own black hole)
		float spot  = 1.4 * pow(0.5 + 0.5 * cos(ph + seed * 3.0), 14.0) * exp(-pow((rho - 1.7) / 0.25, 2.0))
		            + 0.9 * pow(0.5 + 0.5 * cos(ph * 2.0 + seed * 5.0), 20.0) * exp(-pow((rho - 2.4) / 0.3, 2.0));
		// Doppler beaming: the side swinging toward us is brighter and bluer, the side moving away dimmer and redder
		float v    = 0.35 / sqrt(rho);
		float beam = pow(1.0 + v * cos(phi), 3.0);
		// gravitational redshift: light from right beside the horizon loses energy climbing out, so the inner edge dims and reddens
		float gz = smoothstep(1.15, 1.9, rho);
		float tk = clamp((rho - 1.15) / 3.6, 0.0, 1.0);
		vec3 col = (tk < 0.35) ? mix(hot, mid, tk / 0.35) : mix(mid, cool, (tk - 0.35) / 0.65);
		col = mix(col, vec3(0.80, 0.88, 1.0), clamp((beam - 1.0) * 0.35, 0.0, 0.6));
		col = mix(col, vec3(0.70, 0.20, 0.25), clamp((1.0 - beam) * 0.8, 0.0, 0.6));
		col = mix(vec3(0.85, 0.22, 0.12), col, 0.35 + 0.65 * gz);
		outc += col * prof * (tex + spot) * beam * (0.45 + 0.55 * gz) * 1.5;
	}
	// the smoky envelope: thinner, cooler gas puffed up above and below the disk, wispy at its edges
	vec2  pe   = vec2(q.x, q.y / SQT);
	float rhoe = length(pe) / r;
	if (rhoe > 1.2 && rhoe < 5.0) {
		float phe  = atan(pe.y, pe.x);
		float smk  = turb(phe, rhoe * 0.6, seed + 3.0);
		float wisp = smoothstep(0.42, 0.78, smk);
		float profe = pow(1.3 / rhoe, 1.6) * smoothstep(1.2, 1.6, rhoe) * (1.0 - smoothstep(3.0, 5.0, rhoe));
		outc += mix(mid, cool, 0.5) * profe * wisp * (1.0 + 0.35 / sqrt(rhoe) * cos(phe)) * 0.22;
	}
	return outc;
}

void main()
{
	vec2 p    = v_vTexcoord * u_size;
	vec2 src  = p;
	vec2 blur = vec2(0.0);   // near the hole the image is stretched round it: smear along the ring so it's a smooth arc

	for (int i = 0; i < 4; i++) {
		vec4 L = u_lens[i];
		if (L.w <= 0.0) continue;
		src -= p - lensmap(p, L);
		vec2  d  = p - L.xy;
		float dl = max(length(d), 1.0);
		float er = sqrt(L.z);
		float x  = (dl - er) / (0.6 * er);
		blur += vec2(-d.y, d.x) / dl * er * 0.2 * L.w * exp(-x * x);
	}

	// a ripple through space: a ring that squeezes and stretches the sky as it passes (a black hole's birth, merging holes, shockwaves)
	for (int i = 0; i < 4; i++) {
		vec4 R = u_ripple[i];
		if (R.w == 0.0) continue;
		vec2  d  = p - R.xy;
		float dl = max(length(d), 1.0);
		float x  = (dl - R.z) / 48.0;
		src += d / dl * R.w * exp(-x * x) * sin(x * 6.0);
	}

	vec4 c = texture2D(gm_BaseTexture, clamp(src / u_size, 0.0, 1.0)) * 0.4;
	c += texture2D(gm_BaseTexture, clamp((src + blur) / u_size, 0.0, 1.0)) * 0.15;
	c += texture2D(gm_BaseTexture, clamp((src - blur) / u_size, 0.0, 1.0)) * 0.15;
	c += texture2D(gm_BaseTexture, clamp((src + blur * 0.5) / u_size, 0.0, 1.0)) * 0.15;
	c += texture2D(gm_BaseTexture, clamp((src - blur * 0.5) / u_size, 0.0, 1.0)) * 0.15;

	// the black holes themselves: shadow, disk, and the disk's light bent over the top and under the bottom (Gargantua, NASA 2019)
	for (int i = 0; i < 4; i++) {
		vec4 D = u_disk[i];
		float rk = u_ringk[i];
		if (D.z <= 0.0 && rk <= 0.0) continue;
		vec4  L  = u_lens[i];
		float r  = D.x;
		float ct = cos(D.y), st = sin(D.y);
		vec2  d  = p - L.xy;
		float dl = length(d);
		if (dl > r * 7.0) continue;
		vec2 q = vec2(d.x * ct - d.y * st, d.x * st + d.y * ct);   // into the hole's frame (the same turn as scr_hex_draw_hole)
		vec3 add = vec3(0.0);
		if (dl < r) {
			c.rgb = vec3(0.0);                                       // the shadow: no light comes back out
		} else {
			// the far half of the disk, seen by light that bent up and over the hole: it wraps over the top as a bright brim
			vec2 s  = lensmap(p, vec4(L.xy, L.z, 1.0)) - L.xy;
			vec2 sq = vec2(s.x * ct - s.y * st, s.x * st + s.y * ct);
			if (sq.y < 0.0) add += disk(sq, r, D.w) * D.z;
			else if (q.y > 0.0 && dl < r * 2.2) add += disk(vec2(sq.x, -sq.y), r, D.w) * 0.35 * D.z;   // and a thin image under the bottom
			// the photon ring: light that circled the hole before escaping. each extra lap makes a thinner, fainter ring nested
			// inside the last, all hugging the shadow. brighter on the side spinning toward us
			float px  = max(0.6, r * 0.007);
			float rng = 0.9  * exp(-pow((dl - r * 1.030) / (r * 0.035), 2.0))
			          + 0.55 * exp(-pow((dl - r * 1.012) / max(px, r * 0.014), 2.0))
			          + 0.35 * exp(-pow((dl - r * 1.004) / px, 2.0));
			add += vec3(1.0, 0.84, 0.66) * rng * (0.75 + 0.35 * q.x / dl) * rk;
			// glare: the brightest light bleeds a soft glow around the hole and along the disk, like a camera sees it
			float gl = exp(-(dl - r) / (1.3 * r)) * 0.06 + exp(-abs(q.y) / (0.22 * r)) * exp(-abs(q.x) / (3.5 * r)) * 0.07;
			add += vec3(1.0, 0.78, 0.55) * gl * (1.0 + 0.5 * q.x / max(dl, 1.0)) * D.z;
		}
		if (q.y > 0.0) add += disk(q, r, D.w) * D.z;                 // the near half, in front of everything, crossing the shadow
		c.rgb += add;
	}
	// the afterglow of creation (the cosmic microwave background): the young universe's light, hot and nearly even but mottled
	// with faint warmer and cooler patches (real: those ripples are the seeds of every galaxy). it cools and fades as it expands
	if (u_cmb.x > 0.0) {
		vec2  cp   = p / (u_size.y * 0.09) + u_cmb.z;
		float mott = fbm(cp, 4096.0) * 0.7 + fbm(cp * 3.1 + 11.0, 4096.0) * 0.3;
		vec3  hotc = mix(vec3(1.0, 0.66, 0.36), vec3(0.42, 0.08, 0.14), u_cmb.y);
		c.rgb += hotc * u_cmb.x * (0.35 + 1.3 * smoothstep(0.32, 0.72, mott));
	}
	gl_FragColor = c;
}
