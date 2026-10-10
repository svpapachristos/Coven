// sh_starlit: turns a sprite into a window onto the Hexweaver's cosmos
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2  u_texel; // the size of one pixel of this sprite's texture, for finding its edges
uniform vec4  u_uvs;   // where the sprite sits on its texture page: left, top, right, bottom
uniform float u_fill;  // 0 to 1: how far up the body the starlight has risen
uniform float u_time;  // seconds, for twinkling
uniform vec3  u_rim;   // colour of the glowing edge

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main()
{
	vec4 base = texture2D(gm_BaseTexture, v_vTexcoord);
	float a = base.a * v_vColour.a;

	// 0 at its feet, 1 at the top of its head
	float h = (u_uvs.w - v_vTexcoord.y) / (u_uvs.w - u_uvs.y);
	float lit   = step(h, u_fill);                                   // below the fill line: cosmos
	float front = (1.0 - smoothstep(0.0, 0.1, abs(h - u_fill)))      // a bright band right at the fill line...
	            * step(u_fill, 0.999);                               // ...that disappears once it's full

	// an edge pixel is one with a see-through neighbour
	float n = texture2D(gm_BaseTexture, v_vTexcoord + vec2(u_texel.x, 0.0)).a
	        * texture2D(gm_BaseTexture, v_vTexcoord - vec2(u_texel.x, 0.0)).a
	        * texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0, u_texel.y)).a
	        * texture2D(gm_BaseTexture, v_vTexcoord - vec2(0.0, u_texel.y)).a;
	float edge = 1.0 - step(0.5, n);

	// her cosmos, using SCREEN position (gl_FragCoord) so the body is a window, not a painted texture
	vec2  cell = floor(gl_FragCoord.xy / 2.0);  // raise 2.0 for chunkier stars
	float r    = hash(cell);
	float star = step(0.94, r) * (0.55 + 0.45 * sin(u_time * 4.0 + r * 60.0));
	float glow = 0.5 + 0.5 * sin(gl_FragCoord.x * 0.02 + gl_FragCoord.y * 0.015 + u_time * 0.7);
	vec3 cosmos = mix(vec3(0.05, 0.02, 0.14), vec3(0.20, 0.08, 0.38), glow) + vec3(star);

	vec3 col = mix(base.rgb * v_vColour.rgb, cosmos, lit);  // real colours above the line, cosmos below
	col = mix(col, u_rim, max(edge * lit, front));
	gl_FragColor = vec4(col, a);
}