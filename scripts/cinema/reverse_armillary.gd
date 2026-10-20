extends RefCounted
const Art = preload("res://scripts/cinema/atlas.gd")
const Timing = preload("res://scripts/reverse_timing.gd")

static func draw(canvas: CanvasItem, origin: Vector2, age: float) -> void:
	if age < 0.55 or age > 4.5: return
	var launch := smoothstep(0.55,1.30,age)
	var opacity := smoothstep(0.55,0.70,age) * (1.0-smoothstep(3.65,4.40,age))
	var endpoint := Vector2(clampf(origin.x+145,300,1170),396)
	var at := origin.lerp(endpoint,launch) + Vector2(0,-20*sin(PI*launch))
	var side := lerpf(47.0,206.0,launch)
	var angle := PI*smoothstep(Timing.ROTATE_START,Timing.ROTATE_END,age)
	var tex: AtlasTexture = Art.texture("reverse")
	var ratio := side/307.0
	var top_left := at-Vector2(221,307)*ratio*0.5
	# Retain the approved bearing pivot, fixed wood pedestal and original shading.
	var pedestal := Rect2(tex.region.position+Vector2(0,225),Vector2(221,82))
	canvas.draw_texture_rect_region(tex.atlas,Rect2(top_left+Vector2(0,225)*ratio,pedestal.size*ratio),pedestal,Color(1,1,1,opacity))
	var pivot := Vector2(110.5,122.0)
	canvas.draw_set_transform(top_left+pivot*ratio,angle,Vector2.ONE*ratio)
	canvas.draw_texture_rect_region(tex.atlas,Rect2(-pivot,Vector2(221,225)),Rect2(tex.region.position,Vector2(221,225)),Color(1,1,1,opacity))
	canvas.draw_set_transform(Vector2.ZERO)
