#+feature dynamic-literals
package ui

import "core:log"

import "../draw"
import col "../collisions"
import "../sound"
import "../scenes"
import "../utils"
import ev "../events"

Ui_id :: string

Ui_element :: struct{
	transform: Transform, // pos given as screen pos Vec2{0-1, 0-1} size given as decimal of screen width
	sprite_filepath: cstring,
	type: Ui_type,
	sprite: Sprite_id,
	world_transform: Transform,
}

Ui_type :: union{
	Button,
}

Button :: struct{
	trigger_proc: proc(),
	collider: col.Collider_id,
}

Ui_elements: map[Ui_id]Ui_element

//creates a ui element
init_ui_element :: proc(element_desc: Ui_element, scene: scenes.Scene_id = scenes.NIL_SCENE_ID) -> Ui_id{
	id := utils.generate_string_id()
	assert(!(id in Ui_elements))
	scene := scene
	if scene == scenes.NIL_SCENE_ID do scene = scenes.get_current_scene()

	Ui_elements[id] = element_desc
	element := &Ui_elements[id]


	element.sprite = draw.init_sprite(
		filename = element.sprite_filepath,
		transform = element.transform,
		draw_priority = draw.Draw_layers.ui,
		tex_index = draw.Tex_indices.no_lighting,
		scene = scene,
	)

	switch type in element.type{
	case Button:
		init_button(element, scene)
	case:
		log.debug("Ui element given has no type")
	}

	return id
}

//creates all the things for a button ui element
init_button :: proc(element: ^Ui_element, scene: scenes.Scene_id = scenes.NIL_SCENE_ID){
	button := &element.type.(Button)

	button.collider = col.init_collider(col.Collider{
		"",
		true,
		false,
		col.Rect_collider_shape{element.world_transform.size},
		.Trigger,
		&element.world_transform.pos,
		&element.transform.rot.z,
		proc(this_col: ^col.Collider, other_col: ^col.Collider){
			if other_col.data.is_cursor == true && ev.listen_mouse_single_down(.LEFT) do this_col.data.button_trigger_proc()
		},
		nil,
		scene,
		{button_trigger_proc = button.trigger_proc}
	})

}

//deletes an element
remove_element :: proc(id: Ui_id){
	assert (id in Ui_elements)

	element := &Ui_elements[id]

	draw.remove_sprite_object(element.sprite)

	switch type in element.type{
	case Button:
		remove_button(element.type.(Button))
	case:
		
	}

	delete_key(&Ui_elements, id)
}

//deletes the things for the button element
remove_button :: proc(button: Button){
	col.remove_collider(button.collider)
}

//update the sizes and positions of the ui elements
update :: proc(){
	for id, &element in Ui_elements{
		element.world_transform.pos = draw.screen_point_to_world_at_z(element.transform.pos*utils.screen_size, 0).xy
		draw.update_sprite(element.world_transform, element.sprite)
		
		element.world_transform.size = draw.get_pixel_size_in_world(element.transform.size*utils.screen_size.x, 0).xy
		draw.update_sprite_size(element.world_transform.size, element.sprite)
		
		#partial switch type in element.type{
		case Button:
			button := &element.type.(Button)
			col.update_rect_collider_size(button.collider, element.world_transform.size)
		}
	}
}
