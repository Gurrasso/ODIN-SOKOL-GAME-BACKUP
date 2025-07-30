package game

import "../draw"
import cu "../utils/color"
import "../events"
import "../scenes"

// BACKGROUND

//takes in a background color as a vec3
init_background :: proc(color: Vec3 = {255, 255, 255}){
	gs.background_sprite = draw.init_rect(
		color = cu.sg_color(color),
		transform = Transform{size = draw.get_screen_size_in_world(0)}, 
		draw_priority = .background,
		scene = scenes.GLOBAL_SCENE_ID,
	)
}

update_background :: proc(){
	background_counter_rotation: Vec3
	if draw.camera.rotation != 0 do background_counter_rotation = {0, 0, 360 - to_degrees(draw.camera.rotation)}
	
	draw.update_sprite(
		transform = Transform{pos = draw.camera.position.xy, rot = background_counter_rotation}, 
		id = gs.background_sprite
	)

	if events.listen_screen_resized() do draw.update_sprite_size(draw.get_screen_size_in_world(0), gs.background_sprite)
}
