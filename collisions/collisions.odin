package collisions

import "base:intrinsics"
import "core:log"
import "core:math"

import "../utils/"

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

check_collision :: proc(col1: Collider, col2: Collider) -> bool{
	//only dynamic colliders move and collide with things can actually collide with things
	if col1.type != .Dynamic || col2.type != .Dynamic do return false

	//check collisions
	

	return false
}

resolve_collision :: proc(col1: ^Collider, col2: ^Collider){
	// do the collider trigger proc
	col1.trigger_proc(col1, col2)
	col2.trigger_proc(col2, col1)

	// Trigger colliders arent rigid
	if col1.type == .Trigger || col2.type == .Trigger do return

	//resolve collision
	
	if col1.type == .Dynamic && col2.type == .Dynamic{		//both colliders are dynamic
		
	}else{																								// one collider is dynamic and one is static
		//which collider is dynamic and which is static
		dynamic_col : ^Collider = col1.type == .Dynamic ? col1 : col2
		static_col : ^Collider = dynamic_col == col1 ? col2 : col1

		log.debug(dynamic_col)
	}

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

//returns a collider struct with the default settings
default_collider :: proc() -> Collider{
	return Collider{
		"",
		default_collider_shape(),
		.Static,
		&{0, 0},
		nil,
		nil,
	}
}

