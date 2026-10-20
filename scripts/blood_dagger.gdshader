shader_type canvas_item;
render_mode unshaded;
uniform vec2 region_start=vec2(0.0);
uniform vec2 region_size=vec2(1.0);
uniform float blood=0.0;
uniform float buried=0.0;
varying vec4 sprite_tint;
void vertex(){sprite_tint=COLOR;}
float hash(vec2 p){return fract(sin(dot(p,vec2(41.93,27.17)))*14387.53);}
float noise(vec2 p){
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
	vec4 tex=texture(TEXTURE,UV);
	vec2 q=(UV-region_start)/region_size;
	vec2 tip=vec2(.032,.970),axis=normalize(vec2(.63,-.77));
	vec2 d=q-tip;float along=dot(d,axis),across=dot(d,vec2(-axis.y,axis.x));
	float edge=.142+noise(q*57.0)*.033+noise(q*127.0)*.011;
	float patch=(1.0-smoothstep(edge-.012,edge+.014,along));
	patch*=smoothstep(-.01,.018,along)*(1.0-smoothstep(.028,.055,abs(across)));
	patch*=smoothstep(.035,.16,tex.r)*blood;
	float lum=dot(tex.rgb,vec3(.21,.71,.08));
	vec3 wet=vec3(.21,.012,.028)*(0.58+lum*.95);
	wet+=vec3(.13,.024,.032)*noise(q*85.0);
	float gleam=exp(-pow((across+.010)/.004,2.0))*smoothstep(.022,.06,along)*(1.0-smoothstep(.105,.14,along));
	wet+=vec3(.40,.15,.13)*gleam*.6;
	tex.rgb=mix(tex.rgb,wet,patch*.93);
	// Hide only the inserted few millimetres while the knife touches the chest.
	if(buried>.001)tex.a*=smoothstep(buried-.004,buried+.004,along);
	COLOR=tex*sprite_tint;
}
