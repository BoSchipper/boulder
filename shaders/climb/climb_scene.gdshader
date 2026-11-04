shader_type canvas_item;
// The climbing screen behind the climber: the rock stays sharp pixel art, so you can read
// every hold; around it the forest of the walking world, out of focus (the picture is
// blurred once when the climb starts), a little hazier with distance, with a soft shaft of
// sunlight falling through it. Without a picture of the forest the painted one is kept.

uniform sampler2D rock : source_color, filter_nearest;
uniform sampler2D rock_mask : filter_nearest;
uniform sampler2D backdrop : source_color, filter_linear;
uniform bool has_backdrop = false;
uniform vec3 haze : source_color = vec3(0.85, 0.9, 0.88);
uniform float haze_amount = 0.16;
uniform vec3 shaft_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float shaft = 0.18;  // 0 at night
uniform float floor_y = 258.0;

void fragment() {
	vec2 px = UV * vec2(480.0, 270.0);
	vec4 r = texture(rock, UV);
	float m = texture(rock_mask, UV).r;
	if (!has_backdrop || m > 0.5 || px.y > floor_y - 4.0) {
		COLOR = r;
	} else {
		vec3 b = mix(texture(backdrop, UV).rgb, haze, haze_amount);
		float d = (px.x - 120.0 + px.y * 0.75) / 36.0;
		b += shaft_color * exp(-d * d) * clamp(1.0 - px.y / 240.0, 0.0, 1.0) * shaft;
		COLOR = vec4(b, 1.0);
	}
}
