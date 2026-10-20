shader_type canvas_item;
render_mode unshaded;
uniform float progress=0.;
uniform float clock_time=0.;
uniform float ember_amount=0.;
uniform float variant=0.;
uniform vec4 ember_color : source_color=vec4(1.,.38,.08,1.);
uniform vec4 hot_color : source_color=vec4(1.,.94,.66,1.);
uniform vec2 face_origin;
uniform vec2 face_size;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return .56*noise(p)+.28*noise(p*2.04+8.7)+.13*noise(p*4.15+23.4);}
float field(vec2 p){
 vec2 q=(p-vec2(.5,.49))*vec2(.74,1.);
 float angle=atan(q.y,q.x);
 return length(q)*(1.+sin(angle*3.+1.4)*.065)+fbm(p*7.3+variant*3.7)*.16+noise(p*49.)*.020;
}
float bounds(vec2 p){return smoothstep(-.008,.01,p.x)*smoothstep(-.008,.01,p.y)*(1.-smoothstep(.99,1.008,p.x))*(1.-smoothstep(.99,1.008,p.y));}
vec4 over(vec4 a,vec4 b){float alpha=a.a+b.a*(1.-a.a);return vec4((a.rgb*a.a+b.rgb*b.a*(1.-a.a))/max(alpha,.0001),alpha);}
void fragment(){
 vec4 original=texture(TEXTURE,UV); vec2 p=(UV-face_origin)/face_size;
 float front=progress*.80-.013;
 float edge=field(p)-front;
 float live=smoothstep(-.009,.009,edge);
 float scorch=(1.-smoothstep(.02,.12,edge));
 float grain=noise(p*173.);
 vec3 ash=vec3(.047,.028,.025)*( .55+grain*.7);
 vec3 paper=mix(original.rgb,ash,scorch*.96);
 float rim=exp(-pow((edge-.009)/.020,2.));
 float coal=exp(-pow((edge-.025)/.038,2.))*(.7+.3*noise(p*70.-clock_time*3.));
 paper=mix(paper,ember_color.rgb*.65,coal*.65);
 paper+=mix(ember_color.rgb,hot_color.rgb,.68)*rim*1.1;
 float crinkle=noise(p*38.);
 float curled=1.-scorch*.18*(.5+.5*sin(p.x*110.+crinkle*13.));paper*=curled;
 float ending=1.-smoothstep(.96,1.,progress);
 vec4 base=vec4(paper,original.a*live*ending);
 float flame=0.;
 for(int i=0;i<7;i++){
   float lift=float(i)*(.053+variant*.004);
   float flow=fbm(vec2(p.x*16.,p.y*8.+clock_time*2.3));
   vec2 q=p+vec2((flow-.48)*.10*float(i),lift);
   float e=field(q)-front;
   float band=exp(-pow(e/.037,2.));
   float inside=bounds(q)*texture(TEXTURE,face_origin+q*face_size).a;
   float tongues=smoothstep(.21,.70,fbm(vec2(p.x*24.+float(i)*.47,p.y*15.+clock_time*(3.1+variant*.8))));
   flame+=band*inside*tongues*exp(-lift*6.5)*.58;
 }
 flame*=ember_amount;
 vec3 fire=mix(ember_color.rgb,hot_color.rgb,smoothstep(.20,.70,flame));
 vec4 fire_layer=vec4(fire*(1.+flame*.3),clamp(flame*.84,0.,.97));
 float blur=exp(-pow(edge/.080,2.))*bounds(p)*ember_amount;
 base=over(fire_layer,base);
 base.rgb+=ember_color.rgb*blur*.10;
 if(progress<=.0001){base=original;}
 COLOR=base;
}
