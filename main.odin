#+feature dynamic-literals
package main

/*
	TODO: 

	use uuid:s,

	Seperate everything into multiple files(find a good way to organize the project)

	Item lags behind player especially at lower fps,

	Maybe dont calculate the screen_size_world every frame? Maybe just on resize and camera changing z pos?,

	u32 sprite ids?

	generate an image atlas on init with all the images instead of loading induvidual images?
	fix sprites being wierd and having subpixel positions, automatically get the size of sprites based off off the amount of pixels in the img,
	
	UI system

	fix updating text size, 
	fix text being weird when changing z pos or perspective,
	fix text \n not working,
	fix small characters like .,: having the wrong spacing,
	maybe add .CORNER, .CENTER etc, for text alignment,

	fix updating of vertex_buffers,
	
	make it so item holders can hold nothing,
	weapons dont work for multiple enteties at a time,
	
	make sure everything that should use the transform struct uses it,
	make sure we use the same naming for pos, rot etc everywhere,

	sprite sheet rendering,
	animation system with a sprite_animation object with different functions to toggle animations,
	collisions,
	
	tilemap and other environment/map things,
	map generation with wave function collapse,

	lighting(normalmaps),
	antialiasing is a little buggy?,
	resolution scaling? or try and change the dpi/res with sokol?,
	fix init_icon,


	particle system implemented as a structure of arrays:
	Particles :: struct {
		positions [dynamic]Vec2,
		array,
		universal particle data,
	} instead of:
	Particle :: struct {
		pos: Vec3,
		other data,
	}
	Particles: [dynamic]Particle


	make it so cursor doesnt camerashake?
	cursor changes size when camera changes z pos whilst game is running,
	
	use enteties for abilities?,
*/

// ===============
//	  :IMPORTS
// ===============
import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/ease"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:sort"
import "core:fmt"
// stb
import stbi "vendor:stb/image"
import stbtt "vendor:stb/truetype"
// sokol imports
import sapp "../sokol/app"
import shelpers "../sokol/helpers"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
//ecs
import ecs "./lib/odin-ecs"

to_radians :: linalg.to_radians
to_degrees :: linalg.to_degrees
Matrix4 :: linalg.Matrix4f32;

//global var for context
default_context: runtime.Context

//define own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Id :: u32

//draw call data
Draw_data :: struct{
	m: Matrix4,
	b: sg.Bindings,
	// the draw_priority of an obj, basically just says higher draw_priority, draw last(on top)
	draw_priority: i32,
}

Asympatic_object :: struct{
	depletion: f32,
	position: Vec2,
	destination: Vec2,
}

// the vertex data
Vertex_data :: struct{
	pos: Vec3,
	col: sg.Color,
	uv: Vec2,
	tex_index: u8,
}

Vertex_buffer_data :: struct{
	uv_data: Vec4,
	size_data: Vec2,
	color_data: sg.Color,
	tex_index_data: u8,
	buffer: sg.Buffer,
}

Object_group :: struct{
	objects: [dynamic]Object,
}


Images :: struct{
	filename: cstring,
	image: sg.Image,
}

// Handle multiple objects
Object :: struct{
	pos: Vec3,
	rot: Vec3,
	img: sg.Image,
	draw_priority: i32,
	vertex_buffer: sg.Buffer,
	size: Vec2,
}

Transform :: struct{
	pos: Vec2,
	rot: Vec3, // in degrees for sprites
	size: Vec2,
}

DEFAULT_TRANSFORM: Transform : {
	size = {0.5, 0.5},
	pos = {0, 0},
	rot = {0, 0, 0}
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
	// Game state stuff
	should_quit: bool,
	runtime: f32,
	screen_size: Vec2,
	frame_count: i32,
	dt: f32,
	//Objects for drawing
	text_objects: map[string]Text_object,
	objects: map[string]Object_group,
	//Things there are only one of
	camera: Camera,
	player: Player,
	cursor: Cursor,
	//used to avoid initing multiple of the same buffer
	vertex_buffers: [dynamic]Vertex_buffer_data,
	//used to avoid initing mutiple of the same img
	images: [dynamic]Images,

	fonts: map[string]FONT_INFO,
	enteties: Enteties,
}

backends_with_bottom_left_screen_origins: [3]sg.Backend : {.GLCORE, .GLES3, .WGPU}

Rendering_globals :: struct {
	//graphics stuff
	shader: sg.Shader,
	pipeline: sg.Pipeline,
	index_buffer: sg.Buffer,	
	sampler: sg.Sampler,
	//assumes the correct screen origin to be top left
	inverse_screen_y: bool,
	reverse_screen_y: int,
}

Uniforms_vs_data :: struct{
	model_matrix: Mat4,
	veiw_matrix: Mat4,
	projection_matrix: Mat4,
	scz: Vec2,
	reverse_screen_y: int,
}


rg: ^Rendering_globals

g: ^Globals


ctx: ecs.Context

// ============== 
//     :MAIN
// ==============

main :: proc(){
	//logger
	context.logger = log.create_console_logger()
	default_context = context
	
	ctx = ecs.init_ecs()

	defer ecs.deinit_ecs(&ctx)

	//sokol app
	sapp.run({
		width	= 1000,
		height = 1000,
		window_title = "ODIN-SOKOL-GAME",
		sample_count = 8,


		allocator = sapp.Allocator(shelpers.allocator(&default_context)),
		logger = sapp.Logger(shelpers.logger(&default_context)),

		init_cb = init_cb,
		frame_cb = frame_cb,
		cleanup_cb = cleanup_cb,
		event_cb = event_cb,
	})

	
}

// =================
//   :SOKOL PROCS
// =================

//initialization
init_cb :: proc "c" (){
	context = default_context
	
	//init_icon("./src/assets/sprites/ase256.png")

	//setup for the sokol graphics
	sg.setup({
		environment = shelpers.glue_environment(),
		allocator = sg.Allocator(shelpers.allocator(&default_context)),
		logger = sg.Logger(shelpers.logger(&default_context)),
	})

	//the globals
	g = new(Globals)
	rg = new(Rendering_globals)

	//different rendering backends have top left or bottom left as the screen origin
	rg.inverse_screen_y = false
	rg.reverse_screen_y = 1
	if contains(backends_with_bottom_left_screen_origins, sg.query_backend()){
		rg.inverse_screen_y = true
		rg.reverse_screen_y = -1;
	}

	//white image for scuffed rect rendering
	WHITE_IMAGE = get_image(WHITE_IMAGE_PATH)

	g.screen_size = {sapp.widthf(), sapp.heightf()}

	//make the shader and pipeline
	rg.shader = sg.make_shader(main_shader_desc(sg.query_backend()))
	pipeline_desc : sg.Pipeline_Desc = {
		shader = rg.shader,
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
		//depth = {
		//	write_enabled = true,
		//	compare = .LESS_EQUAL
		//},
	}
	
	//the blend state for working with alphas
	blend_state : sg.Blend_State = {
		enabled = true,
		src_factor_rgb = .SRC_ALPHA,
		dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
		op_rgb = .ADD,
		src_factor_alpha = .ONE,
		dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
		op_alpha = .ADD,
	}
	
	pipeline_desc.colors[0] = { blend = blend_state}
	rg.pipeline = sg.make_pipeline(pipeline_desc)

	// indices
	indices := []u16 {
		0, 1, 2,
		2, 1, 3,
	}
	// index buffer
	rg.index_buffer = sg.make_buffer({
		type = .INDEXBUFFER,
		data = sg_range(indices),
	})

	//create the sampler
	rg.sampler = sg.make_sampler({})

	init_game_state()
}



//cleanup
cleanup_cb :: proc "c" (){
	context = default_context

	// DESTROY!!!
	for buffer in g.vertex_buffers{
		sg.destroy_buffer(buffer.buffer)
	}

	for image in g.images{
		sg.destroy_image(image.image)
	}

	sg.destroy_sampler(rg.sampler)
	sg.destroy_buffer(rg.index_buffer)
	sg.destroy_pipeline(rg.pipeline)
	sg.destroy_shader(rg.shader)

	//free the global vars
	free(g)
	free(rg)
	free(game_state)

	free_all()

	//shut down sokol graphics
	sg.shutdown()
}

