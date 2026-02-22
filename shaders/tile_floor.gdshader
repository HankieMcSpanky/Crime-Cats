shader_type spatial;

// Cartoony tile floor - world position via varying
uniform vec3 tile_color_1 : source_color = vec3(0.92, 0.93, 0.95);
uniform vec3 tile_color_2 : source_color = vec3(0.78, 0.82, 0.88);
uniform vec3 grout_color : source_color = vec3(0.6, 0.58, 0.55);
uniform float tile_size : hint_range(0.2, 2.0) = 0.6;
uniform float grout_width : hint_range(0.01, 0.08) = 0.035;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.35;
uniform bool checkerboard = true;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;

	vec2 tile_uv = uv / tile_size;
	vec2 tile_id = floor(tile_uv);
	vec2 tile_pos = fract(tile_uv);

	float gs = grout_width / tile_size;
	float is_grout = step(tile_pos.x, gs) + step(1.0 - gs, tile_pos.x)
				   + step(tile_pos.y, gs) + step(1.0 - gs, tile_pos.y);
	is_grout = clamp(is_grout, 0.0, 1.0);

	vec3 tile_color;
	if (checkerboard) {
		float checker = mod(tile_id.x + tile_id.y, 2.0);
		tile_color = mix(tile_color_1, tile_color_2, checker);
	} else {
		tile_color = tile_color_1;
	}

	ALBEDO = mix(tile_color, grout_color, is_grout);
	ROUGHNESS = mix(roughness_val, 0.9, is_grout);
	SPECULAR = mix(0.5, 0.1, is_grout);
}
