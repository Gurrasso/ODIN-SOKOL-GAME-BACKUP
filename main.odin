#+feature dynamic-literals
package main


// 
//  IMPORTS
//
import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
// stb
import stbi "vendor:stb/image"
import stbtt "vendor:stb/truetype"
// sokol imports
import sapp "./sokol/app"
import shelpers "./sokol/helpers"
import sg "./sokol/gfx"
import sglue "./sokol/glue"

to_radians :: linalg.to_radians
Matrix4 :: linalg.Matrix4f32;

//global var for context
default_context: runtime.Context

//define our own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

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
	camera: struct{
		position: Vec3,
		target: Vec3,
		look: Vec2,
	},
	player: Player,
	fonts: [dynamic]FONT_INFO,
}
g: ^Globals

//main
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

	//do things for all objects
	for obj in g.objects {
		//matrix
		m := linalg.matrix4_translate_f32(obj.pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.y), to_radians(obj.rot.x), to_radians(obj.rot.z))


		b := sg.Bindings {
			vertex_buffers = { 0 = obj.vertex_buffer },
			index_buffer = g.index_buffer,
			images = { IMG_tex = obj.img },
			samplers = { SMP_smp = g.sampler },
		}

		//apply the bindings(something that says which things we want to draw)
		

		sg.apply_bindings(b)

		//apply uniforms
		sg.apply_uniforms(UB_vs_params, sg_range(&Vs_Params{
			mvp = p * v * m
		}))

		//drawing
		sg.draw(0, 6, 1)
	}

	sg.end_pass()

	sg.commit()

	mouse_move = {}
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

//Events
event_cb :: proc "c" (ev: ^sapp.Event){
	context = default_context

	#partial switch ev.type{
		case .MOUSE_MOVE:
			mouse_move += {ev.mouse_dx, ev.mouse_dy}
		case .KEY_DOWN:
			key_down[ev.key_code] = true
		case .KEY_UP:
			key_down[ev.key_code] = false
	}
}

//
// UTILS
//

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

//
// DRAWING
//

