shader_type spatial;
render_mode unshaded, world_vertex_coords;
uniform sampler2D suppression : filter_nearest, repeat_disable;
uniform vec2 mask_origin;
uniform vec3 viewer;
uniform vec3 tint : source_color;
uniform float far_distance = 60.0;
varying float coverage;
void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float blocked = texture(suppression,(root.xz-mask_origin)/256.0).r;
	coverage = (1.0-blocked)*(1.0-smoothstep(far_distance-12.0,far_distance,distance(root.xz,viewer.xz)));
	VERTEX = mix(root,VERTEX,coverage);
}
void fragment() {
	if (coverage < fract(dot(floor(FRAGCOORD.xy),vec2(0.75487766,0.56984029)))) { discard; }
	ALBEDO = tint;
}
