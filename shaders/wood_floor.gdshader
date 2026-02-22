shader_type spatial;

// Cartoony wood plank floor - world position via varying
uniform vec3 plank_color_light : source_color = vec3(0.76, 0.56, 0.38);
uniform vec3 plank_color_dark : source_color = vec3(0.62, 0.42, 0.26);
uniform vec3 gap_color : source_color = vec3(0.35, 0.22, 0.12);
uniform float plank_width : hint_range(0.2, 2.0) = 0.8;
uniform float plank_length : hint_range(1.0, 8.0) = 3.0;
uniform float gap_width : hint_range(0.005, 0.06) = 0.025;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.75;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;

	vec2 plank_uv = vec2(uv.x / plank_width, uv.y / plank_length);
	float row = floor(plank_uv.x);
	plank_uv.y += mod(row, 2.0) * 0.5;

	vec2 plank_id = floor(plank_uv);
	float variation = hash(plank_id);
	vec2 plank_pos = fract(plank_uv);

	float gx = gap_width / plank_width;
	float gy = gap_width / plank_length;
	float is_gap = step(plank_pos.x, gx) + step(1.0 - gx, plank_pos.x)
				 + step(plank_pos.y, gy) + step(1.0 - gy, plank_pos.y);
	is_gap = clamp(is_gap, 0.0, 1.0);

	float shade = floor(variation * 3.0) / 3.0;
	vec3 plank_color = mix(plank_color_light, plank_color_dark, shade);
	plank_color *= 0.92 + variation * 0.16;

	float grain = step(0.92, fract(plank_pos.y * 8.0 + variation * 5.0)) * 0.08;
	plank_color -= vec3(grain);

	ALBEDO = mix(plank_color, gap_color, is_gap);
	ROUGHNESS = mix(roughness_val, 0.95, is_gap);
}
