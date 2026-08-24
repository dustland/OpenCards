shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float strength : hint_range(0.0, 1.0) = 0.40;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv * vec2(0.90, 1.06));
	float edge = smoothstep(0.32, 1.08, d) * strength;
	float top_fade = smoothstep(0.06, 0.42, UV.y) * 0.06;
	COLOR = vec4(0.025, 0.018, 0.012, edge + top_fade);
}
