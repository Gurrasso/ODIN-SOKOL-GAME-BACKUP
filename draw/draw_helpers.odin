package draw

import "core:math/linalg"
import sg "../../sokol/gfx"

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
