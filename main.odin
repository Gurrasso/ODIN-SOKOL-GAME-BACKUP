#+feature dynamic-literals
package main



/*
	TODO: 
	
	use hashmaps for things like the fonts?, 
	fix updating text size, 
	fix text being weird when changing z pos or perspective,


	sprite sheet rendering, 
	animation system thing?, 
	
	tilemap and other environment/map things,
	lighting(normalmaps),
	
		-camera shake,
	
	player movement acceleration and deceleration,
	collisions,
	
	custom cursor,
		-make it so cursor cant go outside screen,
	
*/



// 
//  IMPORTS
//
import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/ease"
import "core:mem"
import "core:os"
import "core:sort"
// stb
import stbi "vendor:stb/image"
import stbtt "vendor:stb/truetype"
// sokol imports
import sapp "../sokol/app"
import shelpers "../sokol/helpers"
import sg "../sokol/gfx"
import sglue "../sokol/glue"

to_radians :: linalg.to_radians
Matrix4 :: linalg.Matrix4f32;

//global var for context
default_context: runtime.Context

//define own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

//draw call data
Draw_data :: struct{
	m: Matrix4,
	b: sg.Bindings,
	priority: i32,
}

// the vertex data
Vertex_Data :: struct{
	pos: Vec3,
	col: sg.Color,
	uv: Vec2,
	tex_index: u8,
}

// Handle multiple objects
Object :: struct{
	pos: Vec3,
	rot: Vec3,
	img: sg.Image,
	vertex_buffer: sg.Buffer,
	id: cstring,
	priority: i32,
}

Spring :: struct{
	//where the spring is attached
	anchor: Vec2,
	//where the spring end is at
	position: Vec2,
	//the velocity which affects the springs position
	velocity: Vec2,
	//at which length the spring wants to be at
	restlength: f32,
	//the "springyness"
	force: f32,
	//how much the springs velocity depletes ( how bouncy the spring is )
	depletion: f32,
}

//global vars
Globals :: struct {
	should_quit: bool,
	shader: sg.Shader,
	pipeline: sg.Pipeline,
	index_buffer: sg.Buffer,
	objects: [dynamic]Object,
	sampler: sg.Sampler,
	rotation: Vec3,
	camera: Camera,
	player: Player,
	fonts: [dynamic]FONT_INFO,
	text_objects: [dynamic]Text_object,
	cursor: Cursor,
	runtime: f32,
}
g: ^Globals

// 
// MAIN!!!!!
// 

main :: proc(){
	//logger
	context.logger = log.create_console_logger()
	default_context = context


	//sokol app
	sapp.run({
		width = 1000,
		height = 1000,
		window_title = "ODIN-SOKOL-GAME",

		allocator = sapp.Allocator(shelpers.allocator(&default_context)),
		logger = sapp.Logger(shelpers.logger(&default_context)),
		icon = { sokol_default = true },

		init_cb = init_cb,
		frame_cb = frame_cb,
		cleanup_cb = cleanup_cb,
		event_cb = event_cb,
	})
}

//
// SOKOL PROCS
//

//initialization
init_cb :: proc "c" (){
	context = default_context

	//setup for the sokol graphics
	sg.setup({
		environment = shelpers.glue_environment(),
		allocator = sg.Allocator(shelpers.allocator(&default_context)),
		logger = sg.Logger(shelpers.logger(&default_context)),
	})

	//white image for scuffed rect rendering
	WHITE_IMAGE = load_image(WHITE_IMAGE_PATH)

	//the globals
	g = new(Globals)

	init_game_state()
		
	//make the shader and pipeline
	g.shader = sg.make_shader(main_shader_desc(sg.query_backend()))
	g.pipeline = sg.make_pipeline({
		shader = g.shader,
		layout = {
			//different attributes
			attrs = {
				ATTR_main_pos = { format = .FLOAT3 },
				ATTR_main_col = { format = .FLOAT4 },
				ATTR_main_uv = { format = .FLOAT2 },
				ATTR_main_bytes0 = { format = .UBYTE4N },
			}
		},

		// specify that we want to use index buffer
		index_type = .UINT16,
		//make it so objects draw based on distance from camera
		depth = {
			write_enabled = true,
			compare = .LESS_EQUAL
		}
	})


	

	// indices
	indices := []u16 {
		0, 1, 2,
		2, 1, 3,
	}
	// index buffer
	g.index_buffer = sg.make_buffer({
		type = .INDEXBUFFER,
		data = sg_range(indices),
	})

	//create the sampler
	g.sampler = sg.make_sampler({})
}



//cleanup
cleanup_cb :: proc "c" (){
	context = default_context

	//destroy all the things we init
	for obj in g.objects{
		sg.destroy_buffer(obj.vertex_buffer)
		sg.destroy_image(obj.img)
	}
	sg.destroy_sampler(g.sampler)
	sg.destroy_buffer(g.index_buffer)
	sg.destroy_pipeline(g.pipeline)
	sg.destroy_shader(g.shader)

	//free the global vars
	free(g)


	//shut down sokol graphics
	sg.shutdown()
}

