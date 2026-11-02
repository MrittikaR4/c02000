shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Glow ring around the black hole event horizon. Quad half-size = outer radius.
uniform float inner_frac = 0.63; // inner radius / outer radius

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float t = clamp((d - inner_frac) / (1.0 - inner_frac), 0.0, 1.0);
	float a = (1.0 - t) * (1.0 - t) * step(inner_frac, d) * step(d, 1.0);
	ALBEDO = vec3(1.0, 0.75, 0.43) * a * 1.4;
	ALPHA = 1.0;
}
