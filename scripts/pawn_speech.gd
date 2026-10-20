extends Control
## Reusable, nonblocking pawn dialogue. Call say() for a timed line, or drive
## present(age) from an existing animation clock to survive board rebuilds.
var body := Rect2()
var tail := PackedVector2Array()
var message_label: Label
var border := Color("aa8b57")
var duration := 2.0
var started := -1

func configure(actor: int, message: String, pawn: Rect2, tint: Color, seconds: float = 2.0) -> void:
	set_meta("pawn_speech",actor)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	duration = seconds
	border = tint.lerp(Color("aa8b57"),0.65)
	if message_label == null:
		message_label = Label.new()
		message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_label.add_theme_font_size_override("font_size",18)
		message_label.add_theme_color_override("font_color",Color("493c2a"))
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(message_label)
	message_label.text = message
	var measured := get_theme_font("font").get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	var width := clampf(measured+26,144,218)
	var height := maxf(48,ceilf(measured/(width-26))*25+20)
	var anchor := pawn.position+Vector2(30,48)
	body = Rect2(maxf(12,anchor.x-width-18),maxf(12,anchor.y-height/2),width,height)
	var right := body.end.x
	tail = PackedVector2Array([Vector2(right-2,anchor.y-8),anchor+Vector2(5,3),Vector2(right-2,anchor.y+10)])
	message_label.position = body.position+Vector2(13,10)
	message_label.size = body.size-Vector2(26,20)
	# Label initially measures wrapping at width zero; reapply the height once
	# its new width has invalidated that temporary multiline minimum size.
	message_label.set_deferred("size",body.size-Vector2(26,20))
	present(-1)
	queue_redraw()

func say(actor: int, message: String, pawn: Rect2, tint: Color = Color("355f89"), seconds: float = 2.0) -> void:
	configure(actor,message,pawn,tint,seconds)
	started = Time.get_ticks_msec()
	present(0)

func _process(_delta: float) -> void:
	if started >= 0: present((Time.get_ticks_msec()-started)/1000.0)

func present(age: float) -> void:
	visible = age >= 0 and age < duration
	modulate.a = minf(smoothstep(0,0.10,maxf(age,0)),1-smoothstep(maxf(0,duration-.30),duration,age))

func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fff1d5")
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(11)
	box.shadow_color = Color(0.20,0.13,0.07,0.18)
	box.shadow_size = 4
	box.shadow_offset = Vector2(1,3)
	draw_colored_polygon(tail,box.bg_color)
	draw_polyline(tail,border,2,true)
	preload("res://scripts/art_ui/ui_chrome.gd").nine(self,preload("res://scripts/art_ui/ui_chrome.gd").texture("panel"),body,10)
	draw_line(tail[0]+Vector2(-1,2),tail[2]+Vector2(-1,-2),box.bg_color,4,true)
