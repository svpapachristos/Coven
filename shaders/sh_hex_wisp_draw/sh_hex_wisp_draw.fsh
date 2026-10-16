// sh_hex_wisp_draw: turns the wisp's field into smoke and light. Output is PREMULTIPLIED: rgb already includes alpha, so it is
// drawn with gpu_set_blendmode_ext(bm_one, bm_inv_src_alpha). That way the smoke keeps its own color over bright ground
// (plain additive light washes to white on grass), while the hottest part adds a little glow on top (rgb is allowed to
// exceed alpha, and that excess is the added light).
// Around each ball of her magic (an attractor, the same ones the flow shader pulls toward) it ADDS the picture of collapse: spiral
// arms that travel inward as they turn, and a dense ball at the middle. Drawn per screen pixel, so the arms are smooth and sharp
// even though the field itself is coarse.
// density -> a three-step ramp: faint smoke, glowing body, bright core, with an optional white-hot center. The palette is
// handed in as uniforms, so swapping her color is just swapping a few numbers.
// gm_BaseTexture = the field (r = smoke, g = core, b = energy flowing home)
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2  u_uvmax;   // where the field ends in texture coordinates (1, 1 unless the driver padded the texture)
uniform vec2  u_size;    // the field, in pixels
uniform vec2  u_org;     // where the view's top-left corner is in the world, in field pixels
uniform float u_time;    // seconds
uniform float u_gain;    // how fast density turns into light
uniform float u_bright;  // overall brightness
uniform float u_detail;  // 0 to 1: how much fine wispy filament breaks up the smoke
uniform float u_hot;     // 0 to 1: how white the very brightest part burns
uniform float u_add;     // how much extra light the hot part adds on top of the smoke (0 = none)
uniform vec4  u_att[4];  // the balls: x, y (field pixels, from the view's top-left), radius (field pixels), strength 0 to 1 (0 = not there)
uniform float u_arms;    // how bright the inward-turning spiral arms are
uniform float u_ball;    // how dense the ball at the middle is
uniform float u_spin;    // how fast the arms turn and fall inward
uniform vec3  u_smoke;   // the palette, 0 to 1 per channel
uniform vec3  u_glow;
uniform vec3  u_core;
uniform vec3  u_spark;   // what energy flowing home is tinted toward

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 3; i++) { v += a * wnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return v / 0.875; }
void main()
{
	vec2 uv = v_vTexcoord;
	vec2 n = uv / u_uvmax;                                             // 0 to 1 across the field
	vec4 f = texture2D(gm_BaseTexture, uv);
	float d = f.r + f.g * 1.6;
	vec2 fpx = n * u_size;                                             // this pixel, in field pixels from the view's top-left
	float ball = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 a = u_att[i];
		vec2 q = fpx - a.xy;
		float R = max(a.z, 0.5);
		float u = length(q) / R;                                       // distance in ball radii
		float ang = atan(q.y, q.x + 0.0001);
		float ph = 3.0 * ang - 4.0 * log(u + 0.25) - u_time * u_spin;  // three arms; a point on an arm slides toward the middle as time passes
		float arm = pow(0.5 + 0.5 * sin(ph), 1.5);
		float env = (1.0 - smoothstep(1.3, 4.2, u)) * smoothstep(0.15, 0.8, u);   // arms live between the ball and a few radii out
		d += a.w * u_arms * arm * env;
		ball += a.w * u_ball * exp(-u * u * 2.2);
	}
	// fine filaments: the density is roughened by moving noise (anchored to the world), only where there's something to roughen
	vec2 wp = n * u_size + u_org;
	float fil = fbm(wp / 7.0 + vec2(u_time * 0.35, -u_time * 0.22));
	d *= mix(1.0, 0.3 + 1.4 * fil, u_detail * clamp(d * 3.0, 0.0, 1.0));
	d += ball;                                                         // the ball itself stays solid (not roughened)
	float t = 1.0 - exp(-d * u_gain);                                  // soft ceiling: stacking more light brightens, never clips harshly
	t = clamp(t + f.b * 0.5, 0.0, 1.0);                                // energy flowing home burns a little brighter
	vec3 col = mix(u_smoke, u_glow, smoothstep(0.04, 0.5, t));
	col = mix(col, u_core, smoothstep(0.45, 0.95, t));
	col = mix(col, u_spark, clamp(f.b * 1.6, 0.0, 1.0) * 0.55);
	col = mix(col, vec3(1.0), u_hot * smoothstep(0.85, 1.0, t));
	vec2 e2 = min(n, 1.0 - n);
	float edge = smoothstep(0.0, 0.04, min(e2.x, e2.y));               // fade at the view's edge instead of a hard cut
	float a = smoothstep(0.0, 0.55, t) * u_bright * edge;              // how much of the ground the smoke hides
	float glow = smoothstep(0.5, 1.0, t) * u_add * edge;               // the hot part adds light on top
	gl_FragColor = vec4(col * (a + glow), a);                          // premultiplied
}
