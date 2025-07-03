//
// TODO: seg fault when adding more in and out in vs and fs. Maybe try placing array at top of in/out
//
@header package user
@header import sg "../../sokol/gfx"

@ctype mat4 Mat4
@ctype vec4 Vec4

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
	vec4[16] lights_transform_data;
	vec4[16] lights_color_data;
	
};



out vec4 color;
out vec2 texcoord;
out vec4 bytes;

out vec4[16] lights;

vec2 world_to_screen_pos(vec2 pos){
	vec4 clippos = (projection_matrix*view_matrix) * vec4(pos.x, pos.y, 0, 1);
	vec2 ndcpos = vec2(clippos.x/clippos.w, (-clippos.y*reverse_screen_y)/ clippos.w);
	return (ndcpos.xy*0.5+0.5)*scz;
}

void main() {
	//model_view_projection matrix for the objects
	mat4 mvp = projection_matrix*view_matrix*model_matrix;
	color = col;
	texcoord = uv;
	bytes = bytes0;

	vec4[16] lights_pos0;

	for (int i = 0; i < 16; i ++){
		lights_pos0[i].xy = world_to_screen_pos(lights_transform_data[i].xy);
		lights_pos0[i].w = lights_transform_data[i].w;
		lights_pos0[i].z = lights_transform_data[i].z;
	}

	lights = lights_pos0;


	gl_Position = mvp*vec4(pos, 1);
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

in vec4[16] lights;

layout(binding=0) uniform texture2D tex;
// sampler specifies things
layout(binding=0) uniform sampler smp;

out vec4 frag_color; 

vec4 tex_col = vec4(1.0);

void update_lighting(){
	for(int i = 0; i < lights[0].w; i++){
		float dist = length(gl_FragCoord.xy-lights[i].xy);
		vec3 lightColor = vec3(1,1,1);
		float lightRadius = lights[i].z; // in screen pixels

		float attenuation = clamp(1.0 - dist / lightRadius, 0.0, 1.0);
  	attenuation = pow(attenuation, 2.0);

		tex_col += vec4((lightColor) * attenuation, 0);
	}
}

void main() {

	// unflips the images
	vec2 new_texcoord = texcoord;
	new_texcoord.y = 1 - new_texcoord.y;

	int tex_index = int(bytes.x * 255.0);

	if (tex_index == 0) {				// ALL NORMAL TEXTURES
		tex_col = texture(sampler2D(tex, smp), new_texcoord);


	} else if (tex_index == 1) {		// TEXT
		// this is text, it's only got the single .r channel so we stuff it into the alpha
		tex_col.a = texture(sampler2D(tex, smp), texcoord).r;
	}

	tex_col *= color;

	update_lighting();

	frag_color = tex_col;
}

@end

@program main vs fs
