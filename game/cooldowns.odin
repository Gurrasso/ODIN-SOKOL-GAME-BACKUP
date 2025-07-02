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
import cu "../utils/color"
import es "../enteties"


//the cooldown id
Cooldown :: u32

//Timer object for cooldowns
Cooldown_object :: struct{
	enabled: bool,
	cooldown: f32,
	duration: f32,
}

//updates all the cooldowns
update_cooldowns :: proc(){
	for id in gs.cooldowns{
		cooldown_object := &gs.cooldowns[id]
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
	return gs.cooldowns[id].enabled
}

//starts the cooldown
start_cooldown :: proc(id: Cooldown){
	assert(id in gs.cooldowns)
	cooldown_object := &gs.cooldowns[id]

	cooldown_object.enabled = true
}

//creates the cooldown object and gives the id
init_cooldown_object :: proc(cooldown: f32) -> Cooldown{
	id := utils.generate_map_u32_id(gs.cooldowns)

	gs.cooldowns[id] = Cooldown_object{
		cooldown = cooldown,
	}
	
	return Cooldown(id)
}



