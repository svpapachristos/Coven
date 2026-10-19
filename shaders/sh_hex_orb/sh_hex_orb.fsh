// sh_hex_orb: the Hexweaver's living hex, the little knot of hex she always has curling in her off hand.
// THE RULE (notes/hex-visual-bible.md): the hex is LIGHT, not paint. Every part of it adds up into one brightness, the
// brightness picks the color (dark violet -> blue -> lilac -> white-hot), and it's drawn as light: a see-through violet tint
// over whatever is behind it, plus added glow. Nothing is a solid shape, not even the white-hot heart (it's just a lot of light).
// The parts that add up:
//   heart     a small soft hot point that flickers, with embers popping right around it
//   strands   soft filaments of light orbiting the heart (far side dimmer, so they orbit in depth)
//   gas       a small ghostly knot of light whose outline keeps shifting
//   veil      thin see-through haze following the strands' flow, with holes
//   overflow  (only while holding something) light licking outward, straining against what it holds
// Output is PREMULTIPLIED (drawn with gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha)). u_energy 0..1: calm .. wild.
// Everything is drawn on a grid of u_px world pixels (K cycles it in game), with a few flat brightness steps (no dither).
// The parts (Sophia's names): CORE/SPARK white-hot and lilac; BODY hex blue (the mist hugging the core, with dust);
// GLOW blue-violet (where light overlaps and builds up); SMOKE/EDGE dark violet (the only non-light part: rim and patches).
varying vec2 v_world;     // this pixel's position in the room, from the vertex shader
uniform vec2  u_center;   // where the ball is in the room (world pixels)
uniform vec2  u_box;      // the square being drawn around it, in world pixels
uniform float u_R;        // the ball's size (world pixels)
uniform float u_energy;   // 0 calm .. 1 wild
uniform float u_time;
uniform float u_seed;
uniform float u_px;       // how big one pixel of the magic is, in world pixels
uniform float u_veil;     // how thick the veil is (1 = normal)
uniform float u_over;     // 0..1: the overflow, for when the hex is holding something
uniform float u_strand;   // how strong the strands are (1 = full; the charging orb uses less until it gets its own look)
uniform float u_hollow;   // orb: 0 = solid; otherwise the radius of something held inside it (no core, and the hex wraps around it instead of covering it)
uniform float u_mode;     // 0 = an orb (a ball of her magic); 1 = the old mote FLOW (unused now); 2 = HEX FLAME (parked); 3 = THE RIVER
uniform vec4  u_rv;       // river: the far end (xy) and the bend point (zw), from u_center (her palm)
uniform vec4  u_rv2;      // river: lo, hi (the stretch of the path that is there), half-width, dir (1 out, -1 home)
uniform float u_heart;    // orb: how formed its white-hot heart is (0 = still coalescing, no heart yet .. 1 = full)
uniform float u_n;        // flow: how many motes are in u_motes
uniform vec4  u_motes[32];  // flow: each mote's position (xy, from u_center) and velocity (zw)
uniform vec3  u_smoke;
uniform vec3  u_glow;
uniform vec3  u_core;
uniform vec3  u_spark;
uniform float u_hot;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + u_seed * 17.0) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), u.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), u.x), u.y);
}
vec2 rot(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }

// the curling flow the strands follow (q: position, a little wider than tall so it clings along her hand)
vec2 tflow(vec2 q, float E, float t) {
	float rq = length(q);
	vec2 s = rot(q, -(0.35 + 0.5 * E) * t);        // the whole field turns slowly as one (a rigid turn: no spiral arms)
	vec2 w1 = vec2(vn(s * 0.07 + vec2(t * 0.35, 3.0)), vn(s * 0.07 + vec2(8.0, -t * 0.3))) - 0.5;
	s += w1 * (7.0 + 9.0 * E);                     // curl: warped noise bends the strands into loops and hooks
	vec2 w2 = vec2(vn(s * 0.15 + vec2(-t * 0.9, 1.0)), vn(s * 0.15 + vec2(5.0, t * 0.8))) - 0.5;
	s += w2 * (3.0 + 2.0 * E);                     // a faster, smaller turbulence on top, so they warble
	s.y += t * (1.5 + 3.0 * E) * smoothstep(u_R * 1.2, u_R * 3.0, rq);   // out past the body, strands peel off and drift up
	return s;
}
float tfield(vec2 s, float E) { return vn(s * mix(0.16, 0.09, E)) * 0.8 + vn(s * 0.23 + 4.0) * 0.2; }

