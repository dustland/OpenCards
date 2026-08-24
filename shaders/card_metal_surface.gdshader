shader_type canvas_item;
render_mode unshaded, blend_mix;

// Brushed matte metal — horizontal grain like anodized aluminum or black titanium.
uniform float grain = 0.045;
uniform float brush = 0.035;

void fragment() {
	vec2 uv = UV;
	float n = fract(sin(dot(floor(uv * vec2(420.0, 12.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float streak = sin(uv.y * 520.0 + n * 3.0) * 0.5 + 0.5;
	float v = (n - 0.5) * grain + (streak - 0.5) * brush;
	COLOR.rgb *= (1.0 + v);
}
