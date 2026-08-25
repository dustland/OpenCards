shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float grain = 0.12;
uniform float brush = 0.14;
uniform float sheen = 0.18;

void fragment() {
	vec2 uv = UV;
	float n = fract(sin(dot(floor(uv * vec2(96.0, 48.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float n2 = fract(sin(dot(uv * vec2(27.0, 9.0), vec2(39.346, 11.135))) * 23421.631);
	float streak = sin(uv.y * 36.0 + n2 * 3.0);
	float spec = pow(clamp(1.0 - abs(uv.x * 1.15 - 0.38 + (n - 0.5) * 0.08), 0.0, 1.0), 3.4);
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = smoothstep(0.10, 0.0, edge);
	float v = (n - 0.5) * grain + streak * brush * 0.45 + spec * sheen + rim * 0.10;
	COLOR.rgb *= (1.0 + v);
	COLOR.rgb += vec3(0.07, 0.055, 0.035) * (spec * sheen + rim * 0.35);
}
