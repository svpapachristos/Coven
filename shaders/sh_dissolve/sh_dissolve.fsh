// sh_dissolve: a piece of the frozen world being unmade. it crumbles away from the rip outward,
// its edges burning violet as they go
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform float u_cut;    // 0 = whole, 1 = gone
uniform float u_ripv;   // where the rip runs, in texture coordinates (up/down), so it eats outward from there
uniform vec2  u_scale;  // how many noise cells across the texture (across, down)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// smooth random hills: a random height at every grid corner, blended between them
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main()
{
	vec4  c   = texture2D(gm_BaseTexture, v_vTexcoord);
	vec2  p   = v_vTexcoord * u_scale;
	float n   = vnoise(p) * 0.6 + vnoise(p * 3.1) * 0.3 + vnoise(p * 9.7) * 0.1;   // big blobs with crumbly edges
	float far = clamp(abs(v_vTexcoord.y - u_ripv) * 2.0, 0.0, 1.0);             // 0 at the rip, 1 out at the screen's edge
	float k   = n * 0.55 + far * 0.45;                                            // so the ground nearest the rip goes first
	float cut = u_cut * 1.15;
	if (k < cut) discard;                                                         // this bit has been unmade
	float on   = step(0.001, u_cut);
	float edge = (1.0 - smoothstep(0.0, 0.06, k - cut)) * on;                    // the band about to go next
	vec3  col  = c.rgb * v_vColour.rgb;
	col  = mix(col, vec3(0.75, 0.45, 1.0), edge);                                 // burning violet
	col += vec3(1.0, 0.85, 1.0) * pow(edge, 4.0) * 0.8;                           // white-hot right at the edge
	gl_FragColor = vec4(col, v_vColour.a);
}