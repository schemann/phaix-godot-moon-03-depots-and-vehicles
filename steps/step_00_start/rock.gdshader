shader_type spatial;
render_mode world_vertex_coords;
// The stones of the crater: blue grey rock with dust settled on what faces up. Every stone rides on the dust under its centre.

#include "dust.gdshaderinc"

uniform vec3 dust_colour : source_color = vec3(0.6, 0.575, 0.62);
uniform vec3 rock_colour : source_color = vec3(0.3, 0.31, 0.38);

varying float up;

// In world coordinates: the whole stone rises by the lift of the dust under its centre, so it lies on the dust and sinks where the dust is cleaned.
void vertex() {
	up = normalize(NORMAL).y;
	vec2 centre = MODEL_MATRIX[3].xz;
	VERTEX.y += lift(edge_at(centre / tile_metres + vec2(0.5)));
}

void fragment() {
	float settled = smoothstep(0.35, 0.8, up);
	ALBEDO = mix(rock_colour, dust_colour, settled);
	ROUGHNESS = mix(0.5, 0.95, settled);
}