//var for keeping time since last fixed update
time_since_fixed_update: f32
// how often the fixed update function should try to update (it will only update as fast as the framerate)
FIXED_UPDATE_TIME: f32 : 1/60

//Every x seconds
fixed_frame_cb :: proc(){
	fixed_update_game_state()
}

//Every frame
frame_cb :: proc "c" (){
	context = default_context
	
	//exit the program
	if g.should_quit {
		quit_game()
		return
	}

	if screen_resized do g.screen_size = Vec2{sapp.widthf(), sapp.heightf()}

	//deltatime
	g.dt = f32(sapp.frame_duration())
	time_since_fixed_update += g.dt

	//fixed update
	if time_since_fixed_update > FIXED_UPDATE_TIME{
		fixed_frame_cb()
		time_since_fixed_update = 0
	}

	//updates
	update_game_state()

	if listen_screen_resized() do screen_resized = false
	
	//
	// rendering	
	//

	//projection matrix
	p := linalg.matrix4_perspective_f32(70, g.screen_size.x / g.screen_size.y, 0.0001, 1000)
	//view matrix
	v := linalg.matrix4_look_at_f32(g.camera.position, g.camera.target, {g.camera.rotation, 1, 0})

	sg.begin_pass({ swapchain = shelpers.glue_swapchain()})

	//apply the pipeline to the sokol graphics
	sg.apply_pipeline(rg.pipeline)

	draw_data: [dynamic]Draw_data

	//do things for all text objects
	for id in g.text_objects {
		for obj in g.text_objects[id].objects{

			pos := obj.pos + Vec3{obj.rotation_pos_offset.x, obj.rotation_pos_offset.y, 0}
			//model matrix turns vertex positions into world space positions
			m := linalg.matrix4_translate_f32(pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.x), to_radians(obj.rot.y), to_radians(obj.rot.z))
	
	
			//apply the bindings(something that says which things we want to draw)
			b := sg.Bindings {
				vertex_buffers = { 0 = obj.vertex_buffer },
				index_buffer = rg.index_buffer,
				images = { IMG_tex = obj.img },
				samplers = { SMP_smp = rg.sampler },
			}

			append(&draw_data, Draw_data{
				m = m,
				b = b,
				draw_priority = g.text_objects[id].draw_priority,
			})
		}
	}

	//do things for all objects
	for id in g.objects {
		for obj in g.objects[id].objects{
			
			//model matrix turns vertex positions into world space positions
			m := linalg.matrix4_translate_f32(obj.pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.x), to_radians(obj.rot.y), to_radians(obj.rot.z))
	
			//apply the bindings(something that says which things we want to draw)
			b := sg.Bindings {
				vertex_buffers = { 0 = obj.vertex_buffer },
				index_buffer = rg.index_buffer,
				images = { IMG_tex = obj.img },
				samplers = { SMP_smp = rg.sampler },
			}

			append(&draw_data, Draw_data{
				m = m,
				b = b,
				draw_priority = obj.draw_priority,
			})
		}	
	}

	//sort the array based on draw_priority so we can chose which things we want to be drawn over other, higher draw priority means that it gets drawn after(on top)
	sort.quick_sort_proc(draw_data[:], compare_draw_data_draw_priority)

	for drt in draw_data {
		sg.apply_bindings(drt.b)

		//apply uniforms
		sg.apply_uniforms(UB_Uniforms_Data, sg_range(&Uniforms_vs_data{
			model_matrix = drt.m,
			veiw_matrix = v,
			projection_matrix = p,
			scz = g.screen_size,
			reverse_screen_y = rg.reverse_screen_y,
		}))

		sg.draw(0, 6, 1)
	}

	sg.end_pass()

	sg.commit()
}

//Events
event_cb :: proc "c" (ev: ^sapp.Event){
	context = default_context

	#partial switch ev.type{
		case .MOUSE_MOVE:
			mouse_move += {ev.mouse_dx, ev.mouse_dy}
		case .KEY_DOWN:

			if !key_down[ev.key_code] && !single_key_down[ev.key_code]{
				single_key_down[ev.key_code] = true
			}

			key_down[ev.key_code] = true

			single_key_up[ev.key_code] = false
		case .KEY_UP:
			if key_down[ev.key_code] && !single_key_up[ev.key_code]{
				single_key_up[ev.key_code] = true
			}

			key_down[ev.key_code] = false

			single_key_down[ev.key_code] = false
		case .MOUSE_DOWN:

			if  !mouse_down[ev.mouse_button] && !single_mouse_down[ev.mouse_button]{
				single_mouse_down[ev.mouse_button] = true
			}

			mouse_down[ev.mouse_button] = true

			single_mouse_up[ev.mouse_button] = false	
		case .MOUSE_UP:
			if mouse_down[ev.mouse_button] && !single_mouse_up[ev.mouse_button]{
				single_mouse_up[ev.mouse_button] = true
			}

			mouse_down[ev.mouse_button] = false

			single_mouse_down[ev.mouse_button] = false
		case .RESIZED:
			screen_resized = true
	}
}

// ==================
//   :IMAGE THINGS
// ==================


//	proc for loading an image from a file
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

	append(&g.images, Images{
		filename = filename,
		image = image,
	})


	stbi.image_free(pixels)
	
	return image
}

get_image :: proc(filename: cstring) -> sg.Image{
	
	new_image: sg.Image
	image_exists: bool = false
	for image in g.images{
		if image.filename == filename{
			image_exists = true
			new_image = image.image
		} 
	}

	if !image_exists{
		new_image = load_image(filename)
	}

	return new_image
}

get_image_desc :: proc(filename: cstring) -> sapp.Image_Desc{
	w, h: i32
	pixels := stbi.load(filename, &w, &h, nil, 4)
	assert(pixels != nil)

	pixel_range := sapp.Range{
		ptr = pixels, 
		size = uint(w * h * 4)
	}
	image_desc := sapp.Image_Desc{
		width = w,
		height = h,
		pixels = pixel_range,
	}

	stbi.image_free(pixels)

	return image_desc
}

//var for mouse movement
mouse_move: Vec2

//stores the states for all keys
key_down: #sparse[sapp.Keycode]bool
single_key_up: #sparse[sapp.Keycode]bool
single_key_down: #sparse[sapp.Keycode]bool
mouse_down: #sparse[sapp.Mousebutton]bool
single_mouse_down: #sparse[sapp.Mousebutton]bool
single_mouse_up: #sparse[sapp.Mousebutton]bool
screen_resized: bool



// =============
//    :UTILS
// =============

//the cooldown id
Cooldown :: u32

//Timer object for cooldowns
Cooldown_object :: struct{
	enabled: bool,
	cooldown: f32,
	duration: f32,
}

//updates all the cooldowns
update_cooldowns :: proc(){
	for id in game_state.cooldowns{
		cooldown_object := &game_state.cooldowns[id]
		if cooldown_object.enabled{
			cooldown_object.duration += g.dt
			
			if cooldown_object.duration > cooldown_object.cooldown{
				cooldown_object.enabled = false
				cooldown_object.duration = 0
			}
		}
	}
}

cooldown_enabled :: proc(id: Cooldown) -> bool{
	return game_state.cooldowns[id].enabled
}

//starts the cooldown
start_cooldown :: proc(id: Cooldown){
	assert(id in game_state.cooldowns)
	cooldown_object := &game_state.cooldowns[id]

	cooldown_object.enabled = true
}

//creates the cooldown object and gives the id
init_cooldown_object :: proc(cooldown: f32) -> Cooldown{
	id := generate_map_u32_id(game_state.cooldowns)

	game_state.cooldowns[id] = Cooldown_object{
		cooldown = cooldown,
	}
	
	return Cooldown(id)
}

