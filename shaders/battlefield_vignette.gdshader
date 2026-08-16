shader_type canvas_item;
render_mode unshaded, blend_mix;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv * vec2(1.04, 1.18));
	float a = smoothstep(0.42, 1.22, d) * 0.58;
	COLOR = vec4(0.03, 0.035, 0.028, a);
}
