#+feature dynamic-literals
package game

import "base:intrinsics"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/ease"
import "core:math/rand"
// sokol imports
import sapp "../../sokol/app"
import sg "../../sokol/gfx"

import "../utils"
import "../draw"
import cooldown "../utils/cooldown"
import cu "../utils/color"
import ev "../events"

// ==============
//     :GAME
// ==============

//game specific globals
Game_state :: struct{
	background_sprite: Sprite_id,
	projectiles: [dynamic]Projectile,
	enteties: Enteties,
	player: Player,
	cursor: Cursor,
}


gs: ^Game_state

//test vars
test_text_rot: f32
test_text_rot_speed: f32 = 120
test_text_id: string

init_game_state :: proc(){
	gs = new(Game_state)

	init_items()
	sapp.show_mouse(false)
	sapp.lock_mouse(true)

	init_player()

	draw.set_world_brightness(0.4)

	draw.init_light(pos = {1, 3}, size = 6, intensity = 1, color = {1, 1, 1, 1})
	draw.init_light(pos = {2, -2}, size = 3.5, intensity = 1, color = {1, 1, 1, 1})

	draw.init_font(font_path = "./src/assets/fonts/MedodicaRegular.otf", id = "font1", font_h = 32)
	
	test_text_id = draw.init_text(
		text = "TÅST", 
		draw_from_center = true, 
		text_rot = test_text_rot, 
		pos = {0, 1}, 
		scale = 0.03, 
		color = cu.sg_color(color3 = Vec3{138,43,226}), 
		font_id = "font1"
	)

	draw.init_rect(color = cu.sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {0, 2.5}, size = {10, .2}, rot = {0, 0, 0}}, draw_priority = .environment)
	draw.init_rect(color = cu.sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {0, -2.5}, size = {10, .2}, rot = {0, 0, 0}}, draw_priority = .environment)
	draw.init_rect(color = cu.sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {4.9, 0}, size = {.2, 4.8}, rot = {0, 0, 0}}, draw_priority = .environment)
	draw.init_rect(color = cu.sg_color(color4 = Vec4{255, 20, 20, 120}), transform = Transform{pos = {-4.9, 0}, size = {.2, 4.8}, rot = {0, 0, 0}}, draw_priority = .environment)

	init_cursor()

	init_background({130, 130, 130})
}

update_game_state :: proc(){

	event_listener()

	update_projectiles(&gs.projectiles)
	//move_camera_3D()
	update_player()
	
	update_camera()

	update_cursor()
	
	test_text_rot -= test_text_rot_speed * utils.dt
	draw.update_text(test_text_rot, test_text_id)


	update_background();

	ev.mouse_move = {}
	
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
	if ev.listen_key_down(.ESCAPE) {
		quit_game()
	}

	//fullscreen on F11
	if ev.listen_key_single_down(.F11) {
		sapp.toggle_fullscreen()
	}

	if ev.listen_key_single_down(.F){
		if tempiteminc %% 2 == 0{
			give_item(&gs.player.holder, "otto")
			tempiteminc += 1
		}else{
			give_item(&gs.player.holder, "gun")
			tempiteminc -= 1
		}
	}

	if !sapp.mouse_locked() && ev.listen_mouse_single_down(.LEFT) do sapp.lock_mouse(true)
}