//generate an id from the runtime and a random float
generate_string_id :: proc() -> string{
	builder := strings.builder_make()
	strings.write_f32(&builder, f32(g.runtime) + rand.float32_range(0, 100), 'f')
	return strings.to_string(builder)
}

//generates a u32 that isnt already in the map
generate_map_u32_id :: proc(target_map: $T) -> u32{
	id := rand.uint32()
	if id in target_map do id = generate_map_u32_id(target_map)
	return id
}


//used to sort the draw data based on draw_priority
compare_draw_data_draw_priority :: proc(drt: Draw_data, drt2: Draw_data) -> int{
	return int(drt.draw_priority-drt2.draw_priority)
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

sg_color :: proc{
	sg_color_from_rgb,
	sg_color_from_rgba,
}


sg_color_from_rgba :: proc (color4: Vec4) -> sg.Color{
	color := color4

	new_color := sg.Color{color.r/255, color.g/255, color.b/255, color.a/255}

	return new_color

}

sg_color_from_rgb :: proc (color3: Vec3) -> sg.Color{
	color := color3

	new_color := sg.Color{color.r/255, color.g/255, color.b/255, 1}

	return new_color

}

// array utils

contains :: proc(array: $T, target: $T1) -> bool{
	is := false

	for element in array{
		if element == target{
			is = true
		}
	}

	return is
}

// Intersect a ray with a plane Z = target_z
ray_plane_intersect_z :: proc(ray_origin, ray_dir: Vec3, target_z: f32) -> Vec3 {
    t := (target_z - ray_origin.z) / ray_dir.z;
    return ray_origin + ray_dir * t
}

//convert a point on the screen at a certain z pos to a world pos
screen_point_to_world_at_z :: proc(point: Vec2, target_z: f32) -> Vec3 {

	viewport := Vec4{0.0, 0.0, g.screen_size.x, g.screen_size.y}

	//projection matrix
	projection_matrix := linalg.matrix4_perspective_f32(70, g.screen_size.x / g.screen_size.y, 0.0001, 1000)
	//view matrix
	view_matrix := linalg.matrix4_look_at_f32(g.camera.position, g.camera.target, {g.camera.rotation, 1, 0})


	//Convert pixel to NDC
	ndc_x := 2.0 * (point.x - viewport.x) / viewport.z - 1.0;
	ndc_y := (2.0 * (point.y - viewport.y) / viewport.w - 1.0) * -1;

	//Unproject near (depth = 0.0) and far (depth = 1.0) points
	ndc_near := Vec4{ndc_x, ndc_y, -1.0, 1.0}; // Near plane
	ndc_far  := Vec4{ndc_x, ndc_y,  1.0, 1.0}; // Far plane

  inv_proj := linalg.inverse(projection_matrix)
	inv_view := linalg.inverse(view_matrix)

	eye_near := inv_proj * ndc_near
	eye_far  := inv_proj * ndc_far

	eye_near /= eye_near.w
	eye_far  /= eye_far.w

	world_near := inv_view * eye_near
	world_far  := inv_view * eye_far

	world_near /= world_near.w
	world_far  /= world_far.w

	//Make ray and intersect with Z plane
	ray_origin := world_near.xyz
	ray_dir := linalg.normalize(world_far.xyz - world_near.xyz)

	return ray_plane_intersect_z(ray_origin, ray_dir, target_z).xyz
	
}

//get a size in pixels to size in world
get_pixel_size_in_world :: proc(size: Vec2, target_z: f32) -> Vec2{
	top_left := Vec2{0, 0}
	bottom_right := size
	
	return linalg.abs(screen_point_to_world_at_z(bottom_right, target_z).xy - screen_point_to_world_at_z(top_left, target_z).xy)
}

//get the screen size in world coords at a certain z pos
get_screen_size_in_world :: proc(target_z: f32) -> Vec2{
	bottom_right := g.screen_size-1

	return linalg.abs(get_pixel_size_in_world(bottom_right, target_z))
}

// will return 0 if element isnt found
get_index :: proc(array: $T, target: $T1) -> int{
	index: int = 0

	for i := 0; i < len(array); i+=1{
		if array[i] == target{
				index = i
		}
	}

	return index
}

get_next_index :: proc(array: $T, target: $T1) -> int{
	index := 0
	target_index := get_index(array, target) 
	if target_index < len(array)-1{
		index = target_index + 1
	}

	return index
}


//buffer util


// checks if the buffer already exists and if so it grabs that otherwise it creates it and adds it to an array
get_vertex_buffer :: proc(
	size: Vec2, 
	color_offset: sg.Color, 
	uvs: Vec4, tex_index: u8
) -> sg.Buffer{
	
	buffer: sg.Buffer
	
	buffer_exists: bool = false
	for vertex_buffer in g.vertex_buffers{
		if vertex_buffer.uv_data != uvs || vertex_buffer.size_data != size || vertex_buffer.color_data != color_offset || vertex_buffer.tex_index_data != tex_index do continue
		
		buffer_exists = true
		buffer = vertex_buffer.buffer
		break
	}
	if !buffer_exists{
		vertices := []Vertex_data {
			{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.y}, tex_index = tex_index},
			{ pos = {	(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.y}, tex_index = tex_index},
			{ pos = { -(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.w}, tex_index = tex_index},
			{ pos = {	(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.w}, tex_index = tex_index},
		}
		buffer = sg.make_buffer({size = sg_range(vertices).size, usage = .DYNAMIC})
		sg.update_buffer(buffer, data = sg_range(vertices))

		buffer_data := Vertex_buffer_data{
			buffer = buffer,
			uv_data = uvs,
			size_data = size,
			color_data = color_offset,
			tex_index_data = tex_index,
		}
		append(&g.vertex_buffers, buffer_data)
	}

	return buffer
}


update_vertex_buffer_size :: proc(buffer: sg.Buffer, size: Vec2){
	exists: bool

	for &buffer_data in g.vertex_buffers{
		if buffer_data.buffer == buffer{
			color_offset := buffer_data.color_data
			uvs := buffer_data.uv_data
			tex_index := buffer_data.tex_index_data
			buffer_data.size_data = size

			vertices := []Vertex_data {
				{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.y}, tex_index = tex_index },
				{ pos = {	(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.y}, tex_index = tex_index},
				{ pos = { -(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.w}, tex_index = tex_index},
				{ pos = {	(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.w}, tex_index = tex_index},
			}

			sg.update_buffer(buffer, sg_range(vertices))

			exists = true
		}
	}

	if !exists do log.debug("ERROR: FAILED TO UPDATE BUFFER IN update_vertex_buffer_size")
}

// EVENT UTILS (dont really need all of these procs but it makes it a bit more intuitive)

//key press utils

listen_key_single_up :: proc(keycode: sapp.Keycode) -> bool{
	if single_key_up[keycode] {
		single_key_up[keycode] = false
		return true	
	} else do return false
}

listen_key_single_down :: proc(keycode: sapp.Keycode) -> bool{
	if single_key_down[keycode] {
		single_key_down[keycode] = false
		return true	
	} else do return false
}

listen_key_down :: proc(keycode: sapp.Keycode) -> bool{
	if key_down[keycode] do return true	
	else do return false
}

listen_key_up :: proc(keycode: sapp.Keycode) -> bool{
	if !key_down[keycode] do return true	
	else do return false
}


//mouse press utils

listen_mouse_single_up :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if single_mouse_up[Mousebutton] {
		single_mouse_up[Mousebutton] = false
		return true	
	} else do return false
}

listen_mouse_single_down :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if single_mouse_down[Mousebutton] {
		single_mouse_down[Mousebutton] = false
		return true	
	} else do return false
}

listen_mouse_down :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if mouse_down[Mousebutton] do return true	
	else do return false
}

listen_mouse_up :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if !mouse_down[Mousebutton] do return true	
	else do return false
}

//checks if the screen has been resized and returns a bool
listen_screen_resized :: proc() -> bool{
	if screen_resized do return true
	else do return false
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

remove_object ::	proc(id: Sprite_id){
	assert(id in g.objects)

	delete_key(&g.objects, id)
}

remove_text_object :: proc(id: string) {
	assert(id in g.text_objects)

	delete_key(&g.text_objects, id)
}

//rotation of objects around center point

vec2_rotation :: proc(objpos: Vec2, centerpos: Vec2, rot: f32) -> Vec2 {
	obj_xform := xform_rotate(-rot)
	obj_xform *= xform_translate(Vec2{objpos.x, -objpos.y} - {centerpos.x, -centerpos.y})

	new_pos2d := Vec2{obj_xform[3][0], obj_xform[3][1]} + Vec2{centerpos.x, -centerpos.y}
	return Vec2{new_pos2d.x, -new_pos2d.y} - objpos
}

vec2_to_vec3 :: proc(vec: Vec2) -> Vec3{
	return Vec3{vec.x, vec.y, 0}
}

//math util

//bit inefficient you could just compare the result to a squared var and not do the sqrt  
get_vector_magnitude :: proc(vec: Vec2) -> f32{
	magv := math.sqrt(math.fmuladd_f32(vec.y, vec.y, vec.x * vec.x))
	return magv
}

//adds some randomness to a vec2 direction
add_randomness_vec2 :: proc(vec: Vec2, randomness: f32) -> Vec2{
	unit_vector := linalg.normalize0(vec)

	random_angle := rand.float32_range(-randomness, randomness)

	new_x := unit_vector.x * math.cos(random_angle) - unit_vector.y * math.sin(random_angle)
	new_y := unit_vector.x * math.sin(random_angle) + unit_vector.y * math.cos(random_angle)

	magnitude := get_vector_magnitude(vec)
	return Vec2{new_x * magnitude, new_y * magnitude}
}

//offsets a vec2 direction
offset_vec2 :: proc(vec: Vec2, offset: f32) -> Vec2{
	unit_vector := linalg.normalize0(vec)


	new_x := unit_vector.x * math.cos(offset) - unit_vector.y * math.sin(offset)
	new_y := unit_vector.x * math.sin(offset) + unit_vector.y * math.cos(offset)

	magnitude := get_vector_magnitude(vec)
	return Vec2{new_x * magnitude, new_y * magnitude}
}

//spring physics
update_spring :: proc(spring: ^Spring){

	force := spring.position - spring.anchor
	x := get_vector_magnitude(force) - spring.restlength
	force = linalg.normalize0(force)
	force *= -1 * spring.force * x
	spring.velocity += force * g.dt
	spring.position += spring.velocity
	spring.velocity *= spring.depletion * g.dt
	
}

//uses springs to do something similar to spring physics but without the springiness. It's more like something like Asympatic averaging.
update_asympatic_spring :: proc(spring: ^Spring){

	force := spring.position - spring.anchor
	x := get_vector_magnitude(force) - spring.restlength
	force = linalg.normalize0(force)
	force *= -1 * spring.force * x
	force *= g.dt
	spring.velocity = force
	spring.position += spring.velocity
}

//asympatic averaging
update_asympatic_averaging :: proc(asym_obj: ^Asympatic_object){
	force := asym_obj.position - asym_obj.destination
	x := get_vector_magnitude(force)
	force = linalg.normalize0(force)
	force *= -1 * x
	force *= g.dt
	force *= asym_obj.depletion
	asym_obj.position += force
}

asympatic_average_transform :: proc(transform: ^Transform, destination: Vec2, depletion: f32){
	force := transform.pos - destination
	x := get_vector_magnitude(force)
	force = linalg.normalize0(force)
	force *= -1 * x
	force *= g.dt
	force *= depletion
	transform.pos += force
}

//init the icon
init_icon :: proc(imagefile: cstring){
	// ICON
	icon_desc := sapp.Icon_Desc{
		images = {0 = get_image_desc(imagefile)}
	}
	sapp.set_icon(icon_desc)
}





// =============
//   :DRAWING
// =============

Sprite_id :: string
Null_sprite_id :: ""

WHITE_IMAGE_PATH : cstring = "./src/assets/textures/WHITE_IMAGE.png"
WHITE_IMAGE : sg.Image

//kinda scuffed but works
init_rect :: proc(
	color: sg.Color = { 1,1,1,1 }, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, tex_index: u8 = tex_indices.default, 
	draw_priority: Draw_layers = .default
) -> string{
	return init_sprite_from_img(WHITE_IMAGE, transform, id, tex_index, draw_priority, color)	
}


init_sprite :: proc{
	init_sprite_from_filename,
	init_sprite_from_img,
}

init_sprite_from_img :: proc(
	img: sg.Image, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, tex_index: 
	u8 = tex_indices.default, 
	draw_priority: Draw_layers = .default, 
	color_offset: sg.Color = { 1,1,1,1 }
) -> string{

	DEFAULT_UV :: Vec4 { 0,0,1,1 }

	id := id
	if id == ""{
		id = generate_string_id()
	}

	buffer := get_vertex_buffer(transform.size, color_offset, DEFAULT_UV, tex_index)

	if id in g.objects == false{
		g.objects[id] = Object_group{}
	}

	object_group := &g.objects[id]

	append(&object_group.objects, Object{
		vec2_to_vec3(transform.pos),
		transform.rot,
		img,
		auto_cast draw_priority,
		buffer,
		transform.size,
	})

	return id
}


//proc for creating a new sprite on the screen and adding it to the objects
init_sprite_from_filename :: proc(
	filename: cstring, 
	transform: Transform = DEFAULT_TRANSFORM, 
	id: Sprite_id = Null_sprite_id, 
	tex_index: u8 = tex_indices.default, 
	draw_priority: Draw_layers = .default
) -> string{
	return init_sprite_from_img(get_image(filename), transform, id, tex_index, draw_priority)	
}

//involves some code duplication
update_sprite :: proc{
	update_sprite_transform,
	update_sprite_transform_image,
	update_sprite_image,
	update_sprite_size,
}

update_sprite_transform_image :: proc(img: sg.Image, transform: Transform, id: Sprite_id){
	assert(id in g.objects)

	for &object in g.objects[id].objects{
		object = Object{
			vec2_to_vec3(transform.pos),
			transform.rot,
			img,
			object.draw_priority,
			object.vertex_buffer,
			object.size,
		}
	}
}

update_sprite_image :: proc(img: sg.Image, id: Sprite_id){
	assert(id in g.objects)

	for &object in g.objects[id].objects{

		object = Object{
			object.pos,
			object.rot,
			img,
			object.draw_priority,
			object.vertex_buffer,
			object.size,
		}
	}
}

update_sprite_transform :: proc(transform: Transform, id: Sprite_id){

	assert(id in g.objects)

	for &object in g.objects[id].objects{

		object = Object{
			vec2_to_vec3(transform.pos),
			transform.rot,
			object.img,
			object.draw_priority,
			object.vertex_buffer,
			object.size,
		}
	}
}

update_sprite_size :: proc(size: Vec2, id: Sprite_id){

	assert(id in g.objects)

	for &object in g.objects[id].objects{
		//update the vertex buffer
		if object.size != size{
			update_vertex_buffer_size(object.vertex_buffer, size)
		}

		object.size = size
	}
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
	cursor = 6,
	top = 7,
}


// TEX_INDICES

Tex_indices :: struct{
	default: u8,
	text: u8,
}

tex_indices := Tex_indices{
	default = 0,
	text = 1,
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
	id: string,
	draw_priority: i32,
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
	font_id: string, 
	text_object_id: string = "text", 
	text_rot : f32 = 0, 
	draw_priority: Draw_layers = .text, 
	draw_from_center: bool = false
) -> string{
	using stbtt

	assert(font_id in g.fonts)

	assert(text_object_id in g.text_objects == false)
	
	text_object_id := text_object_id
	if text_object_id == ""{
		text_object_id = generate_string_id()
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
		xform *= xform_translate(pos)
		xform *= xform_scale(Vec2{auto_cast scale, auto_cast scale})
		xform *= xform_translate(offset_to_render_at)
		

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
		draw_from_center
	)
	
	return text_object_id
}

append_text_object :: proc(
	rot: Vec3, 
	text_objects: [dynamic]Char_object, 
	text_object_id: string, 
	text_pos: Vec2, 
	draw_priority: i32, 
	draw_from_center: bool
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

			obj.rotation_pos_offset = vec2_rotation(Vec2{obj.pos.x, obj.pos.y}, text_center, obj.rot.z)
		}
	}
	
	//add the text objects to the text objects
	g.text_objects[text_object_id] = Text_object{
		text_objects,
		text_center,
		text_rot,
		text_object_id,
		draw_priority,
	}

	//show the center point of the text
	//init_rect(color = sg_color(color3 = Vec3{255, 255, 255}), text_center, {0.05, 0.05}, "center")
}

