package cooldown

import "core:log"

import "../../utils"


//the cooldown id
Cooldown :: u32

//Timer object for cooldowns
Cooldown_object :: struct{
	enabled: bool,
	cooldown: f32,
	duration: f32,
}

cooldowns: map[Cooldown]Cooldown_object

//updates all the cooldowns
update_cooldowns :: proc(){
	for id in cooldowns{
		cooldown_object := &cooldowns[id]
		if cooldown_object.enabled{
			cooldown_object.duration += utils.dt
			
			if cooldown_object.duration > cooldown_object.cooldown{
				cooldown_object.enabled = false
				cooldown_object.duration = 0
			}
		}
	}
}

cooldown_enabled :: proc(id: Cooldown) -> bool{
	return cooldowns[id].enabled
}

//starts the cooldown
start_cooldown :: proc(id: Cooldown){
	assert(id in cooldowns)
	cooldown_object := &cooldowns[id]

	cooldown_object.enabled = true
}

//creates the cooldown object and gives the id
init_cooldown_object :: proc(cooldown: f32) -> Cooldown{
	id := utils.generate_map_u32_id(cooldowns)

	cooldowns[id] = Cooldown_object{
		cooldown = cooldown,
	}
	
	return Cooldown(id)
}

delete_cooldown_object :: proc(id: Cooldown){
	assert(id in cooldowns)

	delete_key(&cooldowns, id)
}

update_cooldown_cooldown :: proc(id: Cooldown, cooldown: f32){
	assert(id in cooldowns)

	obj := &cooldowns[id]
	obj.cooldown = cooldown
}

get_cooldown_cooldown :: proc(id: Cooldown) -> f32{
	assert(id in cooldowns)

	obj := &cooldowns[id]
	return obj.cooldown
}

// Run every seconds

Res_object :: string

res_objects: map[Res_object]Cooldown

// goes to true every "seconds"
run_every_seconds :: proc(time: f32, id: Res_object) -> bool{
	if !(id in res_objects){
		res_objects[id] = init_cooldown_object(time)
		start_cooldown(res_objects[id])
		return false
	}else {
		res := res_objects[id]
		if time != get_cooldown_cooldown(res) do update_cooldown_cooldown(res, time)

		if cooldown_enabled(res) do return false
		else{
			start_cooldown(res)
			return true
		}
	}
}

delete_res_object :: proc(id: Res_object){
	assert(id in res_objects)

	delete_key(&res_objects, id)
}
