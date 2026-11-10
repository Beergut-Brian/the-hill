// A 13-tap blur of the node's own texture (a SubViewport or a still image), tinted toward `tint`.
shader_type canvas_item;

uniform float radius = 2.5;
uniform vec4 tint : source_color = vec4(0.1, 0.07, 0.25, 0.25);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius;
	vec3 c = texture(TEXTURE, UV).rgb * 0.2;
	float w = 0.2;
	for (int i = 0; i < 12; i++) {
		float an = float(i) * 0.5236;
		float rr = (i % 2 == 0) ? 1.0 : 2.0;
		float k = (i % 2 == 0) ? 0.09 : 0.044;
		c += texture(TEXTURE, UV + vec2(cos(an), sin(an)) * px * rr).rgb * k;
		w += k;
	}
	COLOR = vec4(mix(c / w, tint.rgb, tint.a), 1.0);
}
