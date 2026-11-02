shader_type spatial;
// Procedural planet surfaces (no textures needed). kind: 0 rock, 1 earth, 2 mars, 3 gas bands, 4 pluto, 5 sun

uniform int kind = 0;
uniform float seed = 1.0;
uniform float scale = 1.0;
uniform vec3 col_a : source_color = vec3(0.5);
uniform vec3 col_b : source_color = vec3(0.4);
uniform vec3 col_c : source_color = vec3(0.7);
uniform float bands = 20.0;
uniform float spot = 0.0;

varying vec3 obj_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 p = normalize(obj_pos);
	vec3 q = p * scale + vec3(seed * 7.13);
	vec3 col = col_a;
	float rough = 0.92;
	float emit = 0.0;
	if (kind == 1) {
		float n = fbm(q * 2.2);
		float land = smoothstep(0.50, 0.54, n);
		vec3 ocean = mix(col_a * 0.7, col_a, fbm(q * 6.0));
		vec3 ground = mix(col_b, col_c, fbm(q * 5.0));
		col = mix(ocean, ground, land);
		float cl = smoothstep(0.55, 0.78, fbm(q * 3.0 + vec3(9.0)));
		col = mix(col, vec3(1.0), cl * 0.7);
		col = mix(col, vec3(0.95, 0.97, 1.0), smoothstep(0.84, 0.92, abs(p.y)));
		rough = mix(0.35, 0.9, land);
	} else if (kind == 2) {
		float n = fbm(q * 3.0);
		col = mix(col_a, col_b, smoothstep(0.35, 0.7, n));
		col = mix(col, col_c, smoothstep(0.55, 0.8, fbm(q * 7.0)) * 0.5);
		col = mix(col, vec3(0.95, 0.92, 0.9), smoothstep(0.9, 0.96, abs(p.y)));
	} else if (kind == 3) {
		float warp = fbm(q * vec3(1.5, 5.0, 1.5)) * 2.5;
		float b = 0.5 + 0.5 * sin(p.y * bands + warp * 3.0);
		col = mix(col_a, col_b, b);
		col = mix(col, col_c, smoothstep(0.55, 0.9, fbm(q * vec3(2.0, 9.0, 2.0))) * 0.6);
		if (spot > 0.0) {
			vec2 d = vec2(p.x - 0.75, (p.y + 0.30) * 2.2);
			float sp = smoothstep(0.22, 0.12, length(vec2(d.x * 0.6 + p.z * 0.0, d.y)) + 0.0 * p.z) * step(0.0, p.x);
			col = mix(col, vec3(0.71, 0.28, 0.18), sp);
		}
	} else if (kind == 4) {
		float n = fbm(q * 4.0);
		col = mix(col_a, col_b, smoothstep(0.4, 0.7, n));
		col = mix(col, col_c, smoothstep(0.62, 0.75, fbm(q * 2.0 + vec3(3.0))) * 0.8);
	} else if (kind == 5) {
		float n = fbm(q * 5.0 + vec3(TIME * 0.05));
		col = mix(col_a, col_b, n);
		emit = 1.0;
	} else {
		float n = fbm(q * 6.0);
		col = mix(col_a, col_b, smoothstep(0.35, 0.65, n));
		col = mix(col, col_c, smoothstep(0.7, 0.85, fbm(q * 13.0)) * 0.5);
		rough = 1.0;
	}
	ALBEDO = col * (1.0 - emit);
	EMISSION = col * emit * 1.35;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}
