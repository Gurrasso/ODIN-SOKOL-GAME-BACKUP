package draw

import "base:intrinsics"
import "core:log"

import sg "../../sokol/gfx"

import "../utils"
import cooldown "../utils/cooldown"

// ===================
//  :ANIMATED SPRITES
// ===================

// Handle multiple objects
Animated_sprite_object :: struct{
	pos: Vec3,
	rot: Vec3,
	size: Vec2,
	sprite_sheet: sg.Image,
	draw_priority: i32,
	vertex_buffer: sg.Buffer,
	sprite_count: uint,
	res_id: cooldown.Res_object,
	animation_speed: f32,
	animation_enabled: bool,
}

delete_animated_sprite :: proc(id: Sprite_id){
	assert(id in g.animated_sprite_objects)

	delete_key(&g.animated_sprite_objects, id)
}

update_animated_sprite :: proc{
	update_animated_sprite_transform,
}

update_animated_sprite_transform :: proc(transform: Transform, id: Sprite_id){
	assert(id in g.animated_sprite_objects)

	obj := &g.animated_sprite_objects[id]
	obj.pos = utils.vec2_to_vec3(transform.pos)
	obj.rot = transform.rot
}

update_animated_sprite_speed :: proc(id: Sprite_id, animation_speed: f32){
	assert(id in g.animated_sprite_objects)

	obj := &g.animated_sprite_objects[id]
	obj.animation_speed = animation_speed
}

update_animated_sprite_sheet :: proc{
	update_animated_sprite_sheet_from_img,
	update_animated_sprite_sheet_from_filename,
}

update_animated_sprite_sheet_from_filename :: proc(
	id: Sprite_id,
	sprite_sheet_filename: cstring,
	sprite_count: uint,
){
	update_animated_sprite_sheet_from_img(id, get_image(sprite_sheet_filename), sprite_count)
}

update_animated_sprite_sheet_from_img :: proc(
	id: Sprite_id,
	sprite_sheet: sg.Image,
	sprite_count: uint,
){
	assert(id in g.animated_sprite_objects)
	obj := &g.animated_sprite_objects[id]
	obj.sprite_sheet = sprite_sheet
	obj.sprite_count = sprite_count

	update_vertex_buffer_uv(obj.vertex_buffer, {0, 0, 1 / auto_cast obj.sprite_count, 1})
}

init_animated_sprite :: proc{
	init_animated_sprite_from_img,
	init_animated_sprite_from_filename,
}

init_animated_sprite_from_img :: proc(
	sprite_sheet: sg.Image, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, 
	tex_index: Tex_indices = .default, 
	draw_priority: Draw_layers = .default, 
	color_offset: sg.Color = { 1,1,1,1 },
	//how many seconds it takes for the animation to switch image
	animation_speed: f32 = 0.1,
	sprite_count: uint = 1,
) -> string{

	uv := Vec4 { 0,0, 1 / auto_cast sprite_count, 1 }

	id := id
	if id == Null_sprite_id do id = utils.generate_string_id()

	buffer := get_vertex_buffer(transform.size, color_offset, uv, tex_index)

	if !(id in g.animated_sprite_objects) do g.animated_sprite_objects[id] = Animated_sprite_object{}

	object_group := &g.sprite_objects[id]

	g.animated_sprite_objects[id] = Animated_sprite_object{
		utils.vec2_to_vec3(transform.pos),
		transform.rot,
		transform.size,
		sprite_sheet,
		auto_cast draw_priority,
		buffer,
		sprite_count,
		utils.generate_string_id(),
		animation_speed,
		false,
	}

	return id
}

init_animated_sprite_from_filename :: proc(
	sprite_sheet_filename: cstring, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, 
	tex_index: Tex_indices = .default, 
	draw_priority: Draw_layers = .default, 
	color_offset: sg.Color = { 1,1,1,1 },
	animation_speed: f32 = 0.1,
	sprite_count: uint = 1,
) -> string{
	return init_animated_sprite_from_img(load_image(sprite_sheet_filename), transform, id, tex_index, draw_priority, color_offset, animation_speed, sprite_count)
}

update_animated_sprites :: proc(){
	for id in g.animated_sprite_objects{
		obj := g.animated_sprite_objects[id]
		if !obj.animation_enabled do continue
		
		if cooldown.run_every_seconds(obj.animation_speed, obj.res_id){
			buffer := obj.vertex_buffer
			exists: bool
			for &buffer_data in g.vertex_buffers{
				if buffer_data.buffer == buffer{
					color_offset := buffer_data.color_data
					size := buffer_data.size_data
					tex_index := buffer_data.tex_index_data

					uvs := buffer_data.uv_data
					uvs.x += 1/f32(obj.sprite_count)
					uvs.z += 1/f32(obj.sprite_count)
					buffer_data.uv_data = uvs

					vertices := []Vertex_data {
						{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.y}, tex_index = tex_index },
						{ pos = {	(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.y}, tex_index = tex_index},
						{ pos = { -(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.w}, tex_index = tex_index},
						{ pos = {	(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.w}, tex_index = tex_index},
					}

					sg.update_buffer(buffer, utils.sg_range(vertices))

					exists = true
				}
			}
		}
	}
}

start_animation :: proc(id: Sprite_id){
	assert(id in g.animated_sprite_objects)

	obj := &g.animated_sprite_objects[id]
	
	obj.animation_enabled = true
}


stop_animation :: proc(id: Sprite_id){
	assert(id in g.animated_sprite_objects)

	obj := &g.animated_sprite_objects[id]
	update_vertex_buffer_uv(obj.vertex_buffer, {0, 0, 1 / auto_cast obj.sprite_count, 1})
	obj.animation_enabled = false
}
