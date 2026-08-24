shader_type canvas_item;
render_mode blend_mix;

uniform vec4 tint_color : source_color = vec4(0.82, 0.68, 0.36, 1.0);
uniform float intensity : hint_range(0.0, 1.5) = 0.72;
uniform float shimmer_speed = 0.35;

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	if (mask.a < 0.04) {
		discard;
	}
	float wave = sin((UV.x * 9.0 + UV.y * 7.0) + TIME * shimmer_speed) * 0.5 + 0.5;
	float band = sin(UV.y * 16.0 - UV.x * 4.0 - TIME * 0.22) * 0.5 + 0.5;
	float sparkle = sin((UV.x - UV.y) * 22.0 + TIME * 0.5) * 0.5 + 0.5;
	float mixv = wave * 0.42 + band * 0.38 + sparkle * 0.20;
	vec3 dark = tint_color.rgb * 0.62;
	vec3 bright = tint_color.rgb * 1.45 + vec3(0.08, 0.06, 0.02);
	vec3 foil = mix(dark, bright, mixv);
	COLOR = vec4(foil, mask.a * intensity);
}
