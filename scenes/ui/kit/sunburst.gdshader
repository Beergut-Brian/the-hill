// Showtime stage: a slowly turning sunburst in the skin's colours, a soft light in the middle and
// halftone dots creeping in from the bottom right. `alpha` < 1 lets the game's world show through.
shader_type canvas_item;

uniform vec4 a : source_color = vec4(0.54, 0.36, 0.96, 1.0);
uniform vec4 b : source_color = vec4(0.42, 0.28, 0.75, 1.0);
uniform vec4 deep : source_color = vec4(0.16, 0.1, 0.36, 1.0);
uniform vec2 centre = vec2(0.3, 0.62);
uniform float speed = 0.035;
uniform float rays = 12.0;
uniform float alpha = 1.0;
uniform float aspect = 1.7778;

void fragment() {
	vec2 p = (UV - centre) * vec2(aspect, 1.0);
	float ang = atan(p.y, p.x) + TIME * speed * 6.2832;
	float r = smoothstep(0.47, 0.53, abs(fract(ang / 6.2832 * rays) - 0.5) * 2.0);
	vec3 col = mix(a.rgb, b.rgb, r);
	float glow = smoothstep(0.8, 0.0, length(p));
	col = mix(col, vec3(1.0), 0.36 * glow);
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * (UV * vec2(aspect, 1.0) * 34.0);
	float d = length(fract(q) - 0.5);
	float sz = 0.5 * smoothstep(0.75, 1.9, UV.x * 1.1 + UV.y);
	col = mix(col, deep.rgb, step(d, sz) * 0.55);
	COLOR = vec4(col, alpha * mix(0.82, 1.0, glow));
}