//initiate font and add it to the g.fonts
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
	tex_index: u8 = tex_indices.text
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
update_text_object :: proc(pos: Vec2, rot: f32, id: string){
	update_text_rot(rot, id)
	update_text_pos(pos, id)

}

update_text_rot :: proc(rot: f32, id: string){
	assert(id in g.text_objects)

	text_object := &g.text_objects[id]

	rotation := Vec3{0, 0, rot}

	text_object.rot = rotation

	for &obj in text_object.objects{

		obj.rot = rotation
		obj.rotation_pos_offset = vec2_rotation(Vec2{obj.pos.x, obj.pos.y}, text_object.pos, obj.rot.z)
	}
}

update_text_pos :: proc(pos: Vec2, id: string){
	assert(id in g.text_objects)

	text_object := &g.text_objects[id]


	motion := pos - text_object.pos
	text_object.pos = pos
	for &obj in text_object.objects{
		obj.pos += Vec3{motion.x, motion.y, 0}
	}
}

// ================
//    :ENTETIES
// ================
/*
	Enteties uses the odin-ecs lib and is mainly meant for items and other stuff that can't be type specific
	( I need to be able to give any item to my player regardless of what type it is or what data it has )
*/


Enteties :: map[string]Entity
Entity :: struct{
	entity: ecs.Entity,
	tags: [dynamic]Entity_tags
}

