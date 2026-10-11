// sh_hex_tone: how a camera sees her sky. light gathered in a 16-bit surface can be brighter than white;
// instead of clipping flat, bright light rolls off smoothly, and only the very brightest cores bleach toward white
varying vec2 v_vTexcoord;
varying vec4 v_vColor;

uniform float u_exposure;  // 1 = as drawn. raise for a brighter sky, lower for a darker one
uniform vec3  u_grade;     // the aeon's color grade: a tint for the whole sky (1,1,1 = none)
uniform vec3  u_lift;      // light added to the whole sky (the crunch's brightening, blueshifted background)

void main()
{
	vec3 c = max(texture2D(gm_BaseTexture, v_vTexcoord).rgb, 0.0) * u_exposure * u_grade + u_lift;

	// brightness below the knee passes untouched (so the dim sky looks exactly as before); above it, it eases toward a ceiling
	float L    = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float knee = 0.7;
	if (L > knee) {
		float Lm = knee + (1.0 - knee) * (1.0 - exp(-(L - knee) / (1.0 - knee)));
		c *= Lm / L;
	}
	// a color too bright for the screen keeps its hue and bleaches toward white, like an overexposed photo of a star
	float m = max(c.r, max(c.g, c.b));
	if (m > 1.0) c = mix(c / m, vec3(1.0), clamp((m - 1.0) * 0.6, 0.0, 0.85));

	gl_FragColor = vec4(c, 1.0);
}
