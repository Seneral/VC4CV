#version 100

attribute vec3 vPos;
attribute vec3 vCol;

varying vec3 col;

void main()
{
    gl_Position = vec4(vPos.xy, 0.5, 1.0);
	col = vCol;
}
