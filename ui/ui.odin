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

Ui_element :: union{
	Button,
}

Button :: struct{
	transform: Transform, // pos given as screen pos Vec2{0-1, 0-1} size given as decimal of screen width
	world_transform: Transform,
	sprite_filepath: cstring,
	sprite: Sprite_id,
	collider: col.Collider_id,
	trigger_proc: proc(),
}

Ui_elements: map[Ui_id]Ui_element

init_button :: proc(button_desc: Button, scene: scenes.Scene_id = scenes.NIL_SCENE_ID) -> Ui_id{
	id := utils.generate_string_id()
	assert(!(id in Ui_elements))
	scene := scene
	if scene == scenes.NIL_SCENE_ID do scene = scenes.get_current_scene()

	Ui_elements[id] = button_desc
	element := &Ui_elements[id]
	button := &element.(Button)


	button.sprite = draw.init_sprite(
		filename = button.sprite_filepath,
		transform = button.transform,
		draw_priority = draw.Draw_layers.ui,
		tex_index = draw.Tex_indices.no_lighting,
		scene = scene,
	)

	button.collider = col.init_collider(col.Collider{
		"",
		true,
		false,
		col.Rect_collider_shape{button.world_transform.size},
		.Trigger,
		&button.world_transform.pos,
		&button.transform.rot.z,
		proc(this_col: ^col.Collider, other_col: ^col.Collider){
			if other_col.data.is_cursor == true && ev.listen_mouse_single_down(.LEFT) do this_col.data.button_trigger_proc()
		},
		nil,
		scene,
		{button_trigger_proc = button.trigger_proc}
	})

	return id
}

remove_element :: proc(id: Ui_id){
	assert (id in Ui_elements)

	element := &Ui_elements[id]

	switch type in element{
	case Button:
		remove_button(element.(Button))
	case:
		panic("Something wierd in remove element in ui")
	}

	delete_key(&Ui_elements, id)
}

remove_button :: proc(button: Button){
	draw.remove_object(button.sprite)
	col.remove_collider(button.collider)
}

//update the sizes and positions of the ui elements
update :: proc(){
	for id, &element in Ui_elements{
		#partial switch type in element{
		case Button:
			button := &element.(Button)
			button.world_transform.pos = draw.screen_point_to_world_at_z(button.transform.pos*utils.screen_size, 0).xy
			draw.update_sprite(button.world_transform, button.sprite)
			//only update the size if the screen size has changed
			if utils.last_screen_size == utils.screen_size do return
			button.world_transform.size = draw.get_pixel_size_in_world(button.transform.size*utils.screen_size.x, 0).xy
			draw.update_sprite_size(button.world_transform.size, button.sprite)
			col.update_rect_collider_size(button.collider, button.world_transform.size)
		}
	}
}
