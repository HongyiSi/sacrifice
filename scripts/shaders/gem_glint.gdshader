shader_type canvas_item;
render_mode unshaded;
uniform float pulse=0.;
uniform float sweep=0.;
uniform vec4 tint:source_color=vec4(.4,.8,1.,1.);
void fragment(){vec4 c=texture(TEXTURE,UV);float value=max(max(c.r,c.g),c.b);float band=exp(-pow((UV.x*.82+UV.y*.48-sweep)/.10,2.));float facet=smoothstep(.22,.85,value);vec3 rgb=c.rgb+mix(tint.rgb,vec3(1.),.72)*(band*.48*facet+pulse*.15);COLOR=vec4(rgb,c.a);}
