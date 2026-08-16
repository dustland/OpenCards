shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float grain = 0.07;
uniform float weave = 0.035;

void fragment() {
	vec2 uv = UV;
	float n = fract(sin(dot(uv * vec2(193.7, 151.3), vec2(12.9898, 78.233))) * 43758.5453);
	float n2 = fract(sin(dot(uv * vec2(47.1, 89.6), vec2(39.346, 11.135))) * 23421.631);
	float cloth = sin(uv.x * 78.0) * sin(uv.y * 72.0);
	float v = (n - 0.5) * grain + (n2 - 0.5) * 0.025 + cloth * weave;
	COLOR.rgb *= (1.0 + v);
}
