shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Black hole accretion disk. UV.x = 0 inner edge .. 1 outer edge, UV.y = angle / 2pi (0..1)

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float r = UV.x;
	vec3 inner = vec3(1.0, 0.98, 0.86);
	vec3 mid = vec3(1.0, 0.78, 0.43);
	vec3 outer = vec3(1.0, 0.43, 0.12);
	vec3 col = r < 0.15 ? mix(inner, mid, r / 0.15) : mix(mid, outer, clamp((r - 0.15) / 0.6, 0.0, 1.0));
	float ang = UV.y * 6.28318;
	vec2 cp = vec2(cos(ang), sin(ang)) * (2.5 + r * 7.0);
	float streak = 0.6 * vn(cp * 2.2 + vec2(TIME * 0.25, -TIME * 0.2)) + 0.4 * vn(cp * 5.0 - vec2(TIME * 0.3));
	float fade = (1.0 - smoothstep(0.55, 1.0, r)) * smoothstep(0.0, 0.04, r);
	float a = fade * (0.55 + 0.7 * streak);
	ALBEDO = col * a;
	ALPHA = 1.0;
}
