shader_type spatial;

// Cartoony carpet - world position via varying
uniform vec3 carpet_color : source_color = vec3(0.4, 0.48, 0.65);
uniform vec3 carpet_color_alt : source_color = vec3(0.35, 0.42, 0.56);
uniform float roughness_val : hint_range(0.8, 1.0) = 0.98;
uniform float pattern_scale : hint_range(1.0, 10.0) = 4.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * pattern_scale;

	float n = noise(uv * 5.0) * 0.5 + noise(uv * 12.0) * 0.3 + noise(uv * 25.0) * 0.2;

	float diamond = abs(fract(uv.x) - 0.5) + abs(fract(uv.y) - 0.5);
	diamond = smoothstep(0.3, 0.7, diamond);

	vec3 color = mix(carpet_color, carpet_color_alt, n * 0.5 + diamond * 0.3);

	ALBEDO = color;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.05;
}
