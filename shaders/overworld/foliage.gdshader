shader_type spatial;
render_mode specular_disabled, cull_disabled;
// Trees: smooth shapes with a pixel texture, lit in four hard steps like the ground. Leaves
// bulge into clumps and let a little sun through; bark is just textured.

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float tile = 0.0;
uniform float tiles = 7.0;
uniform float texel = 0.055;  // the same pixel size as the ground and the people
uniform float wind = 0.0;  // how far the leaves sway, metres at the top; the bark stays still
uniform float tile_px = 32.0;
uniform float translucency = 0.0;
uniform vec3 player_pos = vec3(0.0, -100.0, 0.0);  // trees between the camera and you fade out
uniform float fade_radius = 0.28;
instance uniform float bump = 0.0;  // in the clump's own scale, so the bumps stay the same size

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	if (bump > 0.0) {
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float n = texture(noise, w.xz * 0.45 + w.y * 0.31).r + texture(noise, w.zy * 0.6 + 0.3).r - 1.0;
		VERTEX += NORMAL * n * bump;
	}
	if (wind > 0.0) {
		// the higher, the more it moves: slow waves through the wood and now and then a gust
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = clamp((w.y - 0.8) / 6.0, 0.0, 1.0);
		float t = TIME * 1.1 + w.x * 0.3 + w.z * 0.22;
		float gust = 0.55 + 0.45 * sin(TIME * 0.31 + w.x * 0.04 + w.z * 0.03);
		vec3 sway = vec3(sin(t), 0.0, 0.6 * cos(t * 0.83)) * wind * h * gust;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * sway;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 a = abs(wnrm);
	vec2 p = a.y > max(a.x, a.z) ? wpos.xz : (a.x > a.z ? wpos.zy : wpos.xy);
	vec2 t = fract((floor(p / texel) + 0.5) / tile_px);
	ALBEDO = texture(atlas, vec2((tile + t.x) / tiles, t.y)).rgb;
	ROUGHNESS = 1.0;
	// Between the camera and you, near you on screen: dithered away, so you never get lost
	// behind a tree. Not in the shadow pass (an orthographic sun), so shadows stay whole.
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		vec4 pc = PROJECTION_MATRIX * VIEW_MATRIX * vec4(player_pos, 1.0);
		vec4 fc = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wpos, 1.0);
		vec2 dv = (fc.xy / fc.w - pc.xy / pc.w) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float closer = step(length(wpos - CAMERA_POSITION_WORLD), length(player_pos - CAMERA_POSITION_WORLD) - 1.0);
		float fade = smoothstep(fade_radius, fade_radius * 0.45, length(dv)) * closer * 0.9;
		int bx = int(FRAGCOORD.x) % 4;
		int by = int(FRAGCOORD.y) % 4;
		float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (fade > (bayer[by * 4 + bx] + 0.5) / 16.0) {
			discard;
		}
	}
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float key = LIGHT_IS_DIRECTIONAL ? clamp(round(nl * ATTENUATION * 1.1 * 4.0) / 4.0, 0.0, 1.0)
		: clamp(round(nl * 1.1 * 4.0) / 4.0, 0.0, 1.0) * ATTENUATION;  // lamps fade out softly
	DIFFUSE_LIGHT += LIGHT_COLOR * (key + translucency * ATTENUATION) / PI;
}
