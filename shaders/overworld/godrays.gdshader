shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;
// A shaft of sunlight falling through the trees: one quad turned around its own axis so its
// broad side faces you, soft across, fading in at the top and out near the ground, with
// slow streaks along it. Strongest in the morning and evening, gone at night. After
// Lumina's GodRays (src/engine/fx/GodRays.js), MIT, Copyright (c) 2026 Luminati; see
// THIRD_PARTY_NOTICES.md.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);  // towards the sun
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.7);
uniform float intensity = 0.2;
uniform sampler2D streaks : filter_linear, repeat_enable;
instance uniform vec2 size = vec2(2.0, 10.0);  // width, length in metres
instance uniform float phase = 0.0;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 s = normalize(vec3(sun_dir.x, max(sun_dir.y, 0.6), sun_dir.z));  // steeper, so it reads
	vec3 view = normalize(CAMERA_POSITION_WORLD - c);
	vec3 side = normalize(cross(s, view));
	VERTEX = c + s * (0.5 - UV.y) * size.y + side * (UV.x - 0.5) * size.x;
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float soft = exp(-across * across * 3.5);
	float along = smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.7, 1.0, UV.y));
	float streak = 0.55 + 0.45 * texture(streaks, vec2(UV.x * 1.3 + phase, UV.y * 0.15 - TIME * 0.015)).r;
	ALBEDO = color;
	ALPHA = clamp(intensity * soft * along * streak, 0.0, 1.0);
}
