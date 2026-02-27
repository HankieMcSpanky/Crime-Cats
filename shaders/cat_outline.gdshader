shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled;

uniform vec4 outline_color : source_color = vec4(0.0, 0.8, 1.0, 0.6);
uniform float outline_thickness : hint_range(0.0, 0.05) = 0.008;

void vertex() {
	// Extrude vertices along normals to create outline shell
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
