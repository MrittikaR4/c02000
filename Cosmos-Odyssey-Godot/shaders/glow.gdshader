shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Billboard radial glow. Use on a QuadMesh; always faces the camera.
uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.5);
uniform float opacity = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	// Same falloff as the web version: 1.0 at centre, 0.45 at 25%, 0 at the edge
	float a = d < 0.25 ? mix(1.0, 0.45, d / 0.25) : mix(0.45, 0.0, (d - 0.25) / 0.75);
	ALBEDO = tint * a * opacity;
	ALPHA = 1.0;
}
