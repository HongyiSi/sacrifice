shader_type canvas_item;
render_mode unshaded;
uniform vec4 atlas_rect=vec4(0.0,0.0,1.0,1.0);
uniform vec4 frame_color:source_color=vec4(0.8,0.55,0.16,1.0);
uniform vec4 shine_color:source_color=vec4(1.0,0.92,0.72,1.0);
uniform float clock=0.0;
uniform int family=0;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
float box(vec2 p,vec2 a,vec2 b){return step(a.x,p.x)*step(a.y,p.y)*step(p.x,b.x)*step(p.y,b.y);}
void fragment(){
 vec4 src=texture(TEXTURE,UV);vec2 p=(UV-atlas_rect.xy)/atlas_rect.zw;
 float left=1.0-smoothstep(.060,.094,p.x);float right=smoothstep(.906,.94,p.x);
 float top=1.0-smoothstep(.025,.061,p.y);float bottom=smoothstep(.937,.976,p.y);
 vec2 corner=vec2(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
 float caps=(1.0-smoothstep(.185,.210,corner.x+corner.y))*step(corner.x,.20)*step(corner.y,.16);
 float diamond=box(p,vec2(.478,.063),vec2(.559,.163));
 float frame=max(max(max(left,right),max(top,bottom)),max(caps,diamond));
 // Preserve the approved illustration window, paper, numeral fields and title.
 float paper=box(p,vec2(.135,.230),vec2(.865,.780));
 float name=box(p,vec2(.155,.817),vec2(.845,.938));
 float digits=max(box(p,vec2(.108,.067),vec2(.461,.168)),box(p,vec2(.590,.067),vec2(.884,.168)));
 frame*=1.0-max(paper,max(name,digits));
 float l=dot(src.rgb,vec3(.27,.58,.15));
 float ink=smoothstep(.08,.22,l);
 float light=smoothstep(.72,.94,l);
 vec3 tint=frame_color.rgb*(.26+l*1.17);
 tint=mix(tint,shine_color.rgb,light*.85);
 float band=pow(max(0.0,sin((p.x*.68+p.y-.18*TIME)*6.2831853)),20.0);
 tint+=shine_color.rgb*band*(family==0?.14:.075);
 if(family==4){tint=vec3(.018,.023,.030)+vec3(.12,.135,.15)*l+vec3(.045)*light;}
 src.rgb=mix(src.rgb,tint,frame*ink*(family==4?1.0:.92));
 COLOR=src*item_tint;
}
