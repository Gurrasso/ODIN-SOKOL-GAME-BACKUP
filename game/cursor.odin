package game

import "../utils"
import "../draw"
import "../events"

// CURSOR

Cursor :: struct{
	transform: Transform,	
	world_transform: Transform,
	sensitivity: f32,
	filename: cstring,
	lookahead_distance: f32,
	lookahead: f32,
	sprite_id: Sprite_id,
}

init_cursor :: proc(){
	gs.cursor = Cursor{
		transform = Transform{
			pos = {1, 0},
			size = {24, 24}, // in pixels
		},
		//sensitivity
		sensitivity = 2,
		//cursor sprite path
		filename = "./src/assets/sprites/Cursor2.png",
		//how far the mouse movement affects the lookahead of the camera
		lookahead_distance = 10,
		//divides the lookahead distance to get the actual lookahead of the camera
		lookahead = 13,
	}

	gs.cursor.transform.size = draw.get_pixel_size_in_world(gs.cursor.transform.size, 0)

	gs.cursor.sprite_id = draw.init_sprite(
		filename = gs.cursor.filename, 
		transform = gs.cursor.transform,
		draw_priority = .cursor,
		tex_index = .no_lighting,
	)
}

update_cursor :: proc(){
	gs.cursor.transform.pos += (Vec2{events.mouse_move.x, -events.mouse_move.y} * gs.cursor.sensitivity) * utils.dt
	check_cursor_collision()
	gs.cursor.world_transform = Transform{
		pos = (draw.camera.position.xy-draw.camera.camera_shake.pos_offset) + gs.cursor.transform.pos,
		size = gs.cursor.transform.size,
		rot = gs.cursor.transform.rot,
	}
	if events.listen_screen_resized() do draw.update_sprite_size(size = gs.cursor.world_transform.size, id = gs.cursor.sprite_id)
	draw.update_sprite(transform = gs.cursor.world_transform, id = gs.cursor.sprite_id)
}

//check the cursor collision with the screen
check_cursor_collision :: proc (){

	transform := &gs.cursor.transform
	pos := &transform.pos
	size := transform.size

	collision_offset := Vec2 {size.x/2, size.y/2}
	screen_size_world := draw.get_screen_size_in_world(0)

	if pos.y + collision_offset.y > screen_size_world.y / 2{
		pos.y = (screen_size_world.y / 2) - collision_offset.y
	} else if pos.y - collision_offset.y < -(screen_size_world.y / 2){
		pos.y = -(screen_size_world.y / 2) + collision_offset.y
	}
	if pos.x + collision_offset.x > screen_size_world.x / 2{
		pos.x = (screen_size_world.x / 2) - collision_offset.x
	} else if pos.x - collision_offset.x < -(screen_size_world.x / 2){
		pos.x = -(screen_size_world.x / 2) + collision_offset.x
	}
}
