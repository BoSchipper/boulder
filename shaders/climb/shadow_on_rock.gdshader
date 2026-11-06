shader_type canvas_item;
render_mode unshaded;
// The climber's shadow (a CanvasGroup) only where it can fall: on the rock and on the sand
// at its foot, not on the forest behind. Standing on top of a block, your shadow ends at its
// top edge instead of hanging in the air beside you.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D rock_mask : filter_nearest;
uniform vec2 offset = vec2(0.0);  // where the climbing screen is drawn: it moves up as you climb out
uniform float floor_y = 258.0;
uniform float up = 0.0;  // a highball's mask has this many rows above the screen

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec2 px = SCREEN_UV * vec2(480.0, 270.0) - offset;
	bool rock = px.y + up >= 0.0 && texture(rock_mask, vec2(px.x / 480.0, (px.y + up) / (270.0 + up))).r > 0.5;
	COLOR *= c;
	COLOR.a *= (rock || px.y > floor_y - 4.0) ? 1.0 : 0.0;
}
