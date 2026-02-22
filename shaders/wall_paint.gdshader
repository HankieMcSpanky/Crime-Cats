shader_type spatial;

// Cartoony painted wall - world position via varying
uniform vec3 wall_color : source_color = vec3(0.95, 0.92, 0.85);
uniform float variation_amount : hint_range(0.0, 0.1) = 0.03;
uniform float roughness_val : hint_range(0.5, 1.0) = 0.85;
uniform float stroke_scale : hint_range(5.0, 40.0) = 15.0;

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
	vec2 uv = world_pos.xy + world_pos.yz;

	float stroke = noise(vec2(uv.x * stroke_scale * 2.0, uv.y * stroke_scale * 0.4));
	float detail = noise(vec2(uv.x * stroke_scale * 0.7, uv.y * stroke_scale * 1.2));
	float combined = stroke * 0.6 + detail * 0.4;

	vec3 color = wall_color + vec3(combined - 0.5) * variation_amount;

	ALBEDO = color;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.1;
}
