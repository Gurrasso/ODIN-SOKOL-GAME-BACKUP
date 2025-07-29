
void update_lighting(){

	for(int i = 0; i < lights_transform_data[0].w; i++){
		float dist = length(gl_FragCoord.xy-lights_transform_data[i].xy);
		vec3 light_color = lights_color_data[i].xyz;
		float light_radius = lights_transform_data[i].z; // in screen pixels
		float light_intensity = lights_color_data[i].w;

		float attenuation = smoothstep(light_radius, 0, dist) * light_intensity;
		total_illumination += attenuation * light_color;
	}

	lit_col = mix_vec3((tex_col.rgb*world_brightness), tex_col.rgb, total_illumination);
}

