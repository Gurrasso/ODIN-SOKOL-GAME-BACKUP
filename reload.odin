package main

import "core:dynlib"
import "core:os"
import "core:fmt"
import "core:c/libc"
import "core:log"

import "events"
import "draw"
import "game"
import "collisions"

check_reloads :: proc(){
	//if events.listen_key_single_down(.C) do reset_game_state()
}

reset_game_state :: proc(){
	draw.draw_cleanup()
	draw.g = new(draw.Globals)
	draw.rg = new(draw.Rendering_globals)
	draw.init_draw_state()
	collisions.reload()
	game.gs = new(game.Game_state)
	game.init_game_state()
}
