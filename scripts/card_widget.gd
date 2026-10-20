extends Button
const Symbols = preload("res://scripts/art_symbols.gd")
const PRIORITY_FONT = preload("res://assets/fonts/card_priority.tres")
var card: Dictionary = {}
var death := false
var hidden_card := false
var selected := false
var selection_order := 0
var priority_bonus := 0
var team_color := Color("345c86")
var compact := false
var expanded := false
var targetable := false
var action_status := ""
var card_size := Vector2(76,108)
var resolution_started := -1
var resolution_origin := Vector2.ZERO
var resolution_scale := Vector2.ONE
var resolution_destination := Vector2.ZERO
var resolution_factor := 1.13
var returning := false
var return_from := Vector2.ZERO
var return_scale := Vector2.ONE
var motif_alpha := 1.0
var status_label: Label
var immediate_hover := false

func start_resolution(started: int, destination: Vector2 = Vector2.INF, factor: float = 1.13) -> void:
	resolution_started = started
	resolution_origin = position
	resolution_scale = scale
	resolution_factor = factor
	resolution_destination = destination if destination.is_finite() else resolution_origin-Vector2(size.x*resolution_scale.x*0.065,13)
	z_index = 3
	_process(0)

func start_return(started: int, from: Vector2, from_scale: Vector2) -> void:
	resolution_started = started
	resolution_origin = position
	resolution_scale = scale
	return_from = from
	return_scale = from_scale
	returning = true
	z_index = 3
	_process(0)

func emblem_center() -> Vector2:
	return Vector2(size.x*.5,(size.y-4*size.x/76.0)*.5025)

func _process(_delta: float) -> void:
	if glow_enabled(): queue_redraw()
	if resolution_started < 0 or expanded: return
	if returning:
		var progress := clampf((Time.get_ticks_msec()-resolution_started)/240.0,0,1)
		var ease := smoothstep(0,1,progress)
		position = return_from.lerp(resolution_origin,ease)
		scale = return_scale.lerp(resolution_scale,ease)
		if progress >= 1:
			resolution_started = -1
			z_index = 0
		return
	var t := clampf((Time.get_ticks_msec()-resolution_started)/200.0,0,1)
	var eased := 1.0-pow(1.0-t,3)
	scale = resolution_scale*lerpf(1.0,resolution_factor,eased)
	position = resolution_origin.lerp(resolution_destination,eased)
	if is_instance_valid(status_label):
		status_label.position = position+Vector2((size.x*scale.x-status_label.size.x)/2,size.y*scale.y+3)

func glow_enabled() -> bool:
	return false # Animated frame children have their own clocks; avoid redrawing the face.

func rarity_border() -> Color:
	var palette=preload("res://scripts/art_ui/priority_style.gd")
	var group=palette.group_for(card,death,hidden_card)
	return palette.PALETTE[group] if group>=0 else Color("796040")

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = card_size
	for style in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(style,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _get_minimum_size() -> Vector2:
	return card_size

func _draw() -> void:
	if hidden_card:
		preload("res://scripts/art_ui/back_design.gd").draw(self,death)
		return
	preload("res://scripts/art_ui/frame_design.gd").draw_card(self,card,death,false,selected,priority_bonus)
	preload("res://scripts/art_ui/card_marks.gd").draw(self)

func _draw_priority(font: Font, value: String, at: Vector2, ink: Color, font_size: int) -> void:
	# Rounded, bundled bold numerals render identically on desktop and Web.
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)

func _center_text(value: String, baseline: float, font_size: int, color: Color) -> void:
	draw_string(get_theme_font("font"),Vector2(3,baseline),value,HORIZONTAL_ALIGNMENT_CENTER,size.x-6,font_size,color)

func _get_tooltip(_at: Vector2) -> String:
	return "" if immediate_hover else tooltip_text

func _make_custom_tooltip(for_text: String) -> Object:
	# A queued native tooltip can outlive the mouse-enter handler. Never build
	# its empty frame when the board already owns the immediate description.
	if immediate_hover or for_text.strip_edges().is_empty(): return null
	return make_description(for_text)

func make_description(for_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_meta("hover_card_description",int(card.get("id",0)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f3e4c5")
	box.border_color = Color("a08358")
	box.set_border_width_all(2); box.set_corner_radius_all(8)
	box.content_margin_left = 16; box.content_margin_right = 16
	box.content_margin_top = 12; box.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",preload("res://scripts/art_ui/ui_chrome.gd").panel_style(20))
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 470 if str(card.get("text","")).length() > 75 else 340
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color("3b3430"))
	panel.add_child(label)
	return panel