// PLAYER
Player :: struct{
	sprite_id: Sprite_id,
	idle_sprite_filename: cstring,
	running_sprite_filename: cstring,
	transform: Transform,	
	xflip: f32,
	xflip_threshold: f32,
	
	//used for animations
	last_move_dir: Vec2,

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

	gs.player = Player{
		idle_sprite_filename = "./src/assets/sprite_sheets/idle_template_character.png",
		running_sprite_filename = "./src/assets/sprite_sheets/running_template_character.png",
		
		transform = {
			size = { 0.7,1.4 }
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
			item = gs.enteties["empty"],
			equipped = true,
		},
		
		//how far away from the player an item is
		item_offset = Vec2{0.2, -0.34},
	}
	gs.player.move_speed = gs.player.default_move_speed
	init_player_abilities()

	//init the players sprite
	gs.player.sprite_id = draw.init_animated_sprite(sprite_sheet_filename = gs.player.idle_sprite_filename, transform = gs.player.transform, sprite_count = 8, animation_speed = 0.14)
	draw.start_animation(gs.player.sprite_id)
	//init the players item_holder
	init_item_holder(&gs.player.holder)
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
	player := &gs.player
	transform := &player.transform

	//changing the move_input with wasd
	move_input: Vec2
	if ev.key_down[.W] do move_input.y = 1
	else if ev.key_down[.S] do move_input.y = -1
	if ev.key_down[.A] do move_input.x = -1
	else if ev.key_down[.D] do move_input.x = 1

	//defining the definitions of up and right which in turn gives us the other directions
	up := Vec2{0,1}
	right := Vec2{1,0}

	motion : Vec2

	//for flipping the player sprite
	if gs.cursor.world_transform.pos.x <= transform.pos.x+ player.xflip_threshold*player.xflip{
		player.xflip = 1
	} else {
		player.xflip = -1
	}

	transform.rot.x = (player.xflip + 1) * 90
	//gs.player.look_dir = linalg.normalize0(gs.cursor.pos-(gs.player.pos - Vec2{ge.camera.position.x, ge.camera.position.y}))
	//gs.player.look_dir = gs.player.move_dir

	update_player_abilities()

	//player movement with easing curves
	if move_input != 0 {
		player.move_dir = up * move_input.y + right * move_input.x
		
		//increase duration with the acceleration
		player.duration += player.acceleration * utils.dt
		//clamp the duration between 0 and 1
		player.duration = math.clamp(player.duration, 0, 1)
		//the speed becomes the desired speed times the acceleration easing curve based on the duration value of 0 to 1
		player.current_move_speed = player.move_speed * player_acceleration_ease(gs.player.duration)
	} else {
		player.move_dir = {0,0}
		
		//the duration decreses with the deceleration when not giving any input
		player.duration -= player.deceleration * utils.dt
		//the duration is still clamped between 0 and 1
		player.duration = math.clamp(player.duration, 0, 1)
		//the speed is set to the desired speed times the deceleration easing of the duration
		player.current_move_speed = player.move_speed * player_deceleration_ease(player.duration)
	}	

	//update sprites
	if utils.get_vector_magnitude(player.move_dir) > 0 && utils.get_vector_magnitude(player.last_move_dir) <= 0 {
		draw.update_animated_sprite_sheet(player.sprite_id, player.running_sprite_filename, 12)
	}
	else if utils.get_vector_magnitude(player.move_dir) <= 0 && utils.get_vector_magnitude(player.last_move_dir) > 0 {
		draw.update_animated_sprite_sheet(player.sprite_id, player.idle_sprite_filename, 8)
	}

	//update sprites animation speed
	if utils.get_vector_magnitude(player.move_dir) <= 0 do draw.update_animated_sprite_speed(gs.player.sprite_id, 0.14)
	else if gs.player.sprint.enabled do draw.update_animated_sprite_speed(gs.player.sprite_id, 0.07)
	else do draw.update_animated_sprite_speed(gs.player.sprite_id, 0.1)


	
	motion = linalg.normalize0(player.move_dir) * player.current_move_speed * utils.dt
	transform.pos += motion

	//update the item holder of the player
	holder := &player.holder

	//pos
	holder_item_data := entity_get_component(entity = holder.item.entity, component_type = Item_data) 
	holder_offset := (holder_item_data^.size.x/2) 
	holder_rotation_pos := transform.pos + ( player.item_offset.x * player.xflip)
	new_holder_pos := Vec2{(player.item_offset.x)*-player.xflip, transform.pos.y}

	holder_rotation_vector := linalg.normalize0(gs.cursor.world_transform.pos-(transform.pos))
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

	draw.update_animated_sprite(transform = transform^, id = player.sprite_id)

	player.last_move_dir = player.move_dir
}


