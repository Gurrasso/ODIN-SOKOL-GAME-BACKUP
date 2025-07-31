package draw

import "core:math/linalg"
import sg "../../sokol/gfx"
import "core:log"

to_radians :: linalg.to_radians
to_degrees :: linalg.to_degrees
Matrix4 :: linalg.Matrix4f32;

//define own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Id :: u32



//used to sort the draw data based on draw_priority
compare_draw_data_draw_priority :: proc(drt: Draw_data, drt2: Draw_data) -> int{
	return int(drt.draw_priority-drt2.draw_priority)
}

PIXEL_SIZE :: 0.045

get_sprite_sheet_size :: proc{
	get_sprite_sheet_size_from_filename,
	get_sprite_sheet_size_from_img,
}

get_sprite_sheet_size_from_filename :: proc(filename: cstring, frame_count: int) -> Vec2{
	return get_sprite_sheet_size_from_img(get_image(filename), frame_count)
}

get_sprite_sheet_size_from_img :: proc(image: sg.Image, frame_count: int) -> Vec2{
	img_size := Vec2{auto_cast sg.query_image_width(image), auto_cast sg.query_image_height(image)}
	img_size.x /= auto_cast frame_count

	return img_size * PIXEL_SIZE
}

get_image_size :: proc{ 
	get_image_size_from_filename,
	get_image_size_from_image,
}

get_image_size_from_filename :: proc(filename: cstring) -> Vec2{
	return get_image_size_from_image(get_image(filename))
}

get_image_size_from_image :: proc(image: sg.Image) -> Vec2{
	return Vec2{auto_cast sg.query_image_width(image), auto_cast sg.query_image_height(image)} * PIXEL_SIZE
}
