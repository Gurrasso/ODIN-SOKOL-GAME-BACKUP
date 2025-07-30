#+feature dynamic-literals
package collisions

import "base:intrinsics"
import "core:log"
import "core:math"
import "core:math/linalg"

import "../utils/"
import "../scenes"

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
	enabled: bool, 
	shape: Collider_shape,
	type: Collider_type,
	pos: ^Vec2,
	rot: ^f32,
	trigger_proc: proc(this_col: ^Collider, other_col: ^Collider), //a proc that triggers on collision
	hurt_proc: proc(damage: f32), // the other collider can trigger this in the trigger proc and the thing with this collider can say how to hurt it
	scene: scenes.Scene_id,
}

Collider_id :: string

colliders: map[Collider_id]Collider

//creates a collider by passing a Collider struct
init_collider :: proc(
	collider_desc: Collider,
) -> Collider_id{
	collider_desc := collider_desc

	if collider_desc.scene == scenes.NIL_SCENE_ID do collider_desc.scene = scenes.get_current_scene() 

	//generates a random id if the id given is the default
	collider_desc.id = collider_desc.id == default_collider().id ? utils.generate_string_id() : collider_desc.id
	
	assert(!(collider_desc.id in colliders))

	colliders[collider_desc.id] = collider_desc

	return collider_desc.id
}

//checks collision for every collider and resolves it
update_colliders :: proc(){
	//Loop through all colliders
	for id, &col1 in colliders{
		if !col1.enabled || !scenes.scene_enabled(col1.scene) do continue
		for id, &col2 in colliders{
			if col1 == col2 || !col2.enabled || !scenes.scene_enabled(col1.scene) do continue

			colliding, mtv := check_collision(col1, col2)
			if colliding do resolve_collision(&col1, &col2, mtv)
			
		}
	}
}

/*
	resolves collisions using a minimum translation vector
	
	two dynamic colliders colliding will both move to resolve the collision
	if one is dynamic and one is static, only the dynamic collider will move
	if one or both is a trigger collider there will be no resolution since the trigger colliders arent rigid
*/
resolve_collision :: proc(col1: ^Collider, col2: ^Collider, mtv: Vec2){
	// do the collider trigger proc
	if col1.trigger_proc != nil do col1.trigger_proc(col1, col2)
	if col2.trigger_proc != nil do col2.trigger_proc(col2, col1)

	// Trigger colliders arent rigid
	if col1.type == .Trigger || col2.type == .Trigger do return

	//resolve collision
	
	if col1.type == .Dynamic && col2.type == .Dynamic{		//both colliders are dynamic
		//move both colliders equally
		if col1.pos^.y > col2.pos^.y {
			col1.pos^.y+=mtv.y/2
			col2.pos^.y-=mtv.y/2
		}else {
			col1.pos^.y-=mtv.y/2
			col2.pos^.y+=mtv.y/2
		}
		if col1.pos^.x > col2.pos^.x {
			col1.pos^.x+=mtv.x/2
			col2.pos^.x-=mtv.x/2
		}else {
			col1.pos^.x-=mtv.x/2
			col2.pos^.x+=mtv.x/2
		}
	}else{	// one collider is dynamic and one is static
		//which collider is dynamic and which is static
		dynamic_col : ^Collider = col1.type == .Dynamic ? col1 : col2
		static_col : ^Collider = dynamic_col == col1 ? col2 : col1

		//move only the dynamic collider
		if dynamic_col.pos^.y > static_col.pos^.y do dynamic_col.pos^.y+=mtv.y
		else do dynamic_col.pos^.y -= mtv.y
		if dynamic_col.pos^.x > static_col.pos^.x do dynamic_col.pos^.x+=mtv.x
		else do dynamic_col.pos^.x -= mtv.x
	}

}

