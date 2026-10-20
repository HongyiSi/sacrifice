shader_type canvas_item;
render_mode unshaded;
uniform bool friendly=true;
uniform bool filled=true;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
 vec4 s=texture(TEXTURE,UV)*item_tint;
 float mask=smoothstep(.13,.30,s.r-max(s.g,s.b));
 if(friendly){float lum=dot(s.rgb,vec3(.3,.55,.15));vec3 blue=vec3(.22,.52,.77)*(.35+lum*1.6);s.rgb=mix(s.rgb,blue,mask);}
 if(!filled){float lum=dot(s.rgb,vec3(.3,.55,.15));s.rgb=mix(vec3(.26,.20,.15),vec3(.60,.47,.32),lum);s.a*=.45;}
 COLOR=s;
}
