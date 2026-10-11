// sh_crumble: a body crumbling into stardust, pixel by pixel from the head down,
// its crumbling edge burning white-violet
varying vec2 v_vTexcoord;
varying vec4 v_vColor;

uniform vec4  u_uvs;   // where the sprite sits on its texture page: left, top, right, bottom
uniform vec2  u_texel; // one texture pixel, so each crumb is exactly one sprite pixel
uniform float u_cut;   // 0 = whole, 1 = all dust
uniform vec3  u_edge;  // color of the burning edge

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main()
{
	vec4  c   = texture2D(gm_BaseTexture, v_vTexcoord);
	float h   = (u_uvs.w - v_vTexcoord.y) / (u_uvs.w - u_uvs.y);  // 0 at its feet, 1 at the top of its head
	float n   = hash(floor(v_vTexcoord / u_texel / 2.0));          // a random number per 2x2 crumb: raise 2.0 for chunkier crumbs
	float k   = (1.0 - h) * 0.45 + n * 0.55;                       // head first, but mostly ragged, so it flakes apart instead of scanning away
	float cut = u_cut * 1.05;
	if (k < cut) discard;                                          // this pixel has already crumbled away
	float edge = (1.0 - smoothstep(0.0, 0.08, k - cut)) * step(0.001, u_cut); // the pixels about to go next
	vec3 col = c.rgb * v_vColor.rgb;
	col = mix(col, u_edge, edge);
	col += vec3(1.0) * pow(edge, 3.0) * 0.6;                      // white-hot right at the edge
	gl_FragColor = vec4(col, c.a * v_vColor.a);
}