// 
//  TODO: 
// 

@header package main
@header import sg "../sokol/gfx"

@ctype mat4 Mat4

// :VERTEX SHADER

@vs vs

// vars
in vec3 pos;
in vec4 col;
in vec2 uv;
in vec4 bytes0;

layout(binding=0) uniform Uniforms_Data {
	mat4 mvp;
	vec2 scz;
};



out vec4 color;
out vec2 texcoord;
out vec4 bytes;
out vec2 screen_size;

void main() {
	gl_Position = mvp * vec4(pos, 1);
	color = col;
	texcoord = uv;
	bytes = bytes0;
	screen_size = scz;
}

@end

// :FRAGMENT SHADER

@fs fs
// vars
in vec4 color;
in vec2 texcoord;
in vec4 bytes;
in vec2 screen_size;

layout(binding=0) uniform texture2D tex;
// sampler specifies things
layout(binding=0) uniform sampler smp;

out vec4 frag_color; 

void main() {


	// unflips the images
	vec2 new_texcoord = texcoord;
	new_texcoord.y = 1 - new_texcoord.y;

	int tex_index = int(bytes.x * 255.0);

	vec4 tex_col = vec4(1.0);

	if (tex_index == 0) {				// ALL NORMAL TEXTURES
		tex_col = texture(sampler2D(tex, smp), new_texcoord);


	} else if (tex_index == 1) {		// TEXT
		// this is text, it's only got the single .r channel so we stuff it into the alpha
		tex_col.a = texture(sampler2D(tex, smp), texcoord).r;
	}

	tex_col *= color;

	frag_color = tex_col;
}

@end

@program main vs fs
