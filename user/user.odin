package user

import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/ease"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:sort"
import "core:fmt"
// stb
import stbi "vendor:stb/image"

to_radians :: linalg.to_radians
to_degrees :: linalg.to_degrees
Matrix4 :: linalg.Matrix4f32;

//define own types
Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Id :: u32

