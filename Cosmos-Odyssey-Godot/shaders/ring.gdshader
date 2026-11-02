shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Saturn-style ring. UV.x = 0 inner .. 1 outer.

float hash1(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	float band = floor(UV.x * 160.0);
	float h = hash1(band);
	float a = (0.25 + h * 0.6) * smoothstep(0.0, 0.05, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
	ALBEDO = vec3(0.78 + 0.16 * h, 0.7 + 0.12 * h, 0.55 + 0.1 * h);
	ALPHA = a;
}
