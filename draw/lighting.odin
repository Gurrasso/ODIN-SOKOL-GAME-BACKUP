package draw

import "core:log"
import "../utils"
import sg "../../sokol/gfx"
import cutils "../utils/color"
import "../scenes"

LIGHTS_DATA_SIZE: int : 64

Light_id :: string

Light :: struct{
	enabled: bool,
	pos: Vec2,
	size: f32,
	color: sg.Color,
	intensity: f32,
	scene: scenes.Scene_id
}

init_light :: proc(
	pos: Vec2 = {0, 0}, 
	size: f32 = 1, 
	color: sg.Color = { 1,1,1,1 },
	intensity: f32 = 1,
	scene: scenes.Scene_id = scenes.NIL_SCENE_ID,
) -> Light_id{

	id := utils.generate_string_id()
	assert(!(id in g.lights))

	scene := scene
	if scene == scenes.NIL_SCENE_ID do scene = scenes.get_current_scene() 

	g.lights[id] = Light{
		true,
		pos,
		size,
		color,
		intensity,
		scene,
	}

	return id
}

delete_light :: proc(id: Light_id){
	assert(id in g.lights)
	delete_key(&g.lights, id)
}

//generates the lighting data that is to be passed to the fragment shader
generate_lighting_uniforms_data :: proc() -> ([LIGHTS_DATA_SIZE]Vec4, [LIGHTS_DATA_SIZE]Vec4){
	lights_transform_data: [LIGHTS_DATA_SIZE]Vec4
	lights_color_data: [LIGHTS_DATA_SIZE]Vec4
	lightsinc: int
	for id, val in g.lights{
		if !val.enabled || !scenes.scene_enabled(val.scene) do continue
		light_screen_pos := world_to_screen_pos(val.pos)
		lights_transform_data[lightsinc] = Vec4{light_screen_pos.x, light_screen_pos.y, world_to_screen_size(val.size), auto_cast len(g.lights)}
		lights_color_data[lightsinc] = cutils.sg_color_to_vec4(val.color)
		lights_color_data[lightsinc].a = val.intensity
		lightsinc += 1
	}

	return lights_transform_data, lights_color_data
}

// sets the brightness, 0.5 is bright 0 is completely dark
set_world_brightness :: proc(brightness: f32){
	g.world_brightness = brightness
}

toggle_light :: proc(id: Light_id){
	assert(id in g.lights)

	light := &g.lights[id]
	light.enabled = !light.enabled
}
