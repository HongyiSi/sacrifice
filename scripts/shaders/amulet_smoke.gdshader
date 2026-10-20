shader_type canvas_item;
render_mode unshaded;
uniform float clock_time=0.;
uniform float strength=0.;
uniform vec4 tint : source_color=vec4(.25,.19,.16,1.);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return n(p)*.55+n(p*2.04+4.7)*.28+n(p*4.11+9.3)*.14;}
void fragment(){
 vec2 p=UV;float lift=1.-p.y;
 float curl=fbm(vec2(p.x*4.,p.y*5.+clock_time*.6));
 float center=.5+sin(lift*6.+clock_time*.5)*.06+(curl-.5)*.13;
 float plume=exp(-pow((p.x-center)/(.07+lift*.18),2.));
 float body=fbm(vec2(p.x*9.+curl*2.,p.y*9.+clock_time*1.15));
 float detail=fbm(vec2(p.x*28.,p.y*22.+clock_time*2.2));
 float alpha=plume*smoothstep(.29,.72,body)*(.65+detail*.35);
 alpha*=smoothstep(0.,.17,p.y)*(1.-smoothstep(.81,1.,p.y));
 COLOR=vec4(tint.rgb+vec3(body*.14),alpha*strength*.50);
}
