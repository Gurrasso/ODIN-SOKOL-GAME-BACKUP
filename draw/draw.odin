package draw


import "base:intrinsics"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:os"

import sg "../../sokol/gfx"
// stb
import stbtt "vendor:stb/truetype"

import "../utils"
import cu "../utils/color"
import "../scenes"


Transform :: utils.Transform

DEFAULT_TRANSFORM :: utils.DEFAULT_TRANSFORM

// Handle multiple objects
Sprite_object :: struct{
	pos: Vec3,
	rot: Vec3,
	img: sg.Image,
	draw_priority: i32,
	vertex_buffer: sg.Buffer,
	size: Vec2,
	draw: bool,
	scene: scenes.Scene_id,
}

Sprite_object_group :: struct{
	objects: [dynamic]Sprite_object,
}

// =============
//   :DRAWING
// =============

Sprite_id :: string
Null_sprite_id :: ""

WHITE_IMAGE_PATH : cstring : "./src/assets/textures/WHITE_IMAGE.png"
WHITE_IMAGE : sg.Image

//kinda scuffed but works
init_rect :: proc(
	color: sg.Color = { 1,1,1,1 }, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, tex_index: Tex_indices = .default, 
	draw_priority: Draw_layers = .default,
	draw: bool = true,
	scene: scenes.Scene_id = scenes.NIL_SCENE_ID,
) -> string{
	return init_sprite_from_img(WHITE_IMAGE, transform, id, tex_index, draw_priority, color, draw, scene)	
}


init_sprite :: proc{
	init_sprite_from_filename,
	init_sprite_from_img,
}

init_sprite_from_img :: proc(
	img: sg.Image, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, 
	tex_index: Tex_indices = .default, 
	draw_priority: Draw_layers = .default, 
	color_offset: sg.Color = { 1,1,1,1 },
	draw: bool = true,
	scene: scenes.Scene_id = scenes.NIL_SCENE_ID,
) -> string{

	DEFAULT_UV :: Vec4 { 0,0,1,1 }

	id := id
	if id == Null_sprite_id do id = utils.generate_string_id()

	buffer := get_vertex_buffer(transform.size, color_offset, DEFAULT_UV, tex_index)

	if !(id in g.sprite_objects) do g.sprite_objects[id] = Sprite_object_group{}

	object_group := &g.sprite_objects[id]


	scene := scene
	if scene == scenes.NIL_SCENE_ID do scene = scenes.get_current_scene()   

	append(&object_group.objects, Sprite_object{
		utils.vec2_to_vec3(transform.pos),
		transform.rot,
		img,
		auto_cast draw_priority,
		buffer,
		transform.size,
		draw,
		scene,
	})

	return id
}


//proc for creating a new sprite on the screen and adding it to the objects
init_sprite_from_filename :: proc(
	filename: cstring, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, 
	tex_index: Tex_indices = .default, 
	draw_priority: Draw_layers = .default,
	color_offset: sg.Color = { 1,1,1,1 },
	draw: bool = true,
	scene: scenes.Scene_id = scenes.NIL_SCENE_ID,
) -> string{
	return init_sprite_from_img(get_image(filename), transform, id, tex_index, draw_priority, color_offset, draw, scene)	
}

//involves some code duplication
update_sprite :: proc{
	update_sprite_transform,
	update_sprite_transform_image,
	update_sprite_image,
	update_sprite_size,
}

update_sprite_transform_image :: proc(img: sg.Image, transform: Transform, id: Sprite_id){
	assert(id in g.sprite_objects)

	for &object in g.sprite_objects[id].objects{
		object = Sprite_object{
			utils.vec2_to_vec3(transform.pos),
			transform.rot,
			img,
			object.draw_priority,
			object.vertex_buffer,
			object.size,
			object.draw,
			object.scene
		}
	}
}

