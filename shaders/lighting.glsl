

void update_lighting(){
	for(int i = 0; i < lights_transform_data[0].w; i++){
		float dist = length(gl_FragCoord.xy-lights_transform_data[i].xy);
		vec3 light_color = lights_color_data[i].xyz;
		float light_radius = lights_transform_data[i].z; // in screen pixels

		float attenuation = smoothstep(1, 0, dist/light_radius);
		//light intensity is inside the alpha component of the color since it doesnt do anything
		attenuation *= lights_color_data[i].w/(world_brightness+1);

		lit_col += (tex_col.rgb*(light_color*attenuation+world_brightness));
		lit_col = clamp(lit_col, 0.0, 1);
	}
}



