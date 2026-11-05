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
uniform float extra = 0.0;  // rows above the screen, for when the view moves up as you top out
uniform float cam = 0.0;  // how far the view has moved up now
// The forest is far behind the block: it moves up less than the rock (parallax), and it is
// drawn a little larger, so its picture still fills the screen at the highest view instead
// of running out at the top.
const float DEPTH = 0.35;

void fragment() {
	vec2 px = vec2(UV.x * 480.0, UV.y * (270.0 + extra) - extra);
	vec2 uv = vec2(px.x / 480.0, max(px.y, 0.0) / 270.0);
	vec4 r = texture(rock, uv);
	float m = px.y < 0.0 ? 0.0 : texture(rock_mask, uv).r;
	if (!has_backdrop || m > 0.5 || px.y > floor_y - 4.0) {
		COLOR = r;
	} else {
		// where this pixel is in the forest's own picture: moved up less, and scaled up
		// around its bottom so the top of the highest view is its top row
		float zoom = 270.0 / (270.0 + DEPTH * extra);
		vec2 f = vec2(px.x, px.y + (1.0 - DEPTH) * cam);
		f = vec2(240.0, 270.0) + (f - vec2(240.0, 270.0)) * zoom;
		vec3 b = mix(texture(backdrop, f / vec2(480.0, 270.0)).rgb, haze, haze_amount);
		float d = (f.x - 120.0 + f.y * 0.75) / 36.0;
		b += shaft_color * exp(-d * d) * clamp(1.0 - f.y / 240.0, 0.0, 1.0) * shaft;
		COLOR = vec4(b, 1.0);
	}
}
