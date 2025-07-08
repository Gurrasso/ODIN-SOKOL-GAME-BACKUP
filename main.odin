#+feature dynamic-literals
package main

/*
	TODO: 

	make sure we arent leaking a bunch of memory,
	delete vertex buffers and images that arent in use? Maybe rework the vertex buffer system a little?,

	make lighting have a little effect when its bright,

	use uuid:s,

	maybe try and implement everything as an entity,

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

	make it so item holders can hold nothing,
	weapons dont work for multiple enteties at a time,
	
	make sure we use the same naming for pos, rot etc everywhere,

	maybe dont use cooldowns for the animations instead doing some sort of mod of the runtime might be better?,
	
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
import "core:os"
import "core:math/linalg"
// sokol imports
import sapp "../sokol/app"
import shelpers "../sokol/helpers"
import sg "../sokol/gfx"

import "utils"
import "draw"
import "game"
import "events"
import "enteties"
import "utils/cooldown"

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

// ============== 
//     :MAIN
// ==============

main :: proc(){
	//logger
	context.logger = log.create_console_logger()
	default_context = context
	
	enteties.enteties_init()

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

	utils.init_utils()

	WHITE_IMAGE = draw.WHITE_IMAGE

	draw.init_draw_state()

	game.init_game_state()
}



//cleanup
cleanup_cb :: proc "c" (){
	context = default_context
	
	draw.draw_cleanup()

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
	game.fixed_update_game_state()
}

//Every frame
frame_cb :: proc "c" (){
	context = default_context
	
	utils.update_utils()

	cooldown.update_cooldowns()

	if events.screen_resized do utils.screen_size = Vec2{sapp.widthf(), sapp.heightf()}

	time_since_fixed_update += utils.dt

	//fixed update
	if time_since_fixed_update > FIXED_UPDATE_TIME{
		fixed_frame_cb()
		time_since_fixed_update = 0
	}

	//updates
	game.update_game_state()

	if events.listen_screen_resized() do events.screen_resized = false

	draw.draw_draw_state()
}

//Events
event_cb :: proc "c" (ev: ^sapp.Event){
	context = default_context
	events.update_events(ev)
}



//spring physics
update_spring :: proc(spring: ^Spring){

	force := spring.position - spring.anchor
	x := utils.get_vector_magnitude(force) - spring.restlength
	force = linalg.normalize0(force)
	force *= -1 * spring.force * x
	spring.velocity += force * utils.dt
	spring.position += spring.velocity
	spring.velocity *= spring.depletion * utils.dt
	
}


//uses springs to do something similar to spring physics but without the springiness. It's more like something like Asympatic averaging.
update_asympatic_spring :: proc(spring: ^Spring){

	force := spring.position - spring.anchor
	x := utils.get_vector_magnitude(force) - spring.restlength
	force = linalg.normalize0(force)
	force *= -1 * spring.force * x
	force *= utils.dt
	spring.velocity = force
	spring.position += spring.velocity
}


//init the icon
init_icon :: proc(imagefile: cstring){
	// ICON
	icon_desc := sapp.Icon_Desc{
		images = {0 = draw.get_image_desc(imagefile)}
	}
	sapp.set_icon(icon_desc)
}
