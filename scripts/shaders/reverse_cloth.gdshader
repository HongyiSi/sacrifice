shader_type canvas_item;
render_mode unshaded;
uniform sampler2D purple_texture : source_color, filter_linear;
uniform sampler2D cloth_row_bounds : filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool restoring = false;
uniform float magic_amount = 0.0;
uniform float magic_clock = 0.0;

float leaf_edge(vec2 p,vec2 a,vec2 b) {
    vec2 d=b-a;
    return (d.x*(p.y-a.y)-d.y*(p.x-a.x))/length(d);
}

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec3 textile = texture(purple_texture, UV).rgb;
    // Exact scanline silhouette from the painted asset includes its ornamentation.
    // Interior coverage is solid, so warm lighting cannot leave yellow blotches.
    vec2 bounds = texture(cloth_row_bounds,vec2(0.5,UV.y)).rg;
    float x = UV.x*1536.0;
    float coverage = smoothstep(bounds.x*1536.0-0.8,bounds.x*1536.0+0.8,x)
                   * (1.0-smoothstep(bounds.y*1536.0-0.8,bounds.y*1536.0+0.8,x));
    // Foreground ivy is taken from the original painting, including leaf tips.
    bool left_ivy = UV.x<0.157 && UV.y<0.30;
    bool right_ivy = UV.x>0.835 && UV.y>0.18 && UV.y<0.335;
    if (left_ivy || right_ivy) {
        float cloth_behind = smoothstep(0.45,0.58,original.b/max(original.g,0.001))
                           * smoothstep(0.025,0.070,original.r-original.g);
        coverage *= cloth_behind;
        // Reuse the painted foliage contact shadows on the newly dyed textile.
        float shadow = clamp(dot(original.rgb,vec3(0.26,0.60,0.14))/0.845,0.55,1.0);
        textile *= shadow;
    }
    // This candle-lit leaf tip is as warm as linen; its real outline overrides
    // the material classifier so every part of the original leaf stays intact.
    vec2 p=UV*vec2(1536.0,1024.0);
    float leaf=leaf_edge(p,vec2(186.5,229),vec2(191,227));
    leaf=min(leaf,leaf_edge(p,vec2(191,227),vec2(197,226.8)));
    leaf=min(leaf,leaf_edge(p,vec2(197,226.8),vec2(201,228)));
    leaf=min(leaf,leaf_edge(p,vec2(201,228),vec2(204,230)));
    leaf=min(leaf,leaf_edge(p,vec2(204,230),vec2(207,234)));
    leaf=min(leaf,leaf_edge(p,vec2(207,234),vec2(209,238)));
    leaf=min(leaf,leaf_edge(p,vec2(209,238),vec2(209.8,241)));
    leaf=min(leaf,leaf_edge(p,vec2(209.8,241),vec2(202,242.5)));
    leaf=min(leaf,leaf_edge(p,vec2(202,242.5),vec2(195,242.5)));
    leaf=min(leaf,leaf_edge(p,vec2(195,242.5),vec2(189,240)));
    leaf=min(leaf,leaf_edge(p,vec2(189,240),vec2(186.5,236)));
    leaf=min(leaf,leaf_edge(p,vec2(186.5,236),vec2(186.5,229)));
    coverage*=1.0-smoothstep(-0.45,0.2,leaf);
    float y = clamp((UV.y*1024.0-103.0)/887.0,0.0,1.0);
    float fibers = (textile.r+textile.b-2.0*textile.g-0.27)*0.025;
    float front = mix(-0.075,1.075,progress);
    float amount = 1.0-smoothstep(front-0.075,front+0.075,y+fibers);
    if (restoring) {
        float returning_front = mix(1.075,-0.075,progress);
        amount = 1.0-smoothstep(returning_front-0.075,returning_front+0.075,y+fibers);
    }
    if ((!restoring && progress<=0.0) || (restoring && progress>=1.0)) amount=0.0;
    if ((!restoring && progress>=1.0) || (restoring && progress<=0.0)) amount=1.0;
    vec3 result=mix(original.rgb,textile,coverage*amount);
    float glow_front=mix(-0.075,1.075,progress);
    if (restoring) glow_front=mix(1.075,-0.075,progress);
    float seam=exp(-pow((y+fibers-glow_front)/0.0105,2.0));
    float variation=0.42+0.24*sin(UV.x*53.0+magic_clock*1.1)+0.20*sin(UV.x*103.0-magic_clock*2.2);
    vec3 light=restoring?vec3(1.0,0.82,0.42):vec3(0.79,0.59,1.0);
    result+=light*seam*variation*coverage*magic_amount*0.14;
    COLOR=vec4(result,original.a);
}
