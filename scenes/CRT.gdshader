shader_type canvas_item;

// Allows reading the screen behind this ColorRect
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Settings you can tweak in the Inspector
uniform float scanline_count : hint_range(0, 1800) = 50.0;
uniform float scanline_opacity : hint_range(0, 1) = 0.4;
uniform float warp_amount : hint_range(0, 5) = 0.1; // Curvature
uniform float vignette_amount : hint_range(0, 2) = 0.5;
uniform float chromatic_aberration : hint_range(0, 5) = 1.0;

// Curvature function
vec2 warp(vec2 uv) {
	vec2 dc = abs(0.5 - uv);
	dc *= dc;
	return uv + uv * dc * (warp_amount * 0.5); // 0.5 is warp intensity factor
}

void fragment() {
	// 1. Apply curvature to UVs
	vec2 uv = warp(SCREEN_UV);

	// 2. Black out pixels outside the warped screen area
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// 3. Chromatic Aberration (Splitting RGB slightly)
		float r = texture(SCREEN_TEXTURE, uv + vec2(chromatic_aberration * 0.001, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv - vec2(chromatic_aberration * 0.001, 0.0)).b;

		vec3 color = vec3(r, g, b);

		// 4. Scanlines (Sine wave pattern)
		float scanline = sin(uv.y * scanline_count * 3.14159 * 2.0);
		scanline = (scanline + 1.0) / 2.0; // Normalize 0 to 1
		// Apply opacity
		color -= scanline * scanline_opacity;

		// 5. Vignette (Dark corners)
		float dist = distance(uv, vec2(0.5));
		color *= 1.0 - (dist * vignette_amount);

		COLOR = vec4(color, 1.0);
	}
}