// sh_hex_orb: the Hexweaver's living hex, drawn as a small cloud of ionized hex energy crackling and warbling in her hand.
// Every pixel is computed from shapes and noise (there is no smoke field behind it). scr_hex_wisp (hex_orb_draw) draws one square of
// this around each ball of her magic. Output is PREMULTIPLIED (draw with gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha)); the
// violet glow around it has alpha 0, so it adds light instead of covering the ground.
// The look was designed in the lookdev rig as "round 7" (notes/hex-wisp.md). The pieces, from the inside out:
//   heart    a big, hot, crackling center: a bright patch with crack-holes, ringed by core-blue
//   clumps   a few overlapping soft clouds drifting on their own orbits, so the body is layered with dark seams (not one blob, not strands)
//   crinkle  fine ridged texture bent by moving warps: dark creases between lit ridges
//   sphere   a smooth, dark, dithered haze that fades outward like a nebula's edge, plus a banded violet glow that lights the surroundings
//   life     uneven breathing, independent pulses, twinkling sparks, hex rings when charged
// u_energy 0..1 is how active she is: calm = small and slow; charged = bigger, hotter, crinklier, more violent.
varying vec2 v_world;     // this pixel's position in the room, from the vertex shader
uniform vec2  u_center;   // where the ball is in the room (world pixels)
uniform vec2  u_box;      // the square being drawn around it, in world pixels (an even whole number)
uniform float u_R;
uniform float u_energy;
uniform float u_time;
uniform float u_seed;
uniform vec3  u_smoke;
uniform vec3  u_glow;
uniform vec3  u_core;
uniform vec3  u_spark;
uniform float u_hot;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + u_seed * 17.0) * 43758.5453); }
float h1(float n) { return fract(sin(n * 91.345 + u_seed * 5.0) * 47453.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), u.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), u.x), u.y);
}
float ridge(float n) { return 1.0 - abs(2.0 * n - 1.0); }
float b2(vec2 p) { vec2 m = mod(floor(p), 2.0); return mod(m.x * 2.0 + m.y * 3.0, 4.0); }
float bayer(vec2 p) { return (4.0 * b2(p) + b2(p * 0.5)) / 16.0; }
float hexd(vec2 p) { vec2 q = abs(p); return max(q.x * 0.8660254 + q.y * 0.5, q.y); }

