shader_type canvas_item;
render_mode blend_add;

// Specular catch on raised/engraved edges — AmEx-style metal glint, not holo rainbow.
uniform vec4 tint_color : source_color = vec4(0.78, 0.80, 0.84, 1.0);
uniform float intensity : hint_range(0.0, 1.2) = 0.38;
uniform float sweep_speed = 0.18;

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	if (mask.a < 0.04) {
		discard;
	}
	// Single soft light sweep across the card (like tilting a metal card).
	float sweep = sin((UV.x * 1.6 + UV.y * 0.35) - TIME * sweep_speed) * 0.5 + 0.5;
	sweep = smoothstep(0.35, 0.92, sweep);
	float rim = mask.a * (0.55 + sweep * 0.45);
	vec3 spec = tint_color.rgb * (0.65 + sweep * 0.55);
	COLOR = vec4(spec, rim * intensity);
}
