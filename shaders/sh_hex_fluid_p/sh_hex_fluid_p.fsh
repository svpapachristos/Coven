// sh_hex_fluid_p: THE GAS OF HER UNIVERSE, as astrophysics codes simulate it (scr_hex_fluid_update in scr_hexweaver).
// compressible, self-gravitating gas on a grid, solved the way codes like Athena and RAMSES do: the "finite volume" method.
// each cell holds its gas (as colored mass: the rgb of the gas texture, red + green + blue = its density) and its momentum.
// every step, the gas crossing each wall between two cells is worked out from the cells on either side (the Rusanov, or local
// Lax-Friedrichs, flux), with a second-order MUSCL reconstruction and a minmod limiter so filaments stay sharp without ringing.
// what one cell loses its neighbor gains, so MASS IS EXACTLY CONSERVED. the equations (compressible Euler, isothermal, with
// gravity), in plain words:
//   mass:      gas only moves between neighboring cells
//   momentum:  gas is pushed by its own pressure (P = cs^2 rho: cold gas at a set temperature, the classic model for the
//              clouds stars form in) and pulled by gravity (-rho grad phi). shocks, shells and collapse come out by themselves
// units: velocities in REFERENCE cells per frame (8 sky px); u_k real cells per reference cell; u_dt = this substep's share
// of a frame. modes:
//   u_mode 5:  GRAVITY: the potential of a thin disk at every gravity cell, summed from the mass pyramid (see below)
//   u_mode 10: GAS step (writes the colored mass)
//   u_mode 11: MOMENTUM step (writes the momentum): flux, pressure, gravity, the halo, shockwaves, and the superbubbles' push
// TIME STEPPING: second-order, strong-stability-preserving Runge-Kutta (SSP-RK2, Shu & Osher 1988), as codes pair with MUSCL:
// stage 1 takes a trial step from the start; stage 2 steps again from the trial and averages with the start. (a single plain
// step, forward Euler, is unstable with MUSCL's sharp reconstruction: thanks to Sophia's friend for pointing at Runge-Kutta)
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
uniform vec2  u_texel;      // one real cell (or gravity cell, in mode 5), in texture coordinates
uniform vec2  u_uvmax;
uniform vec2  u_size;       // the grid, in reference cells
uniform float u_k;          // real cells per reference cell
uniform float u_mode;
uniform float u_dt;         // this substep's share of a frame
uniform float u_keep;       // the ledger's thinning, this substep (1 = none)
uniform float u_kick;       // how hard a shockwave pushes, per frame
uniform vec4  u_holes[4];   // each black hole: x, y (reference cells), its feeding rate (share per frame, set from Bondi/Eddington), its size
uniform vec4  u_kicks[8];   // each shockwave: x, y (reference cells), radius (reference cells), strength
uniform sampler2D u_vel;    // momentum (gas steps), or the gravity source (mode 5)
uniform sampler2D u_gas;    // the colored mass
uniform sampler2D u_gas0;   // (Runge-Kutta stage 2) the colored mass at the start of the step
uniform sampler2D u_vel0;   // (Runge-Kutta stage 2) the momentum at the start of the step
uniform float u_stage;      // 0 = Runge-Kutta stage 1 (trial step), 1 = stage 2 (average with the start)
uniform sampler2D u_phi;    // the gravitational potential, on the gravity grid
uniform vec2  u_phimax;
uniform vec2  u_phitexel;
uniform float u_grav;       // gravity's strength
uniform float u_cs;         // the sound speed (reference cells per frame): how hard the gas's pressure pushes
uniform float u_jeans;      // the Jeans pressure floor (see wallFlux): N_J x G x Sigma x (one reference cell), per unit density
uniform float u_gn;         // gravity: the finest level's cells across (128)
uniform float u_geps;       // gravity: the disk's thickness, in gravity cells (softens the pull up close)
uniform vec2  u_halo;       // the dark matter halo: its flat rotation speed (reference cells a frame), its core radius (reference cells)
uniform sampler2D u_light;  // the starlight map (a = hot stars' ionizing light)
uniform vec2  u_lightmax;
uniform float u_cshot;      // the sound speed of gas heated by hot stars' light (~10,000 degrees: photoionized)
uniform sampler2D u_fb;     // the SUPERBUBBLES: every star cluster's bubble pressure (scr_hex_feedback_map), in units of u_fbscale x cs^2
uniform vec2  u_fbmax;
uniform vec2  u_fbtexel;
uniform float u_fbscale;

