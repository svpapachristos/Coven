// passes the room position of each pixel to the fragment shader (sh_hex_orb works out its own pixel grid from it)
attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

varying vec2 v_world;
varying vec2 v_tex;       // the texture coordinate (the hex field surface, u_mode 4)

void main()
{
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position, 1.0);
	v_world = in_Position.xy;
	v_tex = in_TextureCoord;
}
