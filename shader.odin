package main
import sg "../sokol/gfx"
/*
    #version:1# (machine generated, don't edit!)

    Generated by sokol-shdc (https://github.com/floooh/sokol-tools)

    Cmdline:
        sokol-shdc -i src/shader.glsl -o src/shader.odin -l glsl410 -f sokol_odin

    Overview:
    =========
    Shader program: 'main':
        Get shader desc: main_shader_desc(sg.query_backend())
        Vertex Shader: vs
        Fragment Shader: fs
        Attributes:
            ATTR_main_pos => 0
            ATTR_main_col => 1
            ATTR_main_uv => 2
            ATTR_main_bytes0 => 3
    Bindings:
        Uniform block 'vs_params':
            Odin struct: Vs_Params
            Bind slot: UB_vs_params => 0
        Image 'tex':
            Image type: ._2D
            Sample type: .FLOAT
            Multisampled: false
            Bind slot: IMG_tex => 0
        Sampler 'smp':
            Type: .FILTERING
            Bind slot: SMP_smp => 0
*/
ATTR_main_pos :: 0
ATTR_main_col :: 1
ATTR_main_uv :: 2
ATTR_main_bytes0 :: 3
UB_vs_params :: 0
IMG_tex :: 0
SMP_smp :: 0
Vs_Params :: struct #align(16) {
    using _: struct #packed {
        mvp: Mat4,
    },
}
/*
    #version 410

    uniform vec4 vs_params[4];
    layout(location = 0) in vec3 pos;
    layout(location = 0) out vec4 color;
    layout(location = 1) in vec4 col;
    layout(location = 1) out vec2 texcoord;
    layout(location = 2) in vec2 uv;
    layout(location = 2) out vec4 bytes;
    layout(location = 3) in vec4 bytes0;

    void main()
    {
        gl_Position = mat4(vs_params[0], vs_params[1], vs_params[2], vs_params[3]) * vec4(pos, 1.0);
        color = col;
        texcoord = uv;
        bytes = bytes0;
    }

*/
@(private="file")
vs_source_glsl410 := [465]u8 {
    0x23,0x76,0x65,0x72,0x73,0x69,0x6f,0x6e,0x20,0x34,0x31,0x30,0x0a,0x0a,0x75,0x6e,
    0x69,0x66,0x6f,0x72,0x6d,0x20,0x76,0x65,0x63,0x34,0x20,0x76,0x73,0x5f,0x70,0x61,
    0x72,0x61,0x6d,0x73,0x5b,0x34,0x5d,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,
    0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x30,0x29,0x20,0x69,0x6e,
    0x20,0x76,0x65,0x63,0x33,0x20,0x70,0x6f,0x73,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,
    0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x30,0x29,0x20,
    0x6f,0x75,0x74,0x20,0x76,0x65,0x63,0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,
    0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,
    0x3d,0x20,0x31,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,0x34,0x20,0x63,0x6f,0x6c,
    0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,
    0x6e,0x20,0x3d,0x20,0x31,0x29,0x20,0x6f,0x75,0x74,0x20,0x76,0x65,0x63,0x32,0x20,
    0x74,0x65,0x78,0x63,0x6f,0x6f,0x72,0x64,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,
    0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x32,0x29,0x20,0x69,
    0x6e,0x20,0x76,0x65,0x63,0x32,0x20,0x75,0x76,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,
    0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x32,0x29,0x20,
    0x6f,0x75,0x74,0x20,0x76,0x65,0x63,0x34,0x20,0x62,0x79,0x74,0x65,0x73,0x3b,0x0a,
    0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,
    0x3d,0x20,0x33,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,0x34,0x20,0x62,0x79,0x74,
    0x65,0x73,0x30,0x3b,0x0a,0x0a,0x76,0x6f,0x69,0x64,0x20,0x6d,0x61,0x69,0x6e,0x28,
    0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x67,0x6c,0x5f,0x50,0x6f,0x73,0x69,0x74,
    0x69,0x6f,0x6e,0x20,0x3d,0x20,0x6d,0x61,0x74,0x34,0x28,0x76,0x73,0x5f,0x70,0x61,
    0x72,0x61,0x6d,0x73,0x5b,0x30,0x5d,0x2c,0x20,0x76,0x73,0x5f,0x70,0x61,0x72,0x61,
    0x6d,0x73,0x5b,0x31,0x5d,0x2c,0x20,0x76,0x73,0x5f,0x70,0x61,0x72,0x61,0x6d,0x73,
    0x5b,0x32,0x5d,0x2c,0x20,0x76,0x73,0x5f,0x70,0x61,0x72,0x61,0x6d,0x73,0x5b,0x33,
    0x5d,0x29,0x20,0x2a,0x20,0x76,0x65,0x63,0x34,0x28,0x70,0x6f,0x73,0x2c,0x20,0x31,
    0x2e,0x30,0x29,0x3b,0x0a,0x20,0x20,0x20,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,
    0x20,0x63,0x6f,0x6c,0x3b,0x0a,0x20,0x20,0x20,0x20,0x74,0x65,0x78,0x63,0x6f,0x6f,
    0x72,0x64,0x20,0x3d,0x20,0x75,0x76,0x3b,0x0a,0x20,0x20,0x20,0x20,0x62,0x79,0x74,
    0x65,0x73,0x20,0x3d,0x20,0x62,0x79,0x74,0x65,0x73,0x30,0x3b,0x0a,0x7d,0x0a,0x0a,
    0x00,
}
/*
    #version 410

    uniform sampler2D tex_smp;

    layout(location = 2) in vec4 bytes;
    layout(location = 1) in vec2 texcoord;
    layout(location = 0) out vec4 frag_color;
    layout(location = 0) in vec4 color;

    void main()
    {
        int _20 = int(bytes.x * 255.0);
        vec4 tex_col = vec4(1.0);
        if (_20 == 0)
        {
            tex_col = texture(tex_smp, texcoord);
        }
        else
        {
            if (_20 == 1)
            {
                vec4 _68 = tex_col;
                _68.w = texture(tex_smp, texcoord).x;
                tex_col = _68;
            }
        }
        frag_color = tex_col;
        frag_color *= color;
    }

*/
@(private="file")
fs_source_glsl410 := [579]u8 {
    0x23,0x76,0x65,0x72,0x73,0x69,0x6f,0x6e,0x20,0x34,0x31,0x30,0x0a,0x0a,0x75,0x6e,
    0x69,0x66,0x6f,0x72,0x6d,0x20,0x73,0x61,0x6d,0x70,0x6c,0x65,0x72,0x32,0x44,0x20,
    0x74,0x65,0x78,0x5f,0x73,0x6d,0x70,0x3b,0x0a,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,
    0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x32,0x29,0x20,0x69,
    0x6e,0x20,0x76,0x65,0x63,0x34,0x20,0x62,0x79,0x74,0x65,0x73,0x3b,0x0a,0x6c,0x61,
    0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,
    0x31,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,0x32,0x20,0x74,0x65,0x78,0x63,0x6f,
    0x6f,0x72,0x64,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,
    0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x30,0x29,0x20,0x6f,0x75,0x74,0x20,0x76,0x65,
    0x63,0x34,0x20,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x6c,
    0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,
    0x20,0x30,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,0x34,0x20,0x63,0x6f,0x6c,0x6f,
    0x72,0x3b,0x0a,0x0a,0x76,0x6f,0x69,0x64,0x20,0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,
    0x7b,0x0a,0x20,0x20,0x20,0x20,0x69,0x6e,0x74,0x20,0x5f,0x32,0x30,0x20,0x3d,0x20,
    0x69,0x6e,0x74,0x28,0x62,0x79,0x74,0x65,0x73,0x2e,0x78,0x20,0x2a,0x20,0x32,0x35,
    0x35,0x2e,0x30,0x29,0x3b,0x0a,0x20,0x20,0x20,0x20,0x76,0x65,0x63,0x34,0x20,0x74,
    0x65,0x78,0x5f,0x63,0x6f,0x6c,0x20,0x3d,0x20,0x76,0x65,0x63,0x34,0x28,0x31,0x2e,
    0x30,0x29,0x3b,0x0a,0x20,0x20,0x20,0x20,0x69,0x66,0x20,0x28,0x5f,0x32,0x30,0x20,
    0x3d,0x3d,0x20,0x30,0x29,0x0a,0x20,0x20,0x20,0x20,0x7b,0x0a,0x20,0x20,0x20,0x20,
    0x20,0x20,0x20,0x20,0x74,0x65,0x78,0x5f,0x63,0x6f,0x6c,0x20,0x3d,0x20,0x74,0x65,
    0x78,0x74,0x75,0x72,0x65,0x28,0x74,0x65,0x78,0x5f,0x73,0x6d,0x70,0x2c,0x20,0x74,
    0x65,0x78,0x63,0x6f,0x6f,0x72,0x64,0x29,0x3b,0x0a,0x20,0x20,0x20,0x20,0x7d,0x0a,
    0x20,0x20,0x20,0x20,0x65,0x6c,0x73,0x65,0x0a,0x20,0x20,0x20,0x20,0x7b,0x0a,0x20,
    0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x69,0x66,0x20,0x28,0x5f,0x32,0x30,0x20,0x3d,
    0x3d,0x20,0x31,0x29,0x0a,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x7b,0x0a,0x20,
    0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x76,0x65,0x63,0x34,0x20,
    0x5f,0x36,0x38,0x20,0x3d,0x20,0x74,0x65,0x78,0x5f,0x63,0x6f,0x6c,0x3b,0x0a,0x20,
    0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x5f,0x36,0x38,0x2e,0x77,
    0x20,0x3d,0x20,0x74,0x65,0x78,0x74,0x75,0x72,0x65,0x28,0x74,0x65,0x78,0x5f,0x73,
    0x6d,0x70,0x2c,0x20,0x74,0x65,0x78,0x63,0x6f,0x6f,0x72,0x64,0x29,0x2e,0x78,0x3b,
    0x0a,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x74,0x65,0x78,
    0x5f,0x63,0x6f,0x6c,0x20,0x3d,0x20,0x5f,0x36,0x38,0x3b,0x0a,0x20,0x20,0x20,0x20,
    0x20,0x20,0x20,0x20,0x7d,0x0a,0x20,0x20,0x20,0x20,0x7d,0x0a,0x20,0x20,0x20,0x20,
    0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,0x74,0x65,0x78,
    0x5f,0x63,0x6f,0x6c,0x3b,0x0a,0x20,0x20,0x20,0x20,0x66,0x72,0x61,0x67,0x5f,0x63,
    0x6f,0x6c,0x6f,0x72,0x20,0x2a,0x3d,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x7d,
    0x0a,0x0a,0x00,
}
main_shader_desc :: proc (backend: sg.Backend) -> sg.Shader_Desc {
    desc: sg.Shader_Desc
    desc.label = "main_shader"
    #partial switch backend {
    case .GLCORE:
        desc.vertex_func.source = transmute(cstring)&vs_source_glsl410
        desc.vertex_func.entry = "main"
        desc.fragment_func.source = transmute(cstring)&fs_source_glsl410
        desc.fragment_func.entry = "main"
        desc.attrs[0].glsl_name = "pos"
        desc.attrs[1].glsl_name = "col"
        desc.attrs[2].glsl_name = "uv"
        desc.attrs[3].glsl_name = "bytes0"
        desc.uniform_blocks[0].stage = .VERTEX
        desc.uniform_blocks[0].layout = .STD140
        desc.uniform_blocks[0].size = 64
        desc.uniform_blocks[0].glsl_uniforms[0].type = .FLOAT4
        desc.uniform_blocks[0].glsl_uniforms[0].array_count = 4
        desc.uniform_blocks[0].glsl_uniforms[0].glsl_name = "vs_params"
        desc.images[0].stage = .FRAGMENT
        desc.images[0].multisampled = false
        desc.images[0].image_type = ._2D
        desc.images[0].sample_type = .FLOAT
        desc.samplers[0].stage = .FRAGMENT
        desc.samplers[0].sampler_type = .FILTERING
        desc.image_sampler_pairs[0].stage = .FRAGMENT
        desc.image_sampler_pairs[0].image_slot = 0
        desc.image_sampler_pairs[0].sampler_slot = 0
        desc.image_sampler_pairs[0].glsl_name = "tex_smp"
    }
    return desc
}