//Every frame
frame_cb :: proc "c" (){
	context = default_context

	//exit the program
	if(g.should_quit){
		quit_game()
		return
	}

	//deltatime
	dt := f32(sapp.frame_duration())

	update_game_state(dt)

	//  projection matrix(turns normal coords to screen coords)
	p := linalg.matrix4_perspective_f32(70, sapp.widthf() / sapp.heightf(), 0.0001, 1000)
	//view matrix
	v := linalg.matrix4_look_at_f32(g.camera.position, g.camera.target, {0, 1, 0})

	sg.begin_pass({ swapchain = shelpers.glue_swapchain()})

	//apply the pipeline to the sokol graphics
	sg.apply_pipeline(g.pipeline)

	camera_zrotation := g.camera.rotation

	draw_data: [dynamic]Draw_data

	//do things for all text objects
	for text_object in g.text_objects {
		for obj in text_object.objects{
			//matrix

			pos := obj.pos + Vec3{obj.rotation_pos_offset.x, obj.rotation_pos_offset.y, 0}
			m := linalg.matrix4_translate_f32(pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.y), to_radians(obj.rot.x), to_radians(obj.rot.z) + camera_zrotation)
	
	
			//apply the bindings(something that says which things we want to draw)
			b := sg.Bindings {
				vertex_buffers = { 0 = obj.vertex_buffer },
				index_buffer = g.index_buffer,
				images = { IMG_tex = obj.img },
				samplers = { SMP_smp = g.sampler },
			}

			append(&draw_data, Draw_data{
				m = m,
				b = b,
				priority = text_object.priority,
			})
		}
	}

	//do things for all objects
	for obj in g.objects {
		//matrix
		m := linalg.matrix4_translate_f32(obj.pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.y), to_radians(obj.rot.x), to_radians(obj.rot.z) + camera_zrotation)

		//apply the bindings(something that says which things we want to draw)
		b := sg.Bindings {
			vertex_buffers = { 0 = obj.vertex_buffer },
			index_buffer = g.index_buffer,
			images = { IMG_tex = obj.img },
			samplers = { SMP_smp = g.sampler },
		}

		append(&draw_data, Draw_data{
			m = m,
			b = b,
			priority = obj.priority,
		})
		
	}

	//sort the array based on priority
	sort.quick_sort_proc(draw_data[:], compare_draw_data_priority)

	for drt in draw_data {
		sg.apply_bindings(drt.b)

		//apply uniforms
		sg.apply_uniforms(UB_vs_params, sg_range(&Vs_Params{
			mvp = p * v * drt.m
		}))

		//drawing
		sg.draw(0, 6, 1)
	}

	sg.end_pass()

	sg.commit()
}

//
// IMAGE THINGS
//


//  proc for loading an image from a file
load_image :: proc(filename: cstring) -> sg.Image{
	w, h: i32
	pixels := stbi.load(filename, &w, &h, nil, 4)
	assert(pixels != nil)

	image := sg.make_image({
		width = w,
		height = h,
		pixel_format = .RGBA8,
		data = {
			subimage = {
				0 = {
					0 = {
						ptr = pixels,
						size = uint(w * h * 4)
					}
				}
			}
		}
	})
	stbi.image_free(pixels)

	return image
}

//var for mouse movement
mouse_move: Vec2

//stores the states for all keys
key_down: #sparse[sapp.Keycode]bool
single_key_up: #sparse[sapp.Keycode]bool
single_key_down: #sparse[sapp.Keycode]bool

//Events
event_cb :: proc "c" (ev: ^sapp.Event){
	context = default_context

	#partial switch ev.type{
		case .MOUSE_MOVE:
			mouse_move += {ev.mouse_dx, ev.mouse_dy}
		case .KEY_DOWN:

			if key_down[ev.key_code] == false && single_key_down[ev.key_code] == false{
				single_key_down[ev.key_code] = true
			}

			key_down[ev.key_code] = true

			single_key_up[ev.key_code] = false
		case .KEY_UP:
			if !key_down[ev.key_code] == false && single_key_up[ev.key_code] == false{
				single_key_up[ev.key_code] = true
			}

			key_down[ev.key_code] = false

			single_key_down[ev.key_code] = false
	}
}

//
// UTILS
//

//used to sort the draw data based on priority
compare_draw_data_priority :: proc(drt: Draw_data, drt2: Draw_data) -> int{
	return int(drt.priority-drt2.priority)
}

//sg range utils
sg_range :: proc {
	sg_range_from_struct,
	sg_range_from_slice,
}

//proc for the sokol graphics range from struct(doesnt work with slices)
sg_range_from_struct :: proc(s: ^$T) -> sg.Range where intrinsics.type_is_struct(T) {
	return { 
		ptr = s, 
		size = size_of(T)
	 }
}

