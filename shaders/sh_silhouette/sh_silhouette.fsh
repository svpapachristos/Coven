//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColor;

uniform vec3 u_color; // the flat color to paint sent in from gml

void main()
{  //keeps the sprites shape, but paint every pixel the same color
	float a = texture2D(gm_BaseTexture, v_vTexcoord).a * v_vColor.a;
    gl_FragColor = vec4(u_color, a);
}
