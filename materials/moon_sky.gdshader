shader_type sky;
// The sky of the moon: black, stars, the sun and the Earth. Scenery; nothing in the tutorial depends on it.

uniform vec3 earth_direction = vec3(0.34, 0.2, -0.92);
uniform float earth_size = 0.07;
uniform vec3 earth_lit_from = vec3(-0.55, 0.45, 0.7);
uniform vec3 ocean : source_color = vec3(0.03, 0.14, 0.42);
uniform vec3 land : source_color = vec3(0.16, 0.26, 0.12);

float hash(vec3 p) {
	p = fract(p * vec3(127.1, 311.7, 74.7));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float clouds(vec3 p) {
	float sum = 0.0;
	float size = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += noise(p) * size;
		p = p * 2.03 + 11.7;
		size *= 0.5;
	}
	return sum;
}

vec3 stars(vec3 direction) {
	vec3 cell = floor(direction * 210.0);
	float star = hash(cell);
	if (star < 0.9965) {
		return vec3(0.0);
	}
	vec3 centre = (cell + vec3(hash(cell + 1.0), hash(cell + 2.0), hash(cell + 3.0))) / 210.0;
	float near = smoothstep(0.0017, 0.0004, distance(direction, normalize(centre)));
	return mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.78), hash(cell + 4.0)) * near * (star - 0.9965) * 900.0;
}

void sky() {
	vec3 colour = stars(EYEDIR);
	vec3 axis = normalize(earth_direction);
	float angle = acos(clamp(dot(EYEDIR, axis), -1.0, 1.0));
	if (angle < earth_size) {
		vec3 up = normalize(cross(axis, vec3(0.0, 1.0, 0.0)));
		vec3 side = cross(up, axis);
		vec2 disc = vec2(dot(EYEDIR, up), dot(EYEDIR, side)) / sin(earth_size);
		float z = sqrt(max(0.0, 1.0 - dot(disc, disc)));
		vec3 ball = normalize(up * disc.x + side * disc.y - axis * z);
		float lit = clamp(dot(ball, normalize(earth_lit_from)), 0.0, 1.0);
		float ground = smoothstep(0.47, 0.53, clouds(ball * 2.6));
		float cloud = smoothstep(0.5, 0.72, clouds(ball * 4.3 + 40.0));
		vec3 surface = mix(mix(ocean, land, ground), vec3(0.95), cloud);
		colour = surface * (lit * 1.6 + 0.01) + vec3(0.12, 0.24, 0.5) * pow(1.0 - z, 2.0) * lit;
	} else {
		colour += vec3(0.1, 0.22, 0.5) * smoothstep(earth_size * 1.1, earth_size, angle) * 0.5;
	}
	if (LIGHT0_ENABLED) {
		float sun = dot(EYEDIR, LIGHT0_DIRECTION);
		colour += LIGHT0_COLOR * smoothstep(0.99985, 0.99995, sun) * 40.0;
		colour += vec3(1.0, 0.95, 0.88) * pow(max(sun, 0.0), 900.0) * 1.2;
	}
	COLOR = colour;
}
