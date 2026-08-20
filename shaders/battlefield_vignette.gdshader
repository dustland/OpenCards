shader_type canvas_item;
render_mode unshaded, blend_mix;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv * vec2(1.04, 1.18));
	float a = smoothstep(0.48, 1.24, d) * 0.46;
	COLOR = vec4(0.04, 0.03, 0.02, a);
}
