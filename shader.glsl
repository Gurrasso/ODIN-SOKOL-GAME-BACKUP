@header package main
@header import sg "./sokol/gfx"

@ctype mat4 Mat4

@vs vs
// vars
in vec3 pos;
in vec4 col;
in vec2 uv;

layout(binding=0) uniform vs_params {
    mat4 mvp;
};

out vec4 color;
out vec2 texcoord;

void main() {
    gl_Position = mvp * vec4(pos, 1);
    color = col;
    texcoord = uv;
}
@end

@fs fs
// vars
in vec4 color;
in vec2 texcoord;

layout(binding=0) uniform texture2D tex;
// sampler specifies things
layout(binding=0) uniform sampler smp;

out vec4 frag_color; 

void main() {
    frag_color = texture(sampler2D(tex, smp), texcoord) * color; 
}
@end

@program main vs fs