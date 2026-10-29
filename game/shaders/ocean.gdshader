shader_type spatial;
uniform vec3 deep_color : source_color = vec3(0.06, 0.34, 0.48);
uniform vec3 light_color : source_color = vec3(0.13, 0.56, 0.63);
varying vec2 ocean_position;
void vertex() { ocean_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	float wave = sin(ocean_position.x * 0.22 + TIME * 1.2)
		* sin(ocean_position.y * 0.27 - TIME * 0.8) * 0.5 + 0.5;
	ALBEDO = mix(deep_color, light_color, wave * 0.4);
	ROUGHNESS = 0.42;
	SPECULAR = 0.45;
}
