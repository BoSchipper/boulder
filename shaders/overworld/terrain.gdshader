shader_type spatial;
render_mode specular_disabled;
// The ground and the blocks of the walking world. The pixel art is in the texture, not in
// the shape: every texel takes its tone from a small tile, and the sun falls on it in four
// hard steps. Sand, moss and the rest come from a ground map. The blocks are Fontainebleau
// sandstone, worked out per pixel in 3D (font_rock), so they have no seams and no repeats.

uniform sampler2D ground_map : filter_nearest;     // red = which ground, per height cell
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;  // one tile per ground
uniform sampler2D clumps : filter_linear, repeat_enable;  // where moss grows on the blocks
uniform vec2 world_size = vec2(31.2, 27.3);
uniform float texel = 0.065;
uniform float tile_px = 32.0;
uniform float tiles = 8.0;
uniform float variants = 2.0;  // the atlas has every ground twice, one under the other

uniform float bump = 0.7;
uniform float block_base[8];  // the height of the foot of each block, to darken the damp base
uniform bool has_blocks = false;  // the ground map says which block is where (green channel)

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// ---- Fontainebleau sandstone, worked out per pixel in 3D: the colour belongs to the rock,
// not to a picture laid on it. Pale beige stone, grey-brown patina in the hollows and
// towards the top, round pockets, pale lichen, moss on top, rounded bulges and scoops.
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float forms(vec3 q) {  // the rounded relief: big bulges, smaller scoops
	return vnoise(q * 0.9) * 0.65 + vnoise(q * 2.3 + 11.0) * 0.35;
}
float crust(vec3 q) {  // where the grey-brown patina covers the stone
	return vnoise(q * 0.3 + 3.0) * 0.65 + vnoise(q * 0.9 + 7.0) * 0.35;
}
// Round spots scattered through the rock: distance to the nearest centre over its radius
// (below 1 inside). Pockets, lichen and moss are spots, so they get crisp round edges.
float spot(vec3 q, float cell, float rmin, float rmax, float density, float seed) {
	vec3 b = floor(q / cell - 0.5);
	float best = 9.0;
	for (int i = 0; i < 8; i++) {
		vec3 c = b + vec3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1));
		if (hash3(c + seed + 5.5) > density) {
			continue;
		}
		vec3 centre = (c + vec3(hash3(c + seed), hash3(c + seed + 7.1), hash3(c + seed + 3.7))) * cell;
		float r = mix(rmin, rmax, hash3(c + seed + 1.3));
		best = min(best, length(q - centre) / r);
	}
	return best;
}
vec3 font_rock(vec3 wp, vec3 wn, float base_y, out vec3 n) {
	vec3 q = floor(wp / texel) * texel + texel * 0.5;
	// relief: the normal leans with the slope of the forms, per pixel
	float h = forms(q);
	vec3 g = vec3(forms(q + vec3(texel * 2.0, 0, 0)) - h, forms(q + vec3(0, texel * 2.0, 0)) - h, forms(q + vec3(0, 0, texel * 2.0)) - h);
	g -= wn * dot(g, wn);
	n = normalize(wn - g * bump / (texel * 2.0));
	float up = clamp(wn.y, 0.0, 1.0);
	float shade = clamp(-dot(wn.xz, vec2(-0.4, 0.4)), 0.0, 1.0);        // faces away from the sun
	vec3 ramp[5] = vec3[](vec3(0.15, 0.13, 0.14), vec3(0.33, 0.29, 0.27), vec3(0.53, 0.48, 0.41), vec3(0.74, 0.67, 0.55), vec3(0.88, 0.82, 0.69));
	// stone: beige, cream on the bulges. Patina follows the rock: it gathers in the hollows and
	// towards the top, the bulges stay worn clean. No edge line: where it thins out the two
	// tones mingle pixel by pixel (ordered dither), as the crust does on the real stone.
	float cover = crust(q) * 0.55 + (1.0 - h) * 0.45 + up * 0.18;
	ivec3 ip = ivec3(floor(wp / texel));
	float bayer[4] = float[](0.125, 0.625, 0.875, 0.375);
	float dither = bayer[((ip.x + ip.z) & 1) + 2 * (ip.y & 1)] - 0.5;
	float lv = cover + dither * 0.045;  // only a narrow band mingles
	int tone = h > 0.62 ? 4 : 3;
	if (lv > 0.74) {
		tone = 1;
	} else if (lv > 0.62) {
		tone = 2;
	}
	if (wp.y < base_y + 0.45) {
		tone = max(tone - 1, 1);  // damp and dirty at the foot
	}
	float speck = hash3(floor(wp / texel) + 17.0);
	if (speck > 0.965) {
		tone = clamp(tone + 1, 0, 4);  // a grain catching the light, here and there
	} else if (speck < 0.03) {
		tone = clamp(tone - 1, 0, 4);
	}
	vec3 c = ramp[tone];
	// pockets: dark round holes with a rim
	float pk = spot(q, 0.55, 0.05, 0.13, 0.55, 41.0);
	if (pk < 1.0) {
		c = pk < 0.65 ? ramp[0] : ramp[1];
	}
	// lichen: pale grey-green rosettes with a darker edge, more towards the top and in the shade
	float lc = spot(q, 0.4, 0.05, 0.14, 0.18 + up * 0.5 + shade * 0.25, 21.0);
	if (lc < 1.0) {
		c = lc < 0.72 ? vec3(0.74, 0.79, 0.63) : vec3(0.47, 0.54, 0.4);
	}
	// moss on what faces the sky: green cushions with a dark rim
	if (up > 0.6) {
		float ms = spot(q, 0.32, 0.07, 0.17, (up - 0.6) * 2.2, 31.0);
		if (ms < 1.0) {
			c = ms < 0.55 ? vec3(0.46, 0.58, 0.29) : (ms < 0.8 ? vec3(0.33, 0.45, 0.22) : vec3(0.18, 0.26, 0.14));
		}
	}
	return pow(c, vec3(2.2));  // the colours above are written as you see them (sRGB); light works in linear
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
	int blk = has_blocks ? int(floor(gm.g * 255.0 + 0.5)) - 1 : -1;  // which block, if known
	bool outside = any(lessThan(wpos.xz, vec2(0.0))) || any(greaterThan(wpos.xz, world_size));
	if (outside) {
		id = texture(clumps, wpos.xz * 0.05).r > 0.5 ? 3.0 : 2.0;  // moss and needles go on under the trees
	}
	vec3 c;
	if (wnrm.y < 0.62) {
		// a steep face: sandstone, in the plane it faces
		vec2 p = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
		if (id != 5.0) {
			c = tile(0.0, p);  // the edge of a bank of earth
		} else {
			vec3 n;
			c = font_rock(wpos, wnrm, blk >= 0 ? block_base[blk] : -100.0, n);
			NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		}
	} else if (id == 5.0) {
		vec3 n;
		c = font_rock(wpos, wnrm, blk >= 0 ? block_base[blk] : -100.0, n);
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
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