update_sprite_image :: proc(img: sg.Image, id: Sprite_id){
	assert(id in g.sprite_objects)

	for &object in g.sprite_objects[id].objects{

		object = Sprite_object{
			object.pos,
			object.rot,
			img,
			object.draw_priority,
			object.vertex_buffer,
			object.size,
			object.draw,
			object.scene
		}
	}
}

update_sprite_transform :: proc(transform: Transform, id: Sprite_id){

	assert(id in g.sprite_objects)

	for &object in g.sprite_objects[id].objects{

		object = Sprite_object{
			utils.vec2_to_vec3(transform.pos),
			transform.rot,
			object.img,
			object.draw_priority,
			object.vertex_buffer,
			object.size,
			object.draw,
			object.scene
		}
	}
}

update_sprite_size :: proc(size: Vec2, id: Sprite_id){

	assert(id in g.sprite_objects)

	for &object in g.sprite_objects[id].objects{
		//update the vertex buffer
		if object.size != size{
			update_vertex_buffer_size(object.vertex_buffer, size)
		}

		object.size = size
	}
}

//toggles if the sprite should be drawn
toggle_sprite_draw :: proc(id: Sprite_id){
	assert(id in g.sprite_objects)
	for &obj in g.sprite_objects[id].objects{
		obj.draw = !obj.draw
	}
}

toggle_text_object_draw :: proc(id: Sprite_id){
	assert(id in g.sprite_objects)
	obj := &g.text_objects[id]
	obj.draw = !obj.draw
}

//toggles if the sprite, animated sprite or text_object should be drawn
toggle_draw :: proc(id: Sprite_id){
	if (id in g.sprite_objects){
		for &obj in g.sprite_objects[id].objects{
			obj.draw = !obj.draw
		}
	} else if (id in g.animated_sprite_objects){
		obj := &g.animated_sprite_objects[id]
		obj.draw = !obj.draw
	}	else if id in g.text_objects{
		obj := &g.text_objects[id]
		obj.draw = !obj.draw
	}else do panic("Id not in sprite_objects or animated_sprite_objects, toggle_draw proc")
}

//	DRAW_LAYERS

//an enum that defines layers with different draw priority
Draw_layers :: enum i32{
	bottom = 0,
	background = 1,
	environment = 2,
	item = 3,
	default = 4,
	text = 5,
	ui = 6,
	cursor = 7,
	top = 8,
}

// TEX_INDICES

Tex_indices :: enum u8{
	default = 0,
	text = 1,
	no_lighting = 2, 
}


// ==========
//   :FONT			 (	 only a little scuffed	 )
// ==========

Char_object :: struct{
	pos: Vec3,
	rotation_pos_offset: Vec2,
	rot: Vec3,
	img: sg.Image,
	vertex_buffer: sg.Buffer,
}

Text_object :: struct{
	objects: [dynamic]Char_object,
	pos: Vec2,
	rot: Vec3,
	draw_priority: i32,
	draw: bool,
	scene: scenes.Scene_id
}

FONT_INFO :: struct {
	id: string,
	img: sg.Image,
	width: int,
	height: int,
	char_data: [char_count]stbtt.bakedchar,
}

font_bitmap_w :: 256
font_bitmap_h :: 256
char_count :: 256

