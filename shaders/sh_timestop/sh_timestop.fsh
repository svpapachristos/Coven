// sh_timestop: the frozen world, drained to her violet-grey and falling into shadow away from her
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_vWorld;

uniform vec2  u_center; // where she stands
uniform float u_desat;  // 0 = full colour, 1 = drained to grey
uniform vec3  u_tint;   // the colour the grey leans toward
uniform float u_dark;   // 0 to 1: the world falls into shadow away from her
uniform float u_solid; // 1 = ignore the textures own transparency (the snapshot), 0 = keep it (sprites)

void main()
{
	vec4  c    = texture2D(gm_BaseTexture, v_vTexcoord);
	float lum  = dot(c.rgb, vec3(0.299, 0.587, 0.114));   // brightness as the eye sees it
	vec3  outc = mix(c.rgb, lum * u_tint, u_desat);        // drained to a tinted grey
	float d    = distance(v_vWorld, u_center);
	outc *= 1.0 - u_dark * smoothstep(150.0, 1100.0, d);    // shadow everywhere except close around her
	gl_FragColor = vec4(outc, mix(c.a, 1.0, u_solid) * v_vColour.a);
}