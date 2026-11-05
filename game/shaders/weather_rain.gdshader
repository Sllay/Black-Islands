shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float strength = 0.0;
uniform vec2 wind = vec2(0.0);
void vertex() {
	float fall = fract(TIME * 1.6 + INSTANCE_CUSTOM.r);
	VERTEX.y -= fall * 9.0;
	VERTEX.xz += wind * fall * 1.5;
}
void fragment() {
	ALBEDO = vec3(0.65, 0.78, 0.86);
	ALPHA = strength * 0.42;
}