Entity_tags :: enum{
	Item,
	Projectile_weapon,
}

create_entity :: proc(id: string, tags: [dynamic]Entity_tags){
	g.enteties[id] = Entity{
		entity = ecs.create_entity(&ctx),
		tags = tags,
	}
}

entity_add_component :: proc(id: string, component: $T){
	temp, error := ecs.add_component(&ctx, g.enteties[id].entity, component)
	if error != .NO_ERROR do log.debug(error)
}

//get a component using an ecs.Entity or an id
entity_get_component :: proc{
	entity_entity_get_component,
	entity_id_get_component,
}

entity_entity_get_component :: proc(entity: ecs.Entity, $component_type: typeid) -> ^component_type{
	component, error := ecs.get_component(&ctx, entity, component_type)
	if error != .NO_ERROR do log.debug(error)
	return component
}

entity_id_get_component :: proc(id: string, $component_type: typeid) -> ^component_type{
	return entity_entity_get_component(g.enteties[id].entity, component_type)
}

entity_log_component_ptr  :: proc(entity: ecs.Entity, $component_type: typeid){
	component, error := ecs.get_component(&ctx, entity, component_type)
	if error != .NO_ERROR do log.debug(error)
	log.debug(&component)
}

//destroy an entity using an ecs.Entity or an id
destroy_entity :: proc{
	destroy_entity_entity,
	destroy_entity_id,
}

destroy_entity_entity :: proc(entity: ecs.Entity){
	ecs.destroy_entity(&ctx, entity)
}

destroy_entity_id :: proc(id: string){
	ecs.destroy_entity(&ctx, g.enteties[id].entity)
}



//COMPONENTS

Item_data :: struct{
	img: sg.Image,
	size: Vec2,
}

init_item :: proc(transform: ^Transform, item_data: Item_data) -> Sprite_id{
	transform.size = item_data.size
	return init_sprite(item_data.img, transform^, "", draw_priority = .item)
}

update_item :: proc(transform: Transform, item_data: Item_data, sprite_id: string){
	update_sprite(img = item_data.img, transform = transform, id = sprite_id)
}

//projectile weapon
Projectile_weapon :: struct{
	//id of the cooldown object that is linked to this weapon
	cooldown_object: Cooldown,
	//cooldown of the weapon
	cooldown: f32,
	//shoot button
	trigger: sapp.Mousebutton,
	//a radian value that uses the add_randomness_vec2 function to add some randomness to the projectile directions
	random_spread: f32,
	//how far apart shots will be also in radians
	spread: f32,
	//number of shots the weapon fires
	shots: int,
	//add some camera shake to the shot
	camera_shake: f32,
	//the default values of the projectiles
	projectile: Projectile,
	
	automatic: bool,
}

//init function that runs when the item holder inits with a projectile weapon or when a projectile weapon is given to an item holder
init_projectile_weapon :: proc(weapon: ^Projectile_weapon){	
	weapon.cooldown_object = init_cooldown_object(weapon.cooldown)	
}

reset_projectile_weapon :: proc(projectiles: ^Projectile_weapon){
	
}

//update function runs that runs every frame inside of item holder ( only if the item is equiped ofc )
update_projectile_weapon :: proc(weapon: ^Projectile_weapon, shoot_dir: Vec2, shoot_pos: Vec2){
	//add a projectile to the array if you press the right trigger
	should_shoot: bool
	
	if cooldown_enabled(weapon.cooldown_object) do should_shoot = false
	else if !weapon.automatic do should_shoot = listen_mouse_single_down(weapon.trigger)
	else do should_shoot = listen_mouse_down(weapon.trigger)

	if should_shoot{
		start_cooldown(weapon.cooldown_object)
		for i := 0; i < weapon.shots; i += 1{
						
			sprite_id := generate_string_id()
		
			//offset position of shots if we shoot multiple
			shoot_dir := shoot_dir
			if weapon.shots > 1{
				offset := (f32(i)-math.floor(f32(weapon.shots/2)))	* weapon.spread
				shoot_dir = offset_vec2(shoot_dir, offset)
			}

			init_projectile(weapon.projectile, shoot_pos, add_randomness_vec2(shoot_dir, weapon.random_spread), sprite_id)
		}
			
		shake_camera(weapon.camera_shake)
	}
}

//projectile
Projectile :: struct{
	img: sg.Image,
	lifetime: f32,
	speed: f32,
	damage: f32,
	
	transform: Transform,	
	sprite_id: string,
	duration: f32,
	dir: Vec2,
}

update_projectiles :: proc(projectiles: ^[dynamic]Projectile){
	//update the projectiles and check if they should be removed	
	for i := 0; i < len(projectiles); i+=1{
		update_projectile(&projectiles[i])

		if projectiles[i].duration > projectiles[i].lifetime{
			remove_projectile(&projectiles[i])
			ordered_remove(projectiles, i)
			i-=1
		}
	}
}

//update the projectile
update_projectile :: proc(projectile: ^Projectile){
	projectile.duration += g.dt
	projectile.transform.pos += projectile.dir * projectile.speed * g.dt
	update_sprite(transform = projectile.transform, id = projectile.sprite_id)
}

//init a projectile
init_projectile :: proc(
	projectile_data: Projectile, 
	shoot_pos: Vec2, 
	dir: Vec2, 
	sprite_id: string
){
	append(&game_state.projectiles, projectile_data)
	projectile := &game_state.projectiles[len(game_state.projectiles)-1]
	transform := &projectile.transform

	transform.pos = shoot_pos
	projectile.dir = dir
	transform.rot.z = linalg.to_degrees(linalg.atan2(projectile.dir.y, projectile.dir.x))
	projectile.sprite_id = sprite_id
	
	init_sprite(img = projectile.img, transform = transform^, id = projectile.sprite_id)
}

