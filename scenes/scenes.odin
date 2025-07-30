#+feature dynamic-literals
package scenes

import "core:log"
import "../utils"

/*
	
	A system for managing scenes and switching between them

*/

Scene_id :: string
NIL_SCENE_ID :: ""
GLOBAL_SCENE_ID :: "GLOBAL"

Scene :: struct{
	id: Scene_id,
	enabled: bool,
	inited: bool,
	init_proc: proc(),
	update_proc: proc(),
	draw_proc: proc(),
}

scenes: map[Scene_id]Scene
current_scene: Scene

create_scene :: proc(
	id: Scene_id, 
	init: proc(), 
	update: proc(), 
	draw: proc()
){
	assert(!(id in scenes))
	scenes[id] = Scene{
		id,
		false,
		false,
		init,
		update,
		draw,
	}
}

switch_scene :: proc(id: Scene_id){
	assert(id in scenes)

	if id == current_scene.id do return

	if current_scene.id != NIL_SCENE_ID do disable_scene(current_scene.id)
	current_scene = scenes[id]
	scene := &scenes[id]

	if !scene.inited && scene.init_proc != nil{
		scene.init_proc()
		scene.inited = true
	}
	enable_scene(id)
	log.debug("Switched to scene:", id)
}

disable_scene :: proc(id: Scene_id){
	assert(id in scenes)
	scene := &scenes[id]

	if !scene.enabled do return

	scene.enabled = false
}

get_current_scene :: proc() -> Scene_id{
	id := current_scene.id
	return id == NIL_SCENE_ID ? GLOBAL_SCENE_ID : id
}

scene_enabled :: proc(id: Scene_id) -> bool{
	if id == GLOBAL_SCENE_ID do return true
	assert(id in scenes, "Id is probably wrong in an init function")

	return scenes[id].enabled
}

enable_scene  :: proc(id: Scene_id){
	assert(id in scenes)
	scene := &scenes[id]
	
	if scene.enabled do return

	scene.enabled = true
}

scene_init :: proc(){
	if current_scene.init_proc != nil do current_scene.init_proc()
}

scene_update :: proc(){
	if current_scene.update_proc != nil do current_scene.update_proc()
}

scene_draw :: proc(){
	if current_scene.draw_proc != nil do current_scene.draw_proc()
}