// PLAYER ABILITIES

init_player_abilities :: proc(){
	init_player_dash()
	init_player_sprint()
}

update_player_abilities :: proc(){
	//check for sprint
	if ev.listen_key_down(gs.player.sprint.button) do gs.player.sprint.enabled = true
	else do gs.player.sprint.enabled = false
	update_sprint()

	//check for dash
	if ev.listen_key_single_down(gs.player.dash.button){
		gs.player.dash.enabled = true
	}
	if gs.player.dash.enabled{
		update_player_dash(&gs.player.dash)
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
	gs.player.dash = Dash_data{
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
	dash.duration += dash.dash_speed * utils.dt
	dash.distance =  dash_ease(dash.duration)

	transform := &gs.player.transform


	// do the ability
	dash_motion := linalg.normalize0(gs.player.move_dir) * (dash.dash_distance/dash.cutoff)
	transform.pos += dash_motion * (dash.distance-dash.last_distance)
	gs.player.move_speed = 0

	dash.last_distance = dash.distance
	
	if dash.distance >= dash.cutoff{
		
		gs.player.move_speed = gs.player.default_move_speed
		gs.player.dash.distance = 0
		gs.player.dash.last_distance = 0
		gs.player.dash.duration = 0
		gs.player.dash.enabled = false
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
	gs.player.sprint = {
		enabled = false,
		button = .LEFT_SHIFT,
		speed = 5.5,
	}
}

update_sprint :: proc(){
	if gs.player.sprint.enabled {
		gs.player.move_speed = gs.player.sprint.speed
	}
	else { 
		gs.player.move_speed = gs.player.default_move_speed
	}
}

//ITEM INITS

init_items :: proc(){
	init_weapons()

	empty_item_data := Item_data{
		img = draw.get_image("./src/assets/textures/transparent.png"),
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
			img = draw.get_image(draw.WHITE_IMAGE_PATH),
			transform = Transform{
				size = {0.15, 0.15}
			},
			lifetime = 2,
			speed = 25,
			damage = 0,
		},
	}
	gun_item_data := Item_data{
		img = draw.get_image(draw.WHITE_IMAGE_PATH),
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
			img = draw.get_image(WHITE_IMAGE_PATH),
			transform = Transform{
				size = {0.2, 0.2}
			},
			lifetime = 2,
			speed = 20,
			damage = 0,
		},
	}
	arvid_item_data := Item_data{
		img = draw.get_image(WHITE_IMAGE_PATH),
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
			img = draw.get_image(WHITE_IMAGE_PATH),
			transform = Transform{
				size = {0.1, 0.1}
			},
			lifetime = 2,
			speed = 18,
			damage = 0,
		},
	}
	otto_item_data := Item_data{
		img = draw.get_image(WHITE_IMAGE_PATH),
		size = {2, 0.2}
	}
	create_entity("otto", {.Item, .Projectile_weapon})	
	entity_add_component("otto", otto_item_data)
	entity_add_component("otto", otto_weapon_data)

}


update_camera :: proc(){
	draw.update_camera_shake()

	camera_follow_cursor()

	draw.update_camera_position(draw.camera.asym_obj.position + draw.camera.lookahead_asym_obj.position + draw.camera.camera_shake.pos_offset, draw.camera.camera_shake.rot_offset)
}

camera_follow_cursor :: proc(){
	//camera follows cursor

	cursor_dir := gs.cursor.world_transform.pos-(gs.player.transform.pos)

	lookahead := utils.get_vector_magnitude(cursor_dir)

	lookahead = math.clamp(lookahead, -gs.cursor.lookahead_distance, gs.cursor.lookahead_distance)

	lookahead /= gs.cursor.lookahead

	draw.camera_follow(gs.player.transform.pos, lookahead, cursor_dir)
}

camera_follow_player :: proc(lookahead: f32 = 0){
	draw.camera_follow(gs.player.transform.pos, lookahead, gs.player.look_dir)
}