// the veil: see-through smoke following a slower copy of the strands' flow, with holes. Returns 0..1
float veil(vec2 p) {
	float R = u_R, E = clamp(u_energy, 0.0, 1.0), t = u_time;
	vec2 q = vec2(p.x / 1.2, p.y);
	float rq = length(q);
	vec2 s = rot(q, -(0.35 + 0.5 * E) * t);
	vec2 w1 = vec2(vn(s * 0.07 + vec2(t * 0.35, 3.0)), vn(s * 0.07 + vec2(8.0, -t * 0.3))) - 0.5;
	s += w1 * (7.0 + 9.0 * E);
	s.y += t * (1.5 + 3.0 * E) * smoothstep(R * 1.2, R * 3.0, rq);
	float f = vn(s * 0.06 + 11.0);
	float band = 1.0 - smoothstep(0.05, 0.3, abs(f - 0.5));
	float env = exp(-(rq * rq) / (R * R * (1.6 + 0.8 * E)));
	float holes = smoothstep(0.3, 0.7, vn(q * 0.2 + vec2(t * 0.5, -t * 0.7)));
	return env * (0.35 + 0.65 * band) * (0.3 + 0.7 * holes) * 1.25;
}
// the body: a small, ghostly knot of gas whose outline keeps shifting. Returns 0..1
float body(vec2 p) {
	float R = u_R, E = clamp(u_energy, 0.0, 1.0), t = u_time;
	vec2 q = vec2(p.x / 1.15, p.y);
	q += (vec2(vn(q * 0.15 + vec2(t * 0.7, 1.0)), vn(q * 0.15 + vec2(4.0, -t * 0.6))) - 0.5) * R * 0.9;
	float breath = 1.0 + 0.08 * sin(t * 1.9 + 1.3 * sin(t * 0.7));
	float e = exp(-dot(q, q) / (R * R * (0.5 + 0.12 * E) * breath));
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float a = t * (0.6 + 0.3 * fi) * (1.0 - 2.0 * mod(fi, 2.0)) + fi * 2.1;
		vec2 c = R * (0.5 + 0.25 * E) * vec2(cos(a), sin(a));
		e += 0.5 * exp(-dot(q - c, q - c) / (R * R * (0.3 + 0.25 * E)));
	}
	vec2 w = vec2(vn(q * 0.12 + vec2(t * 0.5, 2.0)), vn(q * 0.12 + vec2(6.0, -t * 0.45))) - 0.5;
	float gas = vn((q + w * 6.0) * 0.22 + vec2(0.0, -t * 0.6)) * 0.6 + vn(q * 0.5 + t * 0.7) * 0.4;
	return clamp(e * 0.75, 0.0, 1.0) * (0.45 + 0.8 * gas);
}
// the overflow: flame-like licks pushing outward, curling, tapering and dying, in surges. Returns how far inside a lick (0 = none)
float overflow(vec2 p) {
	float E = clamp(u_energy, 0.0, 1.0), R = u_R, t = u_time;
	vec2 q = vec2(p.x / 1.15, p.y);
	float surge = 0.5 + 0.5 * sin(t * (1.3 + 1.5 * E) + 1.7 * sin(t * 0.6));
	vec2 cw = vec2(vn(q * 0.1 + vec2(t * 0.4, 5.0)), vn(q * 0.1 + vec2(9.0, -t * 0.35))) - 0.5;
	vec2 wq = q + cw * (5.0 + 5.0 * E);
	float wr = length(wq);
	float th0 = atan(wq.y, wq.x) / 6.2831853 + 0.5;
	float K = 11.0, rad = wr * 0.07 - t * (0.9 + 1.4 * E);
	// sampled twice and blended, so there is no seam where the angle wraps around
	float n = mix(vn(vec2(th0 * K, rad)), vn(vec2((th0 - 1.0) * K, rad)), th0) * 0.75
	        + mix(vn(vec2(th0 * K * 2.0, rad * 1.8) + 5.0), vn(vec2((th0 - 1.0) * K * 2.0, rad * 1.8) + 5.0), th0) * 0.25;
	n = 1.0 - abs(2.0 * n - 1.0);
	float reach = R * (1.6 + 0.8 * E + 0.5 * surge);
	float th = 0.7 + 0.45 * smoothstep(R * 0.35, reach, wr);
	return (n - th) * smoothstep(R * 0.2, R * 0.55, wr);
}
// brightness -> color: the brighter, the whiter (like real fire and Wanda's chaos magic)
vec3 ramp(float I) {
	vec3 c = u_smoke;
	c = mix(c, u_glow, smoothstep(0.15, 0.45, I));
	c = mix(c, u_core, smoothstep(0.45, 0.8, I));
	c = mix(c, u_spark, smoothstep(0.8, 1.15, I));
	c = mix(c, vec3(1.0), smoothstep(1.15, 1.5, I) * (0.6 + 0.4 * u_hot));
	return c;
}
vec4 orb(vec2 p, vec2 pc)
{
	float R = u_R, E = clamp(u_energy, 0.0, 1.0), t = u_time;
	vec2 q = vec2(p.x / 1.2, p.y);
	float rq = length(q), r = length(p);
	// strands: soft filaments of light along the curling field (distance in pixels = value / slope)
	vec2 s = tflow(q, E, t);
	float f = tfield(s, E);
	float fx = tfield(tflow(q + vec2(u_px * 0.5, 0.0), E, t), E) - f;
	float fy = tfield(tflow(q + vec2(0.0, u_px * 0.5), E, t), E) - f;
	float slope = length(vec2(fx, fy)) / (u_px * 0.5);
	float dpx = abs(f - 0.5) / max(slope, 0.0001);
	float glowline = exp(-(dpx * dpx) / (u_px * u_px * 1.1));
	float env = exp(-(rq * rq) / (R * R * (2.8 + 2.6 * E)));
	float ang = atan(q.y, q.x) + (0.35 + 0.5 * E) * t;
	float front = 0.6 + 0.4 * sin(ang + 0.6);
	float keep = smoothstep(0.28, 0.45, vn(s * 0.06 - t * 0.4 + 7.0));
	float Is = glowline * env * keep * front * u_strand;
	// BODY (hex blue): the mist hugging the heart, most of the orb's volume. Never a cloud: it's light, and noise eats into it
	float gas = vn(q * 0.18 + vec2(t * 0.6, -t * 0.5)) * 0.6 + vn(q * 0.45 - t * 0.8) * 0.4;
	float Im = (0.6 + 0.4 * u_heart) * 0.5 * (1.0 - 0.35 * E) * exp(-(rq * rq) / (R * R * (1.1 + 0.6 * E))) * (0.55 + 0.7 * gas);
	float Ib = body(p) * 0.6 + Im;
	float Iv = veil(p) * 0.3 * u_veil;
	// dust: faint specks drifting through the field, so light overlaps and builds up in it
	float field = Ib + Iv;
	float Id = (field > 0.12 && h2(pc + floor(t * 5.0) * 2.9) > 0.9) ? 0.25 : 0.0;
	// overflow, only while holding something
	float Io = 0.0;
	if (u_over > 0.0) Io = max(overflow(p), 0.0) * 2.0 * u_over;
	// the heart: a small soft hot point that flickers, with embers popping right around it
	float fl = 0.85 + 0.15 * sin(t * 13.0) * sin(t * 7.1);
	float Ic = 1.7 * exp(-(r * r) / ((6.0 + 3.0 * E) * fl));
	if (r < 6.0 + 3.0 * E && h2(pc + floor(t * 12.0) * 5.7) > 0.86) Ic += 0.6;
	Ic *= u_heart * u_heart;   // a forming orb has no heart yet; it kindles as the hex coalesces
	// twinkles along the strands
	if (Is > 0.3 && h2(pc + floor(t * 10.0) * 13.7) > 0.97 - 0.02 * E) Is += 0.7;
	// SMOKE / EDGE (dark violet): the one part that isn't light. A ragged dark rim where the field fades out, and drifting
	// dark patches on its underside. It gives the orb its shape (light alone can only brighten)
	float sm = vn(p * 0.3 + vec2(t * 0.5, t * 0.3)) * 0.7 + vn(p * 0.7 - t) * 0.3 + 0.3 * smoothstep(-R * 0.3, R, p.y);
	float rimv = field + (h2(pc + 3.0) - 0.5) * 0.06;
	bool isRim = rimv > 0.1 && rimv < 0.22 && vn(p * 0.22 + vec2(-t * 0.4, t * 0.3)) > 0.48;   // broken up: never a clean outline
	bool isShade = Ib > 0.25 && sm > 0.78;
	if (u_hollow > 0.0) {
		// holding something: no white-hot core (that's only for the orb in her hand), and the hex wraps AROUND the thing,
		// thin over its middle so it stays visible inside
		Ic = 0.0;
		float k = smoothstep(u_hollow * 0.95, u_hollow * 1.3, r);   // fully clear over the thing: it SURROUNDS, never overlaps
		Is *= k; Ib *= k * 0.7; Iv *= k; Id *= k; Io *= k;
		Io *= 2.5;                                                   // the licks lead: overflow straining at its edge
		// hugging just outside it: a churning band of hex light, broken into gaps (never a clean ring)
		vec2 nd = p / max(r, 0.001);
		float hr = r - u_hollow * (1.25 + 0.12 * (vn(nd * 3.0 + vec2(t * 0.7, -t * 0.5)) - 0.5));
		float brk = smoothstep(0.35, 0.65, vn(nd * 2.5 + vec2(-t * 0.6, t * 0.9) + 9.0));
		Ib += 0.6 * exp(-(hr * hr) / (u_hollow * u_hollow * 0.04 + 3.0)) * brk * (0.4 + 0.8 * gas);
		// flame licks straining outward off it, taller upward, flowing out and curling as they go
		float up2 = max(-nd.y, 0.0);
		float ln = vn(nd * 4.0 + vec2(r * 0.12 - t * 2.4, t * 0.7)) * 0.7 + vn(nd * 8.0 + vec2(r * 0.25 - t * 4.0, 3.0)) * 0.3;
		float lk = ln * 1.6 - 0.75 - max(r - u_hollow * 1.25, 0.0) / (u_hollow * (0.35 + 0.5 * up2) + 3.0);
		if (r > u_hollow * 1.15) Io = max(Io, smoothstep(0.0, 0.3, lk) * (0.45 + 0.5 * clamp(lk, 0.0, 1.0)) * u_over);
		if (Io > 0.25 && h2(pc + floor(t * 9.0) * 3.3) > 0.93) Io += 0.5;   // sparks flicking off the licks
		if (r < u_hollow * 1.05) { isRim = false; isShade = false; }  // no smoke over the thing either
	}
	float I = Is + Ib + Iv + Io + Ic + Id;
	if (u_hollow > 0.0) I = min(I, 1.05);                // holding something is effort, not concentration: lilac at most, never white-hot
	if (isShade) I -= 0.3;                                // shade sinks into the gas
	I = max(floor(I * 7.0 + 0.5) / 7.0, 0.0);       // a few flat steps of brightness: pixel art, no dither
	float a = clamp(I * 0.6, 0.0, 0.6);              // the see-through violet tint over what's behind
	vec3 c = ramp(I);
	vec4 o = vec4(c * (a + 0.45 * min(I, 1.6)), a);  // tint + added light
	if ((isRim || isShade) && I < 0.45) o = vec4(u_smoke * 0.5, 0.5);   // dark smoke edge (drawn over, not added)
	return o;
}

