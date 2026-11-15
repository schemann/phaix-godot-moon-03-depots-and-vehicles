// The dust of the moon, for every shader that stands on it: the mask, where the dust ends, and how high it stands.

uniform sampler2D dust_mask : hint_default_white, filter_linear, repeat_disable;
uniform float tile_metres = 32.0;
uniform float cut = 0.5; // Where the dust ends: under half a layer the rock shows.
uniform float dust_metres = 0.09; // How high the layer of dust stands on the rock.

// The mask at a place on the tile, the mean of four reads one pixel around it: the edge of a stroke is one pixel wide in the mask, and the
// mean spreads it over three, so the wall can follow it smoothly at any angle. Everything outside the tile counts as full dust.
float dust_at(vec2 tile_uv) {
	if (tile_uv.x < 0.0 || tile_uv.x > 1.0 || tile_uv.y < 0.0 || tile_uv.y > 1.0) {
		return 1.0;
	}
	float pixel = 1.0 / float(textureSize(dust_mask, 0).x);
	return (texture(dust_mask, tile_uv + vec2(-pixel, -pixel)).r + texture(dust_mask, tile_uv + vec2(pixel, -pixel)).r
		+ texture(dust_mask, tile_uv + vec2(-pixel, pixel)).r + texture(dust_mask, tile_uv + vec2(pixel, pixel)).r) * 0.25;
}

// How fast the mask changes per metre, along x and along z: the difference of the pixels on either side.
vec2 change_at(vec2 tile_uv) {
	float pixel = 1.0 / float(textureSize(dust_mask, 0).x);
	return vec2(
		dust_at(tile_uv + vec2(pixel, 0.0)) - dust_at(tile_uv - vec2(pixel, 0.0)),
		dust_at(tile_uv + vec2(0.0, pixel)) - dust_at(tile_uv - vec2(0.0, pixel))
	) / (2.0 * pixel * tile_metres);
}

// How far a point lies inside the dust, in metres, and below zero on the rock: how far its mask is above the cut, divided by how fast the mask changes.
float edge_at(vec2 tile_uv) {
	return (dust_at(tile_uv) - cut) / max(length(change_at(tile_uv)), 0.5);
}

// How high the dust stands: nothing on the rock, the whole layer from 8 cm inside the dust on. In between stands the wall.
float lift(float edge) {
	return smoothstep(0.0, 0.08, edge) * dust_metres;
}