//function for the sokol graphics range from slice
sg_range_from_slice :: proc(s: []$T) -> sg.Range{
	return { 
		ptr = raw_data(s), 
		size = len(s) * size_of(s[0])
	 }
}

//color utils

sg_color :: proc {
	sg_color_from_rgb,
	sg_color_from_rgba,
}


sg_color_from_rgba :: proc (color: Vec4) -> sg.Color{

	new_color := sg.Color{color.r/255, color.g/255, color.b/255, color.a/255}

	return new_color

}

sg_color_from_rgb :: proc (color: Vec3) -> sg.Color{

	new_color := sg.Color{color.r/255, color.g/255, color.b/255, 1}

	return new_color

}

//buffer util

get_vertex_buffer :: proc(size: Vec2, color_offset: sg.Color, uvs: Vec4, current_tex_index: u8) -> sg.Buffer{
	vertices := []Vertex_Data {
		{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.y}, tex_index = current_tex_index  },
		{ pos = {  (size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.y}, tex_index = current_tex_index  },
		{ pos = { -(size.x/2),  (size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.w}, tex_index = current_tex_index  },
		{ pos = {  (size.x/2),  (size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.w}, tex_index = current_tex_index  },
	}
	buffer := sg.make_buffer({ data = sg_range(vertices)})

	return buffer
}

//key press utils

listen_key_single_up :: proc(keycode: sapp.Keycode) -> bool{
	if single_key_up[keycode] {
		single_key_up[keycode] = false
		return true	
	} else{
		return false
	}
}

listen_key_single_down :: proc(keycode: sapp.Keycode) -> bool{
	if single_key_down[keycode] {
		single_key_down[keycode] = false
		return true	
	} else{
		return false
	}

}

listen_key_down :: proc(keycode: sapp.Keycode) -> bool{
	if key_down[keycode] {
		return true	
	} else{
		return false
	}
}

listen_key_up :: proc(keycode: sapp.Keycode) -> bool{
	if key_down[keycode] == false {
		return true	
	} else{
		return false
	}
}

//xform utils

xform_translate :: proc(pos: Vec2) -> Matrix4 {
	return linalg.matrix4_translate(Vec3{pos.x, pos.y, 0})
}
xform_rotate :: proc(angle: f32) -> Matrix4 {
	return linalg.matrix4_rotate(to_radians(angle), Vec3{0,0,1})
}
xform_scale :: proc(scale: Vec2) -> Matrix4 {
	return linalg.matrix4_scale(Vec3{scale.x, scale.y, 1});
}

//removing objects

remove_object ::  proc(id: cstring){
	for i := 0; i < len(g.objects); i += 1 {
		if g.objects[i].id == id{
			ordered_remove(&g.objects, i)
			i-=1
		}
	}
}

remove_text_object :: proc(id: cstring) {
	for i := 0; i < len(g.text_objects); i += 1 {
		if g.text_objects[i].id == id{
			ordered_remove(&g.text_objects, i)
			i-=1
		}
	}
}

//rotation of objects around center point

vec2_rotation :: proc(objpos: Vec2, centerpos: Vec2, rot: f32) -> Vec2 {
	obj_xform := xform_rotate(-rot)
	obj_xform *= xform_translate(objpos - centerpos)

	new_pos2d := Vec2{obj_xform[3][0], obj_xform[3][1]} + Vec2{centerpos.x, -centerpos.y}
	return Vec2{new_pos2d.x, -new_pos2d.y} - objpos
}

//math util

get_vector_magnitude :: proc(vec: Vec2) -> f32{
	magv := math.sqrt(vec.x * vec.x  + vec.y * vec.y)
	return magv
}

//spring physics
update_spring :: proc(spring: ^Spring, dt: f32){

	force := spring.position - spring.anchor
	x := get_vector_magnitude(force) - spring.restlength
	force = linalg.normalize0(force)
	force *= -1 * spring.force * x
	spring.velocity += force * dt
	spring.position += spring.velocity
	spring.velocity *= spring.depletion * dt
	
}

//spring physics
update_weird_spring :: proc(spring: ^Spring, dt: f32){

	force := spring.position - spring.anchor
	x := get_vector_magnitude(force) - spring.restlength
	force = linalg.normalize0(force)
	force *= -1 * spring.force * x
	force *= dt
	spring.velocity = force
	spring.position += spring.velocity
}

//
// DRAWING
//

WHITE_IMAGE_PATH : cstring = "./source/assets/textures/WHITE_IMAGE.png"
WHITE_IMAGE : sg.Image

//kinda scuffed but works
init_rect :: proc(color_offset: sg.Color = { 1,1,1,1 }, pos2: Vec2 = { 0,0 }, size: Vec2 = { 0.5,0.5 }, id: cstring = "rect", current_tex_index: u8 = 0, priority: i32 = 1){

	DEFAULT_UV :: Vec4 { 0,0,1,1 }

	vertex_buffer := get_vertex_buffer(size, color_offset, DEFAULT_UV, current_tex_index)

	append(&g.objects, Object{
		{pos2.x, pos2.y, 0},
		{0, 0, 0},
		WHITE_IMAGE,
		vertex_buffer,
		id,
		priority,
	})
}


//proc for updating objects
update_object :: proc(pos2: Vec2, rot3: Vec3 = { 0,0,0 }, id: cstring){
	for &obj in g.objects{
		if obj.id == id{
			obj.pos = {pos2.x, pos2.y, 0}
			obj.rot = {rot3.x, rot3.y, rot3.z}
		}
	}
}


//proc for creating a new sprite on the screen and adding it to the objects
init_sprite :: proc(filename: cstring, pos2: Vec2 = {0,0}, size: Vec2 = {0.5, 0.5}, id: cstring = "sprite", current_tex_index: u8 = 0, priority: i32 = 1){


	//color offset
	WHITE :: sg.Color { 1,1,1,1 }

	DEFAULT_UV :: Vec4 { 0,0,1,1 }


	vertex_buffer := get_vertex_buffer(size, WHITE, DEFAULT_UV, current_tex_index)


	append(&g.objects, Object{
		{pos2.x, pos2.y, 0},
		{0, 0, 0},
		load_image(filename),
		vertex_buffer,
		id,
		priority,
	})
}

//proc for updating sprites
update_sprite :: proc(pos2: Vec2, rot3: Vec3 = { 0,0,0 }, id: cstring){
	for &obj in g.objects{
		if obj.id == id{
			obj.pos = {pos2.x, pos2.y, 0}
			obj.rot = {rot3.x, rot3.y, rot3.z}
		}
	}
}



//
// FONT       (   a bit scuffed rn, gonna fix later(probably not)   )
//

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
	id: cstring,
	priority: i32,
}

FONT_INFO :: struct {
	id: cstring,
	img: sg.Image,
	width: int,
	height: int,
	char_data: [char_count]stbtt.bakedchar,
}

font_bitmap_w :: 256
font_bitmap_h :: 256
char_count :: 96

//initiate the text and add it to our objects to draw it to screen
init_text :: proc(pos: Vec2, scale: f32 = 0.05, color: sg.Color = { 1,1,1,1 }, text: string, font_id: cstring, text_object_id: cstring = "text", text_rot : f32 = 0, priority: i32 = 1) {
	using stbtt

	rotation : Vec3 = {0, 0, text_rot}

	atlas_image : sg.Image
	font_data : [char_count]stbtt.bakedchar

	for font in g.fonts {
		if font_id == font.id {
			atlas_image = font.img
			font_data = font.char_data
		}
	}

	assert(atlas_image.id != 0, "failed to get font")
	using stbtt

	x: f32
	y: f32

	text_objects : [dynamic]Char_object

	for char in text {
		
		advance_x: f32
		advance_y: f32
		q: aligned_quad

		GetBakedQuad(&font_data[0], font_bitmap_w, font_bitmap_h, cast(i32)char - 32, &advance_x, &advance_y, &q, false)
		
		
		size := Vec2{ abs(q.x0 - q.x1), abs(q.y0 - q.y1) }
		
		bottom_left := Vec2{ q.x0, -q.y1 }
		top_right := Vec2{ q.x1, -q.y0 }

		assert(bottom_left + size == top_right)
		
		offset_to_render_at := Vec2{x,y} + bottom_left
		
		uv := Vec4{ q.s0, q.t1, q.s1, q.t0 }

		xform := Matrix4(1)
		xform *= xform_translate(pos)
		xform *= xform_scale(Vec2{auto_cast scale, auto_cast scale})
		xform *= xform_translate(offset_to_render_at)

		text_size := size*scale
		char_pos := Vec2{xform[3][0], xform[3][1]}

		char_obj := generate_char_object(char_pos, text_size, uv, color, atlas_image)
		
		append(&text_objects, char_obj)

		x +=  advance_x
		y += -advance_y
	}

	append_text_object(rotation, text_objects, text_object_id, pos, priority)
	
}

append_text_object :: proc(rot: Vec3, text_objects: [dynamic]Char_object, text_object_id: cstring, text_pos: Vec2, priority: i32){
	text_center : Vec2
	text_rot : Vec3 = rot

	//Figure out the center point of the text
	positions_total := Vec2{ 0,0 }
	for obj in text_objects{
		positions_total += Vec2{obj.pos.x, obj.pos.y}
	}
	text_center = positions_total/Vec2{f32(len(text_objects)), f32(len(text_objects))}
	
	//make the center y coord not be the center of all the positions. Instead it is the designated y coord for the text
	text_center.y = text_pos.y

	//offset the text so its center is at the text pos
	difference := text_center-text_pos
	text_center = text_pos
	for &obj in text_objects{
		obj.pos -= Vec3{difference.x, difference.y, 0}
	}


	//rotation things
	if text_rot.z != 0{
		for &obj in text_objects{
			obj.rot = text_rot

			obj.rotation_pos_offset = vec2_rotation(Vec2{obj.pos.x, obj.pos.y}, text_center, obj.rot.z)
		}
	}

	//add the text objects to the text objects
	append(&g.text_objects, Text_object{
		text_objects,
		text_center,
		text_rot,
		text_object_id,
		priority,
	})

	//show the center point of the text
	//init_rect(sg_color(Vec3{255, 255, 255}), text_center, {0.05, 0.05}, "center")
}

//initiate font and add it to the g.fonts
init_font :: proc(font_path: string, font_h: i32 = 16, id: cstring) {
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
store_font :: proc(w: int, h: int, sg_img: sg.Image, font_char_data: [char_count]stbtt.bakedchar, font_id: cstring){
	append(&g.fonts, FONT_INFO{
		id = font_id,
		img = sg_img,
		width = w,
		height = h,
		char_data = font_char_data
	})
}

//generate the Char_object
generate_char_object :: proc(pos2: Vec2, size: Vec2, text_uv: Vec4, color_offset: sg.Color , img: sg.Image, current_tex_index: u8 = 1) -> Char_object{

	// vertices
	vertex_buffer := get_vertex_buffer(size, color_offset, text_uv, current_tex_index)

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
update_text_object :: proc(pos: Vec2, rot: f32, id: cstring){
	update_text_rot(rot, id)
	update_text_pos(pos, id)

}

update_text_rot :: proc(rot: f32, id: cstring){

	rotation := Vec3{0, 0, rot}

	for &text_object in g.text_objects{
		if text_object.id == id{

			text_object.rot = rotation

			for &obj in text_object.objects{

				obj.rot = rotation
				obj.rotation_pos_offset = vec2_rotation(Vec2{obj.pos.x, obj.pos.y}, text_object.pos, obj.rot.z)
			}
		}
	}
}

update_text_pos :: proc(pos: Vec2, id: cstring){

	for &text_object in g.text_objects{
		if text_object.id == id{
			motion := pos - text_object.pos
			text_object.pos = pos
			for &obj in text_object.objects{
				obj.pos += Vec3{motion.x, motion.y, 0}
			}
		}
	}

}


//
// GAME
//

//test text vars
test_text_rot: f32
test_text_rot_speed: f32 = 120

init_game_state :: proc(){

	sapp.show_mouse(false)
	sapp.lock_mouse(true)


	init_player()

	init_camera()


	init_font(font_path = "./source/assets/fonts/MedodicaRegular.otf", id = "font1", font_h = 32)
	
	init_text(text_object_id = "test_text", text_rot = test_text_rot, pos = {0, 1}, scale = 0.03, text = "TEST", color = sg_color(Vec3{138,43,226}), font_id = "font1")
	
	init_cursor()
}

update_game_state :: proc(dt: f32){

	event_listener()
	// move_camera_3D(dt)
	update_player(dt)

	update_camera(dt)


	test_text_rot += test_text_rot_speed * dt
	update_text(test_text_rot, "test_text")

	update_cursor(dt)

	mouse_move = {}
	g.runtime += dt
}

//proc for quiting the game
quit_game :: proc(){
	sapp.quit()
}

// all the event based checks (eg keyboard inputs)
event_listener :: proc(){
	//Exit program if you hit escape
	if listen_key_down(.ESCAPE) {
		g.should_quit = true
	}

	//fullscreen on F11
	if listen_key_single_down(.F11) {
		sapp.toggle_fullscreen()
	}

	if listen_key_down(.F){
		g.camera.camera_shake.trauma = 1.3
	}
}

//check the player collision
check_collision :: proc (){

	wierd_const := (7.6/8)*g.camera.position.z
	collision_offset := Vec2 {g.player.size.x/2, g.player.size.y/2}
	screen_size_from_origin := Vec2 {sapp.widthf()/2, sapp.heightf()/2}
	pixels_per_coord: f32 = sapp.heightf()/wierd_const



	if g.player.pos.y + collision_offset.y > screen_size_from_origin.y/ pixels_per_coord{
		g.player.pos.y = (screen_size_from_origin.y / pixels_per_coord) - collision_offset.y
	} else if g.player.pos.y - collision_offset.y < -(screen_size_from_origin.y / pixels_per_coord){
		g.player.pos.y = -screen_size_from_origin.y / pixels_per_coord + collision_offset.y
	}
	if g.player.pos.x + collision_offset.x > screen_size_from_origin.x/ pixels_per_coord{
		g.player.pos.x = (screen_size_from_origin.x / pixels_per_coord) - collision_offset.x
	} else if g.player.pos.x - collision_offset.x < -(screen_size_from_origin.x/ pixels_per_coord){
		g.player.pos.x = -screen_size_from_origin.x / pixels_per_coord + collision_offset.x
	}
}

// PLAYER


Player :: struct{
	id: cstring,
	sprite: cstring,
	pos: Vec2,
	size: Vec2,
	rot: f32,
	move_dir: Vec2,
	look_dir: Vec2,
	default_move_speed: f32,
	move_speed: f32,
}

init_player :: proc(){
	// setup the player
	g.player = Player{
		id = "Player",
		sprite = "./source/assets/textures/Random.png",
		pos = {0, 0},
		size ={1, 1},
		rot = 0,
		move_dir = {1, 0},
		default_move_speed = 5,
	}
	g.player.move_speed = g.player.default_move_speed
	init_player_abilities()

	init_sprite(g.player.sprite, g.player.pos, g.player.size, g.player.id)
}

update_player :: proc(dt: f32) {
	//changing the move_input with wasd
	move_input: Vec2
	if key_down[.W] do move_input.y = 1
	else if key_down[.S] do move_input.y = -1
	if key_down[.A] do move_input.x = -1
	else if key_down[.D] do move_input.x = 1

	//defining the definitions of up and right which in turn gives us the other directions
	up := Vec2{0,1}
	right := Vec2{1,0}

	motion : Vec2

	if move_input != 0 {
		g.player.move_dir = up * move_input.y + right * move_input.x
	
		motion = linalg.normalize0(g.player.move_dir) * g.player.move_speed * dt
	}

	//g.player.look_dir = linalg.normalize0(g.cursor.pos-(g.player.pos - Vec2{g.camera.position.x, g.camera.position.y}))
	g.player.look_dir = g.player.move_dir

	update_player_abilities(dt)

	//creates a player rotation based of the movement
	g.player.rot = linalg.to_degrees(math.atan2(g.player.look_dir.y, g.player.look_dir.x))

	


	g.player.pos += motion
	update_sprite(g.player.pos, {0, 0, g.player.rot}, g.player.id)
}


// PLAYER ABILITIES

init_player_abilities :: proc(){
	init_dash()
	init_sprint()
}

update_player_abilities :: proc(dt: f32){

	//check for dash
	if listen_key_single_down(dash.button){
		dash.enabled = true
	}
	if dash.enabled == true{
		player_dash(dt)
	}


	//check for sprint
	if listen_key_down(sprint.button) do sprint.enabled = true
	else do sprint.enabled = false
	update_sprint()

}

//DASH ABILIY

Dash_data :: struct{
	enabled: bool,
	default_distance: f32,
	button: sapp.Keycode,
	duration_speed: f32,
	duration: f32,
	last_distance: f32,
	distance: f32,
	cutoff: f32,
}

dash: Dash_data

init_dash :: proc(){
	dash = {
		enabled = false,
		//distance that is going to be traveled by the player
		default_distance = 1.4,
		//dash button
		button = .SPACE,
		//How fast it travels
		duration_speed = 5,
		//The duration traveled
		duration = 0,
		//The last distance traveled
		last_distance = 0,
		//The distance traveled
		distance = 0,
		//cutoff var for cutting off the ease function
		cutoff = 0.96,
	}
}

dash_ease :: proc(x: f32) -> f32 {
	ease := 1 - math.pow(1 - x, 3);

	return ease
}

player_dash :: proc(dt: f32){
	dash.duration +=dash.duration_speed * dt
	dash.distance = dash_ease(dash.duration)


	// do the ability
	dash_motion := linalg.normalize0(g.player.move_dir) * (dash.default_distance/dash.cutoff)
	g.player.pos += dash_motion * (dash.distance-dash.last_distance)
	g.player.move_speed = 0

	dash.last_distance = dash.distance
	
	if dash.distance >= dash.cutoff{
		init_dash()
		g.player.move_speed = g.player.default_move_speed
	}
}

//SPRINT ABILITY

Sprint_data :: struct{
	enabled: bool,
	//sprint button
	button: sapp.Keycode,
	//sprint speed
	speed: f32,
}

sprint: Sprint_data

init_sprint :: proc(){
	sprint = {
		enabled = false,
		button = .LEFT_SHIFT,
		speed = 7.5,
	}
}

update_sprint :: proc(){
	if sprint.enabled == true do g.player.move_speed = sprint.speed
	else do g.player.move_speed = g.player.default_move_speed
}

// CURSOR

Cursor :: struct{
	pos: Vec2,
	rot: f32,
	sensitivity: f32,
	size: Vec2,
	filename: cstring,
}

init_cursor :: proc(){
	g.cursor = Cursor{
		pos = { 0,0 },
		rot = 0,
		sensitivity = 2,
		size = { 0.25,0.25 },
		filename = "./source/assets/sprites/Cursor2.png",
	}

	priority: i32 = 10
	init_sprite(filename = g.cursor.filename, size = g.cursor.size, id = "cursor", priority = priority)
}

update_cursor :: proc(dt: f32){
	g.cursor.pos += (Vec2{mouse_move.x, -mouse_move.y} * g.cursor.sensitivity * dt)
	check_cursor_collision()
	update_sprite(pos2 = Vec2{g.camera.position.x ,g.camera.position.y} + g.cursor.pos, rot3 = {0, 0, g.cursor.rot}, id = "cursor")
}

//check the cursor collision with the screen
check_cursor_collision :: proc (){

	wierd_const := (7.6/8)*g.camera.position.z
	collision_offset := Vec2 {g.cursor.size.x/2, g.cursor.size.y/2}
	screen_size_from_origin := Vec2 {sapp.widthf()/2, sapp.heightf()/2}
	pixels_per_coord: f32 = sapp.heightf()/wierd_const



	if g.cursor.pos.y + collision_offset.y > screen_size_from_origin.y/ pixels_per_coord{
		g.cursor.pos.y = (screen_size_from_origin.y / pixels_per_coord) - collision_offset.y
	} else if g.cursor.pos.y - collision_offset.y < -(screen_size_from_origin.y / pixels_per_coord){
		g.cursor.pos.y = -screen_size_from_origin.y / pixels_per_coord + collision_offset.y
	}
	if g.cursor.pos.x + collision_offset.x > screen_size_from_origin.x/ pixels_per_coord{
		g.cursor.pos.x = (screen_size_from_origin.x / pixels_per_coord) - collision_offset.x
	} else if g.cursor.pos.x - collision_offset.x < -(screen_size_from_origin.x/ pixels_per_coord){
		g.cursor.pos.x = -screen_size_from_origin.x / pixels_per_coord + collision_offset.x
	}
}

camera_follow_cursor :: proc(dt: f32){
	//camera follows cursor

	cursor_dir := g.cursor.pos-(g.player.pos - Vec2{g.camera.position.x, g.camera.position.y})

	lookahead := get_vector_magnitude(cursor_dir)

	lookahead = math.clamp(lookahead, -g.camera.lookahead_distance, g.camera.lookahead_distance)

	lookahead /= g.camera.lookahead

	camera_follow(dt, g.player.pos, lookahead, cursor_dir)
}

camera_follow_player :: proc(dt: f32){
	camera_follow(dt, g.player.pos, 0, g.player.look_dir)
}

// CAMERA

Camera :: struct{
	rotation: f32,
	position: Vec3,
	target: Vec3,
	look: Vec2,
	spring: Spring,
	lookahead_distance: f32,
	lookahead: f32,
	spring_forces: [dynamic]Spring_forces,
	zoom: Camera_zoom,

	lookahead_spring: Spring,

	camera_shake: Camera_shake,
}

Spring_forces :: struct{
	force: f32,
	threshold: f32,
}

Camera_zoom :: struct{
	max: f32,
	threshold: f32,
	default: f32,
	speed: f32,
}

LOOK_SENSITIVITY :: 0.3

init_camera :: proc(){
	//setup the camera
	g.camera = {
		rotation = 0,
		position = { 0,0,11 },
		//what the camera is looking at
		target = { 0,0,-1 },
		//how far the mouse movement affects the lookahead of the camera
		lookahead_distance = 4,
		//divides the lookahead distance to get the actual lookahead of the camera
		lookahead = 6,
		//how much to zoom out, when to max out and how fast to zoom
		zoom = {
			max = 0,
			threshold = 0.2,
			speed = 1,
		},

		//spring forces has to be in order
		//the camera will go between these values smoothly
		spring_forces = {
			//when standing still
			{14, 0},
			//when walking
			{11, 0.0002},
			//when sprinting
			{13, 0.00035},
			//max speed
			{16, 0.0004}
		},

		//the spring for the camera
		spring = Spring{
			restlength = 0,
			depletion = 80,
		},


		//a spring for the lookahead of the camera
		lookahead_spring = Spring{
			restlength = 0,
			depletion = 80,
			force = 25,
		}
	}

	//set the camera zoom position
	g.camera.zoom.default = g.camera.position.z

	//set the camera positions to the player
	g.camera.position.x = g.player.pos.x
	g.camera.position.y = g.player.pos.y
	g.camera.target.x = g.player.pos.x
	g.camera.target.y = g.player.pos.y
	g.camera.spring.position = g.player.pos
	g.camera.spring.anchor = g.player.pos
	g.camera.lookahead_spring.position = g.player.pos
	g.camera.lookahead_spring.anchor = g.player.pos

	init_camera_shake()

}

last_pos: Vec2
current_pos: Vec2


//follows a 2d position 
camera_follow :: proc(dt: f32, position: Vec2, lookahead: f32 = 0, lookahead_dir: Vec2 = {0, 0}) {

	current_pos := position

	//pos camera wants to look at
	lookahead_pos := (linalg.normalize0(lookahead_dir) * lookahead)
	g.camera.lookahead_spring.anchor = lookahead_pos

	g.camera.spring.anchor = position

	//difference pos between last frame and this frame
	pos_difference := current_pos - last_pos
	//how fast the player is moving
	move_mag := get_vector_magnitude(pos_difference) * dt

	//change the spring force with a gradient between different values
	for i := 0; i<len(g.camera.spring_forces); i+=1 {
		//the current threshold and force values
		sf := g.camera.spring_forces[i]
		
		if move_mag < sf.threshold do break
		//if we are not in the last element of the array
		if i < len(g.camera.spring_forces) -1 {
			//the next threshold and force values
			next_sf := g.camera.spring_forces[i+1]

			//difference between the different thresholds
			threshold_player_diff := move_mag - sf.threshold
			threshold_diff := next_sf.threshold - sf.threshold

			//how much of the threshold value we are at
			gradient_index := threshold_player_diff/threshold_diff

			//difference between the forces
			force_diff := next_sf.force - sf.force

			//adds a percentage of the next spring force dependent on our movement speed
			g.camera.spring.force = sf.force + (force_diff * gradient_index)
		//if we are in the last element of the aray. Means we are at the max values
		} else {
			g.camera.spring.force = sf.force
		}
	}

	//change how much the camera is zoomed out ( depentent on movement speed )

	zoom_threshold_diff := move_mag - g.camera.zoom.threshold
	zoom_gradient_index := (zoom_threshold_diff/g.camera.zoom.threshold) + 1
	if zoom_gradient_index > 1 do zoom_gradient_index = 1

	//desired zoom position
	zoom_zpos := g.camera.zoom.default + (g.camera.zoom.max * zoom_gradient_index)

	//slowly moves the z pos of camera to the desired zoom position
	if zoom_zpos > g.camera.position.z{
		g.camera.position.z += g.camera.zoom.speed * dt
	} else if zoom_zpos < g.camera.position.z{
		g.camera.position.z -= g.camera.zoom.speed * dt
	}

	//update the spring physics and update the camera position
	update_weird_spring(&g.camera.spring, dt)
	update_weird_spring(&g.camera.lookahead_spring, dt)

	last_pos = current_pos

}

update_camera_position :: proc(position: Vec2, rotation: f32){
	g.camera.position = Vec3{position.x, position.y, g.camera.position.z}
	g.camera.target = Vec3{position.x ,position.y, g.camera.target.z}
	g.camera.rotation = rotation
}

update_camera :: proc(dt: f32){
	update_camera_shake(dt)

	camera_follow_cursor(dt)

	update_camera_position(g.camera.spring.position + g.camera.lookahead_spring.position + g.camera.camera_shake.pos_offset, g.camera.camera_shake.rot_offset)
}

//function for moving around camera in 3D
move_camera_3D :: proc(dt: f32) {
	move_input: Vec2
	if key_down[.W] do move_input.y = 1
	else if key_down[.S] do move_input.y = -1
	if key_down[.A] do move_input.x = -1
	else if key_down[.D] do move_input.x = 1

	look_input: Vec2 = -mouse_move * LOOK_SENSITIVITY
	g.camera.look += look_input
	g.camera.look.x = math.wrap(g.camera.look.x, 360)
	g.camera.look.y = math.clamp(g.camera.look.y, -89, 89)

	look_mat := linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(g.camera.look.x), to_radians(g.camera.look.y), 0)
	forward := ( look_mat * Vec4 {0,0,-1,1} ).xyz
	right := ( look_mat * Vec4 {1,0,0,1} ).xyz


	move_dir := forward * move_input.y + right * move_input.x

	motion := linalg.normalize0(move_dir) * g.player.move_speed * dt
	g.camera.position += motion

	g.camera.target = g.camera.position + forward
}


// 
// CAMERA SHAKE
// 

Camera_shake :: struct {
	trauma: f32,
	depletion: f32,
	pos_offset: Vec2,
	rot_offset: f32,
	seed: i64,
	time_offset: Vec2,
}

init_camera_shake :: proc(){
	g.camera.camera_shake = Camera_shake{
		trauma = 0,
		depletion = 8,
		pos_offset = { 0,0 },
		rot_offset = 0,
		seed = 27193,
		time_offset = {7.5, 7.5}
	}
}

update_camera_shake :: proc(dt: f32){
	cs := &g.camera.camera_shake
	if cs.trauma <= 0{
		cs.pos_offset = { 0,0 }
		cs.rot_offset = 0
		cs.trauma = 0
	} else {
		seedpos := noise.Vec2{f64(cs.time_offset.x * g.runtime), f64(cs.time_offset.y * g.runtime)}

		cs.pos_offset = Vec2{noise.noise_2d(cs.seed, seedpos), noise.noise_2d(cs.seed + 1, seedpos)}
		cs.pos_offset /= 30
		cs.pos_offset *= cs.trauma * cs.trauma
		cs.rot_offset = noise.noise_2d(cs.seed+2, seedpos)
		cs.rot_offset /= 20
		cs.rot_offset *= cs.trauma * cs.trauma

		cs.trauma -= cs.depletion * dt
	}
}