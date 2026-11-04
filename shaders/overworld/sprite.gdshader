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

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
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
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = 1.0;
}

void light() {
	vec3 up_v = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	vec3 n = normalize(mix(NORMAL, normalize(up_v + vec3(0.0, 0.0, 1.0)), normal_up));
	float w = clamp((dot(n, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float key = LIGHT_IS_DIRECTIONAL ? round(w * ATTENUATION * 4.0) / 4.0 : round(w * 4.0) / 4.0 * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * key / PI;
}
