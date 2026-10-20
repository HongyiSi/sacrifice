shader_type canvas_item;
render_mode unshaded;
uniform vec4 atlas_rect=vec4(0,0,1,1);
uniform float hover=0.0;
uniform float press=0.0;
uniform float locked=0.0;
uniform float clock=0.0;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
 vec4 s=texture(TEXTURE,UV);vec2 p=(UV-atlas_rect.xy)/atlas_rect.zw;
 float edge=max(1.0-smoothstep(.12,.22,p.x),smoothstep(.78,.88,p.x));
 edge=max(edge,max(1.0-smoothstep(.18,.28,p.y),smoothstep(.72,.82,p.y)));
 float band=pow(max(0.0,1.0-abs((p.x+p.y*.13)-fract(clock*.23)*1.6+.2)/.13),2.0);
 float ink=smoothstep(.09,.25,dot(s.rgb,vec3(.27,.58,.15)));
 s.rgb+=vec3(1.0,.70,.28)*edge*ink*hover*(.07+.18*band);
 s.rgb*=1.0-.13*press;
 s.rgb=mix(s.rgb,s.rgb*vec3(.84,.83,.77),locked*.55);
 COLOR=s*item_tint;
}
