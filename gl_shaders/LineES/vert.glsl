#version 100

attribute vec2 vPos;
attribute vec3 vCol;

varying vec3 col;

void main()
{
    gl_Position = vec4(vPos.xy, 0.1, 1.0);
	col = vec3(0.0, 1.0, 0.0);//vCol;
}
