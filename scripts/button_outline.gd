extends Control
## Match the selectable pawns' pulse without intercepting button input.
const TargetOutline = preload("res://scripts/target_outline.gd")
var target: Button
var stroke_width := TargetOutline.MIN_WIDTH

func initialize(button: Button) -> void:
	target = button
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_process(0)

func _process(_delta: float) -> void:
	if not is_instance_valid(target): return
	visible = not target.disabled
	stroke_width = TargetOutline.width_at(Time.get_ticks_msec()/1000.0,target.is_hovered())
	queue_redraw()

func _draw() -> void:
	# Use the same solid, centered strokes as pawn targeting: the outer edge
	# expands and contracts, while both colors and opacity stay constant.
	var radius := 8.0
	var centers := [Vector2(size.x-radius,radius),size-Vector2.ONE*radius,
		Vector2(radius,size.y-radius),Vector2.ONE*radius]
	var points := PackedVector2Array()
	for corner in range(4):
		for step in range(13):
			var angle := (-1+corner+step/12.0)*PI/2
			points.append(centers[corner]+Vector2(cos(angle),sin(angle))*radius)
	points.append(points[0])
	draw_polyline(points,Color("97701f"),(stroke_width+0.7)*2,true)
	draw_polyline(points,Color("ffd15c"),stroke_width*2,true)
