#version 450

//  Coverage: one channel, tinted by the vertex colour. Glyphs.
layout(set = 0, binding = 0) uniform sampler2D text_atlas;

//  Pictures: icons, thumbnails, and colour glyphs, which carry their own colour
//  and take only their opacity from the vertex.
layout(set = 0, binding = 1) uniform sampler2D icon_atlas;

layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec4 in_color;
layout(location = 2) in float in_textured;
layout(location = 3) in float in_texture_source;

layout(location = 0) out vec4 out_color;

void main() {
    vec4 color = in_color;

    if (in_textured > 0.5) {
        if (in_texture_source > 1.5) {
            vec4 sample_color = texture(icon_atlas, in_uv);
            color = vec4(sample_color.rgb, sample_color.a * in_color.a);
        } else {
            float alpha = texture(text_atlas, in_uv).r * in_color.a;
            color = vec4(in_color.rgb, alpha);
        }
    }

    out_color = color;
}
