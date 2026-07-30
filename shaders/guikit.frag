#version 450

//  Coverage: one channel, tinted by the vertex colour. Glyphs.
layout(set = 0, binding = 0) uniform sampler2D text_atlas;

//  Pictures: icons, thumbnails, and colour glyphs, which carry their own colour
//  and take only their opacity from the vertex.
layout(set = 0, binding = 1) uniform sampler2D icon_atlas;

//  Colour glyphs -- emoji -- in a sheet of their own, sampled one to one at the
//  size they were rasterized. They used to ride the icon atlas, which gave a
//  20-pixel picture a 64-pixel tile and resampled it twice: up on the way in,
//  down on the way out, dropping and doubling rows both times.
layout(set = 0, binding = 2) uniform sampler2D colour_glyph_sheet;

layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec4 in_color;
layout(location = 2) in float in_textured;
layout(location = 3) in float in_texture_source;

layout(location = 0) out vec4 out_color;

void main() {
    vec4 color = in_color;

    if (in_textured > 0.5) {
        if (in_texture_source > 2.5) {
            //  A picture with its own colours; the vertex supplies opacity only.
            vec4 glyph = texture(colour_glyph_sheet, in_uv);
            color = vec4(glyph.rgb, glyph.a * in_color.a);
        } else if (in_texture_source > 1.5) {
            vec4 sample_color = texture(icon_atlas, in_uv);
            color = vec4(sample_color.rgb, sample_color.a * in_color.a);
        } else {
            float alpha = texture(text_atlas, in_uv).r * in_color.a;
            color = vec4(in_color.rgb, alpha);
        }
    }

    out_color = color;
}
