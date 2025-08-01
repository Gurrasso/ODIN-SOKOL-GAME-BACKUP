/*
	Builds into a program that builds the game
*/

#+feature dynamic-literals
package build

import path "core:path/filepath"
import "core:fmt"
import "core:os/os2"
import "core:os"
import "core:strings"
import "core:log"
import "core:reflect"
import "core:time"

import "../utils"

EXE_NAME :: "game"

main :: proc() {
	// note, ODIN_OS is built in, but we're being explicit
	assert(ODIN_OS == .Windows || ODIN_OS == .Linux, "unsupported OS target")

	start_time := time.now()

	fmt.println("Building for", ODIN_OS)

	// generate the shader
	// docs: https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md
	when ODIN_OS == .Windows do utils.fire("src/build/tools/windows/sokol-shdc.exe", "-i", "src/shaders/shader.glsl", "-o", "src/user/generated_shader.odin", "-l", "hlsl5", "-f", "sokol_odin")
	when ODIN_OS == .Linux do utils.fire("src/build/tools/linux/sokol-shdc", "-i", "src/shaders/shader.glsl", "-o", "src/user/generated_shader.odin", "-l", "glsl410", "-f", "sokol_odin")

	wd := os.get_current_directory()

	//utils.make_directory_if_not_exist("build")
	
	out_dir : string
	#partial switch ODIN_OS {
		case .Windows: out_dir = "build/windows/"
		case .Linux: out_dir = "build/linux/"
	}

	full_out_dir_path := fmt.tprintf("%v/%v", wd, out_dir)
	log.info(full_out_dir_path)
	utils.make_directory_if_not_exist(full_out_dir_path)

	suffix: string
	#partial switch ODIN_OS{
		case .Windows: suffix = "exe"
		case .Linux: suffix= "bin"
	}

	// build command
	{
		c: [dynamic]string = {
			"odin",
			"run",
			"src",
			fmt.tprintf("-out:%v/%v.%v", out_dir, EXE_NAME, suffix),
		}
		// not needed, it's easier to just generate code into generated.odin
		//append(&c, fmt.tprintf("-define:TARGET_STRING=%v", target))
		utils.fire(..c[:])
	}

	// copy stuff into folder
	{
		// NOTE, if it already exists, it won't copy (to save build time)
		files_to_copy: [dynamic]string

		#partial switch ODIN_OS{
			case .Windows:
			append(&files_to_copy, "src/lib/fmod/studio/lib/windows/x64/fmodstudio.dll")
			append(&files_to_copy, "src/lib/fmod/studio/lib/windows/x64/fmodstudioL.dll")
			append(&files_to_copy, "src/lib/fmod/core/lib/windows/x64/fmod.dll")
			append(&files_to_copy, "src/lib/fmod/core/lib/windows/x64/fmodL.dll")

			case .Linux:
			append(&files_to_copy, "src/lib/fmod/studio/lib/linux/x86_64/libfmodstudio.so.13")
			append(&files_to_copy, "src/lib/fmod/studio/lib/linux/x86_64/libfmodstudioL.so.13")
			append(&files_to_copy, "src/lib/fmod/core/lib/linux/x86_64/libfmod.so.13")
			append(&files_to_copy, "src/lib/fmod/core/lib/linux/x86_64/libfmodL.so.13")
		}

		for src in files_to_copy {
			dir, file_name := path.split(src)
			assert(os.exists(dir), fmt.tprint("directory doesn't exist:", dir))
			dest := fmt.tprintf("%v/%v", out_dir, file_name)
			if !os.exists(dest) {
				os2.copy_file(dest, src)
			}
		}
	}

	fmt.println("DONE in", time.diff(start_time, time.now()))
}


// value extraction example:
/*
target: Target
found: bool
for arg in os2.args {
	if strings.starts_with(arg, "target:") {
		target_string := strings.trim_left(arg, "target:")
		value, ok := reflect.enum_from_name(Target, target_string)
		if ok {
			target = value
			found = true
			break
		} else {
			log.error("Unsupported target:", target_string)
		}
	}
}
*/
