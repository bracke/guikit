#version 450

//  Positions arrive already in clip space; the CPU side does the projection, so
//  there is no push constant and no matrix here.
layout(location = 0) in vec2 in_pos;
layout(location = 1) in vec2 in_uv;
layout(location = 2) in vec4 in_color;
layout(location = 3) in float in_textured;
layout(location = 4) in float in_texture_source;

layout(location = 0) out vec2 out_uv;
layout(location = 1) out vec4 out_color;
layout(location = 2) out float out_textured;
layout(location = 3) out float out_texture_source;

void main() {
    gl_Position = vec4(in_pos, 0.0, 1.0);
    out_uv = in_uv;
    out_color = in_color;
    out_textured = in_textured;
    out_texture_source = in_texture_source;
}
