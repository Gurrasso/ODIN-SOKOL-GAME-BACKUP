package draw

import "base:intrinsics"
import "core:log"

import sg "../../sokol/gfx"

import "../utils"

// ===================
//  :ANIMATED SPRITES
// ===================

// Handle multiple objects
Animated_sprite_object :: struct{
	pos: Vec3,
	rot: Vec3,
	sprite_sheet: sg.Image,
	draw_priority: i32,
	vertex_buffer: sg.Buffer,
	size: Vec2,
}

init_animated_sprite :: proc(){
	
}