//kinda scuffed but works
init_rect :: proc(color_offset: sg.Color, pos2: Vec2, size: Vec2, id: cstring, tex_index2: u8 = 0){


	WHITE_IMAGE : cstring = "./assets/textures/WHITE_IMAGE.png"

	DEFAULT_UV :: Vec4 { 0,0,1,1 }

	// vertices
	vertices := []Vertex_Data {
		{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {DEFAULT_UV.x, DEFAULT_UV.y}, tex_index = tex_index2 },
		{ pos = {  (size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {DEFAULT_UV.z, DEFAULT_UV.y}, tex_index = tex_index2 },
		{ pos = { -(size.x/2),  (size.y/2), 0 }, col = color_offset, uv = {DEFAULT_UV.x, DEFAULT_UV.w}, tex_index = tex_index2 },
		{ pos = {  (size.x/2),  (size.y/2), 0 }, col = color_offset, uv = {DEFAULT_UV.z, DEFAULT_UV.w}, tex_index = tex_index2 },
	}

	append(&g.objects, Object{
		{pos2.x, pos2.y, 0},
		{0, 0, 0},
		load_image(WHITE_IMAGE),
		sg.make_buffer({ data = sg_range(vertices)}),
		id
	})
}


//proc for updating objects
update_object :: proc(pos2: Vec2, rot3: Vec3, id: cstring){
	for &i in g.objects{
		if i.id == id{
			i.pos = {pos2.x, pos2.y, 0}
			i.rot = {rot3.x, rot3.y, rot3.z}
		}
	}
}


//proc for creating a new sprite on the screen and adding it to the objects
init_sprite :: proc(filename: cstring, pos2: Vec2, size: Vec2, id: cstring, tex_index2: u8 = 0){


	//color offset
	WHITE :: sg.Color { 1,1,1,1 }

	DEFAULT_UV :: Vec4 { 0,0,1,1 }


	// vertices
	vertices := []Vertex_Data {
		{ pos = { -(size.x/2), -(size.y/2), 0 }, col = WHITE, uv = {DEFAULT_UV.x, DEFAULT_UV.y}, tex_index = tex_index2  },
		{ pos = {  (size.x/2), -(size.y/2), 0 }, col = WHITE, uv = {DEFAULT_UV.z, DEFAULT_UV.y}, tex_index = tex_index2  },
		{ pos = { -(size.x/2),  (size.y/2), 0 }, col = WHITE, uv = {DEFAULT_UV.x, DEFAULT_UV.w}, tex_index = tex_index2  },
		{ pos = {  (size.x/2),  (size.y/2), 0 }, col = WHITE, uv = {DEFAULT_UV.z, DEFAULT_UV.w}, tex_index = tex_index2  },
	}

	append(&g.objects, Object{
		{pos2.x, pos2.y, 0},
		{0, 0, 0},
		load_image(filename),
		sg.make_buffer({ data = sg_range(vertices)}),
		id
	})
}

//proc for updating sprites
update_sprite :: proc(pos2: Vec2, rot3: Vec3, id: cstring){
	for &i in g.objects{
		if i.id == id{
			i.pos = {pos2.x, pos2.y, 0}
			i.rot = {rot3.x, rot3.y, rot3.z}
		}
	}
}



//
// FONT       (   kinda scuffed rn, gonna fix later(probably not)   )
//

FONT_INFO :: struct {
	id: cstring,
	img: sg.Image,
	width: int,
	height: int,
	char_data: [char_count]stbtt.bakedchar,
}

font_bitmap_w :: 512
font_bitmap_h :: 512
char_count :: 96

//initiate the text and add it to our objects to draw it to screen
init_text :: proc(pos2: Vec2, scale: f32 = 60, margin: Vec2 = {0.02, 0}, color: sg.Color = { 1,1,1,1 }, text: string, font_id: cstring, text_object_id: cstring = "text") {
	using stbtt

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

	x: f32 = pos2.x
	y: f32 = pos2.y

	for char in text {
		
		advance_x: f32
		advance_y: f32
		q: aligned_quad

		GetBakedQuad(&font_data[0], font_bitmap_w, font_bitmap_h, cast(i32)char - 32, &advance_x, &advance_y, &q, false)
		
		
		size := Vec2{ abs(q.x0 - q.x1), abs(q.y0 - q.y1) }
		
		bottom_left := Vec2{ q.x0, -q.y1 }
		top_right := Vec2{ q.x1, -q.y0 }

		assert(bottom_left + size == top_right)
		
		offset_to_render_at := Vec2{x,y} + bottom_left/40
		
		uv := Vec4{ q.s0, q.t1, q.s1, q.t0 }

		create_text(offset_to_render_at, size/scale, uv, color, atlas_image, text_object_id)
		
		x += advance_x/scale
		y += -advance_y/scale
	}
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

//adds the char to the g.objects so it can be drawn
create_text :: proc(pos2: Vec2, size: Vec2, text_uv: Vec4, color_offset: sg.Color , img: sg.Image, id: cstring, tex_index2: u8 = 1){



	// vertices
	vertices := []Vertex_Data {
		{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {text_uv.x, text_uv.y}, tex_index = tex_index2 },
		{ pos = {  (size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {text_uv.z, text_uv.y}, tex_index = tex_index2 },
		{ pos = { -(size.x/2),  (size.y/2), 0 }, col = color_offset, uv = {text_uv.x, text_uv.w}, tex_index = tex_index2 },
		{ pos = {  (size.x/2),  (size.y/2), 0 }, col = color_offset, uv = {text_uv.z, text_uv.w}, tex_index = tex_index2 },
	}

	append(&g.objects, Object{
		{pos2.x, pos2.y, 0},
		{0, 0, 0},
		img,
		sg.make_buffer({ data = sg_range(vertices)}),
		id
	})
}

//update a text by changing its position(relative to its last position) kind of bad rn, also cant rotate (should fix)
update_text :: proc(motion: Vec2, id: cstring){
	for &i in g.objects{
		if i.id == id{
			i.pos = {i.pos.x + motion.x, i.pos.y + motion.y, 0}
		}
	}
}



//
// GAME
//


Player :: struct{
	id: cstring,
	sprite: cstring,
	pos: Vec2,
	size: Vec2,
	rot: f32,
}

init_game_state :: proc(){

	sapp.show_mouse(false)
	sapp.lock_mouse(true)
	//sapp.toggle_fullscreen()

	// setup the player
	g.player = Player{
		id = "Player",
		sprite = "./assets/textures/Random.png",
		pos = {0, 0},
		size ={1, 1},
		rot = 0,
	}

	//setup the camera
	g.camera = {
		position = { 0,0,8 },
		target = { 0,0,-1 },
	}

	init_sprite(g.player.sprite, g.player.pos, g.player.size, g.player.id)

	init_font(font_path = "./assets/fonts/MedodicaRegular.otf", id = "font1", font_h = 64)
	init_text(pos2 = {0,1}, text = "test TEST,,, gg?", color = sg_color(Vec3{255, 255, 255}), font_id = "font1")
}

update_game_state :: proc(dt: f32){

	event_listener()
	//update_camera(dt)
	update_player(dt)
	camera_follow(g.player.pos)
}

//proc for quiting the game
quit_game :: proc(){
	sapp.quit()
}

MOVE_SPEED :: 5
LOOK_SENSITIVITY :: 0.3

event_listener :: proc(){
	//tell the program to exit if you hit escape
	if key_down[.ESCAPE] {
		g.should_quit = true
	}
}

//check the player collision
check_collision :: proc (){

	wierd_const :: 7.6
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

//function for moving around camera
update_player :: proc(dt: f32) {
	move_input: Vec2
	if key_down[.W] do move_input.y = 1
	else if key_down[.S] do move_input.y = -1
	if key_down[.A] do move_input.x = -1
	else if key_down[.D] do move_input.x = 1

	up := Vec2{0,1}
	right := Vec2{1,0}


	move_dir := up * move_input.y + right * move_input.x

	motion := linalg.normalize0(move_dir) * MOVE_SPEED * dt

	//creates a player rotation based of the movement
	if move_dir != 0 {
		g.player.rot = linalg.to_degrees(math.atan2(motion.y, motion.x))
	}

	//check_collision()


	g.player.pos += motion
	update_sprite(g.player.pos, {0, 0, g.player.rot}, g.player.id)
}

camera_follow :: proc(position: Vec2) {
	g.camera.position = {position.x, position.y, g.camera.position.z}
	g.camera.target = {position.x, position.y, g.camera.target.z}
}

//function for moving around camera
update_camera :: proc(dt: f32) {
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

	motion := linalg.normalize0(move_dir) * MOVE_SPEED * dt
	g.camera.position += motion

	g.camera.target = g.camera.position + forward
}