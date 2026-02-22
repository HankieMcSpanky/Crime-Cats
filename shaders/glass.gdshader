shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, shadows_disabled;

// Translucent cartoon window glass
uniform vec3 glass_tint : source_color = vec3(0.65, 0.82, 0.95);
uniform float opacity : hint_range(0.05, 0.6) = 0.25;
uniform float edge_opacity : hint_range(0.1, 0.8) = 0.45;

void fragment() {
	// Fresnel-like effect: edges more opaque than center
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float alpha = mix(opacity, edge_opacity, fresnel);

	ALBEDO = glass_tint;
	ALPHA = alpha;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	METALLIC = 0.05;
}
