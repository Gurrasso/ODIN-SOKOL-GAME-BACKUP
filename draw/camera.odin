#+feature dynamic-literals
package draw

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
// sokol imports
import sapp "../../sokol/app"
import sg "../../sokol/gfx"

import "../utils"
import ev "../events"

Asympatic_object :: struct{
	depletion: f32,
	position: Vec2,
	destination: Vec2,
}


//asympatic averaging
update_asympatic_averaging :: proc(asym_obj: ^Asympatic_object){
	force := asym_obj.position - asym_obj.destination
	x := utils.get_vector_magnitude(force)
	force = linalg.normalize0(force)
	force *= -1 * x
	force *= utils.dt
	force *= asym_obj.depletion
	asym_obj.position += force
}

asympatic_average_transform :: proc(transform: ^Transform, destination: Vec2, depletion: f32){
	force := transform.pos - destination
	x := utils.get_vector_magnitude(force)
	force = linalg.normalize0(force)
	force *= -1 * x
	force *= utils.dt
	force *= depletion
	transform.pos += force
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

camera: Camera

init_camera :: proc(){

	//setup the camera
	camera = {
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
	camera.zoom.default = camera.position.z

	init_camera_shake()

}

last_pos: Vec2
current_pos: Vec2


//follows a 2d position 
camera_follow :: proc(position: Vec2, lookahead: f32 = 0, lookahead_dir: Vec2 = {0, 0}) {

	current_pos := position

	//pos camera wants to look at
	lookahead_pos := (linalg.normalize0(lookahead_dir) * lookahead)
	camera.lookahead_asym_obj.destination = lookahead_pos

	camera.asym_obj.destination = position

	//difference pos between last frame and this frame
	pos_difference := current_pos - last_pos
	//how fast the player is moving
	move_mag := utils.get_vector_magnitude(pos_difference) * utils.dt

	//change the spring force with a gradient between different values
	for i in 0..<len(camera.asym_forces) {
		//the current threshold and force values
		sf := camera.asym_forces[i]
		
		if move_mag < sf.threshold do break
		//if we are not in the last element of the array
		if i < len(camera.asym_forces) -1 {
			//the next threshold and force values
			next_sf := camera.asym_forces[i+1]

			//difference between the different thresholds
			threshold_player_diff := move_mag - sf.threshold
			threshold_diff := next_sf.threshold - sf.threshold

			//how much of the threshold value we are at
			value_index := threshold_player_diff/threshold_diff

			//adds a percentage of the next spring force dependent on our movement speed
			camera.asym_obj.depletion = sf.depletion + math.lerp(sf.threshold, next_sf.threshold, value_index) 
		//if we are in the last element of the aray. Means we are at the max values
		} else {
			camera.asym_obj.depletion = sf.depletion
		}
	}

	//update the spring physics and update the camera position
	update_asympatic_averaging(&camera.asym_obj)
	update_asympatic_averaging(&camera.lookahead_asym_obj)

	last_pos = current_pos

}

update_camera_position :: proc(position: Vec2, rotation: f32){
	camera.position = Vec3{position.x, position.y, camera.position.z}
	camera.target = Vec3{position.x ,position.y, camera.target.z}
	camera.rotation = rotation
}



//function for moving around camera in 3D
move_camera_3D :: proc() {
	move_input: Vec2
	if ev.key_down[.W] do move_input.y = 1
	else if ev.key_down[.S] do move_input.y = -1
	if ev.key_down[.A] do move_input.x = -1
	else if ev.key_down[.D] do move_input.x = 1

	look_input: Vec2 = -ev.mouse_move * LOOK_SENSITIVITY
	camera.look += look_input
	camera.look.x = math.wrap(camera.look.x, 360)
	camera.look.y = math.clamp(camera.look.y, -89, 89)

	look_mat := linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(camera.look.x), to_radians(camera.look.y), 0)
	forward := ( look_mat * Vec4 {0,0,-1,1} ).xyz
	right := ( look_mat * Vec4 {1,0,0,1} ).xyz


	move_dir := forward * move_input.y + right * move_input.x

	motion := linalg.normalize0(move_dir) * 6 * utils.dt
	camera.position += motion

	camera.target = camera.position + forward
}

//shake the camera by setting the trauma
shake_camera :: proc(trauma: f32){
	camera.camera_shake.trauma = trauma
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
	camera.camera_shake = Camera_shake{
		trauma = 0,
		depletion = 8,
		pos_offset = { 0,0 },
		rot_offset = 0,
		seed = 223492,
		time_offset = { 5,5 }
	}
}

update_camera_shake :: proc(){
	cs := &camera.camera_shake
	if cs.trauma <= 0{
		cs.pos_offset = { 0,0 }
		cs.rot_offset = 0
		cs.trauma = 0
	} else {
		seedpos := noise.Vec2{f64(cs.time_offset.x * utils.runtime), f64(cs.time_offset.y * utils.runtime)}

		cs.pos_offset = Vec2{noise.noise_2d(cs.seed, seedpos), noise.noise_2d(cs.seed + 1, seedpos)}
		cs.pos_offset /= 45
		cs.pos_offset *= cs.trauma * cs.trauma
		cs.rot_offset = noise.noise_2d(cs.seed+2, seedpos)
		cs.rot_offset /= 100
		cs.rot_offset *= cs.trauma * cs.trauma * cs.trauma

		cs.trauma -= cs.depletion * utils.dt
	}
}


world_to_screen_pos :: proc(pos: Vec2) -> Vec2{
	//projection matrix
	projection_matrix := linalg.matrix4_perspective_f32(70, utils.screen_size.x / utils.screen_size.y, 0.0001, 1000)
	//view matrix
	view_matrix := linalg.matrix4_look_at_f32(camera.position, camera.target, {camera.rotation, 1, 0})

	clippos := (projection_matrix*view_matrix) * Vec4{pos.x, pos.y, 0, 1};
	ndcpos := Vec2{clippos.x/clippos.w, (-clippos.y * auto_cast rg.reverse_screen_y)/ clippos.w};
	return (ndcpos.xy*0.5+0.5)*utils.screen_size;
}

world_to_screen_size :: proc(size: f32) -> f32{
	new_size := world_to_screen_pos({camera.position.x+size, camera.position.y}).x
	return new_size - (utils.screen_size.x/2)
}

//convert a point on the screen at a certain z pos to a world pos
screen_point_to_world_at_z :: proc(point: Vec2, target_z: f32) -> Vec3 {

	viewport := Vec4{0.0, 0.0, utils.screen_size.x, utils.screen_size.y}

	//projection matrix
	projection_matrix := linalg.matrix4_perspective_f32(70, utils.screen_size.x / utils.screen_size.y, 0.0001, 1000)
	//view matrix
	view_matrix := linalg.matrix4_look_at_f32(camera.position, camera.target, {camera.rotation, 1, 0})

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
	bottom_right := utils.screen_size-1

	return linalg.abs(get_pixel_size_in_world(bottom_right, target_z))
}
