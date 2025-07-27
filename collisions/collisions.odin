#+feature dynamic-literals
package collisions

import "base:intrinsics"
import "core:log"
import "core:math"
import "core:math/linalg"

import "../utils/"
import "../draw"

// the union allows for defining multible different shapes containing different data
Collider_shape :: union #no_nil{
	Rect_collider_shape,
	Circle_collider_shape,
}

Rect_collider_shape :: struct{
	size: Vec2,
}

Circle_collider_shape :: struct{
	radius: f32,
}

Collider_type :: enum{
	Static,
	Dynamic,
	Trigger,
}

Collider :: struct{
	id: Collider_id,				//this is so the collider can find itself in the colliders map
	shape: Collider_shape,
	type: Collider_type,
	pos: ^Vec2,
	rot: ^f32,
	trigger_proc: proc(this_col: ^Collider, other_col: ^Collider),
	hurt_proc: proc(damage: f32), // the other collider can trigger this in the trigger proc and the thing with this collider can say how to hurt it
}

Collider_id :: string

colliders: map[Collider_id]Collider

//creates a collider by passing a Collider struct
init_collider :: proc(
	collider_desc: Collider
) -> Collider_id{
	collider_desc := collider_desc

	//generates a random id if the id given is the default
	collider_desc.id = collider_desc.id == default_collider().id ? utils.generate_string_id() : collider_desc.id
	
	assert(!(collider_desc.id in colliders))

	colliders[collider_desc.id] = collider_desc

	return collider_desc.id
}

update_colliders :: proc(){
	//Loop through all colliders
	for id, &col1 in colliders{
		for id, &col2 in colliders{
			if col1 == col2 do continue

			if check_collision(col1, col2) do resolve_collision(&col1, &col2)
			
		}
	}
}

resolve_collision :: proc(col1: ^Collider, col2: ^Collider){
	// do the collider trigger proc
	if col1.trigger_proc != nil do col1.trigger_proc(col1, col2)
	if col2.trigger_proc != nil do col2.trigger_proc(col2, col1)

	// Trigger colliders arent rigid
	if col1.type == .Trigger || col2.type == .Trigger do return

	//resolve collision
	
	if col1.type == .Dynamic && col2.type == .Dynamic{		//both colliders are dynamic
		
	}else{																								// one collider is dynamic and one is static
		//which collider is dynamic and which is static
		dynamic_col : ^Collider = col1.type == .Dynamic ? col1 : col2
		static_col : ^Collider = dynamic_col == col1 ? col2 : col1

	}

}

check_collision :: proc(col1: Collider, col2: Collider) -> bool{
	//only dynamic colliders move and collide with things can actually collide with things
	if col1.type != .Dynamic && col2.type != .Dynamic do return false

	_, col1_circle := col1.shape.(Circle_collider_shape)
	_, col2_circle := col2.shape.(Circle_collider_shape) 

	//check collisions
	if col1_circle && col2_circle { // both are circles
		return check_circle_circle_collision(col1, col2)
	}else if col1_circle || col2_circle { // one is a circle

		return false
	}else{ // both are polygons
		verts1 := get_vertecies(col1)
		verts2 := get_vertecies(col2)

		// loop through all the sides of both polygons and check if we can find a line that devides them if we can return false otherwise continue checking, if we cant find one then they are colliding
		for i in 0..<len(verts1){
			axis := get_axis(verts1[i], (verts1[(i+1) % len(verts1)]))
			//get the min and max values of the verts on the axis
			verts1_min, verts1_max := project_polygon_to_axis(verts1, axis)
			verts2_min, verts2_max := project_polygon_to_axis(verts2, axis)
			if check_verts_on_axis(verts1_min, verts1_max, verts2_min, verts2_max, col1.pos^, col2.pos^, axis) do return false
			else do continue
		}
		for i in 0..<len(verts2){
			axis := get_axis(verts2[i], (verts2[(i+1) % len(verts2)]))
			//get the min and max values of the verts on the axis
			verts1_min, verts1_max := project_polygon_to_axis(verts1, axis)
			verts2_min, verts2_max := project_polygon_to_axis(verts2, axis)
			if check_verts_on_axis(verts1_min, verts1_max, verts2_min, verts2_max, col1.pos^, col2.pos^, axis) do return false
			else do continue
		}

		return true
	}
	
}

