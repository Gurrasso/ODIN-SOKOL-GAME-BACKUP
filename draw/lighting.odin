package draw

import "core:log"
import "../utils"
import sg "../../sokol/gfx"
import cutils "../utils/color"

Light_id :: string

Light :: struct{
	pos: Vec2,
	size: f32,
	color: sg.Color,
}

init_light :: proc(
	pos: Vec2 = {0, 0}, 
	size: f32 = 1, 
	color: sg.Color = { 1,1,1,1 }
) -> Light_id{

	id := utils.generate_string_id()
	assert(!(id in g.lights))

	g.lights[id] = Light{
		pos,
		size,
		color,
	}

	return id
}

//generates the lighting data that is to be passed to the fragment shader
generate_lighting_uniforms_data :: proc() -> ([LIGHTS_DATA_SIZE]Vec4, [LIGHTS_DATA_SIZE]Vec4){
	lights_transform_data: [LIGHTS_DATA_SIZE]Vec4
	lights_color_data: [LIGHTS_DATA_SIZE]Vec4
	lightsinc: int
	for id, val in g.lights{
		light_screen_pos := world_to_screen_pos(val.pos)
		lights_transform_data[lightsinc] = Vec4{light_screen_pos.x, light_screen_pos.y, world_to_screen_size(val.size), auto_cast len(g.lights)}
		lights_color_data[lightsinc] = cutils.sg_color_to_vec4(val.color)
		lightsinc += 1
	}

	return lights_transform_data, lights_color_data
}
