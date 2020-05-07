#version 100

precision mediump float;

varying vec3 col;

void main()
{
    gl_FragColor = vec4(col, 1.0);
    //gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
}
