extends Control
## Only the transition illumination fades; the stage title remains visible.
var started := 0
var tint := Color("a9d4ed")
var age := 0.0
var title_label: Label
var detail_label: Label
var pop_title := false
var pop_detail := false

static func pop_scale(seconds: float) -> float:
	if seconds < 0.18: return lerpf(1.0,1.28,smoothstep(0,0.18,seconds))
	if seconds < 0.34: return 1.28
	return lerpf(1.28,1.0,smoothstep(0.34,0.82,seconds))

func _pop(label: Label, enabled: bool) -> void:
	if not is_instance_valid(label): return
	label.pivot_offset = label.size/2
	label.scale = Vector2.ONE*(pop_scale(age) if enabled else 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_process(0)

func _process(_delta: float) -> void:
	age = (Time.get_ticks_msec()-started)/1000.0
	_pop(title_label,pop_title)
	_pop(detail_label,pop_detail)
	queue_redraw()
	if age >= 1.35: set_process(false)

func _draw() -> void:
	if age >= 1.35: return
	var enter := smoothstep(0,0.16,age)
	var alpha := enter*(1-smoothstep(0.99,1.35,age))
	var rect := Rect2(Vector2.ZERO,size)
	for i in range(5,0,-1):
		draw_rect(rect.grow(i*1.7),Color(tint,alpha*0.038),false,2.0,true)
	draw_rect(rect,Color(tint,alpha*0.075))
	var extent := 188*enter
	draw_line(Vector2(208-extent,5),Vector2(208+extent,5),Color(tint,alpha*0.85),1.5,true)
	draw_line(Vector2(208-extent,73),Vector2(208+extent,73),Color(tint,alpha*0.85),1.5,true)
	var sweep := lerpf(11,405,clampf(age/0.75,0,1))
	if age < 0.85:
		for i in range(6):
			draw_line(Vector2(sweep-i*6,66),Vector2(sweep-i*6+4,66),Color(tint,alpha*(1-i/6.0)),2.5,true)
