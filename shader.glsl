// 
//  TODO: having some issues on window resize 
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
	mat4 model_matrix;
	mat4 view_matrix;
	mat4 projection_matrix;
	vec2 scz;
	int reverse_screen_y;
};



out vec4 color;
out vec2 texcoord;
out vec4 bytes;
out vec2 screen_size;
out vec2 light;

void main() {
	//model_view_projection matrix for the objects
	mat4 mvp = projection_matrix*view_matrix*model_matrix;
	gl_Position = mvp*vec4(pos, 1);
	color = col;
	texcoord = uv;
	bytes = bytes0;
	screen_size = scz;

	vec4 clippos = ((projection_matrix*view_matrix) * vec4(1, 2, 0, 1));
	vec2 ndcpos = vec2(clippos.x/clippos.w, (-clippos.y*reverse_screen_y)/ clippos.w);
	light = (ndcpos.xy*0.5+0.5)*scz;
}

@end

// :FRAGMENT SHADER

@fs fs

//Utils

@include shader_utils.glsl

// vars
in vec4 color;
in vec2 texcoord;
in vec4 bytes;
in vec2 screen_size;
in vec2 light;

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

	float dist = length(gl_FragCoord.xy-light.xy);
	vec3 lightColor = rgb_to_sg_color(vec3(253, 255, 199));
	float lightRadius = 400; // in screen pixels

	float attenuation = clamp(1.0 - dist / lightRadius, 0.0, 1.0);
  attenuation = pow(attenuation, 2.0);

	tex_col += vec4((lightColor) * attenuation, 0);


	frag_color = tex_col;
}

@end

@program main vs fs
