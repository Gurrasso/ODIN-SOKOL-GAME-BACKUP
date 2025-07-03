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


sg_color_from_rgba :: proc (color4: Vec4) -> sg.Color{
	color := color4

	new_color := sg.Color{color.r/255, color.g/255, color.b/255, color.a/255}

	return new_color

}

sg_color_from_rgb :: proc (color3: Vec3) -> sg.Color{
	color := color3

	new_color := sg.Color{color.r/255, color.g/255, color.b/255, 1}

	return new_color

}

sg_color_to_vec4 :: proc(c: sg.Color) -> Vec4{
	return {c.r, c.g, c.b, c.a}
}