// beyond the edge of the grid is empty space (an OUTFLOW-ONLY boundary): gas can leave, nothing flows back in from outside
bool outside(vec2 uv) { vec2 q = uv / u_uvmax; return q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0; }
vec3 gasAt(vec2 uv) { return outside(uv) ? vec3(0.0) : max(texture2D(u_gas, uv).rgb, vec3(0.0)); }
// PHOTOIONIZATION HEATING: gas lit by hot stars' ultraviolet is heated to ~10,000 degrees, its sound speed jumps, and its
// pressure pushes back far harder: lit gas resists collapse and blows bubbles (HII regions), real stellar feedback
float cs2At(vec2 uv) {
	float L = texture2D(u_light, (uv / u_uvmax) * u_lightmax).a;
	float ion = L / (1.0 + L);
	return u_cs * u_cs + u_cshot * u_cshot * ion;
}
vec2 momAt(vec2 uv) { return outside(uv) ? vec2(0.0) : texture2D(u_vel, uv).xy; }
float rhoOf(vec3 c) { return c.r + c.g + c.b; }
// THE SPEED LIMIT: no gas moves faster than 0.25 reference cells a frame (~1,150 km/s at 1 million years a second: fast supernova
// debris). it also keeps every step inside what the solver can follow (the Courant condition) on every tier
#define VMAX 0.25
vec2 velOf(vec3 c, vec2 m) {                                        // velocity, real cells per frame
	vec2 v = m / max(rhoOf(c), 0.002);
	float s = length(v);
	if (s > VMAX) v *= VMAX / s;
	return v * u_k;
}
vec3 mm3(vec3 a, vec3 b) { return 0.5 * (sign(a) + sign(b)) * min(abs(a), abs(b)); }   // minmod: the gentler slope, or flat at a peak
vec2 mm2(vec2 a, vec2 b) { return 0.5 * (sign(a) + sign(b)) * min(abs(a), abs(b)); }

// the gas crossing the wall between the cell at uv and its neighbor at uv + e (e = one cell along an axis; n = that axis).
// out: the colored-mass flux (fc) and the momentum flux (fm, real units), both positive in the +e direction
void wallFlux(vec2 uv, vec2 e, vec2 n, out vec3 fc, out vec2 fm) {
	// four cells along the line: i-1, i, i+1, i+2 (the wall sits between i and i+1)
	vec3 c0 = gasAt(uv - e), c1 = gasAt(uv), c2 = gasAt(uv + e), c3 = gasAt(uv + 2.0 * e);
	vec2 v0 = velOf(c0, momAt(uv - e)), v1 = velOf(c1, momAt(uv)), v2 = velOf(c2, momAt(uv + e)), v3 = velOf(c3, momAt(uv + 2.0 * e));
	// MUSCL: each side's value at the wall, from a limited slope (second order where smooth, first order at sharp edges)
	vec3 cL = c1 + 0.5 * mm3(c1 - c0, c2 - c1), cR = c2 - 0.5 * mm3(c2 - c1, c3 - c2);
	vec2 vL = v1 + 0.5 * mm2(v1 - v0, v2 - v1), vR = v2 - 0.5 * mm2(v2 - v1, v3 - v2);
	cL = max(cL, vec3(0.0)); cR = max(cR, vec3(0.0));
	float rL = rhoOf(cL), rR = rhoOf(cR);
	float uL = dot(vL, n), uR = dot(vR, n);
	// pressure: P = c^2 rho. c^2 is the cold gas's sound speed squared, plus the JEANS PRESSURE FLOOR (as in real codes: Truelove
	// et al. 1997, Machacek et al. 2001): extra pressure only in gas so dense its collapse would shrink below a few grid cells,
	// where the grid could only fake it (spurious fragments, then blow-ups). for a thin disk the Jeans length is c^2 / (G Sigma), so
	// keeping it N cells long needs c^2 >= N G Sigma dx (u_jeans x rho / u_k: dx is one real cell). collapse stops at the grid's
	// limit instead; the star clusters take over from there
	float k2 = u_k * u_k;
	float c2L = (cs2At(uv) + u_jeans * rL / u_k) * k2, c2R = (cs2At(uv + e) + u_jeans * rR / u_k) * k2;
	float a = max(abs(uL), abs(uR)) + sqrt(max(c2L, c2R));        // the fastest signal at this wall
	vec2 mL = rL * vL, mR = rR * vR;
	fc = 0.5 * (cL * uL + cR * uR) - 0.5 * a * (cR - cL);
	fm = 0.5 * (mL * uL + c2L * rL * n + mR * uR + c2R * rR * n) - 0.5 * a * (mR - mL);
}

