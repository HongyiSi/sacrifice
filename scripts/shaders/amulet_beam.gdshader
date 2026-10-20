shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0,.45,.10,1.0);
uniform vec4 hot : source_color = vec4(1.0,.95,.77,1.0);
uniform float clock_time = 0.0;
uniform float strength = 0.0;
uniform float head = 0.0;
uniform float tail = 0.0;
uniform float variant = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float x=UV.x; float y=UV.y-.5;
 float flow=noise(vec2(x*19.-clock_time*12.,clock_time*.8));
 float spread=.022+flow*.018;
 float bend=sin(x*17.-clock_time*7.)*.012*sin(x*3.14159);
 float d=abs(y-bend);
 float window=smoothstep(tail-.025,tail+.014,x)*(1.-smoothstep(head-.016,head+.025,x));
 window*=smoothstep(0.,.018,x)*(1.-smoothstep(.987,1.,x));
 float core=exp(-pow(d/.0065,2.));
 float body=exp(-pow(d/spread,2.))*.88;
 float haze=exp(-pow(d/.100,2.))*.16;
 float strands=0.;
 for(int i=0;i<3;i++){
   float f=float(i);float ribbon=sin(x*(20.+f*5.)-clock_time*(8.+f*.8)+f*2.1)*(.025+variant*.012)*sin(x*3.14159);
   strands+=exp(-pow((y-ribbon)/.004,2.))*(.05+.045*flow);
 }
 float knots=pow(noise(vec2(x*38.-clock_time*21.,clock_time)),5.0)*exp(-pow(d/.055,2.))*.55;
 float energy=clamp(core+body+haze+strands+knots,0.,1.);
 vec3 light=mix(tint.rgb,hot.rgb,clamp(core*.84+knots*.6,0.,1.));
 COLOR=vec4(light,energy*window*strength);
}
