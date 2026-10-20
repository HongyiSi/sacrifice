shader_type canvas_item;
uniform sampler2D circle_source : filter_linear;
uniform vec2 source_size;
uniform vec4 frame_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 item_tint;
void vertex() {
	// Retain fade, selection dimming, and inherited CanvasItem modulation.
	item_tint = COLOR;
}
void fragment() {
	vec2 p=(UV-frame_uv_rect.xy)/frame_uv_rect.zw*vec2(592.0,832.0)+vec2(8.0,0.0);
	vec2 source_px=vec2(526.5,699.0)+(p-vec2(304.0,411.0))*vec2(853.0/488.0,816.0/488.0);
	vec2 edge=min(p-vec2(36.0,158.0),vec2(574.0,664.0)-p);
	float blend=smoothstep(0.0,6.0,min(edge.x,edge.y));
	vec4 original=texture(TEXTURE,UV);
	vec4 rounded=texture(circle_source,source_px/source_size);
	COLOR=mix(original,rounded,blend)*item_tint;
}
