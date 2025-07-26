package color_utils

import sg "../../../sokol/gfx"



//define own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Id :: u32
//color utils

sg_color :: proc{
	sg_color_from_rgb,
	sg_color_from_rgba,
}

sg_color_from_rgba :: proc (color: Vec4) -> sg.Color where type_of(color) == Vec4{
	return sg.Color{color.r/255, color.g/255, color.b/255, color.a/255}
}

sg_color_from_rgb :: proc (color: Vec3) -> sg.Color{
	return sg.Color{color.r/255, color.g/255, color.b/255, 1}
}

sg_color_to_vec4 :: proc(c: sg.Color) -> Vec4{
	return {c.r, c.g, c.b, c.a}
}
