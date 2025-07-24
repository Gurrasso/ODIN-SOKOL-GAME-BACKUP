package collisions

import "base:intrinsics"
import "core:log"
import "core:math"

import "../utils/"

// the union allows for defining multible different shapes containing different data
Collider_shape :: union{
	Rect_collider_shape,
}

Rect_collider_shape :: struct{
	size: Vec2,
}

Collider_type :: enum{
	Static,
	Dynamic,
	Trigger,
}

Collider :: struct{
	shape: Collider_shape,
	type: Collider_type, 
	pos: Vec2,
	trigger_proc: proc(),
}

Collider_id :: string

colliders: map[Collider_id]Collider

init_collider :: proc(
	collider_desc: Collider
) -> Collider_id{
	id := utils.generate_string_id()
	assert(!(id in colliders))

	colliders[id] = collider_desc

	return id
}

update_colliders :: proc(){
	
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

default_collider :: proc() -> Collider{
	return Collider{
		default_collider_shape(),
		.Static,
		{0, 0},
		nil,
	}
}