// THE FLOW: her motes out in the world, drawn as one body of hex light (the same light model as the orb, so the stream and the
// orb in her hand are visibly the same stuff). Each mote is a soft wisp of light stretched back along the way it's moving;
// where they bunch up the light builds; slow smoky noise eats into it; a broken dark smoke edge gives the stream its shape.
vec4 flow(vec2 p, vec2 pc)
{
	float t = u_time, I = 0.0;
	for (int i = 0; i < 32; i++) {
		if (float(i) >= u_n) break;
		vec4 m = u_motes[i];
		vec2 d = p - m.xy;
		float sp = length(m.zw);
		vec2 dir = (sp > 0.01) ? m.zw / sp : vec2(1.0, 0.0);
		float al = dot(d, dir), pe = d.x * dir.y - d.y * dir.x;
		float L = (al < 0.0) ? 3.0 + sp * 1.6 : 3.0;             // a tail behind it, as long as it's fast
		I += 0.36 * exp(-(al * al) / (L * L) - (pe * pe) / 10.0);
	}
	float gas = vn(p * 0.2 + vec2(t * 0.8, -t * 0.6)) * 0.6 + vn(p * 0.5 - t) * 0.4;
	float field = I * (0.55 + 0.7 * gas);
	// in motion there is no core: the white-hot heart only exists where hex is concentrated (the orbs in her hand). The stream
	// tops out at blue and lilac, with sparkles
	float Iq = min(max(floor(field * 7.0 + 0.5) / 7.0, 0.0), 0.95);
	float a = clamp(Iq * 0.6, 0.0, 0.6);
	vec4 o = vec4(ramp(Iq) * (a + 0.45 * Iq), a);
	if (field > 0.3 && h2(pc + floor(t * 6.0) * 13.7) > 0.975) o = vec4(u_spark * 0.9, 0.9);   // sparkles inside the stream (rare and calm)
	float edge = field + (h2(pc + 3.0) - 0.5) * 0.06;
	if (edge > 0.08 && edge < 0.17 && vn(p * 0.25 + vec2(-t * 0.5, t * 0.4)) > 0.5) o = vec4(u_smoke * 0.45, 0.45);   // smoke edge
	return o;
}
// HEX FLAME (u_mode 2): her hex when she's EXERTING. Wraps her palm while she channels (stance) and engulfs whatever she
// holds up. Flame-like licks of light rising off the shape (screen up), with most of the hex pooled underneath, holding it.
// u_R = the shape's radius, u_energy = effort (0 easy .. 1 straining: taller, wilder, faster licks), u_hollow = see-through
// middle (the radius of the thing held inside), u_over = how present it is (0..1, for growing in and dissolving).
// No white-hot heart: effort tops out at lilac, with embers drifting up off the tips.
vec4 flame(vec2 p, vec2 pc)
{
	float R = u_R, E = clamp(u_energy, 0.0, 1.0), t = u_time, amt = clamp(u_over, 0.0, 1.0);
	vec2 q = p;
	q.x += (vn(vec2(p.x * 0.08, p.y * 0.08 + t * 1.3)) - 0.5) * (3.0 + 4.0 * E);   // the licks curl and sway
	float r = length(vec2(q.x, q.y * 1.15));
	float up = clamp(-q.y / max(r, 0.001), -1.0, 1.0);          // 1 straight up, -1 straight down
	float s = r - R;                                           // how far outside the shape
	// rising noise: features drift upward over time, stretched tall like flame
	float spd = 1.4 + 1.6 * E;
	float n = vn(vec2(q.x * 0.3, q.y * 0.07 + t * spd)) * 0.65 + vn(vec2(q.x * 0.7 + 3.0, q.y * 0.15 + t * spd * 2.0)) * 0.35;   // tall tongues: fine across, long up and down
	// how far licks can reach from the surface: tall above, short at the sides, a low pool underneath. Licks only rise where
	// the noise is high, so there are gaps between them (never a clean ring)
	float upw = max(up, 0.0);
	float L = (R * 0.7 + 8.0) * (0.2 + (0.9 + 1.3 * E) * upw);
	float lick = n * 1.5 - 0.45 - max(s, 0.0) / L;              // > 0 inside a lick; bigger = nearer its base
	float I = smoothstep(0.0, 0.35, lick) * (0.35 + 0.5 * clamp(lick, 0.0, 1.0));
	// inside the shape: a soft fill (her palm glows; a held thing gets hollowed out below)
	I += 0.4 * (1.0 - smoothstep(-R * 0.4, 0.0, s)) * (0.6 + 0.6 * n);
	// the pool underneath, holding it up
	float below = max(-up, 0.0);
	I += 0.45 * below * exp(-(s * s) / (R * R * 0.15 + 8.0)) * (0.4 + 0.8 * n);
	// a faint glow hugging the shape all round
	I += 0.15 * exp(-(s * s) / (R * R * 0.05 + 4.0));
	// see-through middle, so the held thing (or her hand) shows inside
	if (u_hollow > 0.0) I *= mix(0.15, 1.0, smoothstep(u_hollow * 0.55, u_hollow * 1.05, r));
	I *= amt;
	// embers drifting up off the tips
	float em = h2(vec2(pc.x, floor(pc.y + t * (5.0 + 5.0 * E))));
	bool ember = (up > 0.2 && s > 0.0 && s < L * 1.25 && em > 0.992 - 0.006 * E);
	I = min(I, 0.95);                                          // effort, not concentration: blue at most (embers are the lilac), never white-hot
	if (ember) I = 1.05 * amt;
	I = max(floor(I * 7.0 + 0.5) / 7.0, 0.0);
	float a = clamp(I * 0.6, 0.0, 0.6);
	vec4 o = vec4(ramp(I) * (a + 0.45 * I), a);
	float edge = I + (h2(pc + 3.0) - 0.5) * 0.06;
	if (edge > 0.12 && edge < 0.2 && s > 0.0 && vn(p * 0.25 + vec2(-t * 0.5, t * 0.6)) > 0.6) o = vec4(u_smoke * 0.5, 0.45);   // a sparse dark smoke edge
	return o;
}
// THE RIVER (u_mode 3): her hex flowing through the world along a path from her palm (this pixel grid's origin, u_center)
// to u_rv.xy, bending through u_rv.zw (a quadratic bezier). u_rv2 = (lo, hi, half-width, dir): only the stretch lo..hi of the
// path is there; dir 1 = flowing out from her, -1 = flowing home. Built like Wanda's hex pouring out of her: a dark body of
// hex smoke (it's what gives the river weight on bright ground), with bright strands of light running through it in the
// direction it flows (brightest near where it comes from), and a few sparkles. No white-hot: hex in motion tops out at lilac.
vec2 rvq(float f) { return 2.0 * (1.0 - f) * f * u_rv.zw + f * f * u_rv.xy; }
vec4 river(vec2 p, vec2 pc)
{
	float lo = u_rv2.x, hi = u_rv2.y, W = u_rv2.z, dir = u_rv2.w, t = u_time;
	// the nearest point of the stretch to this pixel: a coarse search, then a finer one around the best
	float bd = 1e9, bf = lo;
	for (int i = 0; i <= 24; i++) {
		float f = mix(lo, hi, float(i) / 24.0);
		vec2 d = p - rvq(f);
		float dd = dot(d, d);
		if (dd < bd) { bd = dd; bf = f; }
	}
	float st = (hi - lo) / 24.0, f0 = bf;
	for (int i = -4; i <= 4; i++) {
		float f = clamp(f0 + float(i) * st * 0.25, lo, hi);
		vec2 d = p - rvq(f);
		float dd = dot(d, d);
		if (dd < bd) { bd = dd; bf = f; }
	}
	vec2 q = rvq(bf);
	vec2 tg = rvq(min(bf + 0.01, 1.0)) - rvq(max(bf - 0.01, 0.0));
	tg = tg / max(length(tg), 0.0001);
	vec2 d = p - q;
	float s = d.x * tg.y - d.y * tg.x;                          // which side of the river, and how far (signed)
	float dist = sqrt(bd);
	float L = length(u_rv.xy) * 1.1 + 1.0;                    // about how long the whole path is
	float along = bf * L;                                       // how far along it, in pixels
	float endk = smoothstep(0.0, 6.0, (bf - lo) * L + 1.0) * smoothstep(0.0, 9.0, (hi - bf) * L + 1.0);   // soft ends
	float w = W * (0.75 + 0.4 * vn(vec2(along * 0.06 - t * 1.2 * dir, 3.0))) * (0.35 + 0.65 * endk) + 0.5;
	// SMOKE BODY: billowing as it flows
	float gas = vn(vec2(along * 0.12 - t * 2.0 * dir, s * 0.25) + 5.0) * 0.6 + vn(vec2(along * 0.3 - t * 3.5 * dir, s * 0.5)) * 0.4;
	float body = exp(-(dist * dist) / (w * w)) * (0.5 + 0.75 * gas);
	// STRANDS: a few filaments of light wandering through the body, with light running along them the way it flows
	float Is = 0.0;
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		float off = (vn(vec2(along * 0.045 - t * 0.6 * dir + fk * 7.3, fk * 3.1)) - 0.5) * 1.8 * w;
		float ds = s - off;
		float line = exp(-(ds * ds) / (2.2 + 0.4 * u_px));
		float pulse = 0.4 + 0.8 * vn(vec2(along * 0.09 - t * 6.0 * dir + fk * 11.0, fk));
		Is += line * pulse * (0.6 - 0.1 * fk);
	}
	float src = (dir > 0.0) ? 1.0 - 0.45 * bf : 0.55 + 0.45 * bf;   // brightest near where it comes from
	Is *= src * endk * (1.0 - smoothstep(w * 0.7, w * 1.6, dist));
	float I = min(Is, 1.05);
	if (body > 0.35 && h2(pc + floor(t * 8.0) * 7.7) > 0.975) I = max(I, 1.05);   // sparkles in the body
	I = floor(I * 7.0 + 0.5) / 7.0;
	float bq = floor(clamp(body, 0.0, 1.0) * 4.0 + 0.5) / 4.0;
	// the smoke body (drawn over, not added) with the light on top of it
	float ab = 0.55 * bq;
	float al = clamp(I * 0.6, 0.0, 0.6);
	vec3 col = mix(u_smoke, u_glow, 0.25 * bq) * ab * (1.0 - al) + ramp(I) * (al + 0.45 * I);
	float a = ab + al * (1.0 - ab);
	// a broken darker edge, so the river has a shape
	float e = body + (h2(pc + 3.0) - 0.5) * 0.06;
	if (I < 0.3 && e > 0.12 && e < 0.24 && vn(vec2(along * 0.2 + t * dir, s * 0.3)) > 0.55) { col = u_smoke * 0.5; a = 0.5; }
	return vec4(col, a);
}
void main()
{
	vec2 rel = v_world - floor(u_center);
	vec2 pc = floor(rel / u_px);                     // which magic pixel this is
	vec2 p = (pc + 0.5) * u_px;                      // its middle, in world pixels from the center
	vec4 o;
	if (u_mode > 2.5) o = river(p, pc);
	else if (u_mode > 1.5) o = flame(p, pc);
	else if (u_mode > 0.5) o = flow(p, pc);
	else o = orb(p, pc);
	gl_FragColor = o;
}
