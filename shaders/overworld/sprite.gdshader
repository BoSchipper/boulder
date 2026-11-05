shader_type spatial;
render_mode cull_disabled, specular_disabled;
// People, plants and props drawn as pixel sprites in the 3D world. Lit in four hard steps
// like the ground, but with wrapped light and a normal bent towards you and up, so a sprite
// never goes black with the sun behind it: in the evening you still see who stands there.
// A billboard turns to whoever looks at it, so in the sun's shadow pass it turns to the sun
// and casts its whole silhouette. Wrapped light and bent normal after Lumina's Sprite3D
// (src/engine/sprite/Sprite3D.js), MIT, Copyright (c) 2026 Luminati; see THIRD_PARTY_NOTICES.md.

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);  // a frame of a sheet; a negative x mirrors it
uniform vec2 uv_offset = vec2(0.0);
uniform bool billboard = true;
uniform float wrap = 0.6;
uniform float normal_up = 0.45;
uniform float alpha_cut = 0.5;
uniform float sway = 0.0;  // plants: how far the top moves in the wind, metres
uniform vec3 cam_back = vec3(0.0, 0.0, 1.0);  // towards the game camera, level: the plane a billboard shows
uniform float self_shadow_gap = 0.08;  // metres behind that plane the shadow copy goes

void vertex() {
	if (sway > 0.0) {
		// the top of the sprite moves, the root stays; every plant has its own phase
		vec3 at = MODEL_MATRIX[3].xyz;
		float t = TIME * 1.6 + at.x * 0.7 + at.z * 0.45;
		float gust = 0.55 + 0.45 * sin(TIME * 0.31 + at.x * 0.04 + at.z * 0.03);
		VERTEX.x += sin(t) * sway * gust * (1.0 - UV.y);
	}
	if (billboard) {
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 back = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
		vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		if (PROJECTION_MATRIX[3][3] > 0.5) {
			// The sun's shadow pass (an orthographic view). Turned to the sun, the copy that
			// casts the shadow cuts through the one you see, which faces the camera: half the
			// figure would stand in its own shadow, split by a straight line, with only the
			// top of the head lit. Slide every corner along the sunlight to just behind the
			// plane you see. Along the light a shadow does not move, so the one on the ground
			// stays the same, and the feet, in the middle, barely move at all.
			vec3 sun = INV_VIEW_MATRIX[2].xyz;
			vec3 off = right * VERTEX.x * scale.x + vec3(0.0, VERTEX.y * scale.y, 0.0) + back * VERTEX.z * scale.z;
			float facing = dot(sun, cam_back);
			facing = facing >= 0.0 ? max(facing, 0.15) : min(facing, -0.15);
			vec3 d = -sun * (clamp(dot(off, cam_back) / facing, -4.0, 4.0) + self_shadow_gap);
			VERTEX += vec3(dot(d, right) / scale.x, d.y / scale.y, dot(d, back) / scale.z);
		}
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(scale.x, 0.0, 0.0, 0.0),
			vec4(0.0, scale.y, 0.0, 0.0),
			vec4(0.0, 0.0, scale.z, 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	UV = UV * uv_scale + uv_offset;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	ALBEDO = a.rgb;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 nm = texture(normal_tex, UV).rgb;
	if (uv_scale.x < 0.0) {
		nm.x = 1.0 - nm.x;  // a mirrored frame: what faced left now faces right
	}
	NORMAL_MAP = nm;
	ROUGHNESS = 1.0;
}

void light() {
	vec3 up_v = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	vec3 n = normalize(mix(NORMAL, normalize(up_v + vec3(0.0, 0.0, 1.0)), normal_up));
	float w = clamp((dot(n, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float key = LIGHT_IS_DIRECTIONAL ? round(w * ATTENUATION * 4.0) / 4.0 : round(w * 4.0) / 4.0 * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * key / PI;
}