//returns true if they are colliding and returns a vector to resolve the collision
check_collision :: proc(col1: Collider, col2: Collider) -> (bool, Vec2){
	//only dynamic colliders move and collide with things can actually collide with things
	if col1.type != .Dynamic && col2.type != .Dynamic do return false, {0, 0}

	_, col1_circle := col1.shape.(Circle_collider_shape)
	_, col2_circle := col2.shape.(Circle_collider_shape) 

	//check collisions
	if col1_circle && col2_circle { // both are circles
		return check_circle_circle_collision(col1, col2)
	}else if col1_circle || col2_circle { // one is a circle
		circle_collider := col1_circle ? col1 : col2
		polygon_collider := col1_circle ? col2 : col1

		polygon_verts := get_vertecies(polygon_collider)

		circle_max_dist: f32 = circle_collider.shape.(Circle_collider_shape).radius*2 
		polygon_max_dist: f32 = utils.get_vector_magnitude(polygon_collider.shape.(Rect_collider_shape).size)


		//minimum translation vector
		mtv_dist: f32 = circle_max_dist > circle_max_dist ?  polygon_max_dist : polygon_max_dist 
		mtv_axis: Vec2 = {0, 0}

		//first check every side of the polygon then the axis from the circle to the polygon

		for i in 0..<len(polygon_verts){
			axis := get_normal_axis(polygon_verts[i], (polygon_verts[(i+1) % len(polygon_verts)]))
			//get the min and max values of the verts on the axis
			circle_min, circle_max := project_circle_to_axis(circle_collider.pos^, circle_collider.shape.(Circle_collider_shape).radius, axis)
			polygon_min, polygon_max := project_polygon_to_axis(polygon_verts, axis)
			if check_verts_on_axis(polygon_min, polygon_max, circle_min, circle_max) do return false, {0, 0}

			overlap := math.min(circle_max-polygon_min, circle_max-polygon_min)
			if overlap < mtv_dist{
				mtv_dist = overlap
				mtv_axis = axis
			}
		}

		closest_vert: Vec2 = polygon_verts[0]
		closest_dist: f32 = utils.get_vector_magnitude(closest_vert-circle_collider.pos^)
		//loop through all the vertecies of the polygon to get the closest one to the circle
		for vert in polygon_verts{
			
			dist := utils.get_vector_magnitude(vert-circle_collider.pos^)

			if dist < closest_dist{
				closest_dist = dist
				closest_vert = vert
			}
		}

		//check for a gap on the axis from the circle center to the closest vert
		axis := get_axis_vert_to_vert(closest_vert, circle_collider.pos^)
		circle_min, circle_max := project_circle_to_axis(circle_collider.pos^, circle_collider.shape.(Circle_collider_shape).radius, axis)
		polygon_min, polygon_max := project_polygon_to_axis(polygon_verts, axis)
		if check_verts_on_axis(polygon_min, polygon_max, circle_min, circle_max) do return false, {0, 0}


		overlap := math.min(circle_max-polygon_min, circle_max-polygon_min)
		if overlap < mtv_dist{
			mtv_dist = overlap
			mtv_axis = axis
		}

		return true, linalg.abs(mtv_dist*mtv_axis)
	}else{ // both are polygons
		verts1 := get_vertecies(col1)
		verts2 := get_vertecies(col2)

		col1_max_dist: f32 = utils.get_vector_magnitude(col1.shape.(Rect_collider_shape).size) 
		col2_max_dist: f32 = utils.get_vector_magnitude(col2.shape.(Rect_collider_shape).size)

		//minimum translation vector
		mtv_dist: f32 = col1_max_dist > col2_max_dist ?  col1_max_dist : col2_max_dist 
		mtv_axis: Vec2 = {0, 0}

		//some code duplication but "is fine"
		// loop through all the sides of both polygons and check if we can find a line that devides them if we can return false otherwise continue checking, if we cant find one then they are colliding
		for i in 0..<len(verts1){
			axis := get_normal_axis(verts1[i], (verts1[(i+1) % len(verts1)]))
			//get the min and max values of the verts on the axis
			verts1_min, verts1_max := project_polygon_to_axis(verts1, axis)
			verts2_min, verts2_max := project_polygon_to_axis(verts2, axis)
			if check_verts_on_axis(verts1_min, verts1_max, verts2_min, verts2_max) do return false, {0, 0}

			overlap := math.min(verts2_max-verts1_min, verts1_max-verts2_min)
			if overlap < mtv_dist{
				mtv_dist = overlap
				mtv_axis = axis
			}
		}
		for i in 0..<len(verts2){
			axis := get_normal_axis(verts2[i], (verts2[(i+1) % len(verts2)]))
			//get the min and max values of the verts on the axis
			verts1_min, verts1_max := project_polygon_to_axis(verts1, axis)
			verts2_min, verts2_max := project_polygon_to_axis(verts2, axis)
			if check_verts_on_axis(verts1_min, verts1_max, verts2_min, verts2_max) do return false, {0, 0}

			overlap := math.min(verts2_max-verts1_min, verts1_max-verts2_min)
			if overlap < mtv_dist{
				mtv_dist = overlap
				mtv_axis = axis
			}
		}

		return true, linalg.abs(mtv_dist*mtv_axis)
	}

	return false, {0, 0}
	
}

