// sh_hex_fluid: drawing and reading her universe's gas (scr_hex_fluid_update / scr_hex_fluid_draw in scr_hexweaver). the gas
// itself is simulated in sh_hex_fluid_p (compressible, self-gravitating, mass-conserving). this shader:
//   u_mode 1, DRAW, DUST: how much of the light behind the gas gets through, color by color (drawn multiplying what's behind).
//     dust blocks blue light more than red (the interstellar extinction curve, ~1/wavelength), so thick gas shows as dark,
//     reddish-brown lanes and the stars behind it redden, as in every real galaxy image
//   u_mode 2, DRAW, LIGHT: the gas, LIT BY HER STARS, as real nebulae are (drawn adding). unlit gas gives off almost nothing in
//     visible light; it glows only where light reaches it:
//     emission: hot young stars' ultraviolet ionizes the gas, which glows in the lines of its atoms: hydrogen-alpha pink
//       everywhere it's ionized, oxygen [OIII] teal where the ionizing light is strongest, sulphur [SII] deep red at the
//       ionization fronts at the edges. her kills' colors stay in it as a tint: the elements each enemy became
//     reflection: dust scatters the starlight that falls on it, bluer than the stars themselves (small grains scatter blue best)
//     plus the faint diffuse glow of gas ionized by all her stars together
//   u_mode 3, READ-BACK: the gas's velocity packed into 8-bit color for the CPU (x in red and blue, y in green), MASS-WEIGHTED
//     over each sample's patch (total momentum / total gas, 4 x 4 taps), so near-empty cells blown to the speed limit by a bubble
//     don't count as much as the gas itself. range +-0.3 reference cells a frame (just past the speed limit): ~11 km/s steps.
//     gm_BaseTexture = momentum, u_vel = the gas
//   u_mode 7, READ-BACK: gas density, averaged over each sample's patch, stored as sqrt(d / (1 + d))
//   u_mode 8, GRAVITY SOURCE: the gas averaged onto the coarse gravity grid, minus its mean
//   u_mode 12, MOMENTUM STAMP: a soft sprite's shape times a signed momentum (u_src), added to the momentum texture
// units: velocities in REFERENCE cells per frame (8 sky px); u_size = the grid in reference cells; u_texel = one real cell
varying vec2 v_vTexcoord;
uniform vec2  u_texel;      // one real cell, in texture coordinates
uniform vec2  u_uvmax;      // where the grid ends in texture coordinates (1, unless the driver padded the texture)
uniform vec2  u_size;       // the grid, in reference cells
uniform float u_k;          // real cells per reference cell (1 on High, 2.67 on HYPERMAX)
uniform float u_time;       // seconds
uniform float u_mode;
uniform float u_diss;       // how much survives each frame (draw: brightness)
uniform vec4  u_holes[4];   // each black hole: x, y (reference cells), whirlpool speed at its edge (cells/frame), its size (reference cells)
uniform vec4  u_kicks[8];   // each shockwave: x, y (reference cells), radius (reference cells), push (cells/frame)
uniform sampler2D u_vel;    // the gas (read-back of velocity)
uniform sampler2D u_light;  // starlight (draw step): rgb = the stars' own light (what dust reflects), a = hot stars' ionizing light
uniform vec2  u_lightmax;   // where the light map ends in texture coordinates
uniform float u_amb;        // the faint light of all the stars together, everywhere (grows as her galaxy fills)
uniform float u_ion;        // how brightly ionized gas glows
uniform float u_refl;       // how brightly dust reflects starlight
uniform float u_dust;       // how strongly dense gas blocks the light behind it
uniform vec2  u_src;        // gravity source: the mean density (taken away), and a scale. momentum stamp: x = the momentum scale
uniform float u_tint;       // how much of her kills' own colors stays in the gas's light (the rest is the physics of its lines)
uniform float u_spell;      // her spell's light during a cast: the gas glows in its own colors (fades after the cast)
varying vec4 v_vColour;

