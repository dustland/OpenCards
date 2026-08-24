shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float grain = 0.06;
uniform float weave = 0.025;

void fragment() {
	vec2 uv = UV;
	float n = fract(sin(dot(floor(uv * 320.0), vec2(12.9898, 78.233))) * 43758.5453);
	float n2 = fract(sin(dot(floor(uv * 140.0), vec2(39.346, 11.135))) * 23421.631);
	float fiber = sin(uv.y * 180.0 + n * 5.0) * 0.018;
	float cross = sin(uv.x * 95.0) * sin(uv.y * 88.0) * weave;
	COLOR.rgb *= (1.0 + (n - 0.5) * grain + (n2 - 0.5) * 0.02 + fiber + cross);
}
