shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, world_vertex_coords;
uniform sampler2D blades : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D suppression : filter_nearest, repeat_disable;
uniform vec2 mask_origin = vec2(-128.0);
uniform float mask_size = 256.0;
uniform vec3 viewer;
uniform vec4 actors[5];
uniform float near_distance = 22.0;
uniform float far_distance = 36.0;
uniform float interaction_radius = 2.0;
uniform float wind_amplitude = 0.12;
uniform vec2 u_lod_fade = vec2(1.0); // Replaced by instance uniform on RD renderers.
varying float coverage;
varying float shade;
void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	vec2 mask_uv = (root.xz-mask_origin)/mask_size;
	float suppressed = texture(suppression,mask_uv).r;
	float distance_fade = 1.0-smoothstep(near_distance,far_distance,distance(root.xz,viewer.xz));
	float native_fade = mix(1.0-u_lod_fade.x,u_lod_fade.x,u_lod_fade.y);
	coverage = (1.0-suppressed)*distance_fade*native_fade;
	float tip = clamp((VERTEX.y-root.y)/0.65,0.0,1.0);
	vec3 world_vertex = VERTEX;
	float phase = dot(root.xz,vec2(0.31,0.19));
	float wind = sin(TIME*1.6+phase)+0.4*sin(TIME*2.1+phase*1.7);
	world_vertex.xz += vec2(wind,wind*0.4)*wind_amplitude*tip*tip;
	for (int i=0;i<5;i++) {
		vec2 away = root.xz-actors[i].xz;
		float dist = length(away);
		float influence = (1.0-smoothstep(0.0,interaction_radius,dist))*actors[i].w;
		world_vertex.xz += away/max(dist,0.01)*influence*tip*0.5;
		world_vertex.y -= influence*tip*0.22;
	}
	world_vertex.y = mix(root.y,world_vertex.y,coverage);
	VERTEX = world_vertex;
	shade = 0.82+0.18*sin(phase);
}
void fragment() {
	vec4 color = texture(blades,UV);
	// Alpha scissor and stable screen-door distance fade; no alpha blending.
	float threshold = fract(dot(floor(FRAGCOORD.xy),vec2(0.75487766,0.56984029)));
	if (coverage < threshold) { discard; }
	ALBEDO = color.rgb*shade;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
