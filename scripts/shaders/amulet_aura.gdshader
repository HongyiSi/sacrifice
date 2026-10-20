shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 tint : source_color = vec4(1.,.6,.2,1.);
uniform float strength=0.;
uniform float clock_time=0.;
uniform float flatten=1.;
void fragment(){
 vec2 p=(UV-.5)*2.;p.y*=flatten;
 float r=length(p);float a=atan(p.y,p.x);
 float l=exp(-r*r*8.)*.32+exp(-r*r*29.)*.32;
 l*=.93+.07*sin(clock_time*4.+a*3.+r*8.);
 float rays=pow(abs(sin(a*3.+.3)),18.)*exp(-r*7.)*.16;
 COLOR=vec4(tint.rgb*(l+rays)*strength,1.);
}
