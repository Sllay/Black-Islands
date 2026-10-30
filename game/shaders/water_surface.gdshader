shader_type spatial;
render_mode cull_disabled;
uniform bool ocean = false;
uniform float blend = 1.0;
uniform float wave_amplitude = 0.04;
uniform float foam_strength = 0.4;
uniform vec4 emitters[4];
varying float depth;
varying vec2 flow;
varying vec3 location;
void vertex() {
 depth = ocean ? 12.0 : UV.x;
 flow = ocean ? vec2(0.2,0.05) : UV2;
 VERTEX.y += ocean ? 0.0 : UV.y*(1.0-blend);
 location = VERTEX;
 float wave = sin(VERTEX.x*1.7+TIME*1.6)+0.35*cos(VERTEX.z*2.3-TIME*2.0);
 VERTEX.y += wave*wave_amplitude*clamp(depth,0.0,1.0);
}
void fragment() {
 if (!ocean && depth < 0.008) { discard; }
 vec2 moving = location.xz-flow*TIME;
 float detail = sin(moving.x*3.0+moving.y*1.4+TIME)*cos(moving.y*2.2-TIME*0.8);
 float crest = pow(max(0.0,detail),8.0);
 float shore = (1.0-smoothstep(0.02,0.7,depth))*(0.5+0.5*sin(TIME*2.0+location.x*2.0));
 float ripple = 0.0;
 for (int i=0;i<4;i++) {
  float dist = distance(location.xz,emitters[i].xz);
  ripple += sin(dist*9.0-TIME*6.0)*exp(-dist*dist*0.8)*emitters[i].w;
 }
 vec3 shallow = vec3(0.12,0.65,0.58);
 vec3 deep = vec3(0.015,0.12,0.24);
 ALBEDO = mix(shallow,deep,1.0-exp(-depth*0.3));
 ALBEDO += (crest*0.12+shore*foam_strength+abs(ripple)*0.05)*vec3(0.6,0.8,0.8);
 NORMAL_MAP = vec3(0.5+detail*0.045,0.5+sin(moving.y*2.0+TIME)*0.045,1.0);
 ROUGHNESS = 0.24;
 SPECULAR = 0.65;
}