//check if two circles are colliding
check_circle_circle_collision :: proc(col1: Collider, col2: Collider) -> bool{
	r1 := col1.shape.(Circle_collider_shape).radius
	r2 := col2.shape.(Circle_collider_shape).radius
	pos1 := col1.pos^
	pos2 := col2.pos^

	if math.pow((pos2.x-pos1.x),2) + math.pow((pos2.y-pos1.y), 2) <= math.pow((r1+r2),2) do return true
	else do return false
}

get_mtv :: proc()

check_verts_on_axis :: proc(verts1_min: f32, verts1_max: f32, verts2_min: f32, verts2_max: f32, pos1: Vec2, pos2: Vec2, axis: Vec2) -> bool{
	// quick overlap test of the min and max from both polygons
  if  verts1_min - verts2_max > 0 || verts2_min - verts1_max > 0 {
  	return true							//there is a gap 
  } else do return false		//continue to check
}

project_polygon_to_axis :: proc(vertecies: [dynamic]Vec2, axis: Vec2) -> (min: f32, max: f32){
	verts_min: f32 = linalg.vector_dot(axis, vertecies[0])
	verts_max: f32 = min

	//finds the min and max values for the vertecies on the axis
	for vert in vertecies{
		verts_min = linalg.min_double(verts_min, linalg.vector_dot(axis, vert))
		verts_max = linalg.max_double(verts_max, linalg.vector_dot(axis, vert))
	}

	return verts_min, verts_max
}

get_axis :: proc(vert1: Vec2, vert2: Vec2) -> Vec2{
	// get the perpendicular axis
  axis := Vec2{ 
  	-(vert2.y - vert1.y), 
    vert2.x - vert1.x
  }
	//normalise the axis
	axis = linalg.normalize0(axis)
	return axis
}

get_vertecies :: proc(col: Collider) -> [dynamic]Vec2{
	vertecies: [dynamic]Vec2

	switch type in col.shape {
	case Rect_collider_shape: // if the collider is a rect
	
		//this is not very clean but it works for now
		//gets the vertecies in world space and adds them to an array
		rot := col.rot^
		pos := col.pos^
		size_offset := col.shape.(Rect_collider_shape).size/2
		vert1 := pos-size_offset
		vert2 := Vec2{pos.x + size_offset.x, pos.y - size_offset.y}
		vert3 := pos+size_offset
		vert4 := Vec2{pos.x - size_offset.x, pos.y + size_offset.y}

		append(&vertecies, vert1)
		append(&vertecies, vert2)
		append(&vertecies, vert3)
		append(&vertecies, vert4)

		//rotate the vertecies
		if rot != 0 {
			for &vert in vertecies{
				vert = utils.vec2_rotation(vert, pos, rot)
			}
		}
	case Circle_collider_shape: // if the collider is a circle
		log.debug("Circles dont have vertecies")
	case: // else
		log.debug("Invalid collider shape in get_vertecies")
	}

	return vertecies
}


query_collider :: proc(id: Collider_id) -> Collider{
	assert(id in colliders)
	return colliders[id]
}

default_collider_shape :: proc() -> Collider_shape{
	return Rect_collider_shape{
		size = {1, 1}
	}
}

dpos: Vec2 = {0, 0}
drot: f32 = 0

//returns a collider struct with the default settings
default_collider :: proc() -> Collider{
	return Collider{
		"",
		default_collider_shape(),
		.Static,
		&dpos,
		&drot,
		nil,
		nil,
	}
}

