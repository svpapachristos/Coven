// A world object any witch can interact with. Placeholder art: a gray circle.
material = "stone";   // for the substance rules later (fire, frost, curse...)
r = 10;               // radius in pixels
vx = 0;
vy = 0;
grabbed = false;      // true while a witch's magic is holding it
hit_cd = 0;           // frames before it can hit again
is_bolt = false;      // true when this is a knot of curse energy fired as a bolt, not a rock
bolt_dmg = 20;
life = 600;           // safety: a shot that somehow never leaves the screen ends after this many frames
bolt_size = 1;        // how big a bolt draws (a bigger knot of curse is a bigger bolt)
is_lob = false;       // a lobbed ball of curse: arcs to lob_tx/lob_ty and bursts there
lob_x0 = 0; lob_y0 = 0; lob_tx = 0; lob_ty = 0;
lob_t = 0; lob_dur = 20;
boom_r = 80;          // blast radius when it bursts
mote_n = 0;           // how many of her motes ride in this shot (they flow back to her when it ends)