float tone(vec2 pc)
{
	vec2 p = (pc + 0.5) - u_box * 0.5;
	float r = length(p);
	float R = u_R, E = clamp(u_energy, 0.0, 1.0), t = u_time;
	vec2 dir = p / max(r, 0.5);
	float breath = 1.0 + 0.09 * sin(t * 1.9 + 1.3 * sin(t * 0.7)) + 0.05 * sin(t * 5.3 + 2.0 * sin(t * 1.9));
	// ---- clumps: a central cloud plus four that orbit it on their own paths, at their own sizes ----
	float eb = exp(-pow(mix(r, hexd(p) * 1.12, 0.2) / (R * (1.3 + 0.5 * E) * breath), 2.0));
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float a = t * (0.5 + 0.7 * h1(fi + 1.0)) * (1.0 - 2.0 * mod(fi, 2.0)) + fi * 1.9;
		float orb = R * (0.7 + 0.45 * E + 0.35 * sin(t * (0.8 + 0.3 * fi) + fi * 2.0));
		vec2 c = orb * vec2(cos(a), sin(a));
		float rad = R * (0.95 + 0.5 * E + 0.25 * sin(t * 1.7 + fi * 2.3));
		vec2 dd = p - c;
		eb += 0.8 * exp(-dot(dd, dd) / (rad * rad));
	}
	float e = clamp(eb * 0.6, 0.0, 1.0);
	// ---- warps for crinkle and erosion ----
	vec2 w1 = vec2(vn(p * 0.08 + vec2(t * 0.5, 1.0)), vn(p * 0.08 + vec2(5.2, -t * 0.45))) - 0.5;
	vec2 s = p + w1 * (6.0 + 8.0 * E);
	vec2 w2 = vec2(vn(s * 0.17 + vec2(-t * 0.9, 7.7)), vn(s * 0.17 + vec2(3.3, t * 0.8))) - 0.5;
	s += w2 * (2.5 + 5.0 * E);
	float dens = vn(s * 0.10 + vec2(0.0, t * 0.15)) * 0.45 + vn(s * 0.24 + vec2(t * 0.4, -t * 0.3)) * 0.33 + vn(s * 0.55 + vec2(-t * 0.6, t * 0.5)) * 0.22;
	float F = e * 0.68 + (dens - 0.5) * (1.2 + 0.45 * E) * smoothstep(0.0, 0.3, e);
	float cr = ridge(vn(s * 0.21 + vec2(0.0, t * 0.25))) * 0.55 + ridge(vn(s * 0.46 + vec2(t * 0.5, -t * 0.4) + 5.0)) * 0.45;
	float ph = vn(dir * 1.6 + vec2(2.0, -t * 0.7)) * 6.2831853;
	float pulse = 0.5 + 0.5 * sin(r * 0.55 - t * (3.0 + 4.0 * E) + ph);
	float inner = smoothstep(0.10, 0.5, F);
	float litv = smoothstep(0.62 - 0.10 * E, 0.93, cr);
	F += litv * inner * (0.30 + 0.16 * pulse) - (1.0 - litv) * inner * 0.28;                  // lit ridges, dark creases
	// ---- the heart: big, hot, crackling ----
	float hr = R * (1.0 + 0.45 * E + 0.22 * sin(t * 3.1 + ph) + 0.1 * sin(t * 7.3));
	float H = exp(-(r * r) / (hr * hr));
	float ck = ridge(vn(s * 0.30 + vec2(t * 1.0, -t * 0.8) + 11.0)) * 0.6 + ridge(vn(s * 0.66 + vec2(-t * 1.2, t * 0.9) + 3.0)) * 0.4;
	float heat = H * (0.38 + 0.9 * smoothstep(0.45, 0.92, ck));                             // crack-holes: the hot patch is broken up
	F += H * 0.40;
	// ---- hex rings when charged ----
	float ringT = fract(t * (0.55 + 0.7 * E) + h2(vec2(floor(t * (0.55 + 0.7 * E)), 3.0)));
	float ringR = R * (1.5 + 2.1 * ringT);
	float ring = (1.0 - smoothstep(0.35, 1.0, abs(hexd(p) - ringR))) * (1.0 - ringT) * smoothstep(0.5, 0.9, E) * 0.8;
	F = max(F, ring * 0.62);
	// ---- tones ----
	float Fd = F + (h2(pc + 41.0) - 0.5) * 0.16;                                             // a broad dither band: the edge breaks into fragments
	float q = 0.0;
	if (Fd > 0.20) q = 1.0;
	if (Fd > 0.56) q = 2.0;
	if (Fd > 0.92) q = 3.0;
	if (heat > 0.40) q = max(q, 3.0);
	if (heat > 0.70) q = 4.0;
	// ---- the outer sphere: a smooth, dark, dithered haze fading out (smoke tone), stepped into bands ----
	float hz = exp(-(r * r) / (R * R * (5.0 + 3.0 * E))) * 0.82;
	float hq = floor(hz * 1.15 + bayer(pc) * 0.999);
	if (hq >= 1.0) q = max(q, 1.0);
	// twinkling sparks
	float inb = step(0.3, F);
	float s1 = step(0.985 - 0.012 * E, h2(pc + floor(t * 9.0) * 13.7));
	float s2 = step(0.995, h2(pc + floor(t * 4.0) * 7.3 + 91.0));
	q = max(q, 4.0 * max(s1, s2) * inb);
	return q;
}
void main()
{
	vec2 pc = floor(v_world) - floor(u_center) + u_box * 0.5;   // this world pixel, counted from the corner of the square (so the look snaps to the game's pixel grid)
	float q = tone(pc);
	vec3 col = u_smoke; float al = 0.5;
	if (q >= 2.0) { col = u_glow; al = 1.0; }
	if (q >= 3.0) { col = u_core; }
	if (q >= 4.0) { col = mix(u_spark, vec3(1.0), u_hot); }
	if (q < 1.0) {
		vec2 p = (pc + 0.5) - u_box * 0.5;
		float g = exp(-dot(p, p) / (u_R * u_R * 22.0)) * 0.55;
		float gl = floor(g * 5.0 + bayer(pc) * 0.999) / 5.0;     // posterized into a few flat bands, dithered between them
		gl_FragColor = vec4(mix(u_glow, u_spark, 0.35) * gl, 0.0);   // alpha 0: adds light instead of covering the ground
	} else {
		gl_FragColor = vec4(col * al, al);
	}
}
