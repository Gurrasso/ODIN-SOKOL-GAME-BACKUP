package ui

import "base:runtime"
import "core:math"
import "core:math/linalg"

import sg "../../sokol/gfx"
// stb
import "../utils"
import "../draw"

to_radians :: linalg.to_radians
to_degrees :: linalg.to_degrees

//define own types
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

Sprite_id :: draw.Sprite_id

Transform :: utils.Transform

DEFAULT_TRANSFORM :: utils.DEFAULT_TRANSFORM

WHITE_IMAGE_PATH :: draw.WHITE_IMAGE_PATH
WHITE_IMAGE: sg.Image
