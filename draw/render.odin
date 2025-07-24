package draw


import "core:log"
import "core:math"
import "core:math/linalg"
import "core:sort"
import sg "../../sokol/gfx"
import sapp "../../sokol/app"
import shelpers "../../sokol/helpers"

import "../utils"
import "../user"
import cutils "../utils/color"

//draw call data
Draw_data :: struct{
	m: Matrix4,
	b: sg.Bindings,
	// the draw_priority of an obj, basically just says higher draw_priority, draw last(on top)
	draw_priority: i32,
}

Rendering_globals :: struct {
	//graphics stuff
	shader: sg.Shader,
	pipeline: sg.Pipeline,
	index_buffer: sg.Buffer,	
	sampler: sg.Sampler,
	//assumes the correct screen origin to be top left
	inverse_screen_y: bool,
	reverse_screen_y: int,
}

//global vars
Globals :: struct {
	//Sprite_objects for drawing
	text_objects: map[Sprite_id]Text_object,
	sprite_objects: map[Sprite_id]Sprite_object_group,
	lights: map[Light_id]Light,
	//used to avoid initing multiple of the same buffer
	vertex_buffers: [dynamic]Vertex_buffer_data,
	//used to avoid initing mutiple of the same img
	images: [dynamic]Images,
	
	fonts: map[string]FONT_INFO,

	animated_sprite_objects: map[string]Animated_sprite_object,

	world_brightness: f32,
}

Uniforms_vs_data :: struct{
	model_matrix: Mat4,
	veiw_matrix: Mat4,
	projection_matrix: Mat4,
	scz: Vec2,
	reverse_screen_y: int,
}

Uniforms_fs_data :: struct{
	model_matrix: Mat4,
	veiw_matrix: Mat4,
	projection_matrix: Mat4,
	scz: Vec2,
	reverse_screen_y: int,
	lights_transform_data: [LIGHTS_DATA_SIZE]Vec4,
	lights_color_data: [LIGHTS_DATA_SIZE]Vec4,
	world_brightness: f32,
}


rg: ^Rendering_globals

g: ^Globals

init_draw_state :: proc(){

	rg = new(Rendering_globals)

	g = new(Globals)

	set_world_brightness(0.5)

	init_camera()

	//different rendering backends have top left or bottom left as the screen origin
	rg.inverse_screen_y = sg.query_features().origin_top_left ?  false : true
	rg.reverse_screen_y = sg.query_features().origin_top_left ?  1 : -1 

	//white image for scuffed rect rendering
	WHITE_IMAGE = get_image(WHITE_IMAGE_PATH)


	//make the shader and pipeline
	rg.shader = sg.make_shader(user.main_shader_desc(sg.query_backend()))
	pipeline_desc : sg.Pipeline_Desc = {
		shader = rg.shader,
		layout = {
			//different attributes
			attrs = {
			user.ATTR_main_pos = { format = .FLOAT3 },
			user.ATTR_main_col = { format = .FLOAT4 },
			user.ATTR_main_uv = { format = .FLOAT2 },
			user.ATTR_main_bytes0 = { format = .UBYTE4N },
			}
		},
		
		// specify that we want to use index buffer
		index_type = .UINT16,
		//make it so objects draw based on distance from camera
		//depth = {
		//	write_enabled = true,
		//	compare = .LESS_EQUAL
		//},
	}
	
	//the blend state for working with alphas
	blend_state : sg.Blend_State = {
		enabled = true,
		src_factor_rgb = .SRC_ALPHA,
		dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
		op_rgb = .ADD,
		src_factor_alpha = .ONE,
		dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
		op_alpha = .ADD,
	}
	
	pipeline_desc.colors[0] = { blend = blend_state}
	rg.pipeline = sg.make_pipeline(pipeline_desc)

	// indices
	indices := []u16 {
		0, 1, 2,
		2, 1, 3,
	}
	// index buffer
	rg.index_buffer = sg.make_buffer({
		type = .INDEXBUFFER,
		data = utils.sg_range(indices),
	})

	//create the sampler
	rg.sampler = sg.make_sampler({})


}

