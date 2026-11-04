shader_type spatial;
render_mode specular_disabled;
// The ground and the blocks of the walking world. The pixel art is in the texture, not in
// the shape: every texel takes its tone from a small tile, and the sun falls on it in four
// hard steps. Sand, moss and the rest come from a ground map; steep faces show sandstone.

uniform sampler2D ground_map : filter_nearest;     // red = which ground, per height cell
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;  // one tile per ground
uniform sampler2D rock_side : source_color, filter_nearest, repeat_enable;
uniform sampler2D clumps : filter_linear, repeat_enable;  // where moss grows on the blocks
uniform vec2 world_size = vec2(31.2, 27.3);
uniform float texel = 0.065;
uniform float tile_px = 32.0;
uniform float tiles = 8.0;
uniform float variants = 2.0;  // the atlas has every ground twice, one under the other
uniform float rock_tint = 0.84;  // sandstone a touch darker than the sand around it

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tile(float id, vec2 p) {
	vec2 t = fract((floor(p / texel) + 0.5) / tile_px);
	// two versions of every ground, in irregular patches: the eye finds no repeating grid
	float v = texture(clumps, p * 0.09 + vec2(7.3, 2.1)).r > 0.5 ? 1.0 : 0.0;
	vec3 c = texture(atlas, vec2((id + t.x) / tiles, (t.y + v) / variants)).rgb;
	// big soft patches a little lighter or darker, in three steps: sun-bleached and trodden
	float big = texture(clumps, floor(p / texel) * texel * 0.03 + vec2(3.1, 9.7)).r;
	return c * (big > 0.62 ? 1.05 : (big < 0.4 ? 0.93 : 1.0));
}

void fragment() {
	vec4 gm = texture(ground_map, clamp(wpos.xz / world_size, 0.0, 1.0));
	float id = floor(gm.r * 255.0 + 0.5);
	bool outside = any(lessThan(wpos.xz, vec2(0.0))) || any(greaterThan(wpos.xz, world_size));
	if (outside) {
		id = texture(clumps, wpos.xz * 0.05).r > 0.5 ? 3.0 : 2.0;  // moss and needles go on under the trees
	}
	vec3 c;
	if (wnrm.y < 0.62) {
		// a steep face: sandstone, in the plane it faces
		vec2 p = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
		vec2 t = (floor(p / texel) + 0.5) / 64.0;
		c = texture(rock_side, t).rgb * rock_tint;
		if (id != 5.0) {
			c = tile(0.0, p);  // the edge of a bank of earth
		}
	} else if (id == 5.0) {
		c = tile(5.0, wpos.xz) * rock_tint;
		if (texture(clumps, wpos.xz * 0.12).r > 0.6) {
			c = tile(7.0, wpos.xz);  // moss on top of the block
		}
	} else {
		c = tile(id, wpos.xz);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

void light() {
	// The sun (with its shadow) in four hard steps; a fire or lamp in steps of angle only, its
	// fall-off smooth, so its light fades out instead of ending in a hard disc on the ground.
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float key = LIGHT_IS_DIRECTIONAL ? clamp(round(nl * ATTENUATION * 1.1 * 4.0) / 4.0, 0.0, 1.0)
		: clamp(round(nl * 1.1 * 4.0) / 4.0, 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * key / PI;
}
