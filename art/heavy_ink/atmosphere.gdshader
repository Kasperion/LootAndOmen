shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform vec2 board_size;
uniform vec2 fire_center;
uniform float light_radius;
uniform bool fire_lit = true;
uniform bool on_road = false;

float grain(vec2 tile) {
	return fract(sin(dot(tile, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud(vec2 point) {
	vec2 tile = floor(point);
	vec2 part = fract(point);
	vec2 ease = part * part * (3.0 - 2.0 * part);
	return mix(
		mix(grain(tile), grain(tile + vec2(1.0, 0.0)), ease.x),
		mix(grain(tile + vec2(0.0, 1.0)), grain(tile + vec2(1.0, 1.0)), ease.x),
		ease.y
	);
}

void fragment() {
	vec2 tile = UV * board_size;
	vec2 wind = vec2(TIME * 0.36, -TIME * 0.09);
	float broad = cloud(tile * vec2(0.43, 0.64) - wind);
	vec2 curl = vec2(broad, cloud(tile * 0.38 + wind * 0.5));
	float strand = cloud(tile * vec2(0.82, 1.50) + curl * 1.65 - wind * 1.70);
	float wisps = smoothstep(0.30, 0.79, broad * 0.64 + strand * 0.36);

	if (on_road) {
		float bank = smoothstep(0.34, 0.62, UV.y) * (1.0 - smoothstep(0.68, 0.84, UV.y));
		COLOR = vec4(0.38, 0.33, 0.38, bank * wisps * 0.20);
	} else {
		float distance_to_fire = distance(tile, fire_center);
		float edge = fire_lit ? smoothstep(light_radius - 0.45, light_radius + 0.78,
			distance_to_fire + (broad - 0.5) * 0.58) : 1.0;
		float ember = fire_lit ? mix(0.18, 0.04, clamp(distance_to_fire / light_radius, 0.0, 1.0)) : 0.0;
		vec3 shadow = mix(vec3(0.035, 0.042, 0.075), vec3(0.23, 0.25, 0.29), wisps * 0.74);
		float density = (fire_lit ? 0.58 : 0.66) + wisps * 0.16;
		COLOR = mix(vec4(1.0, 0.61, 0.28, ember), vec4(shadow, density), edge);
	}
}
