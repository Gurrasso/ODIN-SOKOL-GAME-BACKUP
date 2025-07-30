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
	deinit_proc: proc(),
}

scenes: map[Scene_id]Scene
//keeps track of which scene is loaded
current_scene: Scene

//creates a scene with an id
create_scene :: proc(
	id: Scene_id, 
	init: proc(), 
	update: proc(), 
	draw: proc(),
	deinit: proc()
){
	assert(!(id in scenes))
	scenes[id] = Scene{
		id,
		false,
		false,
		init,
		update,
		draw,
		deinit,
	}
}

//disables the current scene and enables a new one, can also deinit and init scenes
switch_scene :: proc(id: Scene_id){
	assert(id in scenes)

	if id == current_scene.id do return

	if current_scene.id != NIL_SCENE_ID{
		disable_scene(current_scene.id)
		if current_scene.deinit_proc != nil && current_scene.inited != false {
			cs := &scenes[current_scene.id]
			cs.deinit_proc()
			cs.inited = false
		}
	}
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

//gets the current scene so that we can add things to the current scene when initing them
get_current_scene :: proc() -> Scene_id{
	id := current_scene.id
	return id == NIL_SCENE_ID ? GLOBAL_SCENE_ID : id
}

//checks if a scene is enabled will also return true when the global scene id is given
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

// Functions for triggering the current scene's procs

scene_init :: proc(){
	if current_scene.init_proc != nil do current_scene.init_proc()
}

scene_update :: proc(){
	if current_scene.update_proc != nil do current_scene.update_proc()
}

scene_draw :: proc(){
	if current_scene.draw_proc != nil do current_scene.draw_proc()
}
