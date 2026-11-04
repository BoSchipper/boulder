shader_type canvas_item;
// The colour grade over the whole picture: contrast, saturation, shadows a touch teal and
// highlights a touch warm, a soft vignette and a fine grain. Ported from Lumina's
// GradeShader (src/engine/render/shaders/GradeShader.js), MIT, Copyright (c) 2026 Luminati,
// https://gitlab.com/stubborn-hug/lumina (see THIRD_PARTY_NOTICES.md); simplified: no
// chromatic aberration or sharpening, which would smear the pixel art.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float contrast = 1.08;
uniform float saturation = 1.1;
uniform vec3 shadows_tint = vec3(0.02, 0.04, 0.08);
uniform vec3 highlights_tint = vec3(0.06, 0.03, -0.02);
uniform float split = 0.8;
uniform float vignette = 0.45;
uniform float vignette_softness = 0.55;
uniform float vignette_roundness = 0.65;
uniform vec3 vignette_color = vec3(0.05, 0.025, 0.04);
uniform float grain = 0.02;
uniform float aspect = 1.7778;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	c = (c - 0.5) * contrast + 0.5;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(lum), c, saturation);
	c += (1.0 - lum) * (1.0 - lum) * shadows_tint * split + lum * lum * highlights_tint;
	vec2 d = SCREEN_UV - 0.5;
	float sx = mix(1.0, aspect, vignette_roundness);
	float r = length(d * vec2(sx, 1.0)) / length(vec2(0.5 * sx, 0.5));
	float v = 1.0 - vignette * pow(clamp((r - (1.0 - vignette_softness)) / vignette_softness, 0.0, 1.0), 1.6);
	c = mix(vignette_color, c, v);
	float n = hash12(floor(FRAGCOORD.xy) + fract(TIME) * 101.0) - 0.5;
	c += n * grain * (1.0 - lum * 0.5);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
