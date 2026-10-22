extends RefCounted
const Chrome = preload("res://scripts/art_ui/ui_chrome.gd")
const Tutorial = preload("res://scripts/tutorial.gd")

static func build(board) -> void:
	var ui = board.ui
	var lesson = ui.session.tutorial
	var content: Dictionary = lesson.lesson()
	var focus: Dictionary = lesson.focus()
	var target: Control
	if not focus.is_empty(): target = find_tag(board.canvas,focus.keys()[0],focus.values()[0])
	# The lesson supplies the instructions; retain the real response button.
	# Duplicating both instruction panels crowds the resolving card out of view.
	var decision := find_tag(board.canvas,"decision_panel",true)
	if decision != null: decision.hide()
	var rect: Rect2 = lesson.panel_rect()
	var panel := Panel.new()
	panel.position = rect.position; panel.size = rect.size
	panel.add_theme_stylebox_override("panel",Chrome.panel_style())
	panel.z_index = 70; panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("tutorial_panel",true)
	board.canvas.add_child(panel)
	Chrome.text(panel,content.title,Rect2(19,12,332,30),21)
	Chrome.text(panel,"教程 · %d / 6" % content.chapter,Rect2(371,16,110,24),14,Chrome.MUTED)
	var body := RichTextLabel.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("normal_font",Chrome.CN)
	body.add_theme_font_size_override("normal_font_size",17)
	body.add_theme_constant_override("line_separation",0)
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.text = content.body
	panel.add_child(body)
	body.position = Vector2(19,46); body.size = Vector2(462,100)
	body.set_meta("tutorial_body",true)
	if not content.hint.is_empty():
		Chrome.text(panel,content.hint,Rect2(19,144,462,20),14,Color("914831"))
		# Feedback remains visible until the correct action or next explanation.
		panel.size.y = 217
	var footer: float = panel.size.y-46
	var restart = board._button(panel,"重新开始",Rect2(19,footer,110,32),func(): ui.session.start_tutorial(ui.saved_name))
	restart.set_meta("tutorial_restart",true)
	var previous = board._button(panel,"上一步",Rect2(145,footer,110,32),func(): ui._tutorial_previous())
	previous.disabled = lesson.playing or lesson.history.size() < 2
	previous.set_meta("tutorial_previous",true)
	if not content.next.is_empty():
		var next = board._button(panel,content.next,Rect2(313,footer,168,32),func():
			board.clear_card_hover()
			ui.session.tutorial_next())
		next.set_meta("tutorial_next",true)
	elif lesson.step == Tutorial.Step.COMPLETE:
		board._button(panel,"确认",Rect2(313,footer,168,32),func(): ui.session.leave()).set_meta("tutorial_finish",true)
	elif lesson.step == Tutorial.Step.GUARD_REACT and target != null:
		target.reparent(panel)
		target.text = "确认"
		target.position = Vector2(313,footer); target.size = Vector2(168,32)
	else:
		Chrome.text(panel,"正在播放…" if lesson.playing or lesson.acknowledged else "按红框提示操作",Rect2(267,footer,214,32),15,Chrome.MUTED,true)
	if target != null:
		var marker := FocusRing.new()
		marker.target = target; marker.canvas = board.canvas
		marker.z_index = 80; marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.canvas.add_child(marker)
		marker.set_meta("tutorial_focus",true)
	# Spotlight the actual board regions rather than adding another diagram.
	if lesson.step == Tutorial.Step.BOARD:
		for id in range(3): mark(board,find_tag(board.canvas,"health_actor",id))
	elif lesson.step == Tutorial.Step.HAND:
		mark(board,find_tag(board.canvas,"hand_slots_actor",0))
	elif lesson.step == Tutorial.Step.DEATH_CARD:
		mark(board,find_tag(board.canvas,"death_fan_actor",0))

static func mark(board, target: Control) -> void:
	if target == null: return
	var marker := FocusRing.new()
	marker.target = target; marker.canvas = board.canvas
	marker.z_index = 60; marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.canvas.add_child(marker)

static func find_tag(root: Node, tag: String, value) -> Control:
	if root is Control and root.has_meta(tag) and root.get_meta(tag) == value: return root
	for child in root.get_children():
		var found := find_tag(child,tag,value)
		if found != null: return found
	return null

static func rect_on_board(node: Control, canvas: Control) -> Rect2:
	var r := node.get_global_rect()
	return Rect2((r.position-canvas.global_position)/canvas.scale,r.size/canvas.scale)

static func overlap(rect: Rect2, obstacles: Array[Rect2]) -> float:
	var area := 0.0
	for obstacle in obstacles: area += rect.intersection(obstacle).get_area()
	return area

class FocusRing extends Control:
	var target: Control
	var canvas: Control
	var style := StyleBoxFlat.new()
	func _ready() -> void:
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color("df3434")
		style.set_corner_radius_all(7)
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		if not is_instance_valid(target) or not is_instance_valid(canvas): return
		var r := target.get_global_rect()
		r = Rect2((r.position-canvas.global_position)/canvas.scale,r.size/canvas.scale).grow(5)
		style.set_border_width_all(2+roundi((sin(Time.get_ticks_msec()/1500.0*TAU)+1.0)*0.5))
		draw_style_box(style,r)
