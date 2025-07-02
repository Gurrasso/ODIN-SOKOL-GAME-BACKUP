#+feature dynamic-literals
package draw

import "core:log"
import "core:mem"
import "core:os"
import sg "../../sokol/gfx"
import sapp "../../sokol/app"
// stb
import stbi "vendor:stb/image"

import utils "../utils"

// ==================
//   :IMAGE THINGS
// ==================

//	proc for loading an image from a file
load_image :: proc(filename: cstring) -> sg.Image{
	w, h: i32
	pixels := stbi.load(filename, &w, &h, nil, 4)
	assert(pixels != nil)

	image := sg.make_image({
		width = w,
		height = h,
		pixel_format = .RGBA8,
		data = {
			subimage = {
				0 = {
					0 = {
						ptr = pixels,
						size = uint(w * h * 4)
					}
				}
			}
		}
	})

	append(&g.images, Images{
		filename = filename,
		image = image,
	})


	stbi.image_free(pixels)
	
	return image
}

get_image :: proc(filename: cstring) -> sg.Image{
	
	new_image: sg.Image
	image_exists: bool = false
	for image in g.images{
		if image.filename == filename{
			image_exists = true
			new_image = image.image
		} 
	}

	if !image_exists{
		new_image = load_image(filename)
	}

	return new_image
}

get_image_desc :: proc(filename: cstring) -> sapp.Image_Desc{
	w, h: i32
	pixels := stbi.load(filename, &w, &h, nil, 4)
	assert(pixels != nil)

	pixel_range := sapp.Range{
		ptr = pixels, 
		size = uint(w * h * 4)
	}
	image_desc := sapp.Image_Desc{
		width = w,
		height = h,
		pixels = pixel_range,
	}

	stbi.image_free(pixels)

	return image_desc
}

// BUFFER THINGS

// checks if the buffer already exists and if so it grabs that otherwise it creates it and adds it to an array
get_vertex_buffer :: proc(
	size: Vec2, 
	color_offset: sg.Color, 
	uvs: Vec4, tex_index: u8
) -> sg.Buffer{
	
	buffer: sg.Buffer
	
	buffer_exists: bool = false
	for vertex_buffer in g.vertex_buffers{
		if vertex_buffer.uv_data != uvs || vertex_buffer.size_data != size || vertex_buffer.color_data != color_offset || vertex_buffer.tex_index_data != tex_index do continue
		
		buffer_exists = true
		buffer = vertex_buffer.buffer
		break
	}
	if !buffer_exists{
		vertices := []Vertex_data {
			{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.y}, tex_index = tex_index},
			{ pos = {	(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.y}, tex_index = tex_index},
			{ pos = { -(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.w}, tex_index = tex_index},
			{ pos = {	(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.w}, tex_index = tex_index},
		}
		buffer = sg.make_buffer({size = utils.sg_range(vertices).size, usage = .DYNAMIC})
		sg.update_buffer(buffer, data = utils.sg_range(vertices))

		buffer_data := Vertex_buffer_data{
			buffer = buffer,
			uv_data = uvs,
			size_data = size,
			color_data = color_offset,
			tex_index_data = tex_index,
		}
		append(&g.vertex_buffers, buffer_data)
	}

	return buffer
}


update_vertex_buffer_size :: proc(buffer: sg.Buffer, size: Vec2){
	exists: bool

	for &buffer_data in g.vertex_buffers{
		if buffer_data.buffer == buffer{
			color_offset := buffer_data.color_data
			uvs := buffer_data.uv_data
			tex_index := buffer_data.tex_index_data
			buffer_data.size_data = size

			vertices := []Vertex_data {
				{ pos = { -(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.y}, tex_index = tex_index },
				{ pos = {	(size.x/2), -(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.y}, tex_index = tex_index},
				{ pos = { -(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.x, uvs.w}, tex_index = tex_index},
				{ pos = {	(size.x/2),	(size.y/2), 0 }, col = color_offset, uv = {uvs.z, uvs.w}, tex_index = tex_index},
			}

			sg.update_buffer(buffer, utils.sg_range(vertices))

			exists = true
		}
	}

	if !exists do log.debug("ERROR: FAILED TO UPDATE BUFFER IN update_vertex_buffer_size")
}

