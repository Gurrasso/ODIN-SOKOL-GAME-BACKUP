package draw

import "../utils"
import sg "../../sokol/gfx"

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