//initiate the text and add it to our objects to draw it to screen
init_text :: proc(
	pos: Vec2, 
	scale: f32 = 0.05, 
	color: sg.Color = { 1,1,1,1 }, 
	text: string, 
	font_id: Sprite_id, 
	text_object_id: Sprite_id = "", 
	text_rot : f32 = 0, 
	draw_priority: Draw_layers = .text, 
	draw_from_center: bool = false,
	draw: bool = true,
	scene: scenes.Scene_id = scenes.NIL_SCENE_ID
) -> Sprite_id{
	using stbtt

	assert(font_id in g.fonts)

	assert(text_object_id in g.text_objects == false)
	
	text_object_id := text_object_id
	if text_object_id == ""{
		text_object_id = utils.generate_string_id()
	}

	rotation : Vec3 = {0, 0, text_rot}

	atlas_image : sg.Image
	font_data : [char_count]stbtt.bakedchar

	atlas_image = g.fonts[font_id].img
	font_data = g.fonts[font_id].char_data
	
	assert(atlas_image.id != 0, "failed to get font")
	using stbtt

	x: f32
	y: f32

	draw_offset: f32

	text_objects : [dynamic]Char_object

	for char in text {

		q: aligned_quad
		advance_x: f32
		advance_y: f32

		GetBakedQuad(&font_data[0], font_bitmap_w, font_bitmap_h, cast(i32)char - 32, &advance_x, &advance_y, &q, false)


		x += advance_x
		y += advance_y
				
		size := Vec2{ abs(q.x0 - q.x1), abs(q.y0 - q.y1) }
		
		offset_to_render_at := Vec2{x,y}
		
		uv := Vec4{ q.s0, q.t1, q.s1, q.t0 }

		xform := Matrix4(1)
		xform *= utils.xform_translate(pos)
		xform *= utils.xform_scale(Vec2{auto_cast scale, auto_cast scale})
		xform *= utils.xform_translate(offset_to_render_at)
		

		text_size := size*scale
		char_pos := Vec2{xform[3][0], xform[3][1]}

		//just to align the text properly
		if x - advance_x == 0{
			draw_offset = (text_size.x/2) - char_pos.x
		}
	
		char_pos.y += text_size.y/2
		char_pos.x += draw_offset

		char_obj := generate_char_object(char_pos, text_size, uv, color, atlas_image)


		append(&text_objects, char_obj)

	}

	append_text_object(
		rotation, 
		text_objects, 
		text_object_id, pos, 
		auto_cast draw_priority, 
		draw_from_center,
		draw,
		scene,
	)

	return text_object_id
}

append_text_object :: proc(
	rot: Vec3, 
	text_objects: [dynamic]Char_object, 
	text_object_id: Sprite_id, 
	text_pos: Vec2, 
	draw_priority: i32, 
	draw_from_center: bool,
	draw: bool,
	scene: scenes.Scene_id
){
	text_center : Vec2
	text_rot : Vec3 = rot

	//Figure out the center point of the text
	positions_total: Vec2
	for obj in text_objects{
		positions_total += Vec2{obj.pos.x, obj.pos.y}
	}
	text_center = positions_total/Vec2{f32(len(text_objects)), f32(len(text_objects))}

	//offset the text so its center is at the text pos if draw_from_center is set to true
	if draw_from_center {
		
		difference := text_center-text_pos
		text_center -= difference
		
		for &obj in text_objects{
			obj.pos -= Vec3{difference.x, difference.y, 0}
		}
	}	

	//rotation things
	if text_rot.z != 0{
		for &obj in text_objects{
			obj.rot = text_rot

			obj.rotation_pos_offset = utils.vec2_rotation(Vec2{obj.pos.x, obj.pos.y}, text_center, obj.rot.z)
		}
	}

	scene := scene
	if scene == scenes.NIL_SCENE_ID do scene = scenes.get_current_scene() 
	
	//add the text objects to the text objects
	g.text_objects[text_object_id] = Text_object{
		text_objects,
		text_center,
		text_rot,
		draw_priority,
		draw,
		scene,
	}

	//show the center point of the text
	//init_rect(color = sg_color(color3 = Vec3{255, 255, 255}), text_center, {0.05, 0.05}, "center")
}

