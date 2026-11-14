shader_type canvas_item;

uniform float expire_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.2, 0.4, 1.0);
uniform float noise_scale = 0.09;
uniform float edge_width : hint_range(0.0, 0.5) = 0.12;
uniform float pulse_speed = 18.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * value_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v / 0.875;
}

void fragment() {
	vec4 base = COLOR;
	float n = fbm(local_pos * noise_scale);

	float threshold = expire_ratio * (1.0 + edge_width);
	if (n < threshold - edge_width) {
		discard;
	}
	float active = step(0.001, expire_ratio);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed * (0.6 + expire_ratio));

	vec3 col = mix(base.rgb, edge_color.rgb, active * pulse * 0.35 * expire_ratio);

	float edge = active * (1.0 - smoothstep(threshold - edge_width, threshold, n));
	col = mix(col, edge_color.rgb * (1.2 + 0.6 * pulse), edge);
	COLOR = vec4(col, base.a * mix(1.0, edge_color.a, edge));
}
