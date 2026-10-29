// Native Transvoxel vertex path: Zylann/godot_voxel v1.7x, MIT.
// See licenses/voxel_tools.txt. Palette presentation belongs to Black Island.
shader_type spatial;
uniform int u_transition_mask;
varying flat vec4 material_ids;
varying vec4 material_weights;

vec4 unpack_bytes(uint value) {
	return vec4(float(value & 255u), float((value >> 8u) & 255u),
		float((value >> 16u) & 255u), float((value >> 24u) & 255u));
}
float secondary_factor(int data) {
	int mask = u_transition_mask & 255;
	int cell_border = data & 63;
	int vertex_border = (data >> 8) & 63;
	return float((mask & cell_border) != 0) * float((vertex_border & ~mask) == 0);
}
vec3 transvoxel_position(vec3 primary, vec4 data) {
	int bits = floatBitsToInt(data.a);
	vec3 position = mix(primary, data.xyz, secondary_factor(bits));
	int transition = (bits >> 16) & 255;
	return position * float(transition == 0 || (transition & u_transition_mask) != 0);
}
vec3 palette(float id) {
	if (id < 0.5) { return vec3(0.77, 0.64, 0.38); }
	if (id < 1.5) { return vec3(0.27, 0.48, 0.21); }
	if (id < 2.5) { return vec3(0.37, 0.23, 0.13); }
	return vec3(0.39, 0.42, 0.43);
}
void vertex() {
	VERTEX = transvoxel_position(VERTEX, CUSTOM0);
	material_ids = unpack_bytes(floatBitsToUint(CUSTOM1.x));
	material_weights = unpack_bytes(floatBitsToUint(CUSTOM1.y)) / 255.0;
}
void fragment() {
	vec4 weights = material_weights / max(dot(material_weights, vec4(1.0)), 0.001);
	ALBEDO = palette(material_ids.x) * weights.x + palette(material_ids.y) * weights.y
		+ palette(material_ids.z) * weights.z + palette(material_ids.w) * weights.w;
	ROUGHNESS = 0.94;
}
