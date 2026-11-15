shader_type spatial;
// The moon surface: light, smooth rock under a layer of lavender grey dust. The mask says how much dust lies on every point of the tile, and where it stands.

#include "dust.gdshaderinc"

uniform vec3 dust_colour : source_color = vec3(0.6, 0.575, 0.62);
uniform vec3 rock_colour : source_color = vec3(0.71, 0.7, 0.73);
uniform vec3 pebble_colour : source_color = vec3(0.6, 0.59, 0.66);
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform sampler2D powder_normals : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normals : hint_normal, filter_linear_mipmap, repeat_enable;

// The same bytes also lift the dust: every point of the mesh rises by its lift.
void vertex() {
	VERTEX.y += lift(edge_at(UV / tile_metres + vec2(0.5)));
}

// Small round stones on the dust: in most cells of 25 cm one, at a random spot, up to 9 cm across.
// x is how much stone covers the point, yz the slope there: flat on top, rounding off softly at the rim.
vec3 pebble_at(vec2 metres) {
	vec2 cell = floor(metres / 0.25);
	vec3 random = fract(sin(vec3(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)), dot(cell, vec2(419.2, 371.9)))) * 43758.5453);
	vec2 centre = (cell + 0.2 + random.yz * 0.6) * 0.25;
	vec2 offset = (metres - centre) / (0.018 + random.y * 0.023);
	// The outline swells and shrinks a little twice around the stone, so it is round but not a perfect circle.
	float outline = 1.0 + 0.1 * sin(2.0 * atan(offset.y, offset.x) + random.z * TAU);
	float reach = length(offset) / outline;
	if (random.x > 0.8 || reach >= 1.0) {
		return vec3(0.0);
	}
	return vec3(1.0 - smoothstep(0.8, 1.0, reach), -1.5 * offset * smoothstep(0.4, 1.0, reach));
}

void fragment() {
	vec2 metres = UV;
	vec2 tile_uv = metres / tile_metres + vec2(0.5);
	float edge = edge_at(tile_uv);

	float fine = texture(grain, metres * 0.61).r;
	float coarse = texture(grain, metres * 0.13).r;
	float land = texture(grain, metres * 0.011).r;
	float dust = smoothstep(-0.01, 0.01, edge);

	vec3 powder = dust_colour * (0.8 + fine * 0.3) * (0.72 + land * 0.56);
	vec3 rock = rock_colour * (0.94 + coarse * 0.12);

	// The wall at every pixel: slope is how steep the lift is here, pointed the way the mask grows.
	vec2 slope = (lift(edge + 0.005) - lift(edge - 0.005)) / 0.01 * normalize(change_at(tile_uv) + vec2(0.000001));
	// The small stones lie only on the full layer, and each one adds its own slope. Far away a stone is smaller than a few pixels and would
	// flicker: fwidth is how many metres one pixel covers here, and from 2 to 4 cm a pixel the stones fade out.
	float far = smoothstep(0.02, 0.04, length(fwidth(metres)));
	vec3 pebble = pebble_at(metres) * smoothstep(0.08, 0.12, edge) * (1.0 - far);
	slope += pebble.yz;
	vec3 up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(up - vec3(slope.x, 0.0, slope.y), 0.0)).xyz);

	ALBEDO = mix(mix(rock, powder, dust), pebble_colour, pebble.x);
	NORMAL_MAP = mix(texture(rock_normals, metres * 0.11).rgb, texture(powder_normals, metres * 0.43).rgb, dust);
	// On a steep face the bumps of the normal map would streak, so they flatten as the slope grows.
	NORMAL_MAP_DEPTH = mix(0.2, 0.8, dust) / (1.0 + 4.0 * dot(slope, slope));
	ROUGHNESS = mix(0.72, 0.96, dust);
	SPECULAR = mix(0.25, 0.2, dust);
}
