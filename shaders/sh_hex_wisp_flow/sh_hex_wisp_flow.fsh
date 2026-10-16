// sh_hex_wisp_flow: one step in the life of the Hex wisp (scr_hex_wisp drives it, once a frame).
// The wisp lives in a small "field" picture that covers the camera's view. Her motes stamp light into it; this shader then
// carries last frame's field forward: it drags every bit of light along a swirling current (curl noise, so it curls and
// folds like smoke instead of clumping), lets a little of it fade, and keeps it pinned to the world as the camera moves.
// Around each "ball" of her magic (an attractor: the ball in her hand, the charging orb, a shot in flight) the current changes
// character: the wandering is calmed, and everything is pulled in along a spiral and eaten at the middle. That constant
// falling-in is what makes the magic read as a ball that is forever collapsing, instead of smoke that blows away.
//   channels: r = smoke (wide and faint), g = core (tight and bright), b = energy flowing home (burns brighter)
// gm_BaseTexture = last frame's field
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2  u_texel;   // one field pixel, in texture coordinates
uniform vec2  u_uvmax;   // where the field ends in texture coordinates (1, 1 unless the driver padded the texture)
uniform vec2  u_size;    // the field, in pixels
uniform vec2  u_org;     // where the view's top-left corner is in the world, in field pixels (the current is anchored to the world)
uniform vec2  u_shift;   // how far the camera moved since last frame, in field pixels
uniform float u_time;    // seconds
uniform float u_flow;    // strength of the current, in field pixels a frame
uniform float u_decay;   // how much of the light survives a frame (0.93 = a trail about 14 frames long)
uniform float u_cut;     // a tiny amount taken away each frame so faint light dies on 8-bit surfaces instead of lingering forever
uniform float u_cell;    // size of the biggest swirl, in field pixels
uniform vec4  u_att[4];  // the balls: x, y (field pixels, from the view's top-left), radius (field pixels), strength 0 to 1 (0 = not there)
uniform float u_pull;    // how fast smoke falls toward a ball, in field pixels a frame
uniform float u_swirl;   // how fast it circles the ball while it falls
uniform float u_eat;     // how much of the light at a ball's middle is swallowed each frame (0 to 1)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
// a smooth hill-and-valley landscape; the current runs along its contour lines, so it never piles up or drains away
float pot(vec2 q) { return wnoise(q) * 0.65 + wnoise(q * 2.13 + vec2(7.3, 3.1)) * 0.35; }
vec2 curl(vec2 q) {
	float e = 0.3;
	float a = pot(q + vec2(0.0, e)) - pot(q - vec2(0.0, e));
	float b = pot(q + vec2(e, 0.0)) - pot(q - vec2(e, 0.0));
	return vec2(a, -b) / (2.0 * e);
}
void main()
{
	vec2 uv = v_vTexcoord;
	vec2 px = uv / u_uvmax * u_size;                                   // this pixel, in field pixels
	vec2 q  = (px + u_org) / u_cell + vec2(u_time * 0.10, -u_time * 0.07);   // where it is in the (slowly sliding) current
	vec2 f  = curl(q) * u_flow;
	vec2 fall = vec2(0.0);
	float calm = 0.0, eat = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 a = u_att[i];
		vec2 d = px - a.xy;
		float r = length(d) + 0.001;
		float R = max(a.z, 0.5);
		float zone = a.w * (1.0 - smoothstep(R * 2.0, R * 6.0, r));          // 1 around the ball, 0 well away from it
		vec2 dir = d / r;
		float inward = u_pull * min(r / R, 1.0);                              // (no overshoot right at the middle)
		float turn = u_swirl * min(R / max(r, 0.5 * R), 1.0);                // circles faster the closer in it gets
		fall += zone * (-dir * inward + vec2(-dir.y, dir.x) * turn);
		calm = max(calm, zone);
		eat = max(eat, a.w * (1.0 - smoothstep(R * 0.5, R * 1.5, r)));
	}
	f = f * (1.0 - 0.85 * calm) + fall;                                       // near a ball the wandering gives way to the falling in
	vec2 src = uv + (u_shift - f) * u_texel;                           // where this pixel's light was a moment ago
	vec2 n = src / u_uvmax;
	float inside = step(0.0, n.x) * step(n.x, 1.0) * step(0.0, n.y) * step(n.y, 1.0);   // nothing arrives from outside the view
	vec4 prev = texture2D(gm_BaseTexture, src);
	gl_FragColor = max(prev * u_decay * (1.0 - u_eat * eat) - u_cut, 0.0) * inside;
}
