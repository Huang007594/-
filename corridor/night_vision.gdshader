shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.06;
uniform float brightness : hint_range(1.0, 5.0) = 2.5;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);

	// Luminance
	float lum = dot(screen.rgb, vec3(0.299, 0.587, 0.114));

	// Boost brightness
	lum = lum * brightness;

	// Green tint — classic NVG color
	vec3 green = vec3(0.1, lum * 1.0, 0.05) + vec3(0.0, lum * 0.6, 0.0);

	// Film grain noise
	float noise = random(SCREEN_UV + fract(TIME)) * noise_amount;
	green += vec3(noise * 0.3, noise, noise * 0.3);

	// Vignette — darken edges
	vec2 center = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(center, center) * 1.5;
	vignette = clamp(vignette, 0.0, 1.0);
	green *= vignette;

	// Scanlines
	float scanline = sin(SCREEN_UV.y * 400.0) * 0.04 + 0.96;
	green *= scanline;

	// Mix original and night vision
	COLOR = vec4(mix(screen.rgb, green, intensity), 1.0);
}