void main()
{
	vec2 uv = v_vTexcoord;
	vec2 tx = vec2(u_texel.x, 0.0), ty = vec2(0.0, u_texel.y);

	if (u_mode < 5.5) {
		// GRAVITY, AS A REAL THIN DISK FEELS IT: phi = -sum of m / sqrt(d^2 + h^2) over all the mass (1/d^2 pull, softened by the disk's
		// thickness h). summed like a tree code (Barnes & Hut 1986) over the mass pyramid laid side by side in gm_BaseTexture (levels of
		// 128, 64, 32, 16, 8 cells, each the 2 x 2 average of the one below): a cell is OPENED (replaced by its 4 children) while it's
		// within 2 of this cell's own at its level, so near mass counts cell by cell and far mass by ever coarser averages, every bit
		// of mass exactly once. ~390 reads a cell; tested offline against the exact sum: ~1% error in the force
		vec2 P0 = floor(uv / u_texel);                                    // this gravity cell
		float phi = 0.0, x0 = 0.0, nl = u_gn, s = 1.0, e2 = u_geps * u_geps;
		for (int l = 0; l < 5; l++) {
			vec2 Pl = floor(P0 / s);
			if (l < 4) {
				vec2 Pp = floor(Pl * 0.5);
				for (int j = 0; j < 10; j++) for (int i = 0; i < 10; i++) {
					vec2 c = 2.0 * (Pp - 2.0) + vec2(float(i), float(j));       // the children of the opened parents
					if (l > 0 && abs(c.x - Pl.x) <= 2.0 && abs(c.y - Pl.y) <= 2.0) continue;   // (opened itself: counted finer)
					if (c.x < 0.0 || c.y < 0.0 || c.x >= nl || c.y >= nl) continue;
					float m = texture2D(gm_BaseTexture, (vec2(x0, 0.0) + c + 0.5) * u_texel).r * s * s;
					vec2 d = (c + 0.5) * s - (P0 + 0.5);
					phi -= m / sqrt(dot(d, d) + e2);
				}
			} else {
				for (int j = 0; j < 8; j++) for (int i = 0; i < 8; i++) {   // the top: every cell that wasn't opened
					vec2 c = vec2(float(i), float(j));
					if (abs(c.x - Pl.x) <= 2.0 && abs(c.y - Pl.y) <= 2.0) continue;
					float m = texture2D(gm_BaseTexture, (vec2(x0, 0.0) + c + 0.5) * u_texel).r * s * s;
					vec2 d = (c + 0.5) * s - (P0 + 0.5);
					phi -= m / sqrt(dot(d, d) + e2);
				}
			}
			x0 += nl; nl *= 0.5; s *= 2.0;
		}
		gl_FragColor = vec4(phi, 0.0, 0.0, 1.0);
		return;
	}
	vec2 n = uv / u_uvmax;
	vec2 p = n * u_size;                                              // in reference cells
	// the four walls of this cell
	vec3 fcE, fcW, fcN, fcS; vec2 fmE, fmW, fmN, fmS;
	wallFlux(uv,       tx, vec2(1.0, 0.0), fcE, fmE);             // east wall (between this cell and the next)
	wallFlux(uv - tx,  tx, vec2(1.0, 0.0), fcW, fmW);             // west wall
	wallFlux(uv,       ty, vec2(0.0, 1.0), fcS, fmS);             // the wall toward +y
	wallFlux(uv - ty,  ty, vec2(0.0, 1.0), fcN, fmN);             // the wall toward -y

	// what falls inside a black hole is gone (it fed)
	float eat = 1.0;
	for (int i = 0; i < 4; i++) {
		vec4 H = u_holes[i];
		if (H.w <= 0.0) continue;
		eat *= mix(1.0 - H.z * u_dt, 1.0, smoothstep(0.4, 1.0, length(p - H.xy) / H.w));
	}
	vec2 e2 = min(n, 1.0 - n);
	float edge = mix(1.0 - 0.05 * u_dt, 1.0, smoothstep(0.0, 0.03, min(e2.x, e2.y)));   // gas leaving the edge of her sky is gone
	float keep = u_keep * eat * edge;

	bool st2 = (u_stage > 0.5);
	vec3 c = gasAt(uv);
	if (u_mode < 10.5) {                                              // GAS: in minus out
		c -= u_dt * ((fcE - fcW) + (fcS - fcN));
		if (st2) c = 0.5 * max(texture2D(u_gas0, uv).rgb, vec3(0.0)) + 0.5 * c;
		gl_FragColor = vec4(max(c, vec3(0.0)) * (st2 ? keep : 1.0), 1.0);
		return;
	}
	// MOMENTUM: in minus out (fluxes are in real units: back to reference units), then gravity and shockwaves
	vec2 m = momAt(uv);
	m -= u_dt * ((fmE - fmW) + (fmS - fmN)) / u_k;
	float rho = rhoOf(c);
	vec2 gu = n * u_phimax;
	vec2 gp = vec2(texture2D(u_phi, gu + vec2(u_phitexel.x, 0.0)).x - texture2D(u_phi, gu - vec2(u_phitexel.x, 0.0)).x,
	               texture2D(u_phi, gu + vec2(0.0, u_phitexel.y)).x - texture2D(u_phi, gu - vec2(0.0, u_phitexel.y)).x) * 0.5;
	m += -rho * gp * u_grav * u_dt;                                   // gravity pulls every bit of gas down the well
	// the DARK MATTER HALO her galaxy sits in: an unseen mass whose pull keeps orbits fast far from the center (a flat rotation
	// curve, as every real galaxy shows). gas poured in already orbits at that speed, so the garden turns instead of collapsing
	vec2 hd = p - u_size * 0.5;
	m += -rho * u_halo.x * u_halo.x * hd / (dot(hd, hd) + u_halo.y * u_halo.y) * u_dt;
	// SUPERBUBBLES (stellar feedback): the hot gas inside a cluster's bubble pushes on whatever surrounds it with its pressure, so the
	// gas feels the slope of the bubble map as a force, -grad P (the same as any pressure, but this one comes from supernova energy,
	// not from the gas's own warmth). it lands on the bubble's rim: the shell is shoved outward and sweeps up the gas it meets
	vec2 fu = n * u_fbmax;
	float pxp = texture2D(u_fb, fu + vec2(u_fbtexel.x, 0.0)).r, pxm = texture2D(u_fb, fu - vec2(u_fbtexel.x, 0.0)).r;
	float pyp = texture2D(u_fb, fu + vec2(0.0, u_fbtexel.y)).r, pym = texture2D(u_fb, fu - vec2(0.0, u_fbtexel.y)).r;
	vec2 dfb = u_size * u_fbtexel / u_fbmax;                         // one feedback texel, in reference cells
	m -= vec2((pxp - pxm) / (2.0 * dfb.x), (pyp - pym) / (2.0 * dfb.y)) * u_fbscale * u_cs * u_cs * u_dt;
	for (int i = 0; i < 8; i++) {                                     // shockwaves: an outward shove, hardest in the middle
		vec4 K = u_kicks[i];
		if (K.w <= 0.0) continue;
		vec2 d = p - K.xy;
		float r = length(d);
		if (r < K.z && r > 0.01) m += rho * d / r * K.w * u_kick * (1.0 - r / K.z) * u_dt;
	}
	if (st2) {                                                        // stage 2: average with the start of the step
		m = 0.5 * texture2D(u_vel0, uv).xy + 0.5 * m;
		rho = 0.5 * rhoOf(max(texture2D(u_gas0, uv).rgb, vec3(0.0))) + 0.5 * rhoOf(max(c - u_dt * ((fcE - fcW) + (fcS - fcN)), vec3(0.0)));
	}
	if (rho < 0.0005) m = vec2(0.0);                                  // (empty space carries no momentum)
	float sp = length(m) / max(rho, 0.002);                           // the speed limit (VMAX)
	if (sp > VMAX) m *= VMAX / sp;
	gl_FragColor = vec4(m * (st2 ? keep : 1.0), 0.0, 1.0);
}
