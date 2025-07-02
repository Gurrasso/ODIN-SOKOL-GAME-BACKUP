package main

import "base:runtime"
import "core:math"
import "core:math/linalg"

import sg "../sokol/gfx"
// stb
import stbi "vendor:stb/image"
import "utils"
import "draw"

//global var for context
default_context: runtime.Context

to_radians :: linalg.to_radians
to_degrees :: linalg.to_degrees
Matrix4 :: linalg.Matrix4f32;

//define own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Id :: u32

Sprite_id :: draw.Sprite_id


Transform :: utils.Transform

DEFAULT_TRANSFORM :: utils.DEFAULT_TRANSFORM

WHITE_IMAGE_PATH :: draw.WHITE_IMAGE_PATH
WHITE_IMAGE: sg.Image
