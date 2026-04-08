uniform int n_colors = 2;
uniform vec3[256] colors;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    color *= Texel(tex, texture_coords);

    int n = int(floor(color[0] * (n_colors - 1)));
    color.rgb = colors[n];

    return color;
}
