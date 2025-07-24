package collisions

import "core:math/linalg"
import "../utils"

to_radians :: linalg.to_radians
to_degrees :: linalg.to_degrees

//define own types
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Id :: u32

Transform :: utils.Transform

DEFAULT_TRANSFORM :: utils.DEFAULT_TRANSFORM
