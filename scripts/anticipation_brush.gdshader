shader_type canvas_item;
render_mode unshaded;
uniform vec4 atlas_region;
uniform float reveal : hint_range(0.0,1.0) = 1.0;
void fragment() {
	vec2 local_uv=(UV-atlas_region.xy)/atlas_region.zw;
	// The bristle tips advance unevenly, rather than exposing a straight rectangle.
	float bristle=sin(local_uv.y*119.0)*.016+sin(local_uv.y*37.0)*.010;
	float head=reveal+bristle*sin(reveal*3.14159265);
	float coverage=1.0-smoothstep(head-.018,head+.006,local_uv.x);
	if(reveal>=.999)coverage=1.0;
	if(reveal<=.001)coverage=0.0;
	COLOR.a*=coverage;
}