vec2 vel(vec2 uv) { return texture2D(gm_BaseTexture, uv).xy; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + 17.1; a *= 0.5; } return v; }
void main()
{
	vec2 uv = v_vTexcoord;
	vec2 n  = uv / u_uvmax;                                           // 0 to 1 across the grid
	vec2 p  = n * u_size;                                             // in reference cells
	vec2 tx = vec2(u_texel.x, 0.0), ty = vec2(0.0, u_texel.y);

	if (u_mode > 11.5) {                                              // MOMENTUM STAMP: new gas arrives already orbiting
		// its momentum rides in the stamp's vertex color (red = x, green = y, 0.5 = none) times the scale u_src.x, so a whole
		// pour of stamps draws in one batch instead of one draw call each
		gl_FragColor = vec4((v_vColour.rg * 2.0 - 1.0) * u_src.x * texture2D(gm_BaseTexture, uv).a, 0.0, 0.0);
		return;
	}
	if (u_mode > 7.5) {                                               // GRAVITY SOURCE: the gas, averaged onto the coarse gravity grid
		float d = 0.0;                                                // (u_diss: tap spacing, in real cells)
		for (int j = 0; j < 4; j++) for (int i = 0; i < 4; i++) {
			vec3 c = texture2D(gm_BaseTexture, uv + (vec2(float(i), float(j)) - 1.5) * u_diss * u_texel).rgb;
			d += c.r + c.g + c.b;
		}
		d /= 16.0;
		vec2 e = min(n, 1.0 - n);
		gl_FragColor = vec4((d - u_src.x) * u_src.y * smoothstep(0.0, 0.03, min(e.x, e.y)), 0.0, 0.0, 1.0);   // (the mean taken away: the "Jeans swindle")
		return;
	}
	if (u_mode > 6.5) {                                               // READ-BACK, DENSITY: the gas averaged over this sample's patch
		float d = 0.0;                                                // (u_diss: tap spacing, in real cells)
		for (int j = 0; j < 4; j++) for (int i = 0; i < 4; i++) {
			vec3 c = texture2D(gm_BaseTexture, uv + (vec2(float(i), float(j)) - 1.5) * u_diss * u_texel).rgb;
			d += c.r + c.g + c.b;
		}
		d /= 16.0;
		d = sqrt(d / (1.0 + d));                                      // (square root: far finer steps for thin gas)
		gl_FragColor = vec4(d, d, d, 1.0);
		return;
	}
	if (u_mode > 2.5) {                                               // READ-BACK: velocity = total momentum / total gas (u_diss: tap spacing)
		vec2 mo = vec2(0.0); float ms = 0.0;
		for (int j = 0; j < 4; j++) for (int i = 0; i < 4; i++) {
			vec2 o = (vec2(float(i), float(j)) - 1.5) * u_diss * u_texel;
			vec3 g = texture2D(u_vel, uv + o).rgb;
			mo += vel(uv + o); ms += g.r + g.g + g.b;
		}
		vec2 v = clamp(mo / max(ms, 0.002) / 0.6 + 0.5, 0.0, 1.0);
		gl_FragColor = vec4(v.x, v.y, v.x, 1.0);
		return;
	}
	if (u_mode > 0.5) {                                               // DRAW: the gas, lit by her stars (mode 2) or its dust (mode 1)
		vec3 c = texture2D(gm_BaseTexture, uv).rgb;                   // its elements' colors times how much gas
		float d = c.r + c.g + c.b;
		// a little fine filament detail on top (the simulation makes the big shapes; this only roughens the edges)
		float r1 = 1.0 - abs(2.0 * fbm(p * 0.22 + vec2(u_time * 0.015, -u_time * 0.01)) - 1.0);
		float r2 = 1.0 - abs(2.0 * fbm(p * 0.55 - vec2(u_time * 0.02, u_time * 0.012) + 31.0) - 1.0);
		float fil = pow(r1, 2.5) * 0.9 + pow(r2, 4.0) * 0.6;
		float detail = mix(1.0, mix(fil * 1.6, 0.55 + fil * 0.8, smoothstep(0.0, 0.6, d)), 0.4);
		vec2 e = min(n, 1.0 - n);
		float edge = smoothstep(0.0, 0.05, min(e.x, e.y));
		float tau = d * u_dust * detail;                              // its dust's optical depth
		if (u_mode < 1.5) {                                           // DUST: what gets through, per color (blue blocked most)
			vec3 T = exp(-tau * vec3(0.78, 1.0, 1.32));
			gl_FragColor = vec4(mix(vec3(1.0), T, edge), 1.0);
			return;
		}
		vec4 L = texture2D(u_light, n * u_lightmax);
		float ion = L.a / (1.0 + L.a);                                // (light piles up softly: a gas can only be so ionized)
		vec3 lr = L.rgb / (1.0 + max(L.r, max(L.g, L.b)));
		// RADIATIVE TRANSFER: thick gas absorbs its own light, so its brightness saturates (I = S (1 - e^-tau), the real law), and a
		// dense core glows deep and rich instead of blowing out to white
		float thick = (1.0 - exp(-tau)) / max(tau, 0.0001);           // ~1 for thin gas, ~1/tau for thick
		// its emission lines: H-alpha pink wherever it's ionized, [OIII] teal where the ionizing field is strongest (near the hottest,
		// youngest clusters), [SII] red at the ionization fronts. normalized so each carries the same total light
		vec3 HA = vec3(1.0, 0.34, 0.50), O3 = vec3(0.30, 0.95, 0.85), S2 = vec3(1.0, 0.28, 0.20);
		float fO = smoothstep(0.45, 0.88, ion) * 0.7, fS = (1.0 - smoothstep(0.06, 0.35, ion)) * 0.55;
		vec3 line = mix(mix(HA, S2, fS), O3, fO);
		vec3 el = c / max(max(c.r, max(c.g, c.b)), 0.0001);          // her kills' colors: the elements this gas is made of
		line = mix(line, el, u_tint);
		line /= max(line.r + line.g + line.b, 0.0001);
		vec3 dig = mix(HA, el, 0.5);                                  // the faint, diffuse ionized gas everywhere (lit by all her stars)
		dig /= (dig.r + dig.g + dig.b);
		vec3 elc = el / max(el.r + el.g + el.b, 0.0001);             // (her kills' colors, carrying the same total light)
		vec3 emis = d * thick * (line * ion * u_ion + dig * u_amb * 0.5 + elc * u_spell);
		vec3 refl = d * thick * lr * vec3(0.72, 0.9, 1.3) * u_refl;  // dust: the stars' light, scattered bluer
		gl_FragColor = vec4((emis + refl) * detail * u_diss * edge, 0.0);
		return;
	}
}
