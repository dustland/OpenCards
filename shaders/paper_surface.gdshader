shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float grain = 0.08;

void fragment() {
	vec2 uv = UV;
	float n = fract(sin(dot(floor(uv * 280.0), vec2(12.9898, 78.233))) * 43758.5453);
	float fiber = sin(uv.y * 220.0 + n * 4.0) * 0.02;
	COLOR.rgb *= (1.0 + (n - 0.5) * grain + fiber);
}
