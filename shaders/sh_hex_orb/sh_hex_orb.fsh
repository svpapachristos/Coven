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
void main()
{
	vec2 rel = v_world - floor(u_center);
	vec2 pc = floor(rel / u_px);                     // which magic pixel this is
	vec2 p = (pc + 0.5) * u_px;                      // its middle, in world pixels from the ball's center
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
	float Im = 0.5 * (1.0 - 0.35 * E) * exp(-(rq * rq) / (R * R * (1.1 + 0.6 * E))) * (0.55 + 0.7 * gas);
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
	// twinkles along the strands
	if (Is > 0.3 && h2(pc + floor(t * 10.0) * 13.7) > 0.97 - 0.02 * E) Is += 0.7;
	// SMOKE / EDGE (dark violet): the one part that isn't light. A ragged dark rim where the field fades out, and drifting
	// dark patches on its underside. It gives the orb its shape (light alone can only brighten)
	float sm = vn(p * 0.3 + vec2(t * 0.5, t * 0.3)) * 0.7 + vn(p * 0.7 - t) * 0.3 + 0.3 * smoothstep(-R * 0.3, R, p.y);
	float rimv = field + (h2(pc + 3.0) - 0.5) * 0.06;
	bool isRim = rimv > 0.1 && rimv < 0.22 && vn(p * 0.22 + vec2(-t * 0.4, t * 0.3)) > 0.48;   // broken up: never a clean outline
	bool isShade = Ib > 0.25 && sm > 0.78;
#ifdef LOOKDEV
	Ic *= on(1.0); Ib *= on(2.0); Id *= on(2.0); Is *= on(8.0); Iv *= on(16.0);
	if (on(4.0) < 0.5) { isRim = false; isShade = false; }
#endif
	float I = Is + Ib + Iv + Io + Ic + Id;
	if (isShade) I -= 0.3;                                // shade sinks into the gas
	I = max(floor(I * 7.0 + 0.5) / 7.0, 0.0);       // a few flat steps of brightness: pixel art, no dither
	float a = clamp(I * 0.6, 0.0, 0.6);              // the see-through violet tint over what's behind
	vec3 c = ramp(I);
	vec4 o = vec4(c * (a + 0.45 * min(I, 1.6)), a);  // tint + added light
	if ((isRim || isShade) && I < 0.45) o = vec4(u_smoke * 0.5, 0.5);   // dark smoke edge (drawn over, not added)
	gl_FragColor = o;
}