//check if two circles are colliding
check_circle_circle_collision :: proc(col1: Collider, col2: Collider) -> (bool, Vec2){
	r1 := col1.shape.(Circle_collider_shape).radius
	r2 := col2.shape.(Circle_collider_shape).radius
	pos1 := col1.pos^
	pos2 := col2.pos^

	//get the overlap by taking the radius of both circles and subtracting the distance between the circles
	overlap :=  (r1+r2) - utils.get_vector_magnitude(pos1-pos2)
	if overlap > 0 do return true, linalg.abs((overlap) * linalg.normalize0(pos1-pos2))
	else do return false, {0, 0}
	return false,{0,0}
}

check_verts_on_axis :: proc(verts1_min: f32, verts1_max: f32, verts2_min: f32, verts2_max: f32) -> bool{
	// quick overlap test of the min and max from both polygons
  if  verts1_min - verts2_max > 0 || verts2_min - verts1_max > 0 {
  	return true							//there is a gap 
  } else do return false		//continue to check
}

//finds the min and max values for the vertecies on the axis
project_polygon_to_axis :: proc(vertecies: [dynamic]Vec2, axis: Vec2) -> (min: f32, max: f32){
	verts_min: f32 = linalg.vector_dot(axis, vertecies[0])
	verts_max: f32 = min

	for vert in vertecies{
		verts_min = linalg.min_double(verts_min, linalg.vector_dot(axis, vert))
		verts_max = linalg.max_double(verts_max, linalg.vector_dot(axis, vert))
	}

	return verts_min, verts_max
}

//creates min and max values for a circle and an axis
project_circle_to_axis :: proc(center: Vec2, radius: f32, axis: Vec2) -> (min: f32, max: f32){
	vertecies: [dynamic]Vec2
	
	verts_min := linalg.vector_dot(axis, center)
	verts_max := verts_min

	verts_min -= radius
	verts_max += radius

	return verts_min, verts_max
}

//creates an axis from one vertex to another
get_axis_vert_to_vert :: proc(vert1: Vec2, vert2: Vec2) -> Vec2{
	return linalg.normalize0(vert1-vert2)
}

//creates an axis normal to the line created by to vertecies
get_normal_axis :: proc(vert1: Vec2, vert2: Vec2) -> Vec2{
	// get the perpendicular axis
  axis := Vec2{ 
  	-(vert2.y - vert1.y), 
    vert2.x - vert1.x
  }
	//normalise the axis
	axis = linalg.normalize0(axis)
	return axis
}

//gives the vertecies for shapes in world space
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
				vert = utils.vec2_rotation_not_relative(vert, pos, rot)
			}
		}
	case Circle_collider_shape: // if the collider is a circle
		panic("Circles dont have vertecies")
	case: // else
		panic("Invalid collider shape in get_vertecies")
	}

	return vertecies
}

toggle_enabled :: proc(id: Collider_id){
	assert(id in colliders)
	collider := &colliders[id]
	collider.enabled = !collider.enabled
}

remove_collider :: proc(id: Collider_id){
	assert(id in colliders)
	delete_key(&colliders, id)
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
		true,
		default_collider_shape(),
		.Static,
		&dpos,
		&drot,
		nil,
		nil,
		scenes.NIL_SCENE_ID,
	}
}

reload :: proc(){
	clear(&colliders)
}

