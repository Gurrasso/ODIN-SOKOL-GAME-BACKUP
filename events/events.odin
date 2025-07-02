package events

import sapp "../../sokol/app"

update_events :: proc(ev: ^sapp.Event){
	#partial switch ev.type{
		case .MOUSE_MOVE:
			mouse_move += {ev.mouse_dx, ev.mouse_dy}
		case .KEY_DOWN:

			if !key_down[ev.key_code] && !single_key_down[ev.key_code]{
				single_key_down[ev.key_code] = true
			}

			key_down[ev.key_code] = true

			single_key_up[ev.key_code] = false
		case .KEY_UP:
			if key_down[ev.key_code] && !single_key_up[ev.key_code]{
				single_key_up[ev.key_code] = true
			}

			key_down[ev.key_code] = false

			single_key_down[ev.key_code] = false
		case .MOUSE_DOWN:

			if  !mouse_down[ev.mouse_button] && !single_mouse_down[ev.mouse_button]{
				single_mouse_down[ev.mouse_button] = true
			}

			mouse_down[ev.mouse_button] = true

			single_mouse_up[ev.mouse_button] = false	
		case .MOUSE_UP:
			if mouse_down[ev.mouse_button] && !single_mouse_up[ev.mouse_button]{
				single_mouse_up[ev.mouse_button] = true
			}

			mouse_down[ev.mouse_button] = false

			single_mouse_down[ev.mouse_button] = false
		case .RESIZED:
			screen_resized = true
	}
}

// EVENT UTILS (dont really need all of these procs but it makes it a bit more intuitive)

//var for mouse movement
mouse_move: [2]f32

//stores the states for all keys
key_down: #sparse[sapp.Keycode]bool
single_key_up: #sparse[sapp.Keycode]bool
single_key_down: #sparse[sapp.Keycode]bool
mouse_down: #sparse[sapp.Mousebutton]bool
single_mouse_down: #sparse[sapp.Mousebutton]bool
single_mouse_up: #sparse[sapp.Mousebutton]bool
screen_resized: bool

//key press utils

listen_key_single_up :: proc(keycode: sapp.Keycode) -> bool{
	if single_key_up[keycode] {
		single_key_up[keycode] = false
		return true	
	} else do return false
}

listen_key_single_down :: proc(keycode: sapp.Keycode) -> bool{
	if single_key_down[keycode] {
		single_key_down[keycode] = false
		return true	
	} else do return false
}

listen_key_down :: proc(keycode: sapp.Keycode) -> bool{
	if key_down[keycode] do return true	
	else do return false
}

listen_key_up :: proc(keycode: sapp.Keycode) -> bool{
	if !key_down[keycode] do return true	
	else do return false
}


//mouse press utils

listen_mouse_single_up :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if single_mouse_up[Mousebutton] {
		single_mouse_up[Mousebutton] = false
		return true	
	} else do return false
}

listen_mouse_single_down :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if single_mouse_down[Mousebutton] {
		single_mouse_down[Mousebutton] = false
		return true	
	} else do return false
}

listen_mouse_down :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if mouse_down[Mousebutton] do return true	
	else do return false
}

listen_mouse_up :: proc(Mousebutton: sapp.Mousebutton) -> bool{
	if !mouse_down[Mousebutton] do return true	
	else do return false
}

//checks if the screen has been resized and returns a bool
listen_screen_resized :: proc() -> bool{
	if screen_resized do return true
	else do return false
}


