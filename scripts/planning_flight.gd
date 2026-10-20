extends Node
## Local planning only. Animate the real clickable widget, never a network event.
const DURATION_MS := 300
var card: Control
var started := 0
var from_position := Vector2.ZERO
var to_position := Vector2.ZERO
var from_scale := Vector2.ONE
var to_scale := Vector2.ONE
var base_z := 0
var arc := 0.0

func configure(widget: Control, source: Rect2, start_time: int, canvas: Control) -> void:
	card = widget
	started = start_time
	var parent_origin: Vector2 = canvas.get_global_transform().affine_inverse()*card.get_parent().global_position
	from_position = source.position-parent_origin
	to_position = card.position
	from_scale = source.size/card.size
	to_scale = card.scale
	base_z = card.z_index
	arc = minf(24.0,from_position.distance_to(to_position)*0.09)
	card.z_index = 20
	if is_instance_valid(card.status_label): card.status_label.visible = false
	set_meta("planning_flight_card",int(card.card.id))
	present(Time.get_ticks_msec())

func _process(_delta: float) -> void:
	present(Time.get_ticks_msec())

func present(now: int) -> void:
	if not is_instance_valid(card): queue_free(); return
	var t := clampf(float(now-started)/DURATION_MS,0,1)
	var eased := smoothstep(0,1,t)
	card.position = from_position.lerp(to_position,eased)-Vector2(0,sin(t*PI)*arc)
	card.scale = from_scale.lerp(to_scale,eased)
	if t >= 1:
		card.position = to_position
		card.scale = to_scale
		card.z_index = base_z
		if is_instance_valid(card.status_label): card.status_label.visible = true
		set_process(false)
		queue_free()
