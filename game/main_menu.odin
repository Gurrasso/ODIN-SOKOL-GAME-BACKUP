package game

import "core:log"

import "../ui"
import "../scenes"
import "../sound"

init_main_menu :: proc(){
	ui.init_ui_element(element_desc = ui.Ui_element{
		Transform{
			size = {.17,.04},
			pos = {.5,.4},
			rot = 0,
		},
		WHITE_IMAGE_PATH,
		ui.Button{
			proc(){
				scenes.switch_scene("game")
			},
			""
		},
		"",
		{},
	})

	ui.init_ui_element(element_desc = ui.Ui_element{
		Transform{
			size = {.17,.04},
			pos = {.5,.53},
			rot = 0,
		},
		WHITE_IMAGE_PATH,
		ui.Button{
			proc(){
				quit_game()
			},
			""
		},
		"",
		{},
	})
}

update_main_menu :: proc(){
	sound.play_continuously("Event:/Chill-theme")
}
