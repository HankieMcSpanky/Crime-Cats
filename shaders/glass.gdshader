shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

void fragment() {
	ALBEDO = vec3(0.6, 0.8, 1.0);
	ALPHA = 0.1;
}
