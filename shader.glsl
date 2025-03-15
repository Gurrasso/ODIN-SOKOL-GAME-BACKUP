// 
//  TODO:
// 

@header package main
@header import sg "../sokol/gfx"

@ctype mat4 Mat4

@vs vs
// vars
in vec3 pos;
in vec4 col;
in vec2 uv;
in vec4 bytes0;

layout(binding=0) uniform vs_params {
  mat4 mvp;
};

out vec4 color;
out vec2 texcoord;
out vec4 bytes;

void main() {
  gl_Position = mvp * vec4(pos, 1);
  color = col;
  texcoord = uv;
  bytes = bytes0;
}
@end

@fs fs
// vars
in vec4 color;
in vec2 texcoord;
in vec4 bytes;

layout(binding=0) uniform texture2D tex;
// sampler specifies things
layout(binding=0) uniform sampler smp;

out vec4 frag_color; 

void main() {

  int tex_index = int(bytes.x * 255.0);

  vec4 tex_col = vec4(1.0);
  if (tex_index == 0) {
        tex_col = texture(sampler2D(tex, smp), texcoord); 
  } else if (tex_index == 1) {
        // this is text, it's only got the single .r channel so we stuff it into the alpha
    tex_col.a = texture(sampler2D(tex, smp), texcoord).r;
  }

  frag_color = tex_col;
  frag_color *= color;
}
@end

@program main vs fs