draw_draw_state :: proc(){
	
	update_animated_sprites()

	//
	// rendering	
	//

	//projection matrix
	p := linalg.matrix4_perspective_f32(70, utils.screen_size.x / utils.screen_size.y, 0.0001, 1000)
	//view matrix
	v := linalg.matrix4_look_at_f32(camera.position, camera.target, {camera.rotation, 1, 0})

	sg.begin_pass({ swapchain = shelpers.glue_swapchain()})

	//apply the pipeline to the sokol graphics
	sg.apply_pipeline(rg.pipeline)

	draw_data: [dynamic]Draw_data

	//do things for all text objects
	for id in g.text_objects {
		for obj in g.text_objects[id].objects{

			pos := obj.pos + Vec3{obj.rotation_pos_offset.x, obj.rotation_pos_offset.y, 0}
			//model matrix turns vertex positions into world space positions
			m := linalg.matrix4_translate_f32(pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.x), to_radians(obj.rot.y), to_radians(obj.rot.z))
	
	
			b := sg.Bindings {
				vertex_buffers = { 0 = obj.vertex_buffer },
				index_buffer = rg.index_buffer,
				images = { user.IMG_tex = obj.img },
				samplers = { user.SMP_smp = rg.sampler },
			}

			append(&draw_data, Draw_data{
				m = m,
				b = b,
				draw_priority = g.text_objects[id].draw_priority,
			})
		}
	}

	//do things for all objects
	for id in g.sprite_objects {
		for obj in g.sprite_objects[id].objects{
			
			//model matrix turns vertex positions into world space positions
			m := linalg.matrix4_translate_f32(obj.pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.x), to_radians(obj.rot.y), to_radians(obj.rot.z))
	
			b := sg.Bindings {
				vertex_buffers = { 0 = obj.vertex_buffer },
				index_buffer = rg.index_buffer,
				images = { user.IMG_tex = obj.img },
				samplers = { user.SMP_smp = rg.sampler },
			}

			append(&draw_data, Draw_data{
				m = m,
				b = b,
				draw_priority = obj.draw_priority,
			})
		}	
	}

	//animated sprites
	for id in g.animated_sprite_objects{
		obj := g.animated_sprite_objects[id]	


		//model matrix turns vertex positions into world space positions
		m := linalg.matrix4_translate_f32(obj.pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.x), to_radians(obj.rot.y), to_radians(obj.rot.z))
	
		b := sg.Bindings {
			vertex_buffers = { 0 = obj.vertex_buffer },
			index_buffer = rg.index_buffer,
			images = { user.IMG_tex = obj.sprite_sheet },
			samplers = { user.SMP_smp = rg.sampler },
		}

		append(&draw_data, Draw_data{
			m = m,
			b = b,
			draw_priority = obj.draw_priority,
		})
	}	

	//sort the array based on draw_priority so we can chose which things we want to be drawn over other, higher draw priority means that it gets drawn after(on top)
	sort.merge_sort_proc(draw_data[:], compare_draw_data_draw_priority)

	for drt in draw_data {
		sg.apply_bindings(drt.b)

		//apply uniforms for vertex shader
		sg.apply_uniforms(user.UB_Uniforms_vs_Data, utils.sg_range(&Uniforms_vs_data{
			model_matrix = drt.m,
			veiw_matrix = v,
			projection_matrix = p,
			scz = utils.screen_size,
			reverse_screen_y = rg.reverse_screen_y,
		}))

		lights_transform_data, lights_color_data := generate_lighting_uniforms_data()

		//apply uniforms for fragment shader
		sg.apply_uniforms(user.UB_Uniforms_fs_Data, utils.sg_range(&Uniforms_fs_data{
			model_matrix = drt.m,
			veiw_matrix = v,
			projection_matrix = p,
			scz = utils.screen_size,
			reverse_screen_y = rg.reverse_screen_y,
			lights_transform_data = lights_transform_data,
			lights_color_data = lights_color_data,
			world_brightness = g.world_brightness,
		}))

		sg.draw(0, 6, 1)
	}

	sg.end_pass()

	sg.commit()

}

draw_cleanup :: proc(){
	// DESTROY!!!
	for buffer in g.vertex_buffers{
		sg.destroy_buffer(buffer.buffer)
	}

	for image in g.images{
		sg.destroy_image(image.image)
	}

	for id, data in g.fonts {
		sg.destroy_image(data.img)
	}



	sg.destroy_sampler(rg.sampler)
	sg.destroy_buffer(rg.index_buffer)
	sg.destroy_pipeline(rg.pipeline)
	sg.destroy_shader(rg.shader)

	//free the global vars
	free(g)
	free(rg)
}