remove_projectile :: proc(projectile: ^Projectile){
	//remove the projectile sprite
	remove_object(projectile.sprite_id)
}



// ITEM HOLDER

//item holder is an obj that can display and update an entity with the item tag
Item_holder :: struct{
	transform: Transform,	
	item: Entity,
	sprite_id: Sprite_id,
	//if items like guns should be equipped
	equipped: bool,
}

//init an item holder and check for certain tags
init_item_holder :: proc(holder: ^Item_holder){

	item := holder.item
	assert(contains(item.tags, Entity_tags.Item))

	#partial switch tag2 := item.tags[get_next_index(item.tags, Entity_tags.Item)]; tag2{
	case .Projectile_weapon:
		if holder.equipped{
			pweapon := entity_get_component(entity = item.entity, component_type = Projectile_weapon) 
			init_projectile_weapon(pweapon)
		}
	}

	item_data := entity_get_component(entity = item.entity, component_type = Item_data)
	holder.sprite_id = init_item(&holder.transform, item_data^)
}


//update the item holder and check for certain tags
update_item_holder :: proc(
	holder: Item_holder, 
	look_dir: Vec2 = {1, 0}, 
	shoot_pos: Vec2 = {0, 0}
){
	//the players item
	item := holder.item
	#partial switch tag2 := item.tags[get_next_index(item.tags, Entity_tags.Item)]; tag2{
	case .Projectile_weapon:
		if holder.equipped{
			pweapon := entity_get_component(entity = item.entity, component_type = Projectile_weapon) 
			update_projectile_weapon(pweapon, look_dir, shoot_pos)
		}		
	}

	item_data := entity_get_component(entity = item.entity, component_type = Item_data)
	update_item(holder.transform, item_data^, holder.sprite_id)
}

//gives an item to the item holder which potentially replaces the old one, the inits the holder
give_item :: proc(holder: ^Item_holder, item_id: string){
	assert(item_id in g.enteties)
	
	remove_object(holder.sprite_id)
	holder.item = g.enteties[item_id]
	init_item_holder(holder)
}



// ==============
//     :GAME
// ==============

//game specific globals
Game_state :: struct{
	background_sprite: Sprite_id,
	projectiles: [dynamic]Projectile,
	cooldowns: map[Cooldown]Cooldown_object,
}

game_state: ^Game_state

//test vars
test_text_rot: f32
test_text_rot_speed: f32 = 120
test_text_id: string

init_game_state :: proc(){
	game_state = new(Game_state)

	init_items()
	init_rect(transform = Transform{size = {0.2, 0.2}, pos = {1, 2}}, color = {1, 0, 0, 1})
	sapp.show_mouse(false)
	sapp.lock_mouse(true)

	init_player()	

	init_camera()

	init_font(font_path = "./src/assets/fonts/MedodicaRegular.otf", id = "font1", font_h = 32)
	
	test_text_id = init_text(
		text = "TÅST", 
		draw_from_center = true, 
		text_rot = test_text_rot, 
		pos = {0, 1}, 
		scale = 0.03, 
		color = sg_color(color3 = Vec3{138,43,226}), 
		font_id = "font1"
	)

	init_rect(color = sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {0, 2.5}, size = {10, .2}, rot = {0, 0, 0}}, draw_priority = .environment)
	init_rect(color = sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {0, -2.5}, size = {10, .2}, rot = {0, 0, 0}}, draw_priority = .environment)
	init_rect(color = sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {4.9, 0}, size = {.2, 4.8}, rot = {0, 0, 0}}, draw_priority = .environment)
	init_rect(color = sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {-4.9, 0}, size = {.2, 4.8}, rot = {0, 0, 0}}, draw_priority = .environment)

	init_cursor()

	init_background({112, 112, 112})
}

update_game_state :: proc(){

	event_listener()

	update_projectiles(&game_state.projectiles)
	update_cooldowns()
	//move_camera_3D()
	update_player()

	update_camera()

	update_cursor()
	
	test_text_rot -= test_text_rot_speed * g.dt
	update_text(test_text_rot, test_text_id)


	update_background();

	mouse_move = {}
	g.runtime += g.dt
	g.frame_count += 1
}

//updates every x seconds
fixed_update_game_state :: proc(){
	
}

//proc for quiting the game immediately, is called in the beginning of the frame if g.should_quit == true
quit_game :: proc(){
	sapp.quit()
}

//for testing
tempiteminc: int

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

	if listen_key_single_down(.F){
		if tempiteminc %% 2 == 0{
			give_item(&g.player.holder, "otto")
			tempiteminc += 1
		}else{
			give_item(&g.player.holder, "gun")
			tempiteminc -= 1
		}
	}

	if !sapp.mouse_locked() && listen_mouse_single_down(.LEFT) do sapp.lock_mouse(true)
}

// PLAYER
Player :: struct{
	sprite_id: Sprite_id,
	sprite_filename: cstring,
	transform: Transform,	
	xflip: f32,
	xflip_threshold: f32,
	
	move_dir: Vec2,
	look_dir: Vec2,
	
	default_move_speed: f32,
	move_speed: f32,
	current_move_speed: f32,
	
	dash: Dash_data,
	sprint: Sprint_data,

	acceleration: f32,
	deceleration: f32,
	duration: f32,

	holder: Item_holder,
	item_offset: Vec2,
}

init_player :: proc(){
	// setup the player

	g.player = Player{
		sprite_filename = "./src/assets/textures/Random.png",
		
		transform = {
			size = { 1,1 }
		},
		//used for flipping the player sprite in the x dir, kinda temporary(should replace later)
		xflip = -1,
		//how far over the player you have to go for it to flip
		xflip_threshold = 0.25,
		
		move_dir = {1, 0},
		default_move_speed = 4,
		
		acceleration = 16.2,
		deceleration = 18,

		holder = {
			item = g.enteties["gun"],
			equipped = true,
		},
		
		//how far away from the player an item is
		item_offset = Vec2{0.3, -0.05},
	}
	g.player.move_speed = g.player.default_move_speed
	init_player_abilities()

	//init the players sprite
	g.player.sprite_id = init_sprite(g.player.sprite_filename, g.player.transform)
	//init the players item_holder
	init_item_holder(&g.player.holder)
}


player_acceleration_ease :: proc(x: f32) -> f32 {
	ease := 1 - math.pow(1 - x, 3);

	return ease
}

player_deceleration_ease :: proc(x: f32) -> f32 {
	ease := x

	return ease
}

update_player :: proc() {
	player := &g.player
	transform := &player.transform

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

	//for flipping the player sprite
	if g.cursor.world_transform.pos.x <= transform.pos.x+ player.xflip_threshold*player.xflip{
		player.xflip = 1
	} else {
		player.xflip = -1
	}

	transform.rot.x = (player.xflip + 1) * 90
	//g.player.look_dir = linalg.normalize0(g.cursor.pos-(g.player.pos - Vec2{g.camera.position.x, g.camera.position.y}))
	//g.player.look_dir = g.player.move_dir

	update_player_abilities()
	
	//player movement with easing curves
	if move_input != 0 {
		player.move_dir = up * move_input.y + right * move_input.x
		
		//increase duration with the acceleration
		player.duration += player.acceleration * g.dt
		//clamp the duration between 0 and 1
		player.duration = math.clamp(player.duration, 0, 1)
		//the speed becomes the desired speed times the acceleration easing curve based on the duration value of 0 to 1
		player.current_move_speed = player.move_speed * player_acceleration_ease(g.player.duration)
	} else {
		
		//the duration decreses with the deceleration when not giving any input
		player.duration -= player.deceleration * g.dt
		//the duration is still clamped between 0 and 1
		player.duration = math.clamp(player.duration, 0, 1)
		//the speed is set to the desired speed times the deceleration easing of the duration
		player.current_move_speed = player.move_speed * player_deceleration_ease(player.duration)
	}	

	
	motion = linalg.normalize0(player.move_dir) * player.current_move_speed * g.dt

	//update the item holder of the player
	holder := &player.holder


	//pos
	holder_item_data := entity_get_component(entity = holder.item.entity, component_type = Item_data) 
	holder_offset := (holder_item_data^.size.x/2) 
	holder_rotation_pos := transform.pos + ( player.item_offset.x * player.xflip)
	new_holder_pos := Vec2{(player.item_offset.x)*-player.xflip, transform.pos.y}

	holder_rotation_vector := linalg.normalize0(g.cursor.world_transform.pos-(transform.pos))
	if holder_rotation_vector == {0, 0} do holder_rotation_vector = {1, 0}


	holder.transform.pos = transform.pos + (holder_rotation_vector*(holder_offset))
	holder.transform.pos.y += player.item_offset.y
	holder.transform.pos.x += new_holder_pos.x

	//rot

	new_holder_rotation := to_degrees(linalg.atan2(holder_rotation_vector.y, holder_rotation_vector.x))
	holder.transform.rot.z = new_holder_rotation
	holder.transform.rot.x = transform.rot.z


	
	//where the bullet should come from if it is a gun
	shoot_pos_offset := holder_rotation_vector * holder_item_data.size.x/2
	shoot_pos := player.holder.transform.pos + shoot_pos_offset
	update_item_holder(holder^, holder_rotation_vector, shoot_pos)

	//creates a player rotation based of the movement
	transform.rot.z = to_degrees(math.atan2(player.look_dir.y, player.look_dir.x))

	transform.pos += motion
	update_sprite(transform = transform^, id = player.sprite_id)
}


