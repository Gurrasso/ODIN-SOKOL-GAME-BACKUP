package utils

import "base:intrinsics"
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

import sg "../../sokol/gfx"
import sapp "../../sokol/app"

to_radians :: linalg.to_radians
to_degrees :: linalg.to_degrees
Matrix4 :: linalg.Matrix4f32;

//define own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Id :: u32

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

// Game state stuff
runtime: f32
screen_size: Vec2
frame_count: i32
dt: f32

init_utils :: proc(){
	screen_size = Vec2{sapp.widthf(), sapp.heightf()}
}

update_utils :: proc(){
	
	//deltatime
	dt = f32(sapp.frame_duration())

	runtime += dt
	frame_count += 1
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


//bit inefficient you could just compare the result to a squared var and not do the sqrt  
get_vector_magnitude :: proc(vec: Vec2) -> f32{
	magv := math.sqrt(math.fmuladd_f32(vec.y, vec.y, vec.x * vec.x))
	return magv
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

//adds some randomness to a vec2 direction
add_randomness_vec2 :: proc(vec: Vec2, randomness: f32) -> Vec2{
	unit_vector := linalg.normalize0(vec)

	random_angle := rand.float32_range(-randomness, randomness)

	new_x := unit_vector.x * math.cos(random_angle) - unit_vector.y * math.sin(random_angle)
	new_y := unit_vector.x * math.sin(random_angle) + unit_vector.y * math.cos(random_angle)

	magnitude :=get_vector_magnitude(vec)
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

//generate an id from the runtime and a random float
generate_string_id :: proc() -> string{
	builder := strings.builder_make()
	strings.write_f32(&builder, f32(runtime) + rand.float32_range(0, 100), 'f')
	return strings.to_string(builder)
}

//generates a u32 that isnt already in the map
generate_map_u32_id :: proc(target_map: $T) -> u32{
	id := rand.uint32()
	if id in target_map do id = generate_map_u32_id(target_map)
	return id
}

// will return 0 if element isnt found
get_index :: proc(array: $T, target: $T1) -> int{
	index: int = 0

	for i in 0..<len(array){
		if array[i] == target{
				index = i
		}
	}

	return index
}

get_next_index :: proc(array: $T, target: $T1) -> int{
	target_index := get_index(array, target) 
	index := (target_index + 1) % len(array)

	return index
}

has_file_suffix :: proc(filename:cstring, suffix: cstring) -> bool{
	filename := string(filename)
	suffix := string(suffix)

	if len(suffix)>len(filename) do return false


	for i := len(suffix)-1; i >= 0; i -= 1{
		schar := suffix[i]
		fchar := filename[len(filename)-(len(suffix)-i)]

		if schar != fchar do return false
	}

	return true
}