//initiate font and add it to the g.fonts map with an id
init_font :: proc(font_path: string, font_h: i32 = 16, id: string) {
	using stbtt
	
	bitmap, _ := mem.alloc(font_bitmap_w * font_bitmap_h)
	font_height := font_h
	path := font_path
	ttf_data, err := os.read_entire_file(path)
	assert(ttf_data != nil, "failed to read font")

	font_char_data : [char_count]stbtt.bakedchar
	
	ret := BakeFontBitmap(raw_data(ttf_data), 0, auto_cast font_height, auto_cast bitmap, font_bitmap_w, font_bitmap_h, 32, char_count, &font_char_data[0])
	assert(ret > 0, "not enough space in bitmap")
	
	// setup font atlas so we can use it in the shader
	desc : sg.Image_Desc
	desc.width = auto_cast font_bitmap_w
	desc.height = auto_cast font_bitmap_h
	desc.pixel_format = .R8
	desc.data.subimage[0][0] = {ptr=bitmap, size=auto_cast (font_bitmap_w*font_bitmap_h)}
	sg_img := sg.make_image(desc)
	if sg_img.id == sg.INVALID_ID {
		log.debug("failed to make image")
	}

	store_font(font_bitmap_w, font_bitmap_h, sg_img, font_char_data, id)
}

//stores font data in g.fonts
store_font :: proc(
	w: int, 
	h: int, 
	sg_img: sg.Image, 
	font_char_data: [char_count]stbtt.bakedchar, 
	font_id: string
){
	assert(font_id in g.fonts == false)

	g.fonts[font_id] = FONT_INFO{
		id = font_id,
		img = sg_img,
		width = w,
		height = h,
		char_data = font_char_data
	}
}

//generate the Char_object
generate_char_object :: proc(
	pos2: Vec2, 
	size: Vec2, 
	text_uv: Vec4, 
	color_offset: sg.Color , 
	img: sg.Image, 
	tex_index: Tex_indices = .text
) -> Char_object{

	// vertices
	vertex_buffer := get_vertex_buffer(size, color_offset, text_uv, tex_index)
	char_obj := Char_object{
		{pos2.x, pos2.y, 0},
		{0, 0},
		{0, 0, 0},
		img,
		vertex_buffer,
	}

	return char_obj
}


// Updating text


update_text :: proc{
	update_text_object,
	update_text_rot,
	update_text_pos,
}

//not super efficient, might fix later
update_text_object :: proc(pos: Vec2, rot: f32, id: Sprite_id){
	update_text_rot(rot, id)
	update_text_pos(pos, id)

}

update_text_rot :: proc(rot: f32, id: Sprite_id){
	assert(id in g.text_objects)

	text_object := &g.text_objects[id]

	rotation := Vec3{0, 0, rot}

	text_object.rot = rotation

	for &obj in text_object.objects{

		obj.rot = rotation
		obj.rotation_pos_offset = utils.vec2_rotation(Vec2{obj.pos.x, obj.pos.y}, text_object.pos, obj.rot.z)
	}
}

update_text_pos :: proc(pos: Vec2, id: Sprite_id){
	assert(id in g.text_objects)

	text_object := &g.text_objects[id]


	motion := pos - text_object.pos
	text_object.pos = pos
	for &obj in text_object.objects{
		obj.pos += Vec3{motion.x, motion.y, 0}
	}
}


remove_sprite_object ::	proc(id: Sprite_id){
	assert(id in g.sprite_objects)

	delete_key(&g.sprite_objects, id)
}

remove_text_object :: proc(id: Sprite_id) {
	assert(id in g.text_objects)

	delete_key(&g.text_objects, id)
}

remove_object	:: proc(id: Sprite_id){
	if (id in g.sprite_objects){
		delete_key(&g.sprite_objects, id)
	} else if (id in g.animated_sprite_objects){
		delete_key(&g.animated_sprite_objects, id)
	}	else if id in g.text_objects{
		delete_key(&g.text_objects, id)
	}else do panic("Id not in sprite_objects or animated_sprite_objects, toggle_draw proc")
}

// Intersect a ray with a plane Z = target_z
ray_plane_intersect_z :: proc(ray_origin, ray_dir: Vec3, target_z: f32) -> Vec3 {
    t := (target_z - ray_origin.z) / ray_dir.z;
    return ray_origin + ray_dir * t
}