// PLAYER ABILITIES

init_player_abilities :: proc(){
	init_player_dash()
	init_player_sprint()
}

update_player_abilities :: proc(){
	//check for sprint
	if listen_key_down(g.player.sprint.button) do g.player.sprint.enabled = true
	else do g.player.sprint.enabled = false
	update_sprint()

	//check for dash
	if listen_key_single_down(g.player.dash.button){
		g.player.dash.enabled = true
	}
	if g.player.dash.enabled{
		update_player_dash(&g.player.dash)
	}
}

//DASH ABILITY


// TODO: could make dashes better by replacing dash speed with how long the dash should take(dash time)
Dash_data :: struct{
	enabled: bool,
	dash_distance: f32,
	button: sapp.Keycode,
	dash_speed: f32,
	duration: f32,
	last_distance: f32,
	distance: f32,
	cutoff: f32,
}



init_player_dash :: proc(){
	g.player.dash = Dash_data{
		enabled = false,
		//distance that is going to be traveled by the player
		dash_distance = 1.6,
		//dash button
		button = .SPACE,
		//How fast it travels
		dash_speed = 5,
		//cutoff var for cutting off the ease function
		cutoff = 0.96,
	}
}

dash_ease :: proc(x: f32) -> f32 {
	ease := 1 - math.pow(1 - x, 3);

	return ease
}

