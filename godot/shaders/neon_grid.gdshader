shader_type canvas_item;

uniform vec2 scroll = vec2(0.0);
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform vec4 bg_color : source_color = vec4(0.0509804, 0.0588235, 0.0784314, 1.0);
uniform vec4 line_color : source_color = vec4(0.24, 0.42, 0.38, 1.0);
uniform vec2 resolution = vec2(1280.0, 720.0);
uniform float minor_cell = 64.0;
uniform float major_cell = 256.0;
uniform float minor_parallax = 0.25;
uniform float major_parallax = 0.5;
uniform float minor_alpha : hint_range(0.0, 1.0) = 0.025;
uniform float major_alpha : hint_range(0.0, 1.0) = 0.075;
uniform float line_width = 1.2;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.85;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.045;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float grid(vec2 p, float cell, float width) {
	vec2 g = p / cell;
	vec2 d = abs(fract(g - 0.5) - 0.5) * cell;
	vec2 aa = max(fwidth(p), vec2(0.0001));
	vec2 m = 1.0 - smoothstep(vec2(width * 0.5), vec2(width * 0.5) + aa, d);
	return max(m.x, m.y);
}

void fragment() {
	vec2 px = UV * resolution;
	vec3 accent = line_color.rgb;
	vec3 hsv = rgb2hsv(accent);
	hsv.x = fract(hsv.x + hue_shift);
	accent = hsv2rgb(hsv);

	vec2 p_minor = px + scroll * minor_parallax;
	vec2 p_major = px + scroll * major_parallax;
	float minor = grid(p_minor, minor_cell, line_width);
	float major = grid(p_major, major_cell, line_width * 1.6);

	vec2 dm = abs(fract(p_major / major_cell - 0.5) - 0.5) * major_cell;
	float node = 1.0 - smoothstep(1.5, 4.0, length(dm));
	float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + dot(floor(p_major / major_cell), vec2(1.3, 2.1)));

	vec3 col = bg_color.rgb;

	col += accent * glow_strength * pow(clamp(UV.y, 0.0, 1.0), 3.0) * 0.6;
	col = mix(col, accent, minor * minor_alpha);
	col = mix(col, accent, major * major_alpha * pulse);
	col = mix(col, accent, node * 0.13 * pulse);

	vec2 v = UV - 0.5;
	float vig = 1.0 - dot(v, v) * vignette_strength * 1.6;
	col *= clamp(vig, 0.0, 1.0);
	COLOR = vec4(col, 1.0);
}
