shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float clock_time = 0.0;
uniform vec4 ember_color : source_color = vec4(1.0,0.66,0.14,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,0.97,0.72,1.0);
uniform vec2 face_origin = vec2(0.1935,0.1538);
uniform vec2 face_size = vec2(0.6129,0.6923);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec4 original=texture(TEXTURE,UV);
 vec2 p=(UV-face_origin)/face_size;
 vec2 delta=(p-vec2(0.5,0.49))*vec2(0.78,1.0);
 float rough=noise(p*13.0)*0.070+noise(p*33.0)*0.025;
 float dist=length(delta)+rough;
 float front=progress*0.715-0.015;
 float edge=dist-front;
 float alive=smoothstep(-0.012,0.009,edge);
 float rim=1.0-smoothstep(0.009,0.055,edge);
 float charred=1.0-smoothstep(0.044,0.120,edge);
 vec3 paper=mix(original.rgb,ember_color.rgb*.45,charred*0.24);
 float flicker=0.94+0.06*sin(clock_time*7.0);
 vec3 fire=mix(ember_color.rgb,hot_color.rgb,1.0-smoothstep(0.005,0.026,edge));
 paper=mix(paper,fire*flicker,rim);
 if(progress<0.002){paper=original.rgb;alive=1.0;}
 if(progress>0.995){alive=0.0;}
 COLOR=vec4(paper,original.a*alive);
}