update_player_dash :: proc(dash: ^Dash_data){
	dash.duration += dash.dash_speed * g.dt
	dash.distance =  dash_ease(dash.duration)

	transform := &g.player.transform


	// do the ability
	dash_motion := linalg.normalize0(g.player.move_dir) * (dash.dash_distance/dash.cutoff)
	transform.pos += dash_motion * (dash.distance-dash.last_distance)
	g.player.move_speed = 0

	dash.last_distance = dash.distance
	
	if dash.distance >= dash.cutoff{
		
		g.player.move_speed = g.player.default_move_speed
		g.player.dash.distance = 0
		g.player.dash.last_distance = 0
		g.player.dash.duration = 0
		g.player.dash.enabled = false
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

init_player_sprint :: proc(){
	g.player.sprint = {
		enabled = false,
		button = .LEFT_SHIFT,
		speed = 5.5,
	}
}

update_sprint :: proc(){
	if g.player.sprint.enabled do g.player.move_speed = g.player.sprint.speed
	else do g.player.move_speed = g.player.default_move_speed
}

//ITEM INITS

init_items :: proc(){
	init_weapons()

	empty_item_data := Item_data{
		img = get_image("./src/assets/textures/transparent.png"),
		size = {1, 1},
	}
	create_entity("empty", {.Item})
	entity_add_component("empty", empty_item_data)

}

init_weapons :: proc(){

	// GUUN
	gun_weapon_data := Projectile_weapon{
		trigger = .LEFT,
		random_spread = 0.05,
		shots = 1,
		cooldown = 0.22,
		automatic = true,
		camera_shake = 1.4,
		projectile = Projectile{
			img = get_image(WHITE_IMAGE_PATH),
			transform = Transform{
				size = {0.15, 0.15}
			},
			lifetime = 2,
			speed = 25,
			damage = 0,
		},
	}
	gun_item_data := Item_data{
		img = get_image(WHITE_IMAGE_PATH),
		size = {1, 0.2}
	}
	
	create_entity("gun", {.Item, .Projectile_weapon})	
	entity_add_component("gun", gun_item_data)
	entity_add_component("gun", gun_weapon_data)

	arvid_weapon_data := Projectile_weapon{
		trigger = .LEFT,
		random_spread = 0.3,
		shots = 5,
		cooldown = 0.5,
		spread = 0.12,
		camera_shake = 1.6,
		projectile = Projectile{
			img = get_image(WHITE_IMAGE_PATH),
			transform = Transform{
				size = {0.2, 0.2}
			},
			lifetime = 2,
			speed = 20,
			damage = 0,
		},
	}
	arvid_item_data := Item_data{
		img = get_image(WHITE_IMAGE_PATH),
		size = {0.7, 0.2}
	}
	create_entity("arvid", {.Item, .Projectile_weapon})	
	entity_add_component("arvid", arvid_item_data)
	entity_add_component("arvid", arvid_weapon_data)

	otto_weapon_data := Projectile_weapon{
		trigger = .LEFT,
		random_spread = 0.2,
		shots = 1,
		cooldown = .06,
		spread = 0,
		camera_shake = 1.1,
		automatic = true,
		projectile = Projectile{
			img = get_image(WHITE_IMAGE_PATH),
			transform = Transform{
				size = {0.1, 0.1}
			},
			lifetime = 2,
			speed = 18,
			damage = 0,
		},
	}
	otto_item_data := Item_data{
		img = get_image(WHITE_IMAGE_PATH),
		size = {2, 0.2}
	}
	create_entity("otto", {.Item, .Projectile_weapon})	
	entity_add_component("otto", otto_item_data)
	entity_add_component("otto", otto_weapon_data)



}

// ====================
//   :CAMERA :CURSOR :BACKGROUND
// ====================

// BACKGROUND


init_background :: proc(color: Vec3 = {255, 255, 255}){
	game_state.background_sprite = init_rect(
		color = sg_color(color3 = color),  
		transform = Transform{size = get_screen_size_in_world(0)}, 
		draw_priority = .background
	)
}

update_background :: proc(){
	background_counter_rotation: Vec3
	if g.camera.rotation != 0 do background_counter_rotation = {0, 0, 360 - to_degrees(g.camera.rotation)}
	
	update_sprite(
		transform = Transform{pos = g.camera.position.xy, rot = background_counter_rotation}, 
		id = game_state.background_sprite
	)

	if listen_screen_resized() do update_sprite_size(get_screen_size_in_world(0), game_state.background_sprite)
}

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
	g.cursor = Cursor{
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
	
	//transform the pixel size to world size
	g.cursor.transform.size = get_pixel_size_in_world(g.cursor.transform.size, 0);

	g.cursor.sprite_id = init_sprite(
		filename = g.cursor.filename, 
		transform = g.cursor.transform, 
		draw_priority = .cursor
	)
}

update_cursor :: proc(){
	g.cursor.transform.pos += (Vec2{mouse_move.x, -mouse_move.y} * g.cursor.sensitivity) * g.dt
	check_cursor_collision()
	g.cursor.world_transform = Transform{
		pos = (g.camera.position.xy-g.camera.camera_shake.pos_offset) + g.cursor.transform.pos,
		size = g.cursor.transform.size,
		rot = g.cursor.transform.rot,
	}
	update_sprite(transform = g.cursor.world_transform, id = g.cursor.sprite_id)
}

//check the cursor collision with the screen
check_cursor_collision :: proc (){

	transform := &g.cursor.transform
	pos := &transform.pos
	size := &transform.size

	collision_offset := Vec2 {size.x/2, size.y/2}
	screen_size_world := get_screen_size_in_world(0)

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

camera_follow_cursor :: proc(){
	//camera follows cursor

	cursor_dir := g.cursor.world_transform.pos-(g.player.transform.pos)

	lookahead := get_vector_magnitude(cursor_dir)

	lookahead = math.clamp(lookahead, -g.cursor.lookahead_distance, g.cursor.lookahead_distance)

	lookahead /= g.cursor.lookahead

	camera_follow(g.player.transform.pos, lookahead, cursor_dir)
}

camera_follow_player :: proc(lookahead: f32 = 0){
	camera_follow(g.player.transform.pos, lookahead, g.player.look_dir)
}

// CAMERA

Camera :: struct{
	rotation: f32, // in radians
	position: Vec3,
	target: Vec3,
	look: Vec2,
	//an object for the asympatic averaging of the camera movement
	asym_obj: Asympatic_object,
	asym_forces: [dynamic]Asympatic_depletion,
	zoom: Camera_zoom,

	lookahead_asym_obj: Asympatic_object,

	camera_shake: Camera_shake,
}

Asympatic_depletion :: struct{
	depletion: f32,
	threshold: f32,
}

Camera_zoom :: struct{
	max: f32,
	threshold: f32,
	default: f32,
	speed: f32,
	enabled: bool,
}

LOOK_SENSITIVITY :: 0.3

init_camera :: proc(){
	//setup the camera
	g.camera = {
		rotation = 0,
		position = { 0,0,11 },
		//what the camera is looking at
		target = { 0,0,-1 },
		//how much to zoom out, when to max out and how fast to zoom
		zoom = {
			max = 12,
			threshold = 0.0002,
			speed = 5,
			enabled = false,
		},

		//spring forces has to be in order
		//the camera will go between these values smoothly
		asym_forces = {
			//when standing still
			{14, 0},
			//when walking
			{11, 0.0002},
			//when sprinting
			{13, 0.00035},
			//max speed
			{16, 0.0004}
		},


		//a spring for the lookahead of the camera
		lookahead_asym_obj = Asympatic_object{
			depletion = 25,
		}
	}

	//set the camera zoom position
	g.camera.zoom.default = g.camera.position.z

	//set the camera positions to the player
	g.camera.position.x = g.player.transform.pos.x
	g.camera.position.y = g.player.transform.pos.y
	g.camera.target.x = g.player.transform.pos.x
	g.camera.target.y = g.player.transform.pos.y
	g.camera.asym_obj.position = g.player.transform.pos
	g.camera.asym_obj.destination = g.player.transform.pos
	g.camera.lookahead_asym_obj.position = g.player.transform.pos
	g.camera.lookahead_asym_obj.destination = g.player.transform.pos

	init_camera_shake()

}

last_pos: Vec2
current_pos: Vec2


//follows a 2d position 
camera_follow :: proc(position: Vec2, lookahead: f32 = 0, lookahead_dir: Vec2 = {0, 0}) {

	current_pos := position

	//pos camera wants to look at
	lookahead_pos := (linalg.normalize0(lookahead_dir) * lookahead)
	g.camera.lookahead_asym_obj.destination = lookahead_pos

	g.camera.asym_obj.destination = position

	//difference pos between last frame and this frame
	pos_difference := current_pos - last_pos
	//how fast the player is moving
	move_mag := get_vector_magnitude(pos_difference) * g.dt

	//change the spring force with a gradient between different values
	for i := 0; i<len(g.camera.asym_forces); i+=1 {
		//the current threshold and force values
		sf := g.camera.asym_forces[i]
		
		if move_mag < sf.threshold do break
		//if we are not in the last element of the array
		if i < len(g.camera.asym_forces) -1 {
			//the next threshold and force values
			next_sf := g.camera.asym_forces[i+1]

			//difference between the different thresholds
			threshold_player_diff := move_mag - sf.threshold
			threshold_diff := next_sf.threshold - sf.threshold

			//how much of the threshold value we are at
			value_index := threshold_player_diff/threshold_diff

			//adds a percentage of the next spring force dependent on our movement speed
			g.camera.asym_obj.depletion = sf.depletion + math.lerp(sf.threshold, next_sf.threshold, value_index) 
		//if we are in the last element of the aray. Means we are at the max values
		} else {
			g.camera.asym_obj.depletion = sf.depletion
		}
	}

	//change how much the camera is zoomed out ( depentent on movement speed )
	// only need to update if we actually have any zoom and if it's enabled
	if g.camera.zoom.default != g.camera.zoom.max && g.camera.zoom.enabled{
		zoom_value_index := (move_mag/g.camera.zoom.threshold)
		zoom_value_index = math.clamp(zoom_value_index, 0, 1)

		//desired zoom position
		zoom_zpos := math.lerp(g.camera.zoom.default, g.camera.zoom.max, zoom_value_index)

		//slowly moves the z pos of camera to the desired zoom position
		if zoom_zpos > g.camera.position.z{
			g.camera.position.z += g.camera.zoom.speed * g.dt
		} else if zoom_zpos < g.camera.position.z{
			g.camera.position.z -= g.camera.zoom.speed * g.dt
		}
	}

	
	//update the spring physics and update the camera position
	update_asympatic_averaging(&g.camera.asym_obj)
	update_asympatic_averaging(&g.camera.lookahead_asym_obj)

	last_pos = current_pos

}

update_camera_position :: proc(position: Vec2, rotation: f32){
	g.camera.position = Vec3{position.x, position.y, g.camera.position.z}
	g.camera.target = Vec3{position.x ,position.y, g.camera.target.z}
	g.camera.rotation = rotation
}

update_camera :: proc(){
	update_camera_shake()

	camera_follow_cursor()

	update_camera_position(g.camera.asym_obj.position + g.camera.lookahead_asym_obj.position + g.camera.camera_shake.pos_offset, g.camera.camera_shake.rot_offset)
}


//function for moving around camera in 3D
move_camera_3D :: proc() {
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

	motion := linalg.normalize0(move_dir) * g.player.move_speed * g.dt
	g.camera.position += motion

	g.camera.target = g.camera.position + forward
}

//shake the camera by setting the trauma
shake_camera :: proc(trauma: f32){
	g.camera.camera_shake.trauma = trauma
}


// 
// CAMERA SHAKE
// 

Camera_shake :: struct {
	trauma: f32,
	depletion: f32,
	pos_offset: Vec2,
	rot_offset: f32, // in radians
	seed: i64,
	time_offset: Vec2,
}

init_camera_shake :: proc(){
	g.camera.camera_shake = Camera_shake{
		trauma = 0,
		depletion = 8,
		pos_offset = { 0,0 },
		rot_offset = 0,
		seed = 223492,
		time_offset = { 5,5 }
	}
}

update_camera_shake :: proc(){
	cs := &g.camera.camera_shake
	if cs.trauma <= 0{
		cs.pos_offset = { 0,0 }
		cs.rot_offset = 0
		cs.trauma = 0
	} else {
		seedpos := noise.Vec2{f64(cs.time_offset.x * g.runtime), f64(cs.time_offset.y * g.runtime)}

		cs.pos_offset = Vec2{noise.noise_2d(cs.seed, seedpos), noise.noise_2d(cs.seed + 1, seedpos)}
		cs.pos_offset /= 45
		cs.pos_offset *= cs.trauma * cs.trauma
		cs.rot_offset = noise.noise_2d(cs.seed+2, seedpos)
		cs.rot_offset /= 100
		cs.rot_offset *= cs.trauma * cs.trauma * cs.trauma

		cs.trauma -= cs.depletion * g.dt
	}
}

